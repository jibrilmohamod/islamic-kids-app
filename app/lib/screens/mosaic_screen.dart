import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'surah_screen.dart';

/// All 114 surahs as mosaic tiles, in the order of the mushaf.
class MosaicScreen extends StatelessWidget {
  const MosaicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final surahs = state.bundle!.surahs;
    final next = state.progress.nextUp(surahs);
    // Tile, gap, and two lines of the name at the reader's text size, so
    // names never overflow the cell at large text.
    final cellHeight = 72 + 4 + 2 * MediaQuery.textScalerOf(context).scale(13) * 1.15 + 4;

    return PopPage(
      title: tr('surahs', lang),
      subtitle: tr('glazedCount', lang, {'n': state.progress.glazedCount(surahs), 'total': surahs.length}),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 100,
          mainAxisExtent: cellHeight,
          crossAxisSpacing: 6,
          mainAxisSpacing: 8,
        ),
        itemCount: surahs.length,
        itemBuilder: (context, i) {
          final s = surahs[i];
          return InkWell(
            onTap: () => go(context, SurahScreen(surah: s)),
            child: Column(
              children: [
                StarTile(
                  size: 72,
                  glaze: state.progress.glazeOf(s, next: next),
                  color: Pop.glazeFor(s.number),
                  label: '${s.number}',
                  semanticsLabel: '${s.name}, ${tr('surahNumber', lang, {'n': s.number})}',
                ),
                const SizedBox(height: 4),
                Text(
                  s.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.15),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
