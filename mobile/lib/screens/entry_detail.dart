import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../api/models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets.dart';

class EntryDetailScreen extends StatelessWidget {
  final int entryId;
  const EntryDetailScreen({super.key, required this.entryId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Closing')),
      body: FutureBuilder<SalesEntry>(
        future: context.read<AppState>().api.entry(entryId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: context.colors.teal));
          }
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          return _EntryBreakdown(entry: snap.data!);
        },
      ),
    );
  }
}

class _EntryBreakdown extends StatelessWidget {
  final SalesEntry entry;
  const _EntryBreakdown({required this.entry});

  @override
  Widget build(BuildContext context) {
    final input = entry.inputs;
    final settings = entry.settingsSnapshot;
    final result = entry.computed;
    return ListView(
      padding: pagePadding(context, top: 10),
      children: [
        Container(
          decoration: panelDecoration(context, color: context.colors.gold),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.entryDate, style: display(20)),
            const SizedBox(height: 6),
            Text(entry.isPending ? 'Menunggu persetujuan admin' : 'Sudah disetujui', style: TextStyle(color: entry.isPending ? context.colors.pending : context.colors.teal, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            const Text('Diterima presenter'),
            Rupiah(result.takeHome, size: 30),
          ]),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Cara hitung'),
        Panel(padding: const EdgeInsets.all(18), child: Column(children: [
          if (settings != null) ...[
            _FormulaRow(
              label: 'Closing',
              formula: '${input.closingCount} × ${rupiah(settings.closingPrice)}',
              result: result.closingTotal,
            ),
            const Divider(),
            _FormulaRow(
              label: 'BOP',
              formula: '${rupiah(input.bopInput)} × ${settings.bopPercent}%',
              result: result.bopValue,
              minus: true,
            ),
            const Divider(),
            _FormulaRow(
              label: 'Souvenir',
              formula: '${input.audienceCount} × ${rupiah(settings.souvenirUnitPrice)} × ${settings.souvenirPercent}%',
              result: result.souvenirValue,
              minus: true,
            ),
          ] else ...[
            Text('Tarif lama tidak tersimpan untuk catatan ini. Nilai hasil saat dicatat tetap tidak berubah.', style: TextStyle(color: context.colors.muted)),
            const Divider(),
            _FormulaRow(label: 'Total closing tersimpan', formula: '${input.closingCount} closing', result: result.closingTotal),
            const Divider(),
            _FormulaRow(label: 'BOP tersimpan', formula: rupiah(input.bopInput), result: result.bopValue, minus: true),
            const Divider(),
            _FormulaRow(label: 'Souvenir tersimpan', formula: '${input.audienceCount} audience', result: result.souvenirValue, minus: true),
          ],
          const Divider(),
          _FormulaRow(label: 'Potongan harian', formula: 'Nilai saat dicatat', result: input.harian, minus: true),
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: DashedLine(color: context.colors.ink)),
          _FormulaRow(
            label: 'Total diterima',
            formula: '${rupiah(result.closingTotal)} − ${rupiah(result.bopValue)} − ${rupiah(result.souvenirValue)} − ${rupiah(input.harian)}',
            result: result.takeHome,
            strong: true,
          ),
        ])),
      ],
    );
  }
}

class _FormulaRow extends StatelessWidget {
  final String label;
  final String formula;
  final int result;
  final bool minus;
  final bool strong;
  const _FormulaRow({required this.label, required this.formula, required this.result, this.minus = false, this.strong = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: AdaptiveSplit(
          leading: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w700)),
            const SizedBox(height: 5),
            Text(formula, style: TextStyle(fontSize: 12, color: context.colors.muted)),
          ]),
          trailing: Text('${minus ? '− ' : ''}${rupiah(result)}', style: display(strong ? 17 : 14, weight: FontWeight.w700, spacing: 0)),
        ),
      );
}
