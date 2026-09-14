import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../util/format.dart';
import 'entry_form.dart';
import 'presenters.dart';
import 'settings.dart';

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
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const EntryFormScreen()));
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final name = state.user?.name ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (_isAdmin)
            PopupMenuButton<String>(
              onSelected: (v) async {
                final page = v == 'presenters' ? const PresentersScreen() : const SettingsScreen();
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
                _refresh();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'presenters', child: Text('Kelola Presenter')),
                PopupMenuItem(value: 'settings', child: Text('Pengaturan Harga')),
              ],
            ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? null
          : FloatingActionButton.extended(
              onPressed: _openEntry,
              icon: const Icon(Icons.add),
              label: const Text('Closing'),
            ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<Object>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _ErrorView(message: '${snap.error}', onRetry: _refresh);
            }
            final data = snap.data!;
            if (data is MyDashboard) return _MyDashboardBody(data: data, greeting: name);
            return _DashboardBody(data: data as Dashboard, greeting: name);
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Dashboard data;
  final String greeting;
  const _DashboardBody({required this.data, required this.greeting});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Text('Halo, $greeting', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(label: 'Pendapatan Hari Ini', value: rupiah(data.todayIncome), icon: Icons.today, tone: true)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Bulan Ini', value: rupiah(data.monthIncome), icon: Icons.calendar_month)),
        ]),
        const SizedBox(height: 24),
        Text('Top 3 Presenter', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (data.top3.isEmpty)
          const _Empty('Belum ada closing bulan ini')
        else
          ...data.top3.asMap().entries.map((e) => _PodiumTile(rank: e.key + 1, row: e.value)),
        const SizedBox(height: 24),
        Text('Rekap Bulan Ini', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (data.monthRecap.isEmpty)
          const _Empty('Belum ada data')
        else
          Card(
            child: Column(
              children: data.monthRecap
                  .map((r) => ListTile(
                        title: Text(r.presenterName),
                        subtitle: Text('${r.entries} closing'),
                        trailing: Text(rupiah(r.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _MyDashboardBody extends StatelessWidget {
  final MyDashboard data;
  final String greeting;
  const _MyDashboardBody({required this.data, required this.greeting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text('Halo, $greeting', style: theme.textTheme.titleMedium)),
            if (data.rank != null) _RankChip(rank: data.rank!, total: data.totalPresenters),
          ],
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(label: 'Pendapatan Hari Ini', value: rupiah(data.todayIncome), icon: Icons.today, tone: true)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Bulan Ini', value: rupiah(data.monthIncome), icon: Icons.calendar_month)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _StatCard(label: 'Closing Bulan Ini', value: '${data.monthClosings}', icon: Icons.check_circle_outline)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(label: 'Rata-rata / Closing', value: rupiah(data.avgPerClosing), icon: Icons.trending_up)),
        ]),
        const SizedBox(height: 24),
        Text('Closing Terbaik', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (data.bestTakeHome == 0)
          const _Empty('Belum ada closing')
        else
          Card(
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0xFFFFC107), child: Icon(Icons.star, color: Colors.white)),
              title: Text(rupiah(data.bestTakeHome), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(data.bestDate ?? ''),
            ),
          ),
        const SizedBox(height: 24),
        Text('Tren 7 Hari', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: _TrendBars(points: data.trend))),
        const SizedBox(height: 24),
        Text('Riwayat Closing', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (data.recent.isEmpty)
          const _Empty('Belum ada closing')
        else
          Card(
            child: Column(
              children: data.recent
                  .map((e) => ListTile(
                        leading: const Icon(Icons.receipt_long),
                        title: Text(rupiah(e.takeHome), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${e.entryDate} • ${e.closingCount} closing'),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _RankChip extends StatelessWidget {
  final int rank;
  final int total;
  const _RankChip({required this.rank, required this.total});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.emoji_events, size: 16, color: scheme.onPrimaryContainer),
        const SizedBox(width: 4),
        Text('Peringkat #$rank / $total', style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

// lightweight 7-bar chart, no chart package. bars scale to the max day.
class _TrendBars extends StatelessWidget {
  final List<TrendPoint> points;
  const _TrendBars({required this.points});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final max = points.fold<int>(0, (m, p) => p.income > m ? p.income : m);
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((p) {
          final ratio = max == 0 ? 0.0 : p.income / max;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (p.income > 0)
                  Text(_short(p.income), style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8 + ratio * 80,
                  decoration: BoxDecoration(
                    color: p.income > 0 ? scheme.primary : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(p.date.substring(8), style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // compact rupiah for tiny bar labels, e.g. 548000 -> "548k", 1200000 -> "1.2jt".
  String _short(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}jt';
    if (v >= 1000) return '${(v / 1000).round()}k';
    return '$v';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool tone;
  const _StatCard({required this.label, required this.value, required this.icon, this.tone = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tone ? scheme.primary : Colors.white;
    final fg = tone ? scheme.onPrimary : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg.withValues(alpha: 0.8), size: 20),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: fg, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 12)),
        ],
      ),
    );
  }
}

class _PodiumTile extends StatelessWidget {
  final int rank;
  final RecapRow row;
  const _PodiumTile({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    const medals = {1: Color(0xFFFFC107), 2: Color(0xFFB0BEC5), 3: Color(0xFFBCAAA4)};
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: medals[rank],
          child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        title: Text(row.presenterName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${row.entries} closing'),
        trailing: Text(rupiah(row.total), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorView({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 120),
          Icon(Icons.error_outline, size: 40, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Center(child: Text(message, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(child: OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi'))),
        ],
      );
}
