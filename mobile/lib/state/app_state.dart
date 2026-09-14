import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/client.dart';
import '../api/models.dart';
import '../theme.dart';

// holds the api client + current user, and drives login/logout for the ui.
class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  AppUser? user;
  bool booting = true;
  AppThemeStyle themeStyle = AppThemeStyle.pocket;

  bool get isLoggedIn => user != null;

  Future<void> boot() async {
    await api.loadToken();
    user = await api.savedUser();
    final prefs = await SharedPreferences.getInstance();
    themeStyle = prefs.getString('theme') == 'ledger' ? AppThemeStyle.ledger : AppThemeStyle.pocket;
    booting = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    user = await api.login(username, password);
    notifyListeners();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeStyle style) async {
    themeStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', style.name);
    notifyListeners();
  }
}
