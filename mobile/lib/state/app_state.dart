import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/client.dart';
import '../api/models.dart';
import '../theme.dart';
import 'offline_queue.dart';

// holds the api client + current user, and drives login/logout for the ui.
class AppState extends ChangeNotifier {
  final ApiClient api = ApiClient();
  AppUser? user;
  bool booting = true;
  AppThemeStyle themeStyle = AppThemeStyle.pocket;

  bool get isLoggedIn => user != null;

  // count of closings saved offline, waiting to sync.
  int pendingCount = 0;
  bool syncing = false;
  bool online = true;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  Future<void> boot() async {
    await api.loadToken();
    user = await api.savedUser();
    final prefs = await SharedPreferences.getInstance();
    themeStyle = prefs.getString('theme') == 'ledger'
        ? AppThemeStyle.ledger
        : AppThemeStyle.pocket;
    await _refreshPending();
    booting = false;
    notifyListeners();
    _connSub = Connectivity().onConnectivityChanged.listen(_applyConnectivity);
    _applyConnectivity(await Connectivity().checkConnectivity());
  }

  // reflects the current connection and flushes the queue when it returns.
  void _applyConnectivity(List<ConnectivityResult> results) {
    final nowOnline = results.any((r) => r != ConnectivityResult.none);
    if (nowOnline != online) {
      online = nowOnline;
      notifyListeners();
    }
    if (nowOnline) syncPending();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  // saves a closing, falling back to the offline queue on a network error.
  // returns true when it had to be queued. server rejections (bad data) throw.
  Future<bool> saveEntry(Map<String, dynamic> payload) async {
    try {
      await api.createEntry(payload);
      await syncPending();
      return false;
    } on ApiException {
      rethrow;
    } catch (_) {
      await OfflineQueue.add(payload);
      await _refreshPending();
      notifyListeners();
      return true;
    }
  }

  // flushes the offline queue. stops on the first network error (still offline),
  // drops entries the server permanently rejects so it can't loop forever.
  Future<void> syncPending() async {
    if (syncing || user == null) return;
    syncing = true;
    notifyListeners();
    try {
      for (final entry in await OfflineQueue.all()) {
        try {
          await api.createEntry(entry.payload);
          await OfflineQueue.remove(entry.localId);
        } on ApiException {
          await OfflineQueue.remove(entry.localId);
        } catch (_) {
          break;
        }
      }
    } finally {
      await _refreshPending();
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshPending() async {
    pendingCount = (await OfflineQueue.all()).length;
  }

  Future<void> login(String username, String password) async {
    user = await api.login(username, password);
    notifyListeners();
    syncPending();
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
