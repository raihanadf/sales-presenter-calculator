import 'package:cupertino_liquid_glass/cupertino_liquid_glass.dart';
import 'package:flutter/material.dart';

import 'theme.dart';

class PlatformBottomNavigation extends StatelessWidget {
  const PlatformBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      return CupertinoLiquidGlassBottomBar(
        currentIndex: selectedIndex,
        onTap: onDestinationSelected,
        horizontalMargin: context.pageInset,
        bottomSpacing: 12,
        activeColor: context.colors.tealDark,
        inactiveColor: context.colors.muted,
        items: const [
          LiquidGlassBottomBarItem(
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Beranda',
          ),
          LiquidGlassBottomBarItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Pengaturan',
          ),
        ],
      );
    }

    final colors = context.colors;
    final radius = BorderRadius.circular(30);

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(
        context.pageInset,
        0,
        context.pageInset,
        12,
      ),
      child: Material(
        elevation: 10,
        shadowColor: colors.ink.withValues(alpha: 0.24),
        color: colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          height: context.usesLargeText ? 84 : 72,
          backgroundColor: colors.card,
          indicatorColor: colors.mint,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}
