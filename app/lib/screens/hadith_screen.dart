import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

class HadithListScreen extends StatelessWidget {
  const HadithListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final hadith = state.bundle!.hadith;
    final groups = <String>{for (final h in hadith) h.group}.toList();

    return PopPage(
      title: tr('hadith', lang),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 10),
              child: Align(alignment: Alignment.centerLeft, child: Caption(tr('group.$g', lang))),
            ),
            for (final h in hadith.where((x) => x.group == g))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkPanel(
                  border: 3,
                  shadow: 4,
                  padding: const EdgeInsets.all(14),
                  onTap: () => go(context, HadithScreen(hadith: h)),
                  child: Text(h.t(lang).title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class HadithScreen extends StatelessWidget {
  final Hadith hadith;
  const HadithScreen({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return PopPage(
      title: tr('hadith', lang),
      subtitle: tr('group.${hadith.group}', lang),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 8, 18, 32), children: [HadithBody(hadith: hadith)]),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkPanel(
          border: 3,
          shadow: 0,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.3)),
              const SizedBox(height: 8),
              ArabicText(hadith.arabic, size: 22),
              Heading(tr('meaning', lang)),
              Text(t.text, style: const TextStyle(fontSize: 17, height: 1.5)),
              Heading(tr('grade', lang)),
              Text('${t.grade}. ${t.attribution}', style: const TextStyle(fontSize: 15, height: 1.4)),
              SourceLabel('hadeethenc', extra: '#${hadith.hadeethencId}'),
            ],
          ),
        ),
        if (t.explanation.isNotEmpty) ...[
          const SizedBox(height: 16),
          InkPanel(
            border: 3,
            shadow: 0,
            color: Pop.highlight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                iconColor: Pop.ink,
                collapsedIconColor: Pop.ink,
                title: Text(tr('understand', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 16)),
                children: [
                  Text(t.explanation, style: const TextStyle(fontSize: 16, height: 1.5)),
                  SourceLabel('hadeethenc', extra: '#${hadith.hadeethencId}'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
