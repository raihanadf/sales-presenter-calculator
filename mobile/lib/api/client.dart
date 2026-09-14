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

  String? get token => _token;

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
      };

  Future<dynamic> _decode(http.Response r) async {
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 200 && r.statusCode < 300) return body;
    final msg = body is Map && body['error'] != null
        ? body['error'].toString()
        : 'request failed (${r.statusCode})';
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
    return AppUser.fromJson(body['user']);
  }

  // restores the persisted user for a still-valid token on app boot.
  Future<AppUser?> savedUser() async {
    if (_token == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('user');
    return raw == null ? null : AppUser.fromJson(jsonDecode(raw));
  }

  Future<void> logout() async {
    await _saveToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
  }

  // dashboards cache their last good payload so an offline reload shows the
  // last-known figures instead of a network error.
  Future<Dashboard> dashboard(String date, String month) async {
    return Dashboard.fromJson(await _cachedGet(
        '/api/dashboard?date=$date&month=$month', 'dash_admin_cache'));
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
    final r =
        await http.get(Uri.parse('$baseUrl/api/settings'), headers: _headers);
    final json = (await _decode(r))['settings'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings_cache', jsonEncode(json));
    return Settings.fromJson(json);
  }

  // last settings we saw online, so the entry form can preview offline.
  Future<Settings?> cachedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('settings_cache');
    return raw == null ? null : Settings.fromJson(jsonDecode(raw));
  }

  Future<Settings> updateSettings(Map<String, int> data) async {
    final r = await http.put(Uri.parse('$baseUrl/api/settings'),
        headers: _headers, body: jsonEncode(data));
    return Settings.fromJson((await _decode(r))['settings']);
  }

  Future<Computed> preview(
      int closingCount, int bopInput, int audienceCount, int? harian) async {
    final r = await http.post(Uri.parse('$baseUrl/api/entries/preview'),
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
    final uri = Uri.parse('$baseUrl/api/entries').replace(queryParameters: q);
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
        .replace(queryParameters: {'month': month});
    final r = await http.get(uri, headers: _headers);
    final body = await _decode(r);
    return (body['entries'] as List)
        .map((e) => SalesEntry.fromJson(e))
        .toList();
  }

  Future<List<AppUser>> presenters() async {
    final r =
        await http.get(Uri.parse('$baseUrl/api/presenters'), headers: _headers);
    final body = await _decode(r);
    return (body['presenters'] as List)
        .map((e) => AppUser.fromJson(e))
        .toList();
  }

  Future<AppUser> createPresenter(
      String name, String username, String password) async {
    final r = await http.post(Uri.parse('$baseUrl/api/presenters'),
        headers: _headers,
        body: jsonEncode(
            {'name': name, 'username': username, 'password': password}));
    return AppUser.fromJson((await _decode(r))['presenter']);
  }
}
