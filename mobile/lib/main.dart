import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/forced_update.dart';
import 'theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..boot(),
      child: const SalesApp(),
    ),
  );
}

class SalesApp extends StatelessWidget {
  const SalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: 'Sales Calculator',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(state.themeStyle),
      // the update screen replaces the whole app, not just the first route, so
      // it also covers a screen the user had already pushed when the server
      // refused the write.
      builder: (context, child) =>
          state.updateRequired ? const ForcedUpdateScreen() : child!,
      home: const _Gate(),
    );
  }
}

// signed out, an ink printer band runs along the top edge and the sign-in slip hangs out of it.
// every change of screen here goes through that band instead of a page swap: the leaving
// screen is drawn back up into it, the arriving one comes out of it, and once signed in the
// band itself rolls up out of sight. boot is the band alone, so a cold start already reads as
// the printer warming up
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final colors = context.colors;
    final still = MediaQuery.of(context).disableAnimations;
    final band = state.booting || !state.isLoggedIn;
    final key = state.booting
        ? 'booting'
        : state.isLoggedIn
            ? 'home'
            : 'login';
    final Widget screen = state.booting
        ? const SizedBox.expand()
        : state.isLoggedIn
            ? const HomeScreen()
            : const LoginScreen();

    // dark icons on paper; the band brings its own light ones while it is on screen. only the
    // status bar is set, the stock dark/light styles would also paint the navigation bar black
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light),
      child: ColoredBox(
        color: colors.paper,
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: still ? Duration.zero : kGateDuration,
              layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, if (current != null) current]),
              transitionBuilder: (child, animation) {
                // both sides share one controller: the leaving screen runs it backwards from 1,
                // so this interval makes it finish its exit in the first half and the arriving
                // screen start in the second, with a short overlap
                final feed = CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.45, 1, curve: Curves.easeOutCubic));
                if ((child.key as ValueKey<String>).value == 'login') {
                  // the slip moves as one piece, so it really is fed out and pulled back
                  return SlideTransition(
                    position:
                        Tween(begin: const Offset(0, -1), end: Offset.zero)
                            .animate(feed),
                    child: child,
                  );
                }
                // a whole screen sliding would drag its bottom bar down through the middle, so
                // it is printed instead: revealed downward from the band while drifting into place
                return AnimatedBuilder(
                  animation: feed,
                  builder: (context, child) => ClipRect(
                    clipper: _PrintedSoFar(feed.value),
                    child: Transform.translate(
                        offset: Offset(0, -56 * (1 - feed.value)),
                        child: child),
                  ),
                  child: child,
                );
              },
              child: KeyedSubtree(key: ValueKey(key), child: screen),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedSlide(
              offset: band ? Offset.zero : const Offset(0, -1),
              duration: still ? Duration.zero : kGateDuration,
              // signing in: rolls up only once home has mostly printed. signing out: drops in
              // first, so home has somewhere to be drawn back into
              curve: band
                  ? const Interval(0, 0.3, curve: Curves.easeOutCubic)
                  : const Interval(0.72, 1, curve: Curves.easeInCubic),
              child: _PrinterBand(busy: state.booting),
            ),
          ),
        ]),
      ),
    );
  }
}

// the part of a screen that has come out of the printer, from the top down
class _PrintedSoFar extends CustomClipper<Rect> {
  final double t;
  _PrintedSoFar(this.t);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, size.height * t);

  @override
  bool shouldReclip(_PrintedSoFar old) => old.t != t;
}

class _PrinterBand extends StatelessWidget {
  final bool busy;
  const _PrinterBand({required this.busy});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final top = MediaQuery.paddingOf(context).top;
    // the slit lines up with the slip's edges, a touch wider so paper visibly comes out of it
    final slit = context.pageInset - 6;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark),
      child: Container(
        height: top + kPrinterBand,
        decoration: BoxDecoration(
          color: colors.ink,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(10)),
        ),
        child: Stack(children: [
          Positioned(
            left: slit,
            right: slit,
            bottom: 5,
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(2),
                border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.14), width: 1)),
              ),
            ),
          ),
          Positioned(
            right: slit + 4,
            bottom: 12,
            child: _Led(busy: busy, color: colors.mint),
          ),
        ]),
      ),
    );
  }
}

// the printer's power light: steady when idle, breathing while the app is still starting up
class _Led extends StatefulWidget {
  final bool busy;
  final Color color;
  const _Led({required this.busy, required this.color});

  @override
  State<_Led> createState() => _LedState();
}

class _LedState extends State<_Led> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    if (widget.busy) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Led old) {
    super.didUpdateWidget(old);
    if (widget.busy && !_c.isAnimating) _c.repeat(reverse: true);
    if (!widget.busy) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.25, end: 1.0).animate(_c),
        child: Container(
          width: 5,
          height: 5,
          decoration:
              BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      );
}
