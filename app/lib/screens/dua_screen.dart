import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../arch.dart';
import '../models.dart';
import '../pop_icons.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'duas_screen.dart';
import 'hadith_screen.dart';

class DuaScreen extends StatefulWidget {
  final List<Dua> duas;
  final int index;
  final DayStop stop;
  const DuaScreen({super.key, required this.duas, required this.index, required this.stop});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  late int index = widget.index;
  bool memorise = false;
  int count = 0;
  AppState? _state;

  Dua get dua => widget.duas[index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).markActive();
    });
  }

  @override
  void dispose() {
    // A dua's ayah belongs to its card, so it stops with it.
    _stopDuaAyah();
    super.dispose();
  }

  void _goTo(int i) => setState(() {
        index = i;
        count = 0;
        memorise = false;
        _stopDuaAyah();
      });

  void _stopDuaAyah() {
    final rec = _state?.recitation;
    final a = _ayah(_state);
    if (rec != null && a != null && rec.key == a.key) rec.stop();
  }

  /// Quranic duas can use the same recitation audio as the surahs.
  Ayah? _ayah(AppState? state) {
    final key = dua.quranKey;
    if (key == null || state == null) return null;
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
    final rec = state.recitation;
    final surah = state.bundle?.surahs.where((s) => s.ayat.contains(a)).firstOrNull;
    if (rec == null || surah == null) return;
    try {
      await rec.start(surah, a.aya - 1, toEnd: false);
    } catch (e) {
      debugPrint('Recitation failed to start: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('audioFailed', state.lang))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    _state = state;
    final lang = state.lang;
    final d = dua;
    final h = d.hadith;
    final stop = widget.stop;
    final ink = stop.dark ? Colors.white : Pop.ink;
    final headerColor = stop.color == Colors.white ? Pop.cyan : stop.color;
    final ayah = _ayah(state);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pop.ink, width: 4))),
            child: ColoredBox(
              color: headerColor,
              child: CustomPaint(
                painter: HalftonePainter(stop.dark ? const Color(0x40FFFFFF) : const Color(0x55FF3D8B)),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            InkIconButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: tr('back', lang),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                            ToggleIconButton(
                              on: state.isFavourite('dua:${d.id}'),
                              onIcon: PopIcon.heartOn,
                              offIcon: PopIcon.heartOff,
                              tooltip: tr(state.isFavourite('dua:${d.id}') ? 'removeFavourite' : 'addFavourite', lang),
                              onPressed: () => state.toggleFavourite('dua:${d.id}'),
                            ),
                            const SizedBox(width: 8),
                            InkIconButton(
                              icon: memorise ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              tooltip: tr('memorise', lang),
                              color: memorise ? Pop.lemon : Colors.white,
                              onPressed: () => setState(() => memorise = !memorise),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${tr(stop.labelKey, lang)}, ${tr('nOfTotal', lang, {'n': index + 1, 'total': widget.duas.length})}',
                          style: TextStyle(fontFamily: Pop.display, fontSize: 20, color: ink),
                        ),
                        const SizedBox(height: 6),
                        Text(duaTitle(d, lang),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3, color: ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                InkPanel(
                  border: 3,
                  shadow: 0,
                  padding: const EdgeInsets.all(14),
                  child: memorise
                      ? MemoriseView(arabic: d.arabic)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (ayah != null && ayah.n != null && state.audio != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: InkIconButton(
                                  icon: Icons.play_arrow_rounded,
                                  tooltip: tr('listen', lang, {'n': ayah.aya}),
                                  color: Pop.cyan,
                                  onPressed: () => _listen(state, ayah),
                                ),
                              ),
                            h != null ? QuotedArabic(d.arabic) : ArabicText(d.arabic),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                _Counter(
                  count: count,
                  color: headerColor == Pop.violet ? Pop.cyan : headerColor,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => count++);
                  },
                  onReset: () => setState(() => count = 0),
                ),
                const SizedBox(height: 16),
                if (h != null)
                  HadithDetails(hadith: h)
                else if (d.meaningFor(lang) != null)
                  InkPanel(
                    border: 3,
                    shadow: 0,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Heading(tr('meaning', lang)),
                        Text(d.meaningFor(lang)!.text, style: const TextStyle(fontSize: 17, height: 1.5)),
                        SourceLabel(d.meaningFor(lang)!.source, extra: '${tr('quran', lang)} ${d.quranKey}'),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: ComicButton(
                          label: tr('previous', lang),
                          icon: Icons.arrow_back_rounded,
                          color: Colors.white,
                          onPressed: () => _goTo(index - 1),
                        ),
                      ),
                    if (index > 0 && index < widget.duas.length - 1) const SizedBox(width: 12),
                    if (index < widget.duas.length - 1)
                      Expanded(
                        child: ComicButton(
                          label: tr('next', lang),
                          icon: Icons.arrow_forward_rounded,
                          onPressed: () => _goTo(index + 1),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final int count;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onReset;
  const _Counter({required this.count, required this.color, required this.onTap, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Row(
      children: [
        Semantics(
          button: true,
          label: '${tr('tapEachTime', lang)}: $count',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Pop.ink, width: 4),
                boxShadow: const [BoxShadow(color: Pop.ink, offset: Offset(5, 5))],
              ),
              alignment: Alignment.center,
              child: Text('$count', style: const TextStyle(fontFamily: Pop.display, fontSize: 34, color: Pop.ink)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('tapEachTime', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 15)),
              Text(tr('highlightHint', lang),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Pop.muted)),
              if (count > 0)
                TextButton(
                  onPressed: onReset,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Pop.ink),
                  child: Text(tr('resetCount', lang), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ),
      ],
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
