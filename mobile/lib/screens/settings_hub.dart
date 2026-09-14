import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../update_dialog.dart';
import '../widgets.dart';
import 'presenters.dart';
import 'settings.dart';

class SettingsHubBody extends StatelessWidget {
  const SettingsHubBody({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user!;

    return ListView(
      padding: pagePadding(context, top: 14, bottom: 124),
      children: [
        Text('Pengaturan', style: display(28)),
        const SizedBox(height: 4),
        Text(
          'Akun, tampilan, dan data aplikasi.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 28),
        const SectionTitle('Akun'),
        Panel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colors.mint,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: context.colors.line,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      user.name.trimLeft().substring(0, 1).toUpperCase(),
                      style: display(22),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${user.username}',
                          style: TextStyle(color: context.colors.muted),
                        ),
                        const SizedBox(height: 9),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.colors.paper,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: context.colors.line),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Text(
                              user.isAdmin ? 'Administrator' : 'Presenter',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: state.logout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Keluar dari akun'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        if (user.isAdmin) ...[
          const SectionTitle('Kelola data'),
          _SettingsTile(
            icon: Icons.groups_rounded,
            title: 'Kelola Presenter',
            subtitle: 'Tambah dan lihat akun sales',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PresentersScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _SettingsTile(
            icon: Icons.sell_rounded,
            title: 'Pengaturan Harga',
            subtitle: 'Harga closing, BOP, souvenir, dan harian',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          const SizedBox(height: 30),
        ],
        const SectionTitle('Aplikasi'),
        _SettingsTile(
          icon: Icons.palette_rounded,
          title: 'Ganti Tema',
          subtitle: state.themeStyle == AppThemeStyle.pocket
              ? 'Pocket Ledger'
              : 'Teal Ledger',
          onTap: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: context.colors.card,
            builder: (_) => const _ThemePicker(),
          ),
        ),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.system_update_rounded,
          title: 'Cek Pembaruan',
          subtitle: 'Lihat apakah ada versi terbaru',
          onTap: () => showUpdateCheck(context),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SettingsTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: ListTile(
          minTileHeight: 76,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: context.colors.mint,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.line)),
            child: Icon(icon, color: context.colors.ink),
          ),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: 4), child: Text(subtitle)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.fromLTRB(context.pageInset, 16, context.pageInset, 28),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Pilih tema', style: display(21)),
              const SizedBox(height: 16),
              _ThemeChoice(
                title: 'Pocket Ledger',
                subtitle: 'Pastel, garis hitam, lebih playful',
                colors: const [
                  Color(0xFFD6BFFF),
                  Color(0xFFBFF59A),
                  Color(0xFFFFD88A)
                ],
                selected: state.themeStyle == AppThemeStyle.pocket,
                onTap: () async {
                  await state.setTheme(AppThemeStyle.pocket);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              _ThemeChoice(
                title: 'Teal Ledger',
                subtitle: 'Tema hijau klasik',
                colors: const [
                  Color(0xFF0E6B57),
                  Color(0xFF2FD3A5),
                  Color(0xFFF2B33D)
                ],
                selected: state.themeStyle == AppThemeStyle.ledger,
                onTap: () async {
                  await state.setTheme(AppThemeStyle.ledger);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ]),
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeChoice(
      {required this.title,
      required this.subtitle,
      required this.colors,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: selected ? context.colors.ink : context.colors.line,
                width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Row(
                children: colors
                    .map((color) => Container(
                          width: 22,
                          height: 40,
                          decoration: BoxDecoration(
                              color: color,
                              border: Border.all(color: Colors.black),
                              borderRadius: BorderRadius.circular(6)),
                        ))
                    .toList()),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          TextStyle(color: context.colors.muted, fontSize: 12)),
                ])),
            if (selected) const Icon(Icons.check_circle_rounded),
          ]),
        ),
      );
}
