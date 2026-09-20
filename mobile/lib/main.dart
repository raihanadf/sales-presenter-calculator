import 'package:flutter/material.dart';
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

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final Widget screen = state.booting
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : state.isLoggedIn
            ? const HomeScreen()
            : const LoginScreen();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.98, end: 1.0).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(state.booting
            ? 'booting'
            : state.isLoggedIn
                ? 'home'
                : 'login'),
        child: screen,
      ),
    );
  }
}
