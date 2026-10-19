import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pop_icons.dart';
import 'theme.dart';

/// The courtyard arch: straight sides and a round top as wide as the rect.
Path archPath(Rect r) {
  final rad = r.width / 2;
  return Path()
    ..moveTo(r.left, r.bottom)
    ..lineTo(r.left, r.top + rad)
    ..arcToPoint(Offset(r.right, r.top + rad), radius: Radius.circular(rad))
    ..lineTo(r.right, r.bottom)
    ..close();
}

/// An arch filled with [fill]; with an ink outline and an optional label
/// band line at [divider] unless [fill] is ink (the hard shadow). With a
/// [divider], the band below it is white and the arch above is glazed with
/// halftone dots (canvas row G).
class ArchPainter extends CustomPainter {
  final Color fill;
  final double? divider;
  const ArchPainter({required this.fill, this.divider});

  @override
  void paint(Canvas canvas, Size size) {
    final arch = archPath(Offset.zero & size);
    canvas.drawPath(arch, Paint()..color = fill);
    if (fill == Pop.ink) return;
    final d = divider;
    canvas.save();
    canvas.clipPath(arch);
    final dots = Paint()..color = Pop.dotsOn(fill);
    final dotsTo = d ?? size.height;
    for (var y = 5.0; y < dotsTo; y += 10) {
      for (var x = 5.0; x < size.width; x += 10) {
        canvas.drawCircle(Offset(x, y), 2, dots);
      }
    }
    if (d != null) canvas.drawRect(Rect.fromLTRB(0, d, size.width, size.height), Paint()..color = Colors.white);
    canvas.restore();
    final stroke = Paint()
      ..color = Pop.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(archPath(const Offset(1.75, 1.75) & Size(size.width - 3.5, size.height - 3.5)), stroke);
    if (d != null) canvas.drawLine(Offset(1.5, d), Offset(size.width - 1.5, d), stroke..strokeWidth = 3);
  }

  @override
  bool shouldRepaint(ArchPainter old) => old.fill != fill || old.divider != divider;
}

/// A niche in the wall: an arch with an icon and a label band, that drops
/// into its shadow when pressed while the icon wobbles (canvas rows E and F).
class ArchNiche extends StatefulWidget {
  final PopIcon icon;
  final String label;
  final String? sublabel;

  /// The arch's glaze; the label band stays white.
  final Color glaze;
  final double width;
  final double height;

  /// Height of the label band at the bottom.
  final double band;
  final VoidCallback onTap;
  const ArchNiche({
    super.key,
    required this.icon,
    required this.label,
    this.sublabel,
    this.glaze = Pop.cyan,
    required this.width,
    required this.height,
    required this.band,
    required this.onTap,
  });

  @override
  State<ArchNiche> createState() => _ArchNicheState();
}

class _ArchNicheState extends State<ArchNiche> with SingleTickerProviderStateMixin {
  late final AnimationController _wobble = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  bool _down = false;

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    final still = MediaQuery.disableAnimationsOf(context);
    final icon = AnimatedBuilder(
      animation: _wobble,
      builder: (context, child) => Transform.rotate(angle: math.sin(_wobble.value * 2 * math.pi) * 0.16, child: child),
      child: PopIconView(widget.icon, size: math.min(w * 0.42, h - widget.band - 30)),
    );
    final sub = widget.sublabel;
    return Semantics(
      button: true,
      label: sub == null ? widget.label : '${widget.label}, $sub',
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _down = true);
          if (!still) _wobble.forward(from: 0);
        },
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: SizedBox(
          width: w + 5,
          height: h + 5,
          child: Stack(
            children: [
              Positioned(left: 5, top: 5, child: CustomPaint(size: Size(w, h), painter: const ArchPainter(fill: Pop.ink))),
              AnimatedContainer(
                duration: still ? Duration.zero : const Duration(milliseconds: 80),
                transform: Matrix4.translationValues(_down ? 5 : 0, _down ? 5 : 0, 0),
                width: w,
                height: h,
                child: Stack(
                  children: [
                    CustomPaint(size: Size(w, h), painter: ArchPainter(fill: widget.glaze, divider: h - widget.band)),
                    Positioned(left: 0, right: 0, top: 0, bottom: widget.band, child: Center(child: Padding(
                      padding: EdgeInsets.only(top: w * 0.12),
                      child: icon,
                    ))),
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 0,
                      height: widget.band,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(widget.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.1)),
                          if (sub != null)
                            Text(sub,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Pop.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pops or rises [child] in when the page opens, [index] steps after the
/// first (70 ms apart, as on Home). Nothing moves under reduce motion.
class Entrance extends StatefulWidget {
  final int index;
  final Widget child;

  /// Scale in from the bottom (niches) instead of rising (cards).
  final bool pop;
  const Entrance({super.key, required this.index, required this.child, this.pop = false});

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  static const _step = 70;
  static const _length = 420;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _length + _step * widget.index),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = _length + _step * widget.index;
    final t = CurvedAnimation(
      parent: _c,
      curve: Interval(_step * widget.index / total, 1, curve: widget.pop ? Curves.easeOutBack : Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) {
        final v = t.value;
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: widget.pop
              ? Transform.scale(scale: 0.4 + 0.6 * v, alignment: Alignment.bottomCenter, child: child)
              : Transform.translate(offset: Offset(0, 28 * (1 - v)), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// A two-state icon button: bookmark ribbon or favourite heart. The icon
/// pops once when it turns on; the state is also in its label and tooltip.
class ToggleIconButton extends StatelessWidget {
  final bool on;
  final PopIcon onIcon;
  final PopIcon offIcon;
  final String tooltip;
  final VoidCallback onPressed;
  const ToggleIconButton({
    super.key,
    required this.on,
    required this.onIcon,
    required this.offIcon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: on,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          radius: 26,
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(on),
                tween: Tween(begin: on && !still ? 1.35 : 1, end: 1),
                duration: still ? Duration.zero : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                child: PopIconView(on ? onIcon : offIcon, size: 34, shadow: false),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
