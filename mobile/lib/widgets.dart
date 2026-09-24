import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'util/format.dart';
import 'anim.dart';

// every surface used to carry the same 3x4 ink shadow, so the hero, a stat tile and a plain list
// all shouted at the same volume and nothing led the eye. panels now sit lower by default and
// the hero passes a deeper lift, so there is a clear first thing to look at
BoxDecoration panelDecoration(BuildContext context,
    {Color? color, double radius = kRadius, Offset lift = const Offset(2, 3)}) {
  final colors = context.colors;
  return BoxDecoration(
    color: color ?? colors.card,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colors.line, width: colors.outlined ? 1.5 : 1),
    boxShadow:
        colors.outlined ? [BoxShadow(color: colors.ink, offset: lift)] : null,
  );
}

// approved and pending, stamped like a ledger entry instead of a line of coloured text. the old
// label was lavender (pocket's "teal") for approved and a hard-coded orange for pending
class StatusStamp extends StatelessWidget {
  final bool pending;
  final String label;
  const StatusStamp({super.key, required this.pending, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ink = pending ? colors.pending : colors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (pending ? colors.gold : colors.mint).withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ink.withValues(alpha: 0.7), width: 1.2),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              color: ink,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9)),
    );
  }
}

class Rupiah extends StatelessWidget {
  final int value;
  final double size;
  final Color? color;
  final FontWeight weight;
  const Rupiah(this.value,
      {super.key, this.size = 20, this.color, this.weight = FontWeight.w700});

  @override
  Widget build(BuildContext context) => Text(rupiah(value),
      style: display(size, weight: weight, color: color ?? context.colors.ink));
}

class AdaptiveSplit extends StatelessWidget {
  final Widget leading;
  final Widget trailing;
  final double gap;
  final bool stretchTrailing;
  const AdaptiveSplit(
      {super.key,
      required this.leading,
      required this.trailing,
      this.gap = 12,
      this.stretchTrailing = false});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (context.usesLargeText || constraints.maxWidth < 280) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                leading,
                SizedBox(height: gap),
                stretchTrailing
                    ? SizedBox(width: double.infinity, child: trailing)
                    : Align(alignment: Alignment.centerLeft, child: trailing),
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
          border: Border.all(
              color: context.colors.ink,
              width: context.colors.outlined ? 1.5 : 0),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events_rounded, size: 15, color: context.colors.ink),
          const SizedBox(width: 5),
          Text('#$rank / $total',
              style: display(13,
                  weight: FontWeight.w700,
                  color: context.colors.ink,
                  spacing: 0)),
        ]),
      );
}

class HeroPanel extends StatelessWidget {
  final String label;
  final int amount;
  final String subLabel;
  final int subAmount;
  final Widget? trailing;
  const HeroPanel(
      {super.key,
      required this.label,
      required this.amount,
      required this.subLabel,
      required this.subAmount,
      this.trailing});

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
            // the hero leads the screen, so it carries the deepest lift of any surface
            ? panelDecoration(context,
                color: colors.wash, radius: 28, lift: const Offset(4, 5))
            : BoxDecoration(
                borderRadius: BorderRadius.circular(kRadius + 4),
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.teal, colors.tealDark]),
                boxShadow: [
                  BoxShadow(
                      color: colors.tealDark.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12))
                ],
              ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AdaptiveSplit(
            leading: Text(label.toUpperCase(),
                style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2)),
            trailing: trailing ?? const SizedBox.shrink(),
          ),
          const SizedBox(height: 10),
          // on a small phone an 8-digit day broke into "Rp" on one line and the figure on the
          // next. a total must never split, so it scales down to fit and only ever down
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: CountUpRupiah(amount, size: 42, color: foreground),
          ),
          const SizedBox(height: 16),
          // a dashed tear line, like the total on a receipt: the same device the entry form
          // already uses above its "diterima presenter" figure, so every money summary matches
          DashedLine(color: foreground.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          AdaptiveSplit(
            leading: Row(children: [
              Icon(Icons.account_balance_wallet_rounded,
                  size: 18,
                  color: colors.outlined ? colors.ink : colors.mint),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(subLabel,
                      style: TextStyle(color: muted, fontSize: 13))),
            ]),
            trailing: Rupiah(subAmount,
                size: 16, color: colors.outlined ? colors.ink : colors.mint),
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
  const StatTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: panelDecoration(context),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: context.colors.mint,
                shape: BoxShape.circle,
                border: Border.all(
                    color: context.colors.line,
                    width: context.colors.outlined ? 1.5 : 0)),
            child: Icon(icon, size: 18, color: context.colors.ink),
          ),
          const SizedBox(height: 12),
          value,
          const SizedBox(height: 3),
          Text(label,
              style: TextStyle(color: context.colors.muted, fontSize: 12)),
        ]),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // a ruled line running off to the edge is what a section break looks like in a real ledger,
    // and it costs nothing structurally. dropped at large text sizes, where the title needs the room
    final ruled = !context.usesLargeText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (!colors.outlined) ...[
          Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                  color: colors.mint, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
        ],
        // the title keeps its natural width and the rule takes whatever is left. as a flexible
        // beside an expanded rule it could only ever have half the row, which wrapped
        // "peringkat presenter" onto two lines. every title is a short fixed string, and at
        // large text sizes the rule steps aside so the title gets the whole row
        if (ruled) ...[
          Text(text, style: display(18, weight: FontWeight.w700, spacing: -0.3)),
          const SizedBox(width: 12),
          Expanded(child: DashedLine(color: colors.rule)),
        ] else
          Expanded(
              child: Text(text,
                  style: display(18, weight: FontWeight.w700, spacing: -0.3))),
      ]),
    );
  }
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const Panel(
      {super.key, required this.child, this.padding = const EdgeInsets.all(4)});

  @override
  Widget build(BuildContext context) => Container(
      decoration: panelDecoration(context), padding: padding, child: child);
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
        children: List.generate(
            count,
            (_) => SizedBox(
                width: 4,
                height: 1.5,
                child:
                    DecoratedBox(decoration: BoxDecoration(color: lineColor)))),
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
    final max = points.fold<int>(
        0, (current, point) => math.max(current, point.income));
    return SizedBox(
      height: context.usesLargeText ? 164 : 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: points.map((point) {
          final ratio = max == 0 ? 0.0 : point.income / max;
          final active = point.income > 0;
          return Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (active)
                Text(_short(point.income),
                    style: display(10,
                        weight: FontWeight.w600,
                        color: context.colors.ink,
                        spacing: 0)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  height: 4 + ratio * 84 * t,
                  decoration: BoxDecoration(
                    // a quiet tint rather than the page colour: on a card, paper was invisible
                    color: active
                        ? context.colors.mint
                        : context.colors.ink.withValues(alpha: 0.07),
                    border: Border.all(
                        color: context.colors.line,
                        width: context.colors.outlined ? 1.2 : 0),
                    // rounding every corner turned a short bar into a lozenge; a bar should sit
                    // on the axis and only round where it ends
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(point.date.substring(8),
                  style: TextStyle(fontSize: 11, color: context.colors.muted)),
            ]),
          );
        }).toList(),
      ),
    );
  }

  String _short(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')}jt';
    }
    if (value >= 1000) return '${(value / 1000).round()}rb';
    return '$value';
  }
}
