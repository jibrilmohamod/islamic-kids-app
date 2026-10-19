import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import 'order_game_screen.dart';

class PlayScreen extends StatelessWidget {
  const PlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final surahs = state.bundle!.surahs;

    return Scaffold(
      appBar: AppBar(title: Text(tr('orderGame', lang))),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(tr('pickSurah', lang), style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final s in surahs)
            ListTile(
              leading: Icon(
                state.completedGames.contains(OrderGameScreen.gameId(s)) ? Icons.star : Icons.star_border,
                color: Colors.amber.shade700,
              ),
              title: Text(s.name),
              trailing: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(s.nameAr, style: const TextStyle(fontSize: 20)),
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderGameScreen(surah: s))),
            ),
        ],
      ),
    );
  }
}
