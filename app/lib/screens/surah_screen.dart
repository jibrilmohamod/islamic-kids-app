import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';
import 'order_game_screen.dart';

class SurahScreen extends StatelessWidget {
  final Surah surah;
  const SurahScreen({super.key, required this.surah});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Scaffold(
      appBar: AppBar(title: Text(surah.name)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.extension),
        label: Text(tr('orderGame', lang)),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OrderGameScreen(surah: surah))),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          SceneHeader(title: surah.name, subtitle: surah.nameAr, colors: sceneDesert),
          for (final a in surah.ayat) _AyahCard(ayah: a),
        ],
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Ayah ayah;
  const _AyahCard({required this.ayah});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final m = ayah.meaning[lang];
    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(ayah.key, style: Theme.of(context).textTheme.labelSmall),
          ArabicText(ayah.arabic),
          if (m != null) ...[
            Heading(tr('meaning', lang)),
            Text(m.text, style: const TextStyle(fontSize: 17, height: 1.5)),
            if (m.footnotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(m.footnotes, style: Theme.of(context).textTheme.bodySmall),
              ),
            SourceLabel(m.source),
          ],
        ],
      ),
    );
  }
}
