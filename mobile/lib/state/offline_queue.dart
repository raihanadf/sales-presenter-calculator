import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// a closing recorded while offline, waiting to be pushed to the server.
class PendingEntry {
  final String localId;
  final Map<String, dynamic> payload;
  final int createdAt;

  PendingEntry(
      {required this.localId, required this.payload, required this.createdAt});

  Map<String, dynamic> toJson() =>
      {'localId': localId, 'payload': payload, 'createdAt': createdAt};

  factory PendingEntry.fromJson(Map<String, dynamic> j) => PendingEntry(
        localId: j['localId'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        createdAt: j['createdAt'] as int,
      );
}

// simple prefs-backed fifo queue of unsynced closings.
class OfflineQueue {
  static const _key = 'offline_entries';

  static Future<List<PendingEntry>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => PendingEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> _save(List<PendingEntry> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(Map<String, dynamic> payload) async {
    final list = await all();
    list.add(PendingEntry(
      localId: DateTime.now().microsecondsSinceEpoch.toString(),
      payload: payload,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _save(list);
  }

  static Future<void> remove(String localId) async {
    final list = await all()
      ..removeWhere((e) => e.localId == localId);
    await _save(list);
  }
}
