import 'package:flutter/foundation.dart';
import '../api/client.dart';
import '../api/models.dart';

// holds the api client + current user, and drives login/logout for the ui.
class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  AppUser? user;
  bool booting = true;

  bool get isLoggedIn => user != null;

  Future<void> boot() async {
    await api.loadToken();
    user = await api.savedUser();
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
}
