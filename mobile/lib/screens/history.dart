import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'entry_detail.dart';

enum _HistoryPeriod { week, month, all }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _HistoryPeriod _period = _HistoryPeriod.month;
  int _page = 1;
  late Future<EntryPage> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final now = DateTime.now();
    String? from;
    String? to;
    if (_period == _HistoryPeriod.week) {
      from = _date(now.subtract(const Duration(days: 6)));
      to = _date(now);
    } else if (_period == _HistoryPeriod.month) {
      from = _date(DateTime(now.year, now.month));
      to = _date(DateTime(now.year, now.month + 1, 0));
    }
    _future = context.read<AppState>().api.entries(from: from, to: to, page: _page);
  }

  void _setPeriod(_HistoryPeriod period) {
    setState(() {
      _period = period;
      _page = 1;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Closing')),
      body: Column(children: [
        Padding(
          padding: pagePadding(context, top: 10, bottom: 16),
          child: LayoutBuilder(builder: (context, constraints) {
            final width = context.usesLargeText ? constraints.maxWidth : (constraints.maxWidth - 16) / 3;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(width: width, child: _PeriodButton(label: 'Mingguan', selected: _period == _HistoryPeriod.week, onTap: () => _setPeriod(_HistoryPeriod.week))),
              SizedBox(width: width, child: _PeriodButton(label: 'Bulanan', selected: _period == _HistoryPeriod.month, onTap: () => _setPeriod(_HistoryPeriod.month))),
              SizedBox(width: width, child: _PeriodButton(label: 'Semua', selected: _period == _HistoryPeriod.all, onTap: () => _setPeriod(_HistoryPeriod.all))),
            ]);
          }),
        ),
        Expanded(
          child: FutureBuilder<EntryPage>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: context.colors.teal));
              }
              if (snap.hasError) return Center(child: Text('${snap.error}'));
              final data = snap.data!;
              if (data.entries.isEmpty) return const Center(child: Text('Belum ada closing'));
              return ListView.separated(
                padding: pagePadding(context, top: 4, bottom: 18),
                itemCount: data.entries.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _EntryTile(entry: data.entries[index]),
              );
            },
          ),
        ),
        FutureBuilder<EntryPage>(
          future: _future,
          builder: (context, snap) {
            final data = snap.data;
            if (data == null || data.totalPages <= 1) return const SizedBox.shrink();
            return SafeArea(
              top: false,
              child: Padding(
                padding: pagePadding(context, top: 8, bottom: 12),
                child: context.usesLargeText
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Text('${data.page} dari ${data.totalPages}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: data.page > 1 ? () => setState(() { _page--; _load(); }) : null,
                          child: const Text('Sebelumnya'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: data.page < data.totalPages ? () => setState(() { _page++; _load(); }) : null,
                          child: const Text('Berikutnya'),
                        ),
                      ])
                    : Row(children: [
                        Expanded(child: OutlinedButton(
                          onPressed: data.page > 1 ? () => setState(() { _page--; _load(); }) : null,
                          child: const Text('Sebelumnya'),
                        )),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('${data.page} / ${data.totalPages}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Expanded(child: OutlinedButton(
                          onPressed: data.page < data.totalPages ? () => setState(() { _page++; _load(); }) : null,
                          child: const Text('Berikutnya'),
                        )),
                      ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? context.colors.mint : context.colors.card,
          foregroundColor: context.colors.ink,
        ),
        child: Text(label),
      );
}

class _EntryTile extends StatelessWidget {
  final SalesEntry entry;
  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) => Panel(
        padding: EdgeInsets.zero,
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EntryDetailScreen(entryId: entry.id))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: AdaptiveSplit(
              leading: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.receipt_long_rounded, size: 26, color: context.colors.teal),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${entry.entryDate} · ${entry.inputs.closingCount} closing', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  StatusStamp(pending: entry.isPending, label: entry.isPending ? 'Menunggu' : 'Disetujui'),
                ])),
              ]),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Rupiah(entry.computed.takeHome, size: 15),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ),
      );
}

String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
