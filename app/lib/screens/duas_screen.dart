import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'dua_screen.dart';

const momentOrder = ['morning-evening', 'home', 'bathroom', 'mosque', 'anytime'];

class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final duas = state.bundle!.duas;

    return PopPage(
      title: tr('duas', lang),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          for (final moment in momentOrder)
            if (duas.any((d) => d.moment == moment)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 10),
                child: Align(alignment: Alignment.centerLeft, child: Caption(tr('moment.$moment', lang))),
              ),
              for (final d in duas.where((x) => x.moment == moment))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkPanel(
                    border: 3,
                    shadow: 4,
                    padding: const EdgeInsets.all(14),
                    onTap: () => go(context, DuaScreen(dua: d)),
                    child: Row(
                      children: [
                        Icon(d.isQuran ? Icons.auto_stories_rounded : Icons.format_quote_rounded, color: Pop.ink),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(_title(d, lang),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
        ],
      ),
    );
  }

  String _title(Dua d, String lang) {
    final h = d.hadith;
    if (h != null) return h.t(lang).title;
    return '${tr('quran', lang)} ${d.quranKey}';
  }
}
