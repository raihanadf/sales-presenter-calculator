import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().login(_username.text.trim(), _password.text);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final outlined = colors.outlined;
    final headerText = outlined ? colors.ink : Colors.white;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
              decoration: BoxDecoration(
                color: outlined ? colors.teal : null,
                gradient: outlined ? null : LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.teal, colors.tealDark]),
                borderRadius: BorderRadius.circular(30),
                border: outlined ? Border.all(color: colors.ink, width: 1.5) : null,
                boxShadow: outlined ? [BoxShadow(color: colors.ink, offset: const Offset(4, 5))] : null,
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: colors.ink, width: outlined ? 1.5 : 0)),
                  child: ClipOval(child: Image.asset('assets/logo.png', width: 68, height: 68)),
                ),
                const SizedBox(height: 18),
                Text('Sales Calculator', style: display(27, color: headerText)),
                const SizedBox(height: 7),
                Text('Closing masuk, angka langsung beres.', style: TextStyle(color: outlined ? colors.muted : Colors.white70, fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 38),
            Text('Selamat datang!', style: display(30, weight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Masuk untuk catat hasil hari ini.', style: TextStyle(color: colors.muted)),
            const SizedBox(height: 24),
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline_rounded)),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.error_outline_rounded, size: 18, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
              ]),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Masuk'),
            ),
          ]),
        ),
      ),
    );
  }
}
