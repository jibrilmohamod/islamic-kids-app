import 'package:flutter/material.dart';

import '../app_state.dart';
import '../recitation.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'surah_screen.dart';

/// A strip at the bottom of a screen while recitation plays elsewhere:
/// which surah and ayah, pause or play, and stop. Tapping it opens the surah.
/// Hidden when nothing is being recited.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final rec = state.recitation;
    if (rec == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: rec,
      builder: (context, _) {
        final s = rec.surah;
        if (s == null) return const SizedBox.shrink();
        final lang = state.lang;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: InkPanel(
              border: 3,
              shadow: 4,
              color: Pop.highlight,
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              onTap: () => go(context, SurahScreen(surah: s)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: const TextStyle(fontFamily: Pop.display, fontSize: 15)),
                        Text(tr('ayahOf', lang, {'n': rec.index + 1, 'total': s.ayat.length}),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Pop.muted)),
                      ],
                    ),
                  ),
                  _PlayPause(rec: rec, lang: lang),
                  const SizedBox(width: 8),
                  InkIconButton(icon: Icons.stop_rounded, tooltip: tr('stop', lang), onPressed: rec.stop),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlayPause extends StatelessWidget {
  final Recitation rec;
  final String lang;
  const _PlayPause({required this.rec, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (rec.waiting) {
      return const SizedBox(
        width: 44,
        height: 44,
        child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 3, color: Pop.ink)),
      );
    }
    return InkIconButton(
      icon: rec.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
      tooltip: tr(rec.playing ? 'pauseAudio' : 'resumeAudio', lang),
      color: Pop.cyan,
      onPressed: rec.playing ? rec.pause : rec.resume,
    );
  }
}
