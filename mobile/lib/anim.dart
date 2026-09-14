import 'package:flutter/material.dart';
import 'theme.dart';
import 'util/format.dart';

// plays a one-shot fade + rise when first shown. an optional delay lets a
// column of these stagger into view.
class Reveal extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double offset;
  const Reveal(
      {super.key, required this.child, this.delayMs = 0, this.offset = 18});

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(
              offset: Offset(0, (1 - _a.value) * widget.offset), child: child),
        ),
        child: widget.child,
      );
}

// rupiah text that rolls from its previous value to the new one.
class CountUpRupiah extends StatelessWidget {
  final int value;
  final double size;
  final Color? color;
  final FontWeight weight;
  const CountUpRupiah(this.value,
      {super.key, this.size = 20, this.color, this.weight = FontWeight.w700});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text(
          rupiah(v.round()),
          style:
              display(size, weight: weight, color: color ?? context.colors.ink),
        ),
      );
}
