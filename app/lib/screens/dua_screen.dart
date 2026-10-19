import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';
import 'hadith_screen.dart';

class DuaScreen extends StatefulWidget {
  final Dua dua;
  const DuaScreen({super.key, required this.dua});

  @override
  State<DuaScreen> createState() => _DuaScreenState();
}

class _DuaScreenState extends State<DuaScreen> {
  bool memorise = false;

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final d = widget.dua;
    final h = d.hadith;
    final m = d.meaningFor(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('moment.${d.moment}', lang)),
        actions: [
          TextButton.icon(
            icon: Icon(memorise ? Icons.visibility : Icons.psychology),
            label: Text(tr('memorise', lang)),
            onPressed: () => setState(() => memorise = !memorise),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SceneHeader(title: tr('moment.${d.moment}', lang), colors: sceneNight),
          if (memorise)
            ContentCard(child: MemoriseView(arabic: d.arabic))
          else if (h != null)
            HadithBody(hadith: h)
          else
            ContentCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('${tr('quran', lang)} ${d.quranKey}', style: Theme.of(context).textTheme.labelSmall),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr('memoriseHint', lang), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            spacing: 6,
            runSpacing: 10,
            children: [
              for (var i = 0; i < words.length; i++)
                GestureDetector(
                  onTap: () => setState(() => hidden.contains(i) ? hidden.remove(i) : hidden.add(i)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: hidden.contains(i) ? scheme.primaryContainer : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Opacity(
                      opacity: hidden.contains(i) ? 0 : 1,
                      child: Text(words[i], style: const TextStyle(fontSize: 24, height: 1.8)),
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
              child: Text(tr('hideAll', lang)),
            ),
            TextButton(onPressed: () => setState(hidden.clear), child: Text(tr('showAll', lang))),
          ],
        ),
      ],
    );
  }
}
