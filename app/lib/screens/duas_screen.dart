import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import 'dua_screen.dart';

const momentOrder = ['morning-evening', 'home', 'bathroom', 'mosque', 'anytime'];

class DuasScreen extends StatelessWidget {
  const DuasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final duas = state.bundle!.duas;

    return Scaffold(
      appBar: AppBar(title: Text(tr('duas', lang))),
      body: ListView(
        children: [
          for (final moment in momentOrder)
            if (duas.any((d) => d.moment == moment)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text(tr('moment.$moment', lang), style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final d in duas.where((x) => x.moment == moment))
                ListTile(
                  leading: Icon(d.isQuran ? Icons.auto_stories : Icons.format_quote),
                  title: Text(_title(d, lang), maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DuaScreen(dua: d))),
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
