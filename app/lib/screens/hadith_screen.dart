import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';

class HadithScreen extends StatelessWidget {
  final Hadith hadith;
  const HadithScreen({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Scaffold(
      appBar: AppBar(title: Text(tr('hadith', lang))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SceneHeader(title: tr('group.${hadith.group}', lang), colors: sceneGarden),
          HadithBody(hadith: hadith),
        ],
      ),
    );
  }
}

/// Arabic, translation, explanation, grade and attribution of one hadith,
/// all verbatim from HadeethEnc. Shared by the hadith and dua screens.
class HadithBody extends StatelessWidget {
  final Hadith hadith;
  const HadithBody({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final t = hadith.t(lang);
    return Column(
      children: [
        ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ArabicText(hadith.arabic, size: 22),
              Heading(tr('meaning', lang)),
              Text(t.text, style: const TextStyle(fontSize: 17, height: 1.5)),
              Heading(tr('grade', lang)),
              Text('${t.grade} · ${t.attribution}'),
              SourceLabel('hadeethenc', extra: '#${hadith.hadeethencId}'),
            ],
          ),
        ),
        if (t.explanation.isNotEmpty)
          ContentCard(
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(tr('understand', lang)),
              children: [
                Text(t.explanation, style: const TextStyle(fontSize: 16, height: 1.5)),
                SourceLabel('hadeethenc', extra: '#${hadith.hadeethencId}'),
              ],
            ),
          ),
      ],
    );
  }
}
