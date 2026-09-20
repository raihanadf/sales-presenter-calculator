import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  // every branch, for the superadmin's branch picker. empty for everyone else.
  List<Branch> branches = [];
  AppThemeStyle themeStyle = AppThemeStyle.pocket;

  bool get isLoggedIn => user != null;

  // null means "all branches at once", which only the superadmin can be in.
  int? get selectedBranchId => api.activeBranchId;

  Branch? get selectedBranch {
    final id = selectedBranchId;
    if (id == null) return null;
    for (final b in branches) {
      if (b.id == id) return b;
    }
    return null;
  }

  // loads the branch list once the owner is logged in; nobody else may read it.
  Future<void> loadBranches() async {
    if (user?.isSuperadmin != true) return;
    branches = await api.branches();
    notifyListeners();
  }

  // switches which branch the owner is looking at. null spans all of them.
  void selectBranch(int? branchId) {
    api.activeBranchId = branchId;
    notifyListeners();
  }

  // set once the server refuses writes from this build. the app then shows
  // the update screen and nothing else.
  bool updateRequired = false;

  // count of closings saved offline, waiting to sync.
  int pendingCount = 0;
  bool syncing = false;
  bool online = true;
  StreamSubscription<List<ConnectivityResult>>? _connSub;

  Future<void> boot() async {
    api.appVersion = (await PackageInfo.fromPlatform()).version;
    api.onUpdateRequired = () {
      if (updateRequired) return;
      updateRequired = true;
      notifyListeners();
    };
    await api.loadToken();
    user = await api.savedUser();
    // the cached copy can be stale (moved branch, changed role). refresh it
    // when the network allows; offline we keep showing the cached one. a token
    // the server rejects ends the session instead of pretending it still works.
    if (user != null) {
      try {
        user = await api.me();
      } on ApiException catch (e) {
        if (e.status == 401) {
          await api.logout();
          user = null;
        }
      } catch (_) {}
    }
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
        } on ApiException catch (e) {
          // 426 means this build is too old to write. keep the closing queued;
          // it syncs after the update, as long as the app is updated and not
          // uninstalled.
          if (e.status == 426) break;
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
    if (user!.isSuperadmin) await loadBranches();
    syncPending();
  }

  Future<void> logout() async {
    await api.logout();
    user = null;
    branches = [];
    api.activeBranchId = null;
    notifyListeners();
  }

  Future<void> setTheme(AppThemeStyle style) async {
    themeStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', style.name);
    notifyListeners();
  }
}
