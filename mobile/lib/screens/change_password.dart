import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

// every account can replace its own password. branch admins get a generated
// one over chat, so this is how it stops living in a chat history.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_next.text != _confirm.text) {
      setState(() => _error = 'Konfirmasi password tidak sama.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context
          .read<AppState>()
          .api
          .changePassword(_current.text, _next.text);
      messenger.showSnackBar(
          const SnackBar(content: Text('Password berhasil diganti.')));
      navigator.pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ganti Password')),
        body: ListView(
          padding: pagePadding(context, top: 16, bottom: 40),
          children: [
            TextField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password sekarang',
                    prefixIcon: Icon(Icons.lock_outline_rounded))),
            const SizedBox(height: 16),
            TextField(
                controller: _next,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Password baru (min 6)',
                    prefixIcon: Icon(Icons.lock_reset_rounded))),
            const SizedBox(height: 16),
            TextField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Ulangi password baru',
                    prefixIcon: Icon(Icons.lock_reset_rounded))),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 26),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan'),
            ),
          ],
        ),
      );
}
