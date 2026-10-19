import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'strings.dart';
import 'theme.dart';

/// Headline in Bungee with a slightly misregistered print shadow.
class MisprintText extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final bool heavyShadow;
  const MisprintText(this.text, {super.key, this.size = 28, this.color = Pop.ink, this.heavyShadow = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: Pop.display,
        fontSize: size,
        height: 1.05,
        color: color,
        shadows: heavyShadow
            ? const [Shadow(color: Pop.ink, offset: Offset(3, 3)), Shadow(color: Pop.cyan, offset: Offset(-2, 0))]
            : const [Shadow(color: Pop.pink, offset: Offset(3, 0)), Shadow(color: Pop.cyan, offset: Offset(-3, 0))],
      ),
    );
  }
}

/// A comic panel: ink outline and a hard offset shadow.
class InkPanel extends StatelessWidget {
  final Widget child;
  final Color color;
  final double border;
  final double shadow;
  final double tiltDegrees;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool halftone;
  final Color dotColor;

  const InkPanel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.border = 4,
    this.shadow = 6,
    this.tiltDegrees = 0,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.halftone = false,
    this.dotColor = const Color(0x80FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget panel = Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Pop.ink, width: border),
        boxShadow: shadow > 0 ? [BoxShadow(color: Pop.ink, offset: Offset(shadow, shadow))] : null,
      ),
      child: CustomPaint(
        painter: halftone ? HalftonePainter(dotColor) : null,
        child: Padding(padding: padding, child: child),
      ),
    );
    if (onTap != null) {
      panel = Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: panel),
      );
    }
    if (tiltDegrees != 0 && !reduceMotion) {
      panel = Transform.rotate(angle: tiltDegrees * math.pi / 180, child: panel);
    }
    return panel;
  }
}

/// Comic-print dot screen.
class HalftonePainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double radius;
  const HalftonePainter(this.color, {this.spacing = 10, this.radius = 2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = spacing / 2; y < size.height; y += spacing) {
      for (var x = spacing / 2; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(HalftonePainter old) => old.color != color;
}

/// Full-screen dotted paper behind a page.
class DottedPaper extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color dot;
  const DottedPaper({super.key, required this.child, this.color = Pop.paper, this.dot = const Color(0x5519C3FF)});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: CustomPaint(painter: HalftonePainter(dot, spacing: 12, radius: 1.5), child: child),
    );
  }
}

/// Primary call to action.
class ComicButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;
  const ComicButton({super.key, required this.label, this.icon, this.onPressed, this.color = Pop.pink});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkPanel(
        color: onPressed == null ? const Color(0xFFDDD8E6) : color,
        shadow: onPressed == null ? 0 : 6,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        onTap: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: Pop.ink, size: 24), const SizedBox(width: 10)],
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: Pop.display, fontSize: 16, color: Pop.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square icon button with an ink outline.
class InkIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  const InkIconButton({super.key, required this.icon, required this.tooltip, this.onPressed, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: InkPanel(
            color: color,
            border: 3,
            shadow: 3,
            padding: EdgeInsets.zero,
            onTap: onPressed,
            child: Center(child: Icon(icon, color: Pop.ink, size: 22)),
          ),
        ),
      ),
    );
  }
}

/// Small caption box, like a comic narration box.
class Caption extends StatelessWidget {
  final String text;
  final Color color;
  const Caption(this.text, {super.key, this.color = Pop.lemon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: color, border: Border.all(color: Pop.ink, width: 3)),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Pop.ink)),
    );
  }
}

/// Quran and hadith Arabic: calm, large, right to left. Never decorated.
class ArabicText extends StatelessWidget {
  final String text;
  final double size;
  const ArabicText(this.text, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: TextStyle(fontFamily: Pop.quran, fontSize: size, height: 2.0, color: Pop.ink),
      ),
    );
  }
}

/// Where a text came from, with the version where the source has one.
class SourceLabel extends StatelessWidget {
  final String sourceKey;
  final String? extra;
  const SourceLabel(this.sourceKey, {super.key, this.extra});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final info = state.bundle?.source(sourceKey);
    final title = info == null ? sourceKey : '${info.title}, ${info.publisher}${info.version.isEmpty ? '' : ' v${info.version}'}';
    final parts = ['${tr('source', state.lang)}: $title', if (extra != null && extra!.isNotEmpty) extra!];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(parts.join(', '), style: const TextStyle(fontSize: 13, color: Pop.muted)),
    );
  }
}

class Heading extends StatelessWidget {
  final String text;
  const Heading(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Pop.ink)),
    );
  }
}

// ---------------------------------------------------------------------------
// Mosaic tiles

enum Glaze { empty, next, partial, full }

/// Eight-pointed star path centred in [size], built from two squares.
Path starPath(Size size, {double inset = 0}) {
  final c = size.center(Offset.zero);
  final r = size.shortestSide / 2 - inset;
  final inner = r * math.cos(math.pi / 4) / math.cos(math.pi / 8);
  final path = Path();
  for (var i = 0; i < 16; i++) {
    final a = math.pi / 8 * i - math.pi / 2;
    final rad = i.isEven ? r : inner;
    final p = Offset(c.dx + rad * math.cos(a), c.dy + rad * math.sin(a));
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  return path..close();
}

class StarTilePainter extends CustomPainter {
  final Glaze glaze;
  final Color color;
  final double stroke;
  StarTilePainter({required this.glaze, required this.color, this.stroke = 3});

  @override
  void paint(Canvas canvas, Size size) {
    final inset = stroke + size.shortestSide * 0.04;
    final star = starPath(size, inset: inset);
    final ink = Paint()
      ..color = Pop.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;

    switch (glaze) {
      case Glaze.full:
        final shadowOffset = size.shortestSide * 0.05;
        canvas.drawPath(star.shift(Offset(shadowOffset, shadowOffset)), Paint()..color = Pop.ink);
        canvas.drawPath(star, Paint()..color = color);
        canvas.drawPath(star, ink);
      case Glaze.partial:
        canvas.drawPath(star, Paint()..color = Colors.white);
        canvas.save();
        canvas.clipPath(star);
        HalftonePainter(color, spacing: size.shortestSide / 9, radius: size.shortestSide / 28).paint(canvas, size);
        canvas.restore();
        canvas.drawPath(star, ink);
      case Glaze.next:
        canvas.drawPath(star, Paint()..color = Colors.white);
        canvas.drawPath(star, ink);
      case Glaze.empty:
        canvas.drawPath(star, Paint()..color = Colors.white);
        _dashed(canvas, star, ink..strokeWidth = stroke * 0.7, dash: size.shortestSide / 14);
    }
  }

  void _dashed(Canvas canvas, Path path, Paint paint, {required double dash}) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash * 1.8;
      }
    }
  }

  @override
  bool shouldRepaint(StarTilePainter old) => old.glaze != glaze || old.color != color || old.stroke != stroke;
}

class StarTile extends StatelessWidget {
  final Glaze glaze;
  final Color color;
  final double size;
  final String? label;
  final String semanticsLabel;
  const StarTile({
    super.key,
    required this.glaze,
    required this.color,
    required this.size,
    required this.semanticsLabel,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: StarTilePainter(glaze: glaze, color: color, stroke: size < 40 ? 2 : 3),
          child: label == null
              ? null
              : Center(
                  child: Text(
                    label!,
                    style: TextStyle(fontSize: size * 0.24, fontWeight: FontWeight.w800, color: Pop.ink, height: 1),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The "Nice!" starburst. Scales in once unless reduced motion is on.
class Burst extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const Burst({super.key, required this.text, this.color = Pop.violet, this.size = 112});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final burst = SizedBox(
      width: size,
      height: size * 0.93,
      child: CustomPaint(
        painter: _BurstPainter(color),
        child: Center(
          child: Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: Pop.display,
                fontSize: size * 0.17,
                color: Colors.white,
                shadows: const [Shadow(color: Pop.ink, offset: Offset(2, 2))],
              )),
        ),
      ),
    );
    if (reduceMotion) return Transform.rotate(angle: 0.17, child: burst);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Transform.rotate(angle: 0.17, child: Transform.scale(scale: t, child: child)),
      child: burst,
    );
  }
}

class _BurstPainter extends CustomPainter {
  final Color color;
  _BurstPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path();
    for (var i = 0; i < 16; i++) {
      final a = math.pi / 8 * i - math.pi / 2;
      final r = i.isEven ? size.width / 2 - 3 : size.width / 2 * 0.62;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a) * (size.height / size.width));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Pop.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.color != color;
}

/// Halftone sky bands used as a placeholder scene until real art lands.
class SceneBands extends StatelessWidget {
  final double height;
  final Widget child;
  const SceneBands({super.key, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pop.ink, width: 4))),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(flex: 5, child: _band(Pop.violet, const Color(0x59FFFFFF))),
              Expanded(flex: 2, child: _band(Pop.pink, const Color(0xB3FFD93B))),
              Container(height: 4, color: Pop.ink),
              Expanded(flex: 3, child: _band(Pop.lemon, const Color(0x80FF3D8B))),
            ],
          ),
          Positioned(
            right: 110,
            top: height * 0.36,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: Pop.lemon, shape: BoxShape.circle, border: Border.all(color: Pop.ink, width: 4)),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _band(Color color, Color dot) =>
      ColoredBox(color: color, child: CustomPaint(painter: HalftonePainter(dot, spacing: 9, radius: 1.8), child: const SizedBox.expand()));
}
