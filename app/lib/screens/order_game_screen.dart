import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../widgets.dart';

/// Game logic kept apart from the widget so it can be unit tested.
class OrderGame {
  final List<Ayah> ayat;
  final List<Ayah> shuffled;
  int next = 0;

  OrderGame(this.ayat, {Random? random})
      : shuffled = _shuffle(ayat, random ?? Random());

  static List<Ayah> _shuffle(List<Ayah> ayat, Random random) {
    final list = List<Ayah>.of(ayat);
    if (list.length < 2) return list;
    // Never hand the child the answer already in order.
    do {
      list.shuffle(random);
    } while (_inOrder(list, ayat));
    return list;
  }

  static bool _inOrder(List<Ayah> a, List<Ayah> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
    }
    return true;
  }

  /// Ayah key -> the position the child placed it at (1-based).
  final Map<String, int> placed = {};

  bool get done => next >= ayat.length;
  bool isPlaced(Ayah a) => placed.containsKey(a.key);

  /// Returns true when [a] is the next ayah in order. Some surahs repeat an
  /// ayah word for word (Al-Kafirun 3 and 5), so identical text counts as
  /// correct.
  bool tap(Ayah a) {
    if (done || isPlaced(a)) return false;
    if (a.arabic == ayat[next].arabic) {
      next++;
      placed[a.key] = next;
      return true;
    }
    return false;
  }
}

class OrderGameScreen extends StatefulWidget {
  final Surah surah;
  const OrderGameScreen({super.key, required this.surah});

  static String gameId(Surah s) => 'order-${s.id}';

  @override
  State<OrderGameScreen> createState() => _OrderGameScreenState();
}

class _OrderGameScreenState extends State<OrderGameScreen> {
  late OrderGame game = OrderGame(widget.surah.ayat);
  String? wrongKey;

  void _tap(Ayah a) {
    final state = AppScope.of(context);
    final ok = game.tap(a);
    setState(() => wrongKey = ok ? null : a.key);
    if (!ok && !game.isPlaced(a)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('tryAgain', state.lang)), duration: const Duration(seconds: 1)));
    }
    if (game.done) state.completeGame(OrderGameScreen.gameId(widget.surah));
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.surah.name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          SceneHeader(title: tr('orderGame', lang), subtitle: widget.surah.nameAr, colors: sceneDesert),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(game.done ? tr('wellDone', lang) : tr('orderHint', lang),
                style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final a in game.shuffled)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              color: game.isPlaced(a)
                  ? scheme.primaryContainer
                  : a.key == wrongKey
                      ? scheme.errorContainer
                      : null,
              child: InkWell(
                onTap: () => _tap(a),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: game.isPlaced(a)
                            ? Text('${game.placed[a.key]}', style: const TextStyle(fontWeight: FontWeight.w700))
                            : const Icon(Icons.touch_app_outlined, size: 20),
                      ),
                      Expanded(child: ArabicText(a.arabic, size: 22)),
                    ],
                  ),
                ),
              ),
            ),
          if (game.done)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                icon: const Icon(Icons.replay),
                label: Text(tr('playAgain', lang)),
                onPressed: () => setState(() {
                  game = OrderGame(widget.surah.ayat);
                  wrongKey = null;
                }),
              ),
            ),
        ],
      ),
    );
  }
}
