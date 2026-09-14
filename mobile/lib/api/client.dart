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
        headers: _headers, body: jsonEncode({'username': username, 'password': password}));
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

  Future<Dashboard> dashboard(String date, String month) async {
    final r = await http.get(
        Uri.parse('$baseUrl/api/dashboard?date=$date&month=$month'),
        headers: _headers);
    return Dashboard.fromJson(await _decode(r));
  }

  Future<MyDashboard> dashboardMe(String date, String month) async {
    final r = await http.get(
        Uri.parse('$baseUrl/api/dashboard/me?date=$date&month=$month'),
        headers: _headers);
    return MyDashboard.fromJson(await _decode(r));
  }

  Future<Settings> settings() async {
    final r = await http.get(Uri.parse('$baseUrl/api/settings'), headers: _headers);
    return Settings.fromJson((await _decode(r))['settings']);
  }

  Future<Settings> updateSettings(Map<String, int> data) async {
    final r = await http.put(Uri.parse('$baseUrl/api/settings'),
        headers: _headers, body: jsonEncode(data));
    return Settings.fromJson((await _decode(r))['settings']);
  }

  Future<Computed> preview(int closingCount, int bopInput, int audienceCount, int? harian) async {
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

  Future<List<SalesEntry>> entries({int? presenterId, String? from, String? to}) async {
    final q = <String, String>{};
    if (presenterId != null) q['presenterId'] = '$presenterId';
    if (from != null) q['from'] = from;
    if (to != null) q['to'] = to;
    final uri = Uri.parse('$baseUrl/api/entries').replace(queryParameters: q.isEmpty ? null : q);
    final r = await http.get(uri, headers: _headers);
    final body = await _decode(r);
    return (body['entries'] as List).map((e) => SalesEntry.fromJson(e)).toList();
  }

  Future<List<AppUser>> presenters() async {
    final r = await http.get(Uri.parse('$baseUrl/api/presenters'), headers: _headers);
    final body = await _decode(r);
    return (body['presenters'] as List).map((e) => AppUser.fromJson(e)).toList();
  }

  Future<AppUser> createPresenter(String name, String username, String password) async {
    final r = await http.post(Uri.parse('$baseUrl/api/presenters'),
        headers: _headers,
        body: jsonEncode({'name': name, 'username': username, 'password': password}));
    return AppUser.fromJson((await _decode(r))['presenter']);
  }
}
