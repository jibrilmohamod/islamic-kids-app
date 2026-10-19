import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';
import 'dua_screen.dart';
import 'duas_screen.dart';
import 'learn_screen.dart';
import 'parent_screen.dart';
import 'play_screen.dart';

/// Picks a dua for the time of day: morning and evening adhkar around those
/// times, otherwise an "any time" dua.
Dua? duaForNow(List<Dua> duas, DateTime now) {
  if (duas.isEmpty) return null;
  final h = now.hour;
  final moment = (h >= 4 && h < 11) || (h >= 16 && h < 20) ? 'morning-evening' : 'anytime';
  final matches = duas.where((d) => d.moment == moment).toList();
  if (matches.isEmpty) return duas.first;
  return matches[now.day % matches.length];
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('appName', lang)),
        actions: [
          IconButton(
            tooltip: tr('parents', lang),
            icon: const Icon(Icons.lock_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ParentScreen())),
          ),
        ],
      ),
      body: bundle == null
          ? Center(
              child: state.error == null
                  ? const CircularProgressIndicator()
                  : Padding(padding: const EdgeInsets.all(24), child: Text(tr('loadError', lang))),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(tr('salaam', lang), style: Theme.of(context).textTheme.headlineSmall),
                ),
                _DuaForNowCard(dua: duaForNow(bundle.duas, DateTime.now())),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _Tile(icon: Icons.menu_book, label: tr('learn', lang), color: sceneGarden.first, page: const LearnScreen()),
                      _Tile(icon: Icons.volunteer_activism, label: tr('duas', lang), color: sceneNight.first, page: const DuasScreen()),
                      _Tile(icon: Icons.extension, label: tr('play', lang), color: sceneDesert.first, page: const PlayScreen()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _DuaForNowCard extends StatelessWidget {
  final Dua? dua;
  const _DuaForNowCard({required this.dua});

  @override
  Widget build(BuildContext context) {
    final d = dua;
    if (d == null) return const SizedBox.shrink();
    final lang = AppScope.of(context).lang;
    return ContentCard(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DuaScreen(dua: d))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('duaForNow', lang), style: Theme.of(context).textTheme.labelLarge),
            Text(tr('moment.${d.moment}', lang), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ArabicText(d.arabic, size: 22),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget page;
  const _Tile({required this.icon, required this.label, required this.color, required this.page});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
