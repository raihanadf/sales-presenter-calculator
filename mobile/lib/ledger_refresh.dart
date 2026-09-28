import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'widgets.dart';

// pull-to-refresh in the app's own language. the page itself comes down and a receipt slip is
// pulled out from the top edge, like paper out of a printer. letting go past the mark holds the
// page while the refresh runs, then the slip gets stamped "beres" (or "gagal") and it all slides
// back. a drop-in for RefreshIndicator: same onRefresh and child, the list inside is untouched
enum _Phase { idle, drag, armed, refreshing, done, failed }

class LedgerRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const LedgerRefresh(
      {super.key, required this.onRefresh, required this.child});

  @override
  State<LedgerRefresh> createState() => _LedgerRefreshState();
}

class _LedgerRefreshState extends State<LedgerRefresh>
    with SingleTickerProviderStateMixin {
  // letting go past this refreshes; the page then rests at hold while it runs
  static const _trigger = 96.0;
  static const _hold = 78.0;
  static const _max = 150.0;

  late final AnimationController _settle = AnimationController(vsync: this);
  _Phase _phase = _Phase.idle;
  double _pull = 0;
  DateTime? _stampedAt;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  // eases the page from wherever it is to target
  Future<void> _settleTo(double target) {
    final from = _pull;
    _settle.duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 280);
    void tick() => setState(() => _pull =
        from + (target - from) * Curves.easeOutCubic.transform(_settle.value));
    _settle.addListener(tick);
    return _settle
        .forward(from: 0)
        .whenComplete(() => _settle.removeListener(tick));
  }

  void _setPull(double value) {
    final next = value.clamp(0.0, _max);
    final armed = next >= _trigger;
    // a small tick at the exact point where letting go starts to count
    if (armed && _phase != _Phase.armed) HapticFeedback.selectionClick();
    setState(() {
      _pull = next;
      _phase = next == 0
          ? _Phase.idle
          : armed
              ? _Phase.armed
              : _Phase.drag;
    });
  }

  Future<void> _run() async {
    setState(() => _phase = _Phase.refreshing);
    await _settleTo(_hold);
    var failed = false;
    try {
      await widget.onRefresh();
    } catch (_) {
      // the page shows the error itself. the slip only has to say this pull did not land,
      // instead of stamping "beres" over a failure
      failed = true;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _phase = failed ? _Phase.failed : _Phase.done;
      _stampedAt = DateTime.now();
    });
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    await _settleTo(0);
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  bool _onScroll(ScrollNotification n) {
    // only the page's own vertical list: not the branch chips scrolling sideways inside it
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final busy = _phase == _Phase.refreshing ||
        _phase == _Phase.done ||
        _phase == _Phase.failed ||
        _settle.isAnimating;
    if (busy) return false;

    // a fling that merely reaches the top must not count, only a finger actually pulling
    if (n is OverscrollNotification && n.overscroll < 0 && n.dragDetails != null) {
      // resistance grows as the page comes down, like paper tugging against the slot
      final give = 1 - (_pull / _max).clamp(0.0, 1.0);
      _setPull(_pull - n.overscroll * 0.55 * give);
    } else if (n is ScrollUpdateNotification &&
        _pull > 0 &&
        n.dragDetails != null &&
        (n.scrollDelta ?? 0) > 0) {
      // pushing back up before letting go puts the slip away again
      _setPull(_pull - n.scrollDelta!);
    } else if (n is ScrollEndNotification && _pull > 0) {
      if (_phase == _Phase.armed) {
        _run();
      } else {
        _settleTo(0).then((_) {
          if (mounted) setState(() => _phase = _Phase.idle);
        });
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<OverscrollIndicatorNotification>(
        // the slip is this list's top edge now, so the platform's glow or stretch there would
        // only fight it. the bottom edge keeps its usual effect
        onNotification: (n) {
          if (n.leading && n.depth == 0) n.disallowIndicator();
          return false;
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ScrollConfiguration(
            // clamping everywhere, so the page only ever moves because this moves it
            behavior: ScrollConfiguration.of(context)
                .copyWith(physics: const ClampingScrollPhysics()),
            child: ClipRect(
              child: Stack(children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: _pull,
                  // the slip keeps its size and is revealed from its bottom edge up, so it reads
                  // as coming out of the slot rather than being squashed into the gap
                  // minWidth 0 matters: the positioned box hands down a tight full-width
                  // constraint, which would stretch the slip edge to edge into a banner
                  child: OverflowBox(
                    alignment: Alignment.bottomCenter,
                    minWidth: 0,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    child: _Slip(
                        phase: _phase,
                        progress: (_pull / _trigger).clamp(0.0, 1.0),
                        stampedAt: _stampedAt),
                  ),
                ),
                Transform.translate(
                    offset: Offset(0, _pull), child: widget.child),
              ]),
            ),
          ),
        ),
      );
}

class _Slip extends StatelessWidget {
  final _Phase phase;
  final double progress;
  final DateTime? stampedAt;
  const _Slip(
      {required this.phase, required this.progress, required this.stampedAt});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = switch (phase) {
      _Phase.armed => 'Lepas untuk memperbarui',
      _Phase.refreshing => 'Memperbarui angka…',
      _Phase.done => 'Diperbarui ${_clock(stampedAt!)}',
      _Phase.failed => 'Belum berhasil, tarik lagi',
      _ => 'Tarik untuk memperbarui',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: 250,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(14)),
          border: Border.all(
              color: colors.outlined ? colors.line : colors.rule,
              width: colors.outlined ? 1.5 : 1),
          boxShadow: colors.outlined
              ? [BoxShadow(color: colors.ink, offset: const Offset(2, 3))]
              : [
                  BoxShadow(
                      color: colors.ink.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            _lead(context),
            const SizedBox(width: 10),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: display(13.5, weight: FontWeight.w700, spacing: 0)),
            ),
          ]),
          const SizedBox(height: 10),
          // the tear line along the bottom of a receipt
          DashedLine(color: colors.rule),
        ]),
      ),
    );
  }

  Widget _lead(BuildContext context) {
    final colors = context.colors;
    if (phase == _Phase.refreshing) {
      return SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: colors.teal));
    }
    if (phase == _Phase.done || phase == _Phase.failed) {
      final ok = phase == _Phase.done;
      final ink = ok ? colors.teal : colors.danger;
      // pressed on like a rubber stamp: comes in large and tilted, lands flat on the paper
      return TweenAnimationBuilder<double>(
        key: ValueKey(phase),
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.rotate(
            angle: -0.12 * t,
            child: Transform.scale(scale: 1.8 - 0.8 * t, child: child),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: (ok ? colors.mint : colors.danger).withValues(alpha: ok ? 0.5 : 0.12),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: ink, width: 1.4),
          ),
          child: Text(ok ? 'BERES' : 'GAGAL',
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  color: ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1)),
        ),
      );
    }
    // a ring that fills toward the release point, with an arrow that flips once it is reached
    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(
            value: progress,
            strokeWidth: 2.4,
            color: colors.teal,
            backgroundColor: colors.rule),
        AnimatedRotation(
          turns: phase == _Phase.armed ? 0.5 : 0,
          duration: const Duration(milliseconds: 180),
          child: Icon(Icons.arrow_downward_rounded,
              size: 13, color: colors.ink),
        ),
      ]),
    );
  }

  static String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';
}
