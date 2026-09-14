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
          if (_isAdmin)
            IconButton(
              tooltip: 'Kelola',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () async {
                await showModalBottomSheet(context: context, backgroundColor: AppColors.card, builder: (_) => const _AdminMenu());
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
              backgroundColor: AppColors.mint,
              foregroundColor: AppColors.ink,
              icon: const Icon(Icons.add_rounded),
              label: Text('Catat Closing', style: display(15, weight: FontWeight.w700, color: AppColors.ink, spacing: 0)),
            ),
      body: RefreshIndicator(
        color: AppColors.teal,
        onRefresh: _refresh,
        child: FutureBuilder<Object>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.teal));
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
          child: Text('Halo, $name', style: const TextStyle(color: AppColors.muted, fontSize: 15)),
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
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.star_rounded, color: AppColors.gold)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Rupiah(data.bestTakeHome, size: 20),
                const SizedBox(height: 2),
                Text(data.bestDate ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
              if (i > 0) const Divider(height: 1, color: AppColors.line, indent: 16, endIndent: 16),
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
          Container(width: 40, height: 40, decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long_rounded, size: 20, color: AppColors.teal)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${entry.entryDate}  ·  ${entry.closingCount} closing', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
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
          child: Text('Halo, $name', style: const TextStyle(color: AppColors.muted, fontSize: 15)),
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
              if (i > 0) const Divider(height: 1, color: AppColors.line, indent: 16, endIndent: 16),
              Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data.monthRecap[i].presenterName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('${data.monthRecap[i].entries} closing', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
    const medals = {1: AppColors.gold, 2: Color(0xFFAFBDC4), 3: Color(0xFFC98A5E)};
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: rank == 1 ? AppColors.gold : AppColors.line)),
      child: Row(children: [
        Container(width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: medals[rank], borderRadius: BorderRadius.circular(12)),
          child: Text('$rank', style: display(18, color: AppColors.ink, spacing: 0))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(row.presenterName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 15)),
          const SizedBox(height: 2),
          Text('${row.entries} closing', style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.groups_rounded, color: AppColors.teal),
            title: const Text('Kelola Presenter'),
            subtitle: const Text('Tambah & lihat akun sales'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const PresentersScreen())); },
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded, color: AppColors.teal),
            title: const Text('Pengaturan Harga'),
            subtitle: const Text('Harga closing, BOP, souvenir, harian'),
            onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())); },
          ),
        ]),
      ),
    );
  }
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
          const Icon(Icons.cloud_off_rounded, size: 44, color: AppColors.muted),
          const SizedBox(height: 12),
          Center(child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted))),
          const SizedBox(height: 16),
          Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi'))),
        ],
      );
}
