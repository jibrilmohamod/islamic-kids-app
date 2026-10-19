import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../progress.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'dua_screen.dart';
import 'duas_screen.dart';
import 'hadith_screen.dart';
import 'mosaic_screen.dart';
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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle;

    return Scaffold(
      body: DottedPaper(
        child: SafeArea(
          child: bundle == null
              ? Center(
                  child: state.error == null
                      ? const CircularProgressIndicator(color: Pop.ink)
                      : Padding(padding: const EdgeInsets.all(24), child: Text(tr('loadError', lang))),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tr('salaam', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              MisprintText(tr('yourMosaic', lang), size: 28),
                            ],
                          ),
                        ),
                        InkIconButton(
                          icon: Icons.lock_outline_rounded,
                          tooltip: tr('parents', lang),
                          onPressed: () => go(context, const ParentScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _MosaicPanel(bundle: bundle, progress: state.progress),
                    const SizedBox(height: 26),
                    _DuaForNowCard(dua: duaForNow(bundle.duas, DateTime.now())),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: _HomeTile(
                            label: tr('duas', lang),
                            icon: Icons.back_hand_outlined,
                            color: Pop.pink,
                            dot: const Color(0x381B1035),
                            onTap: () => go(context, const DuasScreen()),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _HomeTile(
                            label: tr('hadith', lang),
                            icon: Icons.format_quote_rounded,
                            color: Pop.cyan,
                            dot: const Color(0x8CFFFFFF),
                            onTap: () => go(context, const HadithListScreen()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MosaicPanel extends StatelessWidget {
  final ContentBundle bundle;
  final Progress progress;
  const _MosaicPanel({required this.bundle, required this.progress});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final surahs = bundle.surahs;
    final next = progress.nextUp(surahs);
    return InkPanel(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      onTap: () => go(context, const MosaicScreen()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            runSpacing: 2,
            children: [
              for (final s in surahs)
                StarTile(
                  size: 27,
                  glaze: progress.glazeOf(s, next: next),
                  color: Pop.glazeFor(s.number),
                  semanticsLabel: s.name,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr('glazedCount', lang, {'n': progress.glazedCount(surahs), 'total': surahs.length}),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (next == null)
            Text(tr('allGlazed', lang), textAlign: TextAlign.center, style: const TextStyle(fontSize: 16))
          else
            ComicButton(
              label: tr('nextUp', lang, {'name': next.name}),
              icon: Icons.play_arrow_rounded,
              onPressed: () => go(context, SurahScreen(surah: next)),
            ),
        ],
      ),
    );
  }
}

class _DuaForNowCard extends StatelessWidget {
  final Dua? dua;
  const _DuaForNowCard({required this.dua});

  @override
  Widget build(BuildContext context) {
    final d = dua;
    if (d == null) return const SizedBox.shrink();
    final lang = AppScope.of(context).lang;
    final title = d.hadith?.t(lang).title ?? '${tr('quran', lang)} ${d.quranKey}';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkPanel(
          tiltDegrees: -1,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
          onTap: () => go(context, DuaScreen(dua: d)),
          child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.35)),
        ),
        Positioned(left: 12, top: -14, child: Caption(tr('duaForNow', lang))),
      ],
    );
  }
}

class _HomeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color dot;
  final VoidCallback onTap;
  const _HomeTile({required this.label, required this.icon, required this.color, required this.dot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: InkPanel(
        color: color,
        halftone: true,
        dotColor: dot,
        shadow: 5,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: Pop.ink),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontFamily: Pop.display, fontSize: 17)),
            ],
          ),
        ),
      ),
    );
  }
}
