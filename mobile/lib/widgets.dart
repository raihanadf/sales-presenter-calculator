import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'util/format.dart';

BoxDecoration panelDecoration(BuildContext context, {Color? color, double radius = kRadius}) {
  final colors = context.colors;
  return BoxDecoration(
    color: color ?? colors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colors.line, width: colors.outlined ? 1.5 : 1),
    boxShadow: colors.outlined ? [BoxShadow(color: colors.ink, offset: const Offset(3, 4))] : null,
  );
}

class Rupiah extends StatelessWidget {
  final int value;
  final double size;
  final Color? color;
  final FontWeight weight;
  const Rupiah(this.value, {super.key, this.size = 20, this.color, this.weight = FontWeight.w700});

  @override
  Widget build(BuildContext context) => Text(rupiah(value), style: display(size, weight: weight, color: color ?? context.colors.ink));
}

class AdaptiveSplit extends StatelessWidget {
  final Widget leading;
  final Widget trailing;
  final double gap;
  final bool stretchTrailing;
  const AdaptiveSplit({super.key, required this.leading, required this.trailing, this.gap = 12, this.stretchTrailing = false});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (context.usesLargeText || constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leading,
                SizedBox(height: gap),
                stretchTrailing ? SizedBox(width: double.infinity, child: trailing) : Align(alignment: Alignment.centerLeft, child: trailing),
              ],
            );
          }
          return Row(children: [
            Expanded(child: leading),
            SizedBox(width: gap),
            trailing,
          ]);
        },
      );
}

class RankPill extends StatelessWidget {
  final int rank;
  final int total;
  const RankPill({super.key, required this.rank, required this.total});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: context.colors.gold,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.colors.ink, width: context.colors.outlined ? 1.5 : 0),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events_rounded, size: 15, color: context.colors.ink),
          const SizedBox(width: 5),
          Text('#$rank / $total', style: display(13, weight: FontWeight.w700, color: context.colors.ink, spacing: 0)),
        ]),
      );
}

class HeroPanel extends StatelessWidget {
  final String label;
  final int amount;
  final String subLabel;
  final int subAmount;
  final Widget? trailing;
  const HeroPanel({super.key, required this.label, required this.amount, required this.subLabel, required this.subAmount, this.trailing});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = colors.outlined ? colors.ink : Colors.white;
    final muted = colors.outlined ? colors.muted : Colors.white70;
    return Transform.rotate(
      angle: colors.outlined ? -0.012 : 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
        decoration: colors.outlined
            ? panelDecoration(context, color: colors.teal, radius: 28)
            : BoxDecoration(
                borderRadius: BorderRadius.circular(kRadius + 4),
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [colors.teal, colors.tealDark]),
                boxShadow: [BoxShadow(color: colors.tealDark.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 12))],
              ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AdaptiveSplit(
            leading: Text(label.toUpperCase(), style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            trailing: trailing ?? const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          Rupiah(amount, size: 42, color: foreground),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: foreground.withValues(alpha: 0.35)))),
            child: AdaptiveSplit(
              leading: Row(children: [
                Icon(Icons.account_balance_wallet_rounded, size: 18, color: colors.outlined ? colors.ink : colors.mint),
                const SizedBox(width: 10),
                Expanded(child: Text(subLabel, style: TextStyle(color: muted, fontSize: 13))),
              ]),
              trailing: Rupiah(subAmount, size: 16, color: colors.outlined ? colors.ink : colors.mint),
            ),
          ),
        ]),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget value;
  const StatTile({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: panelDecoration(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: context.colors.mint, shape: BoxShape.circle, border: Border.all(color: context.colors.line, width: context.colors.outlined ? 1.5 : 0)),
            child: Icon(icon, size: 18, color: context.colors.ink),
          ),
          const SizedBox(height: 12),
          value,
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: context.colors.muted, fontSize: 12)),
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!context.colors.outlined) ...[
            Container(width: 4, height: 22, decoration: BoxDecoration(color: context.colors.mint, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(text, style: display(18, weight: FontWeight.w700, spacing: -0.3))),
        ]),
      );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(4)});

  @override
  Widget build(BuildContext context) => Container(decoration: panelDecoration(context), padding: padding, child: child);
}

class DashedLine extends StatelessWidget {
  final Color? color;
  const DashedLine({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? context.colors.line;
    return LayoutBuilder(builder: (context, constraints) {
      final count = (constraints.maxWidth / 8).floor();
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(count, (_) => SizedBox(width: 4, height: 1.5, child: DecoratedBox(decoration: BoxDecoration(color: lineColor)))),
      );
    });
  }
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(text, style: TextStyle(color: context.colors.muted)),
      );
}

class TrendBars extends StatelessWidget {
  final List<({String date, int income})> points;
  const TrendBars({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final max = points.fold<int>(0, (current, point) => math.max(current, point.income));
    return SizedBox(
      height: context.usesLargeText ? 164 : 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final ratio = max == 0 ? 0.0 : point.income / max;
          final active = point.income > 0;
          return Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (active) Text(_short(point.income), style: display(10, weight: FontWeight.w600, color: context.colors.ink, spacing: 0)),
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                height: 8 + ratio * 78,
                decoration: BoxDecoration(
                  color: active ? context.colors.mint : context.colors.paper,
                  border: Border.all(color: context.colors.line, width: context.colors.outlined ? 1.2 : 0),
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              const SizedBox(height: 6),
              Text(point.date.substring(8), style: TextStyle(fontSize: 11, color: context.colors.muted)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  String _short(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')}jt';
    if (value >= 1000) return '${(value / 1000).round()}rb';
    return '$value';
  }
}
