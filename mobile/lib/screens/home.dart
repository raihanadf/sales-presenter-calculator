import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../platform_bottom_navigation.dart';
import '../theme.dart';
import '../widgets.dart';
import 'entry_form.dart';
import 'entry_detail.dart';
import 'history.dart';
import 'settings_hub.dart';
import 'import_export.dart';
import '../util/format.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Object> _future;
  late final bool _isAdmin;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _isAdmin = context.read<AppState>().user!.isAdmin;
    _load();
  }

  void _load() {
    final api = context.read<AppState>().api;
    _future = _isAdmin
        ? api.dashboard(today(), thisMonth())
        : api.dashboardMe(today(), thisMonth());
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _openEntry() async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const EntryFormScreen()));
    if (saved == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Closing tersimpan. Menunggu persetujuan admin.')),
        );
      }
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = context.watch<AppState>().user!.name;

    return Scaffold(
      extendBody: true,
      floatingActionButton: !_isAdmin && _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openEntry,
              backgroundColor: context.colors.mint,
              foregroundColor: context.colors.ink,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Catat Closing',
                style: display(
                  15,
                  weight: FontWeight.w700,
                  color: context.colors.ink,
                  spacing: 0,
                ),
              ),
            )
          : null,
      bottomNavigationBar: PlatformBottomNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: _selectedIndex == 1
            ? const SettingsHubBody()
            : RefreshIndicator(
                color: context.colors.teal,
                onRefresh: _refresh,
                child: FutureBuilder<Object>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: context.colors.teal,
                        ),
                      );
                    }
                    if (snap.hasError) {
                      return _ErrorView(
                        message: '${snap.error}',
                        onRetry: _refresh,
                      );
                    }
                    final data = snap.data!;
                    if (data is MyDashboard) {
                      return _MyBody(data: data, name: name);
                    }
                    return _AdminBody(
                      data: data as Dashboard,
                      name: name,
                      onChanged: _refresh,
                    );
                  },
                ),
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
      padding: pagePadding(context, top: 10, bottom: 124),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text('Halo, $name',
              style: TextStyle(color: context.colors.muted, fontSize: 15)),
        ),
        HeroPanel(
          label: 'Pendapatan hari ini',
          amount: data.todayIncome,
          subLabel: 'Bulan ini',
          subAmount: data.monthIncome,
          trailing: data.rank != null
              ? RankPill(rank: data.rank!, total: data.totalPresenters)
              : null,
        ),
        const SizedBox(height: 18),
        LayoutBuilder(builder: (context, constraints) {
          final width = context.usesLargeText
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(
                width: width,
                child: StatTile(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Closing bulan ini',
                    value: Text('${data.monthClosings}', style: display(22)))),
            SizedBox(
                width: width,
                child: StatTile(
                    icon: Icons.trending_up_rounded,
                    label: 'Rata-rata / closing',
                    value: Rupiah(data.avgPerClosing, size: 18))),
          ]);
        }),
        const SizedBox(height: 26),
        const SectionTitle('Closing terbaik'),
        if (data.bestTakeHome == 0)
          const EmptyNote('Belum ada closing bulan ini')
        else
          Panel(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: context.colors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.star_rounded, color: context.colors.gold)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Rupiah(data.bestTakeHome, size: 20),
                    const SizedBox(height: 2),
                    Text(data.bestDate ?? '',
                        style: TextStyle(
                            color: context.colors.muted, fontSize: 13)),
                  ])),
            ]),
          ),
        const SizedBox(height: 26),
        const SectionTitle('Tren 7 hari'),
        Panel(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: TrendBars(
                points: data.trend
                    .map((t) => (date: t.date, income: t.income))
                    .toList())),
        const SizedBox(height: 26),
        const SectionTitle('Riwayat closing'),
        if (data.recent.isEmpty)
          const EmptyNote('Belum ada closing')
        else ...[
          Panel(
              child: Column(children: [
            for (var i = 0; i < data.recent.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    color: context.colors.line,
                    indent: 16,
                    endIndent: 16),
              _HistoryRow(entry: data.recent[i]),
            ],
          ])),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Lihat Semua'),
          ),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final RecentEntry entry;
  const _HistoryRow({required this.entry});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EntryDetailScreen(entryId: entry.id))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: AdaptiveSplit(
            leading:
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: context.colors.paper,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.receipt_long_rounded,
                      size: 22, color: context.colors.teal)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${entry.entryDate} · ${entry.closingCount} closing',
                        style: TextStyle(
                            fontSize: 13, color: context.colors.muted)),
                    const SizedBox(height: 5),
                    Text(entry.isPending ? 'Menunggu persetujuan' : 'Disetujui',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: entry.isPending
                                ? Colors.orange.shade800
                                : context.colors.teal)),
                  ])),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Rupiah(entry.takeHome, size: 16),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 22),
            ]),
          ),
        ),
      );
}

// ---------------- admin ----------------

class _AdminBody extends StatelessWidget {
  final Dashboard data;
  final String name;
  final Future<void> Function() onChanged;
  const _AdminBody(
      {required this.data, required this.name, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: pagePadding(context, top: 10, bottom: 124),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 14),
          child: Text('Halo, $name',
              style: TextStyle(color: context.colors.muted, fontSize: 15)),
        ),
        HeroPanel(
            label: 'Pendapatan hari ini',
            amount: data.todayIncome,
            subLabel: 'Bulan ini',
            subAmount: data.monthIncome),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await showImportSheet(context);
                if (ok == true) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Closing berhasil diimport.')),
                  );
                  await onChanged();
                }
              },
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => showExportSheet(context),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export'),
            ),
          ),
        ]),
        const SizedBox(height: 26),
        const SectionTitle('Menunggu persetujuan'),
        if (data.pending.isEmpty)
          const EmptyNote('Tidak ada closing yang menunggu')
        else
          ...data.pending.map((entry) =>
              _PendingApprovalTile(entry: entry, onApproved: onChanged)),
        const SizedBox(height: 26),
        const SectionTitle('Peringkat presenter'),
        if (data.top3.isEmpty)
          const EmptyNote('Belum ada closing bulan ini')
        else
          ...data.top3
              .asMap()
              .entries
              .map((e) => _PodiumTile(rank: e.key + 1, row: e.value)),
        const SizedBox(height: 26),
        const SectionTitle('Rekap bulan ini'),
        if (data.monthRecap.isEmpty)
          const EmptyNote('Belum ada data')
        else
          Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < data.monthRecap.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: context.colors.line,
                        indent: 18,
                        endIndent: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    child: AdaptiveSplit(
                      leading: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data.monthRecap[i].presenterName,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.ink)),
                            const SizedBox(height: 4),
                            Text('${data.monthRecap[i].entries} closing',
                                style: TextStyle(
                                    color: context.colors.muted, fontSize: 13)),
                          ]),
                      trailing: Rupiah(data.monthRecap[i].total, size: 16),
                    ),
                  ),
                ],
              ])),
      ],
    );
  }
}

class _PendingApprovalTile extends StatefulWidget {
  final SalesEntry entry;
  final Future<void> Function() onApproved;
  const _PendingApprovalTile({required this.entry, required this.onApproved});

  @override
  State<_PendingApprovalTile> createState() => _PendingApprovalTileState();
}

class _PendingApprovalTileState extends State<_PendingApprovalTile> {
  bool _approving = false;

  Future<void> _approve() async {
    setState(() => _approving = true);
    try {
      await context.read<AppState>().api.approveEntry(widget.entry.id);
      await widget.onApproved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Closing disetujui dan sudah masuk perhitungan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          padding: const EdgeInsets.all(18),
          child: AdaptiveSplit(
            gap: 16,
            stretchTrailing: true,
            leading: InkWell(
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          EntryDetailScreen(entryId: widget.entry.id))),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.entry.presenterName!,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(
                        '${widget.entry.entryDate} · ${widget.entry.inputs.closingCount} closing',
                        style: TextStyle(
                            fontSize: 13, color: context.colors.muted)),
                    const SizedBox(height: 7),
                    Rupiah(widget.entry.computed.takeHome, size: 16),
                  ]),
            ),
            trailing: FilledButton(
              onPressed: _approving ? null : _approve,
              child: _approving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Setujui'),
            ),
          ),
        ),
      );
}

class _PodiumTile extends StatelessWidget {
  final int rank;
  final RecapRow row;
  const _PodiumTile({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    final medals = {
      1: context.colors.gold,
      2: const Color(0xFFAFBDC4),
      3: const Color(0xFFC98A5E)
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(
              color: rank == 1 ? context.colors.gold : context.colors.line)),
      child: AdaptiveSplit(
        leading: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: medals[rank], borderRadius: BorderRadius.circular(12)),
              child: Text('$rank',
                  style: display(18, color: context.colors.ink, spacing: 0))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(row.presenterName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.colors.ink,
                        fontSize: 15)),
                const SizedBox(height: 4),
                Text('${row.entries} closing',
                    style:
                        TextStyle(color: context.colors.muted, fontSize: 13)),
              ])),
        ]),
        trailing: Rupiah(row.total, size: 17),
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
          Icon(Icons.cloud_off_rounded, size: 44, color: context.colors.muted),
          const SizedBox(height: 12),
          Center(
              child: Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted))),
          const SizedBox(height: 16),
          Center(
              child: OutlinedButton(
                  onPressed: onRetry, child: const Text('Coba lagi'))),
        ],
      );
}
