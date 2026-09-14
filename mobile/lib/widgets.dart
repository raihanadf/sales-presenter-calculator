import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'util/format.dart';

// rupiah rendered in the display face (space grotesk).
class Rupiah extends StatelessWidget {
  final int value;
  final double size;
  final Color? color;
  final FontWeight weight;
  const Rupiah(this.value, {super.key, this.size = 20, this.color, this.weight = FontWeight.w700});

  @override
  Widget build(BuildContext context) => Text(rupiah(value), style: display(size, weight: weight, color: color ?? AppColors.ink));
}

// gold rank pill, the motivational signature marker.
class RankPill extends StatelessWidget {
  final int rank;
  final int total;
  const RankPill({super.key, required this.rank, required this.total});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events_rounded, size: 15, color: AppColors.ink),
          const SizedBox(width: 5),
          Text('#$rank / $total', style: display(13, weight: FontWeight.w700, color: AppColors.ink, spacing: 0)),
        ]),
      );
}

// deep-teal hero panel: the earnings thesis of every dashboard.
class HeroPanel extends StatelessWidget {
  final String label;
  final int amount;
  final String subLabel;
  final int subAmount;
  final Widget? trailing;
  const HeroPanel({super.key, required this.label, required this.amount, required this.subLabel, required this.subAmount, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadius + 4),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.teal, AppColors.tealDark]),
          boxShadow: [BoxShadow(color: AppColors.tealDark.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 10),
            Rupiah(amount, size: 44, color: Colors.white, weight: FontWeight.w700),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.only(top: 14), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white24))),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.mint),
                const SizedBox(width: 8),
                Text(subLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const Spacer(),
                Rupiah(subAmount, size: 16, color: AppColors.mint),
              ]),
            ),
          ],
        ),
      );
}

// white metric tile used in a grid under the hero.
class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget value;
  const StatTile({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: AppColors.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: AppColors.teal)),
            const SizedBox(height: 12),
            value,
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      );
}

// section eyebrow with a short mint tick, encodes "a group starts here".
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: AppColors.mint, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(text, style: display(17, weight: FontWeight.w700, spacing: -0.3)),
        ]),
      );
}

// plain white card container.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(4)});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(kRadius), border: Border.all(color: AppColors.line)),
        padding: padding,
        child: child,
      );
}

// horizontal dashed rule for the receipt-style breakdown.
class DashedLine extends StatelessWidget {
  final Color color;
  const DashedLine({super.key, this.color = AppColors.line});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final count = (c.maxWidth / 8).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(count, (_) => SizedBox(width: 4, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: color)))),
        );
      });
}

// empty-state line.
class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: const TextStyle(color: AppColors.muted)),
      );
}

// mint bars, 7-day trend. no chart package.
class TrendBars extends StatelessWidget {
  final List<({String date, int income})> points;
  const TrendBars({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final max = points.fold<int>(0, (m, p) => math.max(m, p.income));
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((p) {
          final ratio = max == 0 ? 0.0 : p.income / max;
          final active = p.income > 0;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (active) Text(_short(p.income), style: display(10, weight: FontWeight.w600, color: AppColors.teal, spacing: 0)),
                const SizedBox(height: 4),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  height: 8 + ratio * 78,
                  decoration: BoxDecoration(
                    gradient: active ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.mint, AppColors.teal]) : null,
                    color: active ? null : AppColors.line,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(p.date.substring(8), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // compact money for bar caps, e.g. 548000 -> "548rb", 1200000 -> "1,2jt".
  String _short(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1).replaceAll('.', ',')}jt';
    if (v >= 1000) return '${(v / 1000).round()}rb';
    return '$v';
  }
}
