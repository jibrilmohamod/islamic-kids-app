import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../activity.dart';
import '../app_state.dart';
import '../models.dart';
import '../pop_icons.dart';
import '../progress.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'downloads_screen.dart';
import 'dua_screen.dart';
import 'duas_screen.dart';
import 'hadith_screen.dart';
import 'missing_word_screen.dart';
import 'mosaic_screen.dart';
import 'mushaf_screen.dart';
import 'order_game_screen.dart';
import 'parent_gate.dart';
import 'parent_screen.dart';
import 'surah_screen.dart';

/// Picks a dua for the time of day: morning and evening adhkar around those
/// times, otherwise an "any time" dua.
Dua? duaForNow(List<Dua> duas, DateTime now) {
  if (duas.isEmpty) return null;
  final h = now.hour;
  final moment = (h >= 4 && h < 11) || (h >= 16 && h < 20) ? 'morning-evening' : 'anytime';
  final matches = duas.where((d) => d.moment == moment).toList();
  if (matches.isEmpty) return duas.first;
  return matches[now.day % matches.length];
}

/// The sky over Home follows the day: sunrise, bright afternoon, night.
enum Sky { morning, afternoon, evening }

Sky skyFor(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 11) return Sky.morning;
  if (h >= 11 && h < 16) return Sky.afternoon;
  return Sky.evening;
}

/// Home as a courtyard wall (design canvas row E): an arch showing the sky
/// with "keep going" in it, the dua for now, this week's stars, and arched
/// niches for each part of the app.
///
/// Motion (spec on the canvas): the opening plays once a day, about 1.6 s;
/// later visits that day only fade in; none at all when the phone asks for
/// reduced motion.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 300), value: 1);
  bool _started = false;

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    _pulse.dispose();
    _fade.dispose();
    super.dispose();
  }

  /// Starts the motion once the bundle is there.
  void _start(AppState state) {
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _intro.value = 1;
      return;
    }
    final today = dayKey(state.now());
    final full = state.homeIntroDay != today;
    if (full) {
      state.setHomeIntroDay(today);
      _intro.forward().whenComplete(() async {
        if (!mounted) return;
        for (var i = 0; i < 2; i++) {
          await _pulse.forward();
          await _pulse.reverse();
        }
      });
    } else {
      // Same day: everything already in place, one short fade.
      _intro.value = 1;
      _fade.forward(from: 0);
    }
    _ambient.repeat();
  }

  Animation<double> _at(int fromMs, int lengthMs, [Curve curve = Curves.easeOutBack]) {
    const total = 1600;
    final a = (fromMs / total).clamp(0.0, 1.0);
    final b = ((fromMs + lengthMs) / total).clamp(0.0, 1.0);
    return CurvedAnimation(parent: _intro, curve: Interval(a, b, curve: curve));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle;

    if (bundle == null) {
      return Scaffold(
        body: DottedPaper(
          child: Center(
            child: state.error == null
                ? const CircularProgressIndicator(color: Pop.ink)
                : Padding(padding: const EdgeInsets.all(24), child: Text(tr('loadError', lang))),
          ),
        ),
      );
    }
    _start(state);
    final now = state.now();
    final sky = skyFor(now);

    final content = ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        _Header(sky: sky, onParents: () async {
          if (await askParent(context) && context.mounted) go(context, const ParentScreen());
        }),
        const SizedBox(height: 14),
        _Hero(
          sky: sky,
          skyIn: _at(0, 900, Curves.easeOutCubic),
          cardIn: _at(450, 450),
          ambient: _ambient,
          child: _ContinueCard(state: state),
        ),
        const SizedBox(height: 10),
        _Rise(
          t: _at(600, 450),
          child: _DuaCard(now: now, ambient: _ambient),
        ),
        const SizedBox(height: 14),
        _Rise(
          t: _at(650, 450),
          child: _WeekRow(now: now, intro: _intro, pulse: _pulse),
        ),
        const SizedBox(height: 16),
        _Niches(intro: _intro, ambient: _ambient),
      ],
    );

    return Scaffold(
      body: DottedPaper(
        child: SafeArea(
          child: FadeTransition(opacity: _fade, child: content),
        ),
      ),
    );
  }
}

String greetingKey(Sky sky) => switch (sky) {
      Sky.morning => 'goodMorning',
      Sky.afternoon => 'goodAfternoon',
      Sky.evening => 'goodEvening',
    };

class _Header extends StatelessWidget {
  final Sky sky;
  final VoidCallback onParents;
  const _Header({required this.sky, required this.onParents});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('salaam', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              MisprintText(tr(greetingKey(sky), lang), size: 26),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: tr('parents', lang),
          child: _Pressable(
            onTap: onParents,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border.fromBorderSide(BorderSide(color: Pop.ink, width: 3)),
              ),
              alignment: Alignment.center,
              child: const PopIconView(PopIcon.parents, size: 34, shadow: false),
            ),
          ),
        ),
      ],
    );
  }
}

/// Slides up and fades in as [t] goes 0 to 1.
class _Rise extends StatelessWidget {
  final Animation<double> t;
  final Widget child;
  const _Rise({required this.t, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Opacity(
        opacity: t.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 28 * (1 - t.value)), child: child),
      ),
      child: child,
    );
  }
}

/// Scales in from 40% with a small overshoot as [t] goes 0 to 1.
class _Pop extends StatelessWidget {
  final Animation<double> t;
  final Widget child;
  final Alignment origin;
  const _Pop({required this.t, required this.child, this.origin = Alignment.center});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (context, child) => Opacity(
        opacity: t.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.4 + 0.6 * t.value, alignment: origin, child: child),
      ),
      child: child,
    );
  }
}

/// The comic press: the child drops into its hard shadow while held.
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double shadow;
  const _Pressable({required this.child, required this.onTap, this.shadow = 4});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.shadow;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: s, top: s, right: -s, bottom: -s, child: const ColoredBox(color: Pop.ink)),
          AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            transform: Matrix4.translationValues(_down ? s : 0, _down ? s : 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The arch with the sky

class _Hero extends StatelessWidget {
  final Sky sky;
  final Animation<double> skyIn;
  final Animation<double> cardIn;
  final Animation<double> ambient;
  final Widget child;
  const _Hero({required this.sky, required this.skyIn, required this.cardIn, required this.ambient, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      final h = w * 292 / 350;
      return SizedBox(
        width: w,
        height: h + 5,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(painter: SkyArchPainter(sky: sky, rise: skyIn, ambient: ambient)),
              ),
            ),
            Positioned(
              left: w * 0.13,
              right: w * 0.14,
              top: h * 0.6,
              child: _Rise(t: cardIn, child: child),
            ),
          ],
        ),
      );
    });
  }
}

/// Arch-topped shape: a rectangle whose top is a half circle.
Path archPath(Rect r) {
  final rad = r.width / 2;
  return Path()
    ..moveTo(r.left, r.bottom)
    ..lineTo(r.left, r.top + rad)
    ..arcToPoint(Offset(r.right, r.top + rad), radius: Radius.circular(rad))
    ..lineTo(r.right, r.bottom)
    ..close();
}

class SkyArchPainter extends CustomPainter {
  final Sky sky;
  final Animation<double> rise;
  final Animation<double> ambient;
  SkyArchPainter({required this.sky, required this.rise, required this.ambient}) : super(repaint: Listenable.merge([rise, ambient]));

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height - 5;
    final arch = archPath(Rect.fromLTWH(4, 4, w - 9, h - 8));
    final ink = Paint()..color = Pop.ink;
    final (skyColor, hills, dots) = switch (sky) {
      Sky.morning => (Pop.lemon, Pop.cyan, const Color(0x59FF3D8B)),
      Sky.afternoon => (Pop.cyan, Pop.lemon, const Color(0x73FFFFFF)),
      Sky.evening => (Pop.violet, const Color(0xFF5A28C8), const Color(0x47FFFFFF)),
    };

    canvas.drawPath(arch.shift(const Offset(5, 5)), ink);
    canvas.save();
    canvas.clipPath(arch);
    canvas.drawRect(Offset.zero & size, Paint()..color = skyColor);
    final dot = Paint()..color = dots;
    for (var y = 5.0; y < h; y += 10) {
      for (var x = 5.0; x < w; x += 10) {
        canvas.drawCircle(Offset(x, y), 1.8, dot);
      }
    }

    final t = rise.value.clamp(0.0, 1.0);
    final stroke = Paint()
      ..color = Pop.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    if (sky == Sky.evening) {
      // Crescent fades in; three stars twinkle.
      final moon = Offset(w * 0.77, h * 0.24);
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: t));
      canvas.drawCircle(moon, w * 0.074, Paint()..color = Colors.white);
      canvas.drawCircle(moon + Offset(w * 0.034, -h * 0.027), w * 0.069, Paint()..color = skyColor);
      canvas.restore();
      final phase = ambient.value * 2 * math.pi;
      const stars = [(0.23, 0.27, 8.0), (0.34, 0.18, 6.0), (0.66, 0.41, 5.0)];
      for (var i = 0; i < stars.length; i++) {
        final (px, py, r) = stars[i];
        final twinkle = 0.7 + 0.3 * math.sin(phase + i * 2.1);
        final appear = ((t - 0.2 * i) / 0.4).clamp(0.0, 1.0);
        final scale = r * twinkle;
        final c = Offset(w * px, h * py);
        final path = starPath(Size.square(scale * 2)).shift(c - Offset(scale, scale));
        canvas.drawPath(path, Paint()..color = Pop.lemon.withValues(alpha: appear));
        canvas.drawPath(path, Paint()
          ..color = Pop.ink.withValues(alpha: appear)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
      }
    } else {
      // The sun rises from behind the hills (higher in the afternoon).
      final baseY = sky == Sky.morning ? h * 0.733 : h * 0.45;
      final centre = Offset(w / 2, baseY + h * 0.33 * (1 - t));
      final r = w * 0.166;
      canvas.drawCircle(centre, r, Paint()..color = Colors.white);
      canvas.drawCircle(centre, r, stroke);
      for (var k = 0; k <= 6; k++) {
        final a = math.pi * (1 + k / 6);
        canvas.drawLine(
          centre + Offset(math.cos(a), math.sin(a)) * (r + w * 0.04),
          centre + Offset(math.cos(a), math.sin(a)) * (r + w * 0.09),
          stroke,
        );
      }
    }

    // Rolling hills along the bottom of the arch.
    final top = h - h * 0.24;
    final seg = w / 2.9;
    final hillsPath = Path()..moveTo(0, top);
    var x = 0.0;
    var up = true;
    while (x < w) {
      hillsPath.quadraticBezierTo(x + seg / 2, top + (up ? -h * 0.08 : h * 0.08), x + seg, top);
      x += seg;
      up = !up;
    }
    hillsPath
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(hillsPath, Paint()..color = hills);
    canvas.drawPath(hillsPath, stroke);
    canvas.restore();

    canvas.drawPath(arch, Paint()
      ..color = Pop.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(SkyArchPainter old) => old.sky != sky;
}

class _ContinueCard extends StatelessWidget {
  final AppState state;
  const _ContinueCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final lang = state.lang;
    final surahs = state.bundle!.surahs;
    final next = state.progress.nextUp(surahs);
    final rounds = next == null ? 0 : roundsFor(next.ayat.length).length;
    final done = next == null ? 0 : state.progress.roundsDone(next);
    return Semantics(
      button: next != null,
      label: next == null ? tr('allGlazed', lang) : '${tr('keepGoing', lang)}: ${next.name}',
      child: _Pressable(
        shadow: 5,
        onTap: () {
          if (next != null) go(context, SurahScreen(surah: next));
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.fromBorderSide(BorderSide(color: Pop.ink, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: next == null
              ? Text(tr('allGlazed', lang), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))
              : Row(
                  children: [
                    StarTile(size: 40, glaze: Glaze.full, color: Pop.pink, label: '${next.number}', semanticsLabel: ''),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('keepGoing', lang),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Pop.muted, height: 1.1)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(next.name, style: const TextStyle(fontFamily: Pop.display, fontSize: 17, height: 1.15)),
                          ),
                          Text(tr('roundOf', lang, {'n': math.min(done + 1, rounds), 'total': rounds}),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.1)),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: Pop.cyan, shape: BoxShape.circle, border: Border.all(color: Pop.ink, width: 2)),
                      child: const Icon(Icons.play_arrow_rounded, color: Pop.ink, size: 22),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Rotates its child gently back and forth from the top, like a hanging lantern.
class _Sway extends StatelessWidget {
  final Animation<double> ambient;
  final Widget child;
  const _Sway({required this.ambient, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ambient,
      builder: (context, child) => Transform.rotate(
        angle: math.sin(ambient.value * 2 * math.pi) * 6 * math.pi / 180,
        alignment: Alignment.topCenter,
        child: child,
      ),
      child: child,
    );
  }
}

class _DuaCard extends StatelessWidget {
  final DateTime now;
  final Animation<double> ambient;
  const _DuaCard({required this.now, required this.ambient});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final all = state.bundle!.duas;
    final d = duaForNow(all, now);
    if (d == null) return const SizedBox.shrink();
    final stop = currentStopId(now);
    final label = switch (stop) {
      'morning' => tr('duaThisMorning', lang),
      'evening' => tr('duaThisEvening', lang),
      _ => tr('duaForNow', lang),
    };
    return Semantics(
      button: true,
      label: label,
      child: _Pressable(
        onTap: () {
          final list = all.where((x) => x.moment == d.moment).toList();
          go(context, DuaScreen(duas: list, index: list.indexOf(d), stop: stopFor(d, now)));
        },
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border.fromBorderSide(BorderSide(color: Pop.ink, width: 3)),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Sway(ambient: ambient, child: const PopIconView(PopIcon.duas, size: 36, shadow: false)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Pop.muted)),
                    Text(duaTitle(d, lang),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
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

class _WeekRow extends StatelessWidget {
  final DateTime now;
  final Animation<double> intro;
  final Animation<double> pulse;
  const _WeekRow({required this.now, required this.intro, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final dots = state.activity.weekDots(now);
    final labels = tr('weekdaysShort', lang).split(',');
    final today = weekOf(now).indexWhere((d) => dayKey(d) == dayKey(now));
    return Row(
      children: [
        Text(tr('thisWeek', lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(width: 6),
        for (var i = 0; i < 7; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: _Pop(
              t: CurvedAnimation(
                parent: intro,
                curve: Interval((700 + 40 * i) / 1600, ((700 + 40 * i) + 420) / 1600, curve: Curves.easeOutBack),
              ),
              child: ScaleTransition(
                scale: i == today ? Tween(begin: 1.0, end: 1.3).animate(pulse) : const AlwaysStoppedAnimation(1.0),
                child: StarTile(
                  size: 26,
                  glaze: dots[i] ? Glaze.full : (i == today ? Glaze.next : Glaze.empty),
                  color: Pop.glazes[i % Pop.glazes.length],
                  semanticsLabel: labels.length == 7 ? labels[i] : '',
                ),
              ),
            ),
          ),
        const Spacer(),
        Text(
            state.activity.daysThisWeek(now) == 1
                ? tr('daysCountOne', lang)
                : tr('daysCount', lang, {'n': state.activity.daysThisWeek(now)}),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// The niches

class _NicheSpec {
  final PopIcon icon;
  final String labelKey;
  final void Function(BuildContext) open;
  const _NicheSpec(this.icon, this.labelKey, this.open);
}

class _Niches extends StatelessWidget {
  final Animation<double> intro;
  final Animation<double> ambient;
  const _Niches({required this.intro, required this.ambient});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final book = state.book;
    final specs = [
      if (book != null)
        _NicheSpec(PopIcon.quran, 'quranBook',
            (c) => go(c, MushafScreen(initialPage: state.lastPage.clamp(1, book.pageCount)))),
      _NicheSpec(PopIcon.surahs, 'surahs', (c) => go(c, const MosaicScreen())),
      _NicheSpec(PopIcon.duas, 'duas', (c) => go(c, const DuasScreen())),
      _NicheSpec(PopIcon.hadith, 'hadith', (c) => go(c, const HadithListScreen())),
      _NicheSpec(PopIcon.games, 'gamesTitle', (c) => openGames(c)),
      if (state.audio != null) _NicheSpec(PopIcon.downloads, 'downloads', (c) => go(c, const DownloadsScreen())),
    ];
    return LayoutBuilder(builder: (context, c) {
      const gap = 10.0;
      final w = (c.maxWidth - 2 * gap - 4) / 3;
      final h = w * 132 / 106;
      return Wrap(
        spacing: gap,
        runSpacing: gap + 4,
        children: [
          for (var i = 0; i < specs.length; i++)
            _Pop(
              origin: Alignment.bottomCenter,
              t: CurvedAnimation(
                parent: intro,
                curve: Interval(((850 + 70 * i) / 1600).clamp(0.0, 1.0), ((850 + 70 * i + 420) / 1600).clamp(0.0, 1.0),
                    curve: Curves.easeOutBack),
              ),
              child: _Niche(spec: specs[i], width: w, height: h, ambient: ambient),
            ),
        ],
      );
    });
  }
}

class _Niche extends StatefulWidget {
  final _NicheSpec spec;
  final double width;
  final double height;
  final Animation<double> ambient;
  const _Niche({required this.spec, required this.width, required this.height, required this.ambient});

  @override
  State<_Niche> createState() => _NicheState();
}

class _NicheState extends State<_Niche> with SingleTickerProviderStateMixin {
  late final AnimationController _wobble = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  bool _down = false;

  @override
  void dispose() {
    _wobble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final w = widget.width;
    final h = widget.height;
    final label = tr(widget.spec.labelKey, lang);
    Widget icon = PopIconView(widget.spec.icon, size: w * 0.52);
    if (widget.spec.icon == PopIcon.duas) icon = _Sway(ambient: widget.ambient, child: icon);
    icon = AnimatedBuilder(
      animation: _wobble,
      builder: (context, child) => Transform.rotate(angle: math.sin(_wobble.value * 2 * math.pi) * 0.16, child: child),
      child: icon,
    );
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _down = true);
          _wobble.forward(from: 0);
        },
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () => widget.spec.open(context),
        child: SizedBox(
          width: w + 4,
          height: h + 4,
          child: Stack(
            children: [
              Positioned(left: 4, top: 4, child: CustomPaint(size: Size(w, h), painter: const _ArchPainter(fill: Pop.ink))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                transform: Matrix4.translationValues(_down ? 4 : 0, _down ? 4 : 0, 0),
                width: w,
                height: h,
                child: Stack(
                  children: [
                    CustomPaint(size: Size(w, h), painter: _ArchPainter(fill: Colors.white, divider: h - 34)),
                    Positioned(left: 0, right: 0, top: h * 0.24, child: Center(child: ExcludeSemantics(child: icon))),
                    Positioned(
                      left: 2,
                      right: 2,
                      bottom: 9,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, style: const TextStyle(fontFamily: Pop.display, fontSize: 13, height: 1)),
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

class _ArchPainter extends CustomPainter {
  final Color fill;
  final double? divider;
  const _ArchPainter({required this.fill, this.divider});

  @override
  void paint(Canvas canvas, Size size) {
    final path = archPath(Offset.zero & size);
    canvas.drawPath(path, Paint()..color = fill);
    if (fill == Pop.ink) return;
    final stroke = Paint()
      ..color = Pop.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawPath(archPath(const Offset(1.5, 1.5) & Size(size.width - 3, size.height - 3)), stroke);
    final d = divider;
    if (d != null) canvas.drawLine(Offset(1.5, d), Offset(size.width - 1.5, d), stroke);
  }

  @override
  bool shouldRepaint(_ArchPainter old) => old.fill != fill || old.divider != divider;
}

/// The two games, for the surah that is next up.
Future<void> openGames(BuildContext context) async {
  final state = AppScope.of(context);
  final lang = state.lang;
  final surahs = state.bundle!.surahs;
  final next = state.progress.nextUp(surahs) ?? surahs.first;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Pop.paper,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('gamesFor', lang, {'name': next.name}), style: const TextStyle(fontFamily: Pop.display, fontSize: 18)),
            const SizedBox(height: 14),
            ComicButton(
              label: tr('play', lang),
              icon: Icons.extension_rounded,
              onPressed: () {
                Navigator.pop(sheet);
                final rounds = roundsFor(next.ayat.length);
                go(context, rounds.length == 1 ? OrderGameScreen(surah: next, round: 0) : RoundPickerScreen(surah: next));
              },
            ),
            const SizedBox(height: 12),
            ComicButton(
              label: tr('missingWord', lang),
              icon: Icons.search_rounded,
              color: Pop.cyan,
              onPressed: () {
                Navigator.pop(sheet);
                go(context, MissingWordScreen(surah: next));
              },
            ),
          ],
        ),
      ),
    ),
  );
}
