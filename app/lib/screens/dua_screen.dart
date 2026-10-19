import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'hadith_screen.dart';

class DuaScreen extends StatefulWidget {
  final Dua dua;
  const DuaScreen({super.key, required this.dua});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  bool memorise = false;
  AppState? _state;

  /// Quranic duas can use the same recitation audio as the surahs.
  Ayah? _ayah(AppState state) {
    final key = widget.dua.quranKey;
    if (key == null) return null;
    final surah = int.tryParse(key.split(':').first);
    for (final s in state.bundle?.surahs ?? const <Surah>[]) {
      if (s.number != surah) continue;
      for (final a in s.ayat) {
        if (a.key == key) return a;
      }
    }
    return null;
  }

  Future<void> _listen(AppState state, Ayah a) async {
    try {
      await state.audio!.play(a);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('audioFailed', state.lang))));
    }
  }

  @override
  void dispose() {
    _state?.audio?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _state = state;
    final lang = state.lang;
    final d = widget.dua;
    final h = d.hadith;
    final m = d.meaningFor(lang);
    final ayah = _ayah(state);

    return PopPage(
      title: tr('moment.${d.moment}', lang),
      subtitle: tr('duas', lang),
      trailing: InkIconButton(
        icon: memorise ? Icons.visibility_rounded : Icons.psychology_rounded,
        tooltip: tr('memorise', lang),
        color: memorise ? Pop.lemon : Colors.white,
        onPressed: () => setState(() => memorise = !memorise),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          if (memorise)
            InkPanel(border: 3, shadow: 0, child: MemoriseView(arabic: d.arabic))
          else if (h != null)
            HadithBody(hadith: h)
          else
            InkPanel(
              border: 3,
              shadow: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Caption('${tr('quran', lang)} ${d.quranKey}', color: Colors.white),
                      const Spacer(),
                      if (ayah != null && ayah.n != null && state.audio != null)
                        InkIconButton(
                          icon: Icons.play_arrow_rounded,
                          tooltip: tr('listen', lang, {'n': ayah.aya}),
                          color: Pop.cyan,
                          onPressed: () => _listen(state, ayah),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ArabicText(d.arabic),
                  if (m != null) ...[
                    Heading(tr('meaning', lang)),
                    Text(m.text, style: const TextStyle(fontSize: 17, height: 1.5)),
                    SourceLabel(m.source),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Words can be hidden one by one; tapping a word shows or hides it.
/// Only the display changes, never the text.
class MemoriseView extends StatefulWidget {
  final String arabic;
  const MemoriseView({super.key, required this.arabic});

  @override
  State<MemoriseView> createState() => _MemoriseViewState();
}

class _MemoriseViewState extends State<MemoriseView> {
  late final List<String> words = widget.arabic.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final Set<int> hidden = {};

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('memoriseHint', lang), style: const TextStyle(fontSize: 14, color: Pop.muted)),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            spacing: 6,
            runSpacing: 10,
            children: [
              for (var i = 0; i < words.length; i++)
                GestureDetector(
                  onTap: () => setState(() {
                    if (!hidden.remove(i)) hidden.add(i);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: hidden.contains(i) ? Pop.lemon : Colors.transparent,
                      border: hidden.contains(i) ? Border.all(color: Pop.ink, width: 2) : null,
                    ),
                    child: Opacity(
                      opacity: hidden.contains(i) ? 0 : 1,
                      child: Text(words[i], style: const TextStyle(fontFamily: Pop.quran, fontSize: 24, height: 1.8)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => setState(() => hidden.addAll(List.generate(words.length, (i) => i))),
              child: Text(tr('hideAll', lang), style: const TextStyle(color: Pop.ink, fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: () => setState(hidden.clear),
              child: Text(tr('showAll', lang), style: const TextStyle(color: Pop.ink, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ],
    );
  }
}
