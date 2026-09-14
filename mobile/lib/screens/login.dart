import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../anim.dart';

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
      await context
          .read<AppState>()
          .login(_username.text.trim(), _password.text);
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: pagePadding(context, top: 26, bottom: 28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Reveal(
                child: Row(children: [
              Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: colors.ink, width: outlined ? 1.5 : 1),
                  boxShadow: outlined
                      ? [
                          BoxShadow(
                              color: colors.ink, offset: const Offset(3, 4))
                        ]
                      : [
                          BoxShadow(
                              color: colors.ink.withValues(alpha: 0.10),
                              blurRadius: 14,
                              offset: const Offset(0, 6))
                        ],
                ),
                child: ClipOval(child: Image.asset('assets/logo.png')),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales Calculator', style: display(20)),
                    const SizedBox(height: 3),
                    Text(
                      'Closing masuk, angka langsung beres.',
                      style: TextStyle(
                          color: colors.muted, fontSize: 12.5, height: 1.25),
                    ),
                  ],
                ),
              ),
            ])),
            const SizedBox(height: 44),
            Reveal(
                delayMs: 90,
                child: Text('Selamat\ndatang!',
                    style: display(40, weight: FontWeight.w700, spacing: -1))),
            const SizedBox(height: 10),
            Reveal(
                delayMs: 150,
                child: Text('Masuk untuk catat hasil hari ini.',
                    style: TextStyle(color: colors.muted, fontSize: 15))),
            const SizedBox(height: 24),
            Reveal(
              delayMs: 210,
              child: TextField(
                controller: _username,
                decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.person_outline_rounded)),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(height: 14),
            Reveal(
              delayMs: 270,
              child: TextField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 18, color: Colors.redAccent),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent))),
              ]),
            ],
            const SizedBox(height: 24),
            Reveal(
              delayMs: 340,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Masuk'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
