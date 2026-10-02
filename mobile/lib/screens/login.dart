import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';

// sign-in is a slip hanging out of the printer band the app gate draws along the top edge.
// the gate feeds this whole screen out of the band and, once signed in, pulls it back in
// and prints the home screen from the same slot. so this screen paints no background of its
// own and starts right under the band
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  int _errorCount = 0;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    _shake.dispose();
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
      // on success the gate takes this screen away. loading stays on, so the button does not
      // flip back to "masuk" while the slip is being pulled back into the band
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _errorCount++;
      });
      if (!MediaQuery.of(context).disableAnimations) _shake.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = MediaQuery.paddingOf(context).top + kPrinterBand;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding:
            EdgeInsets.fromLTRB(context.pageInset, top, context.pageInset, 32),
        child: AnimatedBuilder(
          animation: _shake,
          // a short sideways wobble that dies out, like a slip tugged once
          builder: (context, child) => Transform.translate(
            offset: Offset(
                math.sin(_shake.value * math.pi * 5) * 9 * (1 - _shake.value),
                0),
            child: child,
          ),
          child: AnimatedSlide(
            // while the server checks, the slip draws back a little toward the slot
            offset: Offset(0, _loading ? -0.012 : 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: CustomPaint(
              painter: _SlipPainter(colors),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child:
                              Text('SALES CALCULATOR', style: _caps(colors))),
                      Text(_stampDate(DateTime.now()), style: _caps(colors)),
                    ]),
                    const SizedBox(height: 14),
                    DashedLine(color: colors.rule),
                    const SizedBox(height: 26),
                    Row(children: [
                      Container(
                        width: 46,
                        height: 46,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: colors.line,
                              width: colors.outlined ? 1.5 : 1),
                        ),
                        child: ClipOval(child: Image.asset('assets/logo.png')),
                      ),
                      const Spacer(),
                      // the slip's own stamp, the same one approved closings get
                      const StatusStamp(pending: true, label: 'Belum masuk'),
                    ]),
                    const SizedBox(height: 18),
                    Text('Masuk', style: display(44, spacing: -1.6)),
                    const SizedBox(height: 6),
                    Text('Closing masuk, angka langsung beres.',
                        style: TextStyle(
                            color: colors.muted, fontSize: 15, height: 1.35)),
                    const SizedBox(height: 26),
                    _label('Username', colors),
                    TextField(
                      controller: _username,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      style: _fieldText(colors),
                      decoration: _field(colors, hint: 'mis. budi'),
                    ),
                    const SizedBox(height: 16),
                    _label('Password', colors),
                    TextField(
                      controller: _password,
                      focusNode: _passwordFocus,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _loading ? null : _submit(),
                      style: _fieldText(colors),
                      decoration: _field(colors, hint: '••••••').copyWith(
                        suffixIcon: IconButton(
                          tooltip: _obscure
                              ? 'Tampilkan password'
                              : 'Sembunyikan password',
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: colors.muted),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: _error == null
                          ? const SizedBox(width: double.infinity)
                          : Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: _ErrorStamp(
                                  key: ValueKey(_errorCount), text: _error!),
                            ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        disabledBackgroundColor:
                            colors.outlined ? colors.ink : colors.teal,
                        disabledForegroundColor: Colors.white,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _loading
                            ? const Row(
                                key: ValueKey('busy'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white)),
                                  SizedBox(width: 12),
                                  Text('Memeriksa…'),
                                ],
                              )
                            : const Row(
                                key: ValueKey('idle'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Masuk'),
                                  SizedBox(width: 10),
                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    DashedLine(color: colors.rule),
                    const SizedBox(height: 14),
                    Text('Lupa password? Minta admin cabang untuk reset.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.muted, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _caps(AppPalette colors) => TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
      color: colors.muted);

  TextStyle _fieldText(AppPalette colors) => TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: colors.ink);

  Widget _label(String text, AppPalette colors) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(text.toUpperCase(), style: _caps(colors)),
      );

  // a ruled box on the slip: paper fill, no outline until it has focus
  InputDecoration _field(AppPalette colors, {required String hint}) {
    final radius = BorderRadius.circular(kRadiusSm - 2);
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: colors.muted.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500),
      filled: true,
      fillColor: colors.paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.rule, width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: colors.ink, width: 2)),
    );
  }

  static const _days = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];
  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN', //
    'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES',
  ];

  // "KAM, 2 OKT 2026", printed in the slip's corner like a till date
  static String _stampDate(DateTime d) =>
      '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
}

// a wrong password lands as a red stamp, pressed on like the "beres" stamp on the refresh slip
class _ErrorStamp extends StatelessWidget {
  final String text;
  const _ErrorStamp({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 1.25 - 0.25 * t, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: colors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.danger, width: 1.4),
        ),
        child: Row(children: [
          Icon(Icons.block_rounded, size: 18, color: colors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: colors.danger,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5)),
          ),
        ]),
      ),
    );
  }
}

// the slip's outline: open at the top where it leaves the slot, torn into teeth at the bottom
class _SlipPainter extends CustomPainter {
  final AppPalette colors;
  _SlipPainter(this.colors);

  static const _tooth = 14.0;
  static const _depth = 7.0;

  Path _outline(Size size) {
    final teeth = (size.width / _tooth).round();
    final step = size.width / teeth;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - _depth);
    for (var i = teeth; i > 0; i--) {
      path
        ..lineTo(step * (i - 0.5), size.height)
        ..lineTo(step * (i - 1), size.height - _depth);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _outline(size);
    if (colors.outlined) {
      canvas.drawPath(
          path.shift(const Offset(3, 4)), Paint()..color = colors.ink);
    } else {
      canvas.drawShadow(path, colors.ink.withValues(alpha: 0.5), 10, false);
    }
    canvas.drawPath(path, Paint()..color = colors.card);
    // the sides and the torn edge are inked, the top is not: it runs on into the slot
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-4, 1, size.width + 4, size.height + 4));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = colors.outlined ? 1.5 : 1
          ..color = colors.outlined ? colors.line : colors.rule);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlipPainter old) => old.colors != colors;
}
