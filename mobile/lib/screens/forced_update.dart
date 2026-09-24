import 'package:flutter/material.dart';
import '../theme.dart';
import '../update_service.dart';

// shown when the server refuses writes from this build. it cannot be dismissed:
// an old app may no longer record closings, only read what is already there.
class ForcedUpdateScreen extends StatefulWidget {
  const ForcedUpdateScreen({super.key});

  @override
  State<ForcedUpdateScreen> createState() => _ForcedUpdateScreenState();
}

class _ForcedUpdateScreenState extends State<ForcedUpdateScreen> {
  final _service = UpdateService();
  ReleaseInfo? _release;
  String? _path;
  double? _progress;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _find();
  }

  Future<void> _find() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _release = await _service.latestRelease();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      _path = await _service.download(_release!, (received, total) {
        if (!mounted) return;
        setState(() => _progress = total > 0 ? received / total : null);
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _install() async {
    try {
      await _service.install(_path!);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: pagePadding(context, top: 40, bottom: 40),
            children: [
              Icon(Icons.system_update_rounded,
                  size: 54, color: context.colors.teal),
              const SizedBox(height: 18),
              Text('Update dulu ya', style: display(26)),
              const SizedBox(height: 10),
              Text(
                'Versi aplikasi ini sudah lama, jadi belum bisa mencatat '
                'closing baru. Download versi terbaru dulu, nanti semuanya '
                'jalan seperti biasa.',
                style: TextStyle(color: context.colors.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.gold.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.line),
                ),
                child: const Text(
                  'Pilih update (install di atas yang lama). Jangan uninstall '
                  'dulu — closing yang belum tersinkron bisa ikut terhapus.',
                  style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                ),
              ),
              const SizedBox(height: 26),
              if (_loading)
                Center(
                    child:
                        CircularProgressIndicator(color: context.colors.teal))
              else if (_release == null)
                Text(
                  'Belum menemukan versi terbaru. Cek koneksi lalu coba lagi.',
                  style: TextStyle(color: context.colors.muted),
                )
              else ...[
                Text('Versi terbaru: ${_release!.version}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                if (_release!.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_release!.notes.trim(),
                      style: TextStyle(color: context.colors.muted)),
                ],
                if (_progress != null && _path == null) ...[
                  const SizedBox(height: 18),
                  LinearProgressIndicator(value: _progress),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 18),
                Text(_error!, style: TextStyle(color: context.colors.danger)),
              ],
              const SizedBox(height: 26),
              if (_path != null)
                FilledButton.icon(
                  onPressed: _install,
                  icon: const Icon(Icons.install_mobile_rounded),
                  label: const Text('Pasang sekarang'),
                )
              else
                FilledButton.icon(
                  onPressed: _loading || _release == null || _progress != null
                      ? null
                      : _download,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download update'),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _find,
                child: const Text('Cek lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
