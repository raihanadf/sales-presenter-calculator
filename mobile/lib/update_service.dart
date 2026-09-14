import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class ReleaseInfo {
  final String version;
  final Uri downloadUrl;
  final String notes;

  const ReleaseInfo({required this.version, required this.downloadUrl, required this.notes});
}

class UpdateService {
  static const _releaseUrl = 'https://api.github.com/repos/raihanadf/sales-presenter-calculator/releases/latest';

  Future<ReleaseInfo?> latestRelease() async {
    if (!Platform.isAndroid) return null;
    final response = await http.get(Uri.parse(_releaseUrl), headers: {'Accept': 'application/vnd.github+json'});
    if (response.statusCode != 200) throw Exception('GitHub returned ${response.statusCode}');
    final release = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (release['tag_name'] as String).replaceFirst(RegExp(r'^v'), '');
    final assets = release['assets'] as List<dynamic>;
    final apk = assets.cast<Map<String, dynamic>>().firstWhere((asset) => (asset['name'] as String).endsWith('.apk'));
    return ReleaseInfo(
      version: tag,
      downloadUrl: Uri.parse(apk['browser_download_url'] as String),
      notes: release['body'] as String,
    );
  }

  Future<String> download(ReleaseInfo release, void Function(int received, int total) onProgress) async {
    final response = await http.Client().send(http.Request('GET', release.downloadUrl));
    if (response.statusCode != 200) throw Exception('download failed (${response.statusCode})');
    final total = response.contentLength ?? 0;
    final buffer = BytesBuilder();
    var received = 0;
    await for (final chunk in response.stream) {
      buffer.add(chunk);
      received += chunk.length;
      onProgress(received, total);
    }
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/sales-calculator-${release.version}.apk');
    await file.writeAsBytes(buffer.takeBytes(), flush: true);
    return file.path;
  }

  Future<void> install(String path) async {
    final result = await OpenFilex.open(path, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) throw Exception(result.message);
  }

  Future<bool> hasUpdate(ReleaseInfo release) async {
    final info = await PackageInfo.fromPlatform();
    return _compare(release.version, info.version) > 0;
  }

  int _compare(String a, String b) {
    final left = a.split('.').map(int.parse).toList();
    final right = b.split('.').map(int.parse).toList();
    for (var i = 0; i < (left.length > right.length ? left.length : right.length); i++) {
      final l = i < left.length ? left[i] : 0;
      final r = i < right.length ? right[i] : 0;
      if (l != r) return l.compareTo(r);
    }
    return 0;
  }
}
