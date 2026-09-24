import 'package:flutter/material.dart';
import 'theme.dart';
import 'update_service.dart';

Future<void> showUpdateCheck(BuildContext context) async {
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => const _UpdateDialog());
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  final _service = UpdateService();
  late Future<ReleaseInfo?> _future;
  String? _path;
  double? _progress;
  String? _error;
  bool _downloaded = false;

  @override
  void initState() {
    super.initState();
    _future = _check();
  }

  Future<ReleaseInfo?> _check() async {
    try {
      final release = await _service.latestRelease();
      if (release == null || !await _service.hasUpdate(release)) return null;
      return release;
    } catch (error) {
      _error = '$error';
      rethrow;
    }
  }

  Future<void> _download(ReleaseInfo release) async {
    setState(() { _progress = 0; _error = null; });
    try {
      _path = await _service.download(release, (received, total) {
        if (!mounted) return;
        setState(() => _progress = total > 0 ? received / total : null);
      });
      if (mounted) setState(() => _downloaded = true);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _install() async {
    try {
      await _service.install(_path!);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  AlertDialog _dialog(ReleaseInfo? release) {
    final hasUpdate = release != null;
    return AlertDialog(
      title: const Text('Cek pembaruan'),
      content: !hasUpdate
          ? Text(_error ?? 'Aplikasi sudah versi terbaru.')
          : SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Versi baru ${release.version} tersedia.'),
                const SizedBox(height: 14),
                if (_progress != null) LinearProgressIndicator(value: _progress),
                if (_progress != null) ...[
                  const SizedBox(height: 8),
                  Text('${((_progress ?? 0) * 100).round()}%'),
                ],
                if (_downloaded) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: context.colors.gold.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(12)),
                    child: Text(release.notes.replaceAll(RegExp(r'[#*_`]'), '').trim(), style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(height: 10),
                  const Text('Download selesai. Tekan Update untuk memasang versi baru.'),
                ],
                if (_error != null) Text(_error!, style: TextStyle(color: context.colors.danger)),
              ]),
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Nanti')),
        if (hasUpdate && !_downloaded) FilledButton(onPressed: _progress == null ? () => _download(release) : null, child: const Text('Download')),
        if (_downloaded) FilledButton(onPressed: _install, child: const Text('Update')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ReleaseInfo?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AlertDialog(title: Text('Cek pembaruan'), content: SizedBox(height: 70, child: Center(child: CircularProgressIndicator())));
        }
        if (snapshot.hasError) return _dialog(null);
        return _dialog(snapshot.data);
      },
    );
  }
}
