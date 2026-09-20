import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

// thrown for any non-2xx response so the ui can surface the real message
// instead of silently falling back to empty data.
class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class ApiClient {
  // android emulator reaches the host machine via 10.0.2.2; override for a
  // real device/deployed worker.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://10.0.2.2:8787',
  );

  String? _token;

  // the branch every scoped request is read through. a branch admin and a
  // presenter always use their own; the superadmin switches it to drill into a
  // branch, or leaves it null to span all of them.
  int? activeBranchId;

  // this build's version, sent on every request so the server can refuse
  // writes from an app that is too old to be trusted with new data.
  String? appVersion;

  // called when the server answers 426: this build may no longer write.
  void Function()? onUpdateRequired;

  String? get token => _token;

  // appends the active branch to a query, when there is one to append.
  Map<String, String> _scoped(Map<String, String> query) => {
        ...query,
        if (activeBranchId != null) 'branchId': '$activeBranchId',
      };

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> _saveToken(String? value) async {
    _token = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('token');
    } else {
      await prefs.setString('token', value);
    }
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (appVersion != null) 'X-App-Version': appVersion!,
      };

  Future<dynamic> _decode(http.Response r) async {
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'request failed (${r.statusCode})';
    if (r.statusCode == 426) onUpdateRequired?.call();
    throw ApiException(r.statusCode, msg);
  }

  Future<AppUser> login(String username, String password) async {
    final r = await http.post(Uri.parse('$baseUrl/auth/login'),
        headers: _headers,
        body: jsonEncode({'username': username, 'password': password}));
    final body = await _decode(r);
    await _saveToken(body['token']);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(body['user']));
    final user = AppUser.fromJson(body['user']);
    activeBranchId = user.branchId;
    return user;
  }

  // restores the persisted user for a still-valid token on app boot.
  Future<AppUser?> savedUser() async {
    if (_token == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    if (raw == null) return null;
    final user = AppUser.fromJson(jsonDecode(raw));
    activeBranchId = user.branchId;
    return user;
  }

  // re-reads the account from the server so a role change or a branch move
  // shows up without logging out, and refreshes the cached copy.
  Future<AppUser> me() async {
    final r = await http.get(Uri.parse('$baseUrl/api/me'), headers: _headers);
    final body = await _decode(r);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(body['user']));
    final user = AppUser.fromJson(body['user']);
    activeBranchId = user.branchId;
    return user;
  }

  Future<void> logout() async {
    await _saveToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }

  // dashboards cache their last good payload so an offline reload shows the
  // last-known figures instead of a network error.
  Future<Dashboard> dashboard(String date, String month) async {
    final branch = activeBranchId == null ? '' : '&branchId=$activeBranchId';
    return Dashboard.fromJson(await _cachedGet(
        '/api/dashboard?date=$date&month=$month$branch',
        'dash_admin_cache_${activeBranchId ?? 'all'}'));
  }

  // the branches the superadmin can switch between or manage.
  Future<List<Branch>> branches() async {
    final r =
        await http.get(Uri.parse('$baseUrl/api/branches'), headers: _headers);
    final body = await _decode(r);
    return (body['branches'] as List).map((e) => Branch.fromJson(e)).toList();
  }

  // creates a branch with its own calculation values and its first admin.
  Future<NewBranch> createBranch(
      String name, Map<String, int> settings, String adminName,
      String adminUsername) async {
    final r = await http.post(Uri.parse('$baseUrl/api/branches'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'settings': settings,
          'admin': {'name': adminName, 'username': adminUsername},
        }));
    return NewBranch.fromJson(await _decode(r));
  }

  Future<Branch> updateBranch(int id, {String? name, bool? active}) async {
    final r = await http.patch(Uri.parse('$baseUrl/api/branches/$id'),
        headers: _headers,
        body: jsonEncode({
          if (name != null) 'name': name,
          if (active != null) 'active': active,
        }));
    return Branch.fromJson((await _decode(r))['branch']);
  }

  Future<List<AppUser>> branchMembers(int id) async {
    final r = await http.get(Uri.parse('$baseUrl/api/branches/$id/members'),
        headers: _headers);
    final body = await _decode(r);
    return (body['members'] as List).map((e) => AppUser.fromJson(e)).toList();
  }

  Future<void> changePassword(String current, String next) async {
    final r = await http.put(Uri.parse('$baseUrl/api/me/password'),
        headers: _headers,
        body:
            jsonEncode({'currentPassword': current, 'newPassword': next}));
    await _decode(r);
  }

  Future<MyDashboard> dashboardMe(String date, String month) async {
    return MyDashboard.fromJson(await _cachedGet(
        '/api/dashboard/me?date=$date&month=$month', 'dash_me_cache'));
  }

  // gets json, caching it on success; on a network error returns the last
  // cached copy. server errors (reachable) still throw.
  Future<Map<String, dynamic>> _cachedGet(String path, String cacheKey) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final r = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
      final json = await _decode(r) as Map<String, dynamic>;
      await prefs.setString(cacheKey, jsonEncode(json));
      return json;
    } on ApiException {
      rethrow;
    } catch (_) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) return jsonDecode(cached) as Map<String, dynamic>;
      rethrow;
    }
  }

  Future<Settings> settings() async {
    final uri =
        Uri.parse('$baseUrl/api/settings').replace(queryParameters: _scoped({}));
    final r = await http.get(uri, headers: _headers);
    final json = (await _decode(r))['settings'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_cache_${activeBranchId ?? 'all'}',
        jsonEncode(json));
    return Settings.fromJson(json);
  }

  // last settings we saw online, so the entry form can preview offline.
  Future<Settings?> cachedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings_cache_${activeBranchId ?? 'all'}');
    return raw == null ? null : Settings.fromJson(jsonDecode(raw));
  }

  Future<Settings> updateSettings(Map<String, int> data) async {
    final uri =
        Uri.parse('$baseUrl/api/settings').replace(queryParameters: _scoped({}));
    final r = await http.put(uri, headers: _headers, body: jsonEncode(data));
    return Settings.fromJson((await _decode(r))['settings']);
  }

  Future<Computed> preview(
      int closingCount, int bopInput, int audienceCount, int? harian) async {
    final uri = Uri.parse('$baseUrl/api/entries/preview')
        .replace(queryParameters: _scoped({}));
    final r = await http.post(uri,
        headers: _headers,
        body: jsonEncode({
          'closingCount': closingCount,
          'bopInput': bopInput,
          'audienceCount': audienceCount,
          if (harian != null) 'harian': harian,
        }));
    return Computed.fromJson((await _decode(r))['computed']);
  }

  Future<SalesEntry> createEntry(Map<String, dynamic> data) async {
    final r = await http.post(Uri.parse('$baseUrl/api/entries'),
        headers: _headers, body: jsonEncode(data));
    return SalesEntry.fromJson((await _decode(r))['entry']);
  }

  Future<EntryPage> entries({
    int? presenterId,
    String? from,
    String? to,
    int page = 1,
  }) async {
    final q = <String, String>{'page': '$page'};
    if (presenterId != null) q['presenterId'] = '$presenterId';
    if (from != null) q['from'] = from;
    if (to != null) q['to'] = to;
    final uri =
        Uri.parse('$baseUrl/api/entries').replace(queryParameters: _scoped(q));
    final r = await http.get(uri, headers: _headers);
    return EntryPage.fromJson(await _decode(r));
  }

  Future<SalesEntry> entry(int id) async {
    final r = await http.get(Uri.parse('$baseUrl/api/entries/$id'),
        headers: _headers);
    return SalesEntry.fromJson((await _decode(r))['entry']);
  }

  Future<SalesEntry> approveEntry(int id) async {
    final r = await http.post(Uri.parse('$baseUrl/api/entries/$id/approve'),
        headers: _headers);
    return SalesEntry.fromJson((await _decode(r))['entry']);
  }

  // admin bulk import: one presenter, many dated rows. returns inserted count.
  Future<int> bulkImport(
      int presenterId, List<Map<String, dynamic>> rows) async {
    final r = await http.post(Uri.parse('$baseUrl/api/entries/bulk'),
        headers: _headers,
        body: jsonEncode({'presenterId': presenterId, 'rows': rows}));
    return (await _decode(r))['inserted'] as int;
  }

  // admin month recap: every approved entry in a yyyy-mm period, unpaginated.
  Future<List<SalesEntry>> monthEntries(String month) async {
    final uri = Uri.parse('$baseUrl/api/entries/month')
        .replace(queryParameters: _scoped({'month': month}));
    final r = await http.get(uri, headers: _headers);
    final body = await _decode(r);
    return (body['entries'] as List)
        .map((e) => SalesEntry.fromJson(e))
        .toList();
  }

  Future<List<AppUser>> presenters() async {
    final uri = Uri.parse('$baseUrl/api/presenters')
        .replace(queryParameters: _scoped({}));
    final r = await http.get(uri, headers: _headers);
    final body = await _decode(r);
    return (body['presenters'] as List)
        .map((e) => AppUser.fromJson(e))
        .toList();
  }

  Future<AppUser> createPresenter(
      String name, String username, String password) async {
    final r = await http.post(Uri.parse('$baseUrl/api/presenters'),
        headers: _headers,
        body: jsonEncode({
          'name': name,
          'username': username,
          'password': password,
          if (activeBranchId != null) 'branchId': activeBranchId,
        }));
    return AppUser.fromJson((await _decode(r))['presenter']);
  }

  // superadmin only: move a presenter to another branch. past entries stay
  // with the branch they were recorded in.
  // superadmin only: issue a new password for an account whose owner forgot
  // theirs. the new password comes back once and is never stored in clear text.
  Future<String> resetPassword(int userId) async {
    final r = await http.post(
        Uri.parse('$baseUrl/api/users/$userId/reset-password'),
        headers: _headers);
    return (await _decode(r))['password'] as String;
  }

  Future<AppUser> movePresenter(int presenterId, int branchId) async {
    final r = await http.patch(
        Uri.parse('$baseUrl/api/presenters/$presenterId/branch'),
        headers: _headers,
        body: jsonEncode({'branchId': branchId}));
    return AppUser.fromJson((await _decode(r))['presenter']);
  }
}
