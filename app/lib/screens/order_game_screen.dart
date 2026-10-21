import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../progress.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

/// Game logic kept apart from the widget so it can be unit tested.
class OrderGame {
  final List<Ayah> ayat;
  final List<Ayah> shuffled;
  int next = 0;

  OrderGame(this.ayat, {Random? random}) : shuffled = _shuffle(ayat, random ?? Random());

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

/// Long surahs are played a few ayat at a time.
class RoundPickerScreen extends StatelessWidget {
  final Surah surah;
  const RoundPickerScreen({super.key, required this.surah});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final rounds = roundsFor(surah.ayat.length);
    return PopPage(
      title: tr('pickRound', lang),
      subtitle: '${surah.name}, ${tr('roundsProgress', lang, {'n': state.progress.roundsDone(surah), 'total': rounds.length})}',
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        itemCount: rounds.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, i) {
          final r = rounds[i];
          final done = state.progress.isRoundDone(surah.number, i);
          return InkPanel(
            color: done ? Pop.glazeFor(surah.number) : Colors.white,
            border: 3,
            shadow: 4,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            onTap: () => go(context, OrderGameScreen(surah: surah, round: i)),
            child: Row(
              children: [
                Icon(done ? Icons.check_circle_rounded : Icons.extension_rounded, color: Pop.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('roundLabel', lang, {'n': i + 1, 'from': r.start + 1, 'to': r.end}),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OrderGameScreen extends StatefulWidget {
  final Surah surah;
  final int round;
  const OrderGameScreen({super.key, required this.surah, required this.round});

  @override
  State<OrderGameScreen> createState() => _OrderGameScreenState();
}

class _OrderGameScreenState extends State<OrderGameScreen> {
  late final rounds = roundsFor(widget.surah.ayat.length);
  late OrderGame game = _newGame();
  bool showNice = false;
  Timer? _niceTimer;

  OrderGame _newGame() {
    final r = rounds[widget.round];
    return OrderGame(widget.surah.ayat.sublist(r.start, r.end));
  }

  @override
  void dispose() {
    _niceTimer?.cancel();
    super.dispose();
  }

  void _tap(Ayah a) {
    final state = AppScope.of(context);
    if (game.isPlaced(a)) return;
    final ok = game.tap(a);
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('tryAgain', state.lang)), duration: const Duration(seconds: 1)));
      return;
    }
    _niceTimer?.cancel();
    setState(() => showNice = !game.done);
    _niceTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => showNice = false);
    });
    if (game.done) state.completeRound(widget.surah, widget.round);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final r = rounds[widget.round];
    final total = r.end - r.start;
    final placedAyat = game.ayat.where(game.isPlaced).toList()
      ..sort((a, b) => game.placed[a.key]!.compareTo(game.placed[b.key]!));
    final remaining = game.shuffled.where((a) => !game.isPlaced(a)).toList();
    final subtitle = rounds.length == 1
        ? widget.surah.name
        : '${widget.surah.name}, ${tr('roundLabel', lang, {'n': widget.round + 1, 'from': r.start + 1, 'to': r.end})}';

    return PopPage(
      title: tr('play', lang),
      subtitle: subtitle,
      background: Pop.lemon,
      dot: const Color(0x59FF3D8B),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: InkPanel(
              border: 3,
              shadow: 4,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < total; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Transform.rotate(
                        angle: pi / 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: i < game.next ? (i.isEven ? Pop.cyan : Pop.pink) : Colors.white,
                            border: Border.all(color: Pop.ink, width: i < game.next ? 3 : 2),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Text(tr('placed', lang, {'n': game.next, 'total': total}),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                children: [
                  for (final a in placedAyat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkPanel(
                        color: game.placed[a.key]!.isOdd ? Pop.cyan : Pop.pink,
                        border: 3,
                        shadow: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text('${r.start + game.placed[a.key]!}',
                                  style: const TextStyle(fontFamily: Pop.display, fontSize: 17)),
                            ),
                            Expanded(child: ArabicText(a.arabic, size: 21)),
                          ],
                        ),
                      ),
                    ),
                  if (!game.done)
                    Container(
                      constraints: const BoxConstraints(minHeight: 56),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xA6FFFFFF),
                        border: Border.all(color: Pop.ink, width: 3),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text('${r.start + game.next + 1}',
                                style: const TextStyle(fontFamily: Pop.display, fontSize: 17)),
                          ),
                          Expanded(
                            child: Text(tr('whichNext', lang),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.15)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (showNice) Positioned(right: -6, bottom: -40, child: Burst(text: tr('nice', lang))),
            ],
          ),
          const SizedBox(height: 22),
          if (game.done)
            _DonePanel(surah: widget.surah, round: widget.round, rounds: rounds.length)
          else ...[
            Text(tr('tapNext', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 15)),
            const SizedBox(height: 12),
            for (var i = 0; i < remaining.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  button: true,
                  child: InkPanel(
                    tiltDegrees: const [-1.2, 0.8, -0.6, 1.0][i % 4],
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    onTap: () => _tap(remaining[i]),
                    child: ArabicText(remaining[i].arabic, size: 23),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DonePanel extends StatelessWidget {
  final Surah surah;
  final int round;
  final int rounds;
  const _DonePanel({required this.surah, required this.round, required this.rounds});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final glazed = state.progress.isGlazed(surah);
    int? nextRound;
    for (var i = 0; i < rounds; i++) {
      final candidate = (round + 1 + i) % rounds;
      if (!state.progress.isRoundDone(surah.number, candidate)) {
        nextRound = candidate;
        break;
      }
    }
    return Column(
      children: [
        Burst(text: tr(glazed ? 'tileGlazed' : 'roundDone', lang), size: 150, color: Pop.glazeFor(surah.number) == Pop.lemon ? Pop.violet : Pop.glazeFor(surah.number)),
        const SizedBox(height: 18),
        if (nextRound != null) ...[
          ComicButton(
            label: tr('nextRound', lang),
            icon: Icons.arrow_forward_rounded,
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => OrderGameScreen(surah: surah, round: nextRound!)),
            ),
          ),
          const SizedBox(height: 14),
        ],
        ComicButton(
          label: tr(rounds == 1 ? 'backToSurah' : 'pickRound', lang),
          color: Colors.white,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
