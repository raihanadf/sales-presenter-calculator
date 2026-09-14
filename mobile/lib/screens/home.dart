import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'entry_form.dart';
import 'presenters.dart';
import 'settings.dart';
import '../util/format.dart';
import '../update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Object> _future;
  late final bool _isAdmin;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AppState>().user?.isAdmin ?? false;
    _load();
  }

  void _load() {
    final api = context.read<AppState>().api;
    _future = _isAdmin ? api.dashboard(today(), thisMonth()) : api.dashboardMe(today(), thisMonth());
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _openEntry() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const EntryFormScreen()));
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppState>().user?.name ?? '';
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/logo.png', width: 30, height: 30)),
          const SizedBox(width: 10),
          const Text('Beranda'),
        ]),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (value) {
              if (value == 'update') {
                showUpdateCheck(context);
                return;
              }
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: context.colors.card,
                builder: (_) => const _ThemePicker(),
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'theme', child: Text('Ganti tema')),
              PopupMenuItem(value: 'update', child: Text('Cek pembaruan')),
            ],
          ),
          if (_isAdmin)
            IconButton(
              tooltip: 'Kelola',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () async {
                await showModalBottomSheet(context: context, backgroundColor: context.colors.card, builder: (_) => const _AdminMenu());
                _refresh();
              },
            ),
          IconButton(tooltip: 'Keluar', icon: const Icon(Icons.logout_rounded), onPressed: () => context.read<AppState>().logout()),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: _openEntry,
              backgroundColor: context.colors.mint,
              foregroundColor: context.colors.ink,
              icon: const Icon(Icons.add_rounded),
              label: Text('Catat Closing', style: display(15, weight: FontWeight.w700, color: context.colors.ink, spacing: 0)),
            ),
      body: RefreshIndicator(
        color: context.colors.teal,
        onRefresh: _refresh,
        child: FutureBuilder<Object>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: context.colors.teal));
            }
            if (snap.hasError) return _ErrorView(message: '${snap.error}', onRetry: _refresh);
            final data = snap.data!;
            if (data is MyDashboard) return _MyBody(data: data, name: name);
            return _AdminBody(data: data as Dashboard, name: name);
          },
        ),
      ),
    );
  }
}

// ---------------- presenter ----------------

class _MyBody extends StatelessWidget {
  final MyDashboard data;
  final String name;
  const _MyBody({required this.data, required this.name});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text('Halo, $name', style: TextStyle(color: context.colors.muted, fontSize: 15)),
        ),
        HeroPanel(
          label: 'Pendapatan hari ini',
          amount: data.todayIncome,
          subLabel: 'Bulan ini',
          subAmount: data.monthIncome,
          trailing: data.rank != null ? RankPill(rank: data.rank!, total: data.totalPresenters) : null,
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: StatTile(icon: Icons.check_circle_outline_rounded, label: 'Closing bulan ini', value: Text('${data.monthClosings}', style: display(22)))),
          const SizedBox(width: 12),
          Expanded(child: StatTile(icon: Icons.trending_up_rounded, label: 'Rata-rata / closing', value: Rupiah(data.avgPerClosing, size: 18))),
        ]),
        const SizedBox(height: 26),
        const SectionTitle('Closing terbaik'),
        if (data.bestTakeHome == 0)
          const EmptyNote('Belum ada closing bulan ini')
        else
          Panel(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: context.colors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.star_rounded, color: context.colors.gold)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Rupiah(data.bestTakeHome, size: 20),
                const SizedBox(height: 2),
                Text(data.bestDate ?? '', style: TextStyle(color: context.colors.muted, fontSize: 13)),
              ])),
            ]),
          ),
        const SizedBox(height: 26),
        const SectionTitle('Tren 7 hari'),
        Panel(padding: const EdgeInsets.fromLTRB(12, 16, 12, 12), child: TrendBars(points: data.trend.map((t) => (date: t.date, income: t.income)).toList())),
        const SizedBox(height: 26),
        const SectionTitle('Riwayat closing'),
        if (data.recent.isEmpty)
          const EmptyNote('Belum ada closing')
        else
          Panel(child: Column(children: [
            for (var i = 0; i < data.recent.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.colors.line, indent: 16, endIndent: 16),
              _HistoryRow(entry: data.recent[i]),
            ],
          ])),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final RecentEntry entry;
  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: context.colors.paper, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.receipt_long_rounded, size: 20, color: context.colors.teal)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${entry.entryDate}  ·  ${entry.closingCount} closing', style: TextStyle(fontSize: 13, color: context.colors.muted)),
          ])),
          Rupiah(entry.takeHome, size: 16),
        ]),
      );
}

// ---------------- admin ----------------

class _AdminBody extends StatelessWidget {
  final Dashboard data;
  final String name;
  const _AdminBody({required this.data, required this.name});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text('Halo, $name', style: TextStyle(color: context.colors.muted, fontSize: 15)),
        ),
        HeroPanel(label: 'Pendapatan hari ini', amount: data.todayIncome, subLabel: 'Bulan ini', subAmount: data.monthIncome),
        const SizedBox(height: 26),
        const SectionTitle('Peringkat presenter'),
        if (data.top3.isEmpty)
          const EmptyNote('Belum ada closing bulan ini')
        else
          ...data.top3.asMap().entries.map((e) => _PodiumTile(rank: e.key + 1, row: e.value)),
        const SizedBox(height: 26),
        const SectionTitle('Rekap bulan ini'),
        if (data.monthRecap.isEmpty)
          const EmptyNote('Belum ada data')
        else
          Panel(child: Column(children: [
            for (var i = 0; i < data.monthRecap.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.colors.line, indent: 16, endIndent: 16),
              Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.monthRecap[i].presenterName, style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.ink)),
                  const SizedBox(height: 2),
                  Text('${data.monthRecap[i].entries} closing', style: TextStyle(color: context.colors.muted, fontSize: 13)),
                ])),
                Rupiah(data.monthRecap[i].total, size: 16),
              ])),
            ],
          ])),
      ],
    );
  }
}

class _PodiumTile extends StatelessWidget {
  final int rank;
  final RecapRow row;
  const _PodiumTile({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    final medals = {1: context.colors.gold, 2: const Color(0xFFAFBDC4), 3: const Color(0xFFC98A5E)};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.colors.card, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: rank == 1 ? context.colors.gold : context.colors.line)),
      child: Row(children: [
        Container(width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: medals[rank], borderRadius: BorderRadius.circular(12)),
          child: Text('$rank', style: display(18, color: context.colors.ink, spacing: 0))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.presenterName, style: TextStyle(fontWeight: FontWeight.w700, color: context.colors.ink, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${row.entries} closing', style: TextStyle(color: context.colors.muted, fontSize: 13)),
        ])),
        Rupiah(row.total, size: 17),
      ]),
    );
  }
}

class _AdminMenu extends StatelessWidget {
  const _AdminMenu();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.line, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: Icon(Icons.groups_rounded, color: context.colors.teal),
            title: const Text('Kelola Presenter'),
            subtitle: const Text('Tambah & lihat akun sales'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const PresentersScreen())); },
          ),
          ListTile(
            leading: Icon(Icons.tune_rounded, color: context.colors.teal),
            title: const Text('Pengaturan Harga'),
            subtitle: const Text('Harga closing, BOP, souvenir, harian'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); },
          ),
        ]),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pilih tema', style: display(21)),
          const SizedBox(height: 14),
          _ThemeChoice(
            title: 'Pocket Ledger',
            subtitle: 'Pastel, garis hitam, lebih playful',
            colors: const [Color(0xFFD6BFFF), Color(0xFFBFF59A), Color(0xFFFFD88A)],
            selected: state.themeStyle == AppThemeStyle.pocket,
            onTap: () async {
              await state.setTheme(AppThemeStyle.pocket);
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          _ThemeChoice(
            title: 'Teal Ledger',
            subtitle: 'Tema hijau klasik',
            colors: const [Color(0xFF0E6B57), Color(0xFF2FD3A5), Color(0xFFF2B33D)],
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
  const _ThemeChoice({required this.title, required this.subtitle, required this.colors, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? context.colors.ink : context.colors.line, width: selected ? 2 : 1),
          ),
          child: Row(children: [
            Row(children: colors.map((color) => Container(
              width: 22,
              height: 38,
              decoration: BoxDecoration(color: color, border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(6)),
            )).toList()),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(subtitle, style: TextStyle(color: context.colors.muted, fontSize: 12)),
            ])),
            if (selected) const Icon(Icons.check_circle_rounded),
          ]),
        ),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 120),
          Icon(Icons.cloud_off_rounded, size: 44, color: context.colors.muted),
          const SizedBox(height: 12),
          Center(child: Text(message, textAlign: TextAlign.center, style: TextStyle(color: context.colors.muted))),
          const SizedBox(height: 16),
          Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi'))),
        ],
      );
}
