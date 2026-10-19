import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import 'hadith_screen.dart';
import 'surah_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('learn', lang)),
          bottom: TabBar(tabs: [Tab(text: tr('surahs', lang)), Tab(text: tr('hadith', lang))]),
        ),
        body: TabBarView(
          children: [
            ListView(
              children: [
                for (final s in bundle.surahs)
                  ListTile(
                    leading: CircleAvatar(child: Text('${s.number}')),
                    title: Text(s.name),
                    subtitle: Text('${s.ayat.length}'),
                    trailing: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(s.nameAr, style: const TextStyle(fontSize: 20)),
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SurahScreen(surah: s))),
                  ),
              ],
            ),
            ListView(
              children: [
                for (final h in bundle.hadith)
                  ListTile(
                    leading: const Icon(Icons.format_quote),
                    title: Text(h.t(lang).title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(tr('group.${h.group}', lang)),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HadithScreen(hadith: h))),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
