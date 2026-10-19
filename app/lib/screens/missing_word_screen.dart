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

/// Arabic letters without harakat or Quranic marks, for comparing words.
String bareArabic(String w) => w.replaceAll(RegExp('[ـً-ٰٟۖ-ۭ]'), '');

class MissingWordQuestion {
  final Ayah ayah;
  final List<String> words;
  final int hidden;
  final List<String> options;
  const MissingWordQuestion({required this.ayah, required this.words, required this.hidden, required this.options});

  String get answer => words[hidden];
}

/// One question per ayah: a word is hidden and the child picks it from
/// three words of the same surah. Every word shown is a real word of the
/// Quran text; nothing is changed but which word is covered.
class MissingWordGame {
  final List<MissingWordQuestion> questions;
  int current = 0;
  int right = 0;

  MissingWordGame(this.questions);

  factory MissingWordGame.build(List<Ayah> ayat, List<Ayah> pool, {Random? random}) {
    final rnd = random ?? Random();
    bool usable(String w) => bareArabic(w).length >= 3;
    final poolWords = <String>{
      for (final a in pool)
        for (final w in a.arabic.split(RegExp(r'\s+')))
          if (usable(w)) w,
    }.toList();
    final questions = <MissingWordQuestion>[];
    for (final a in ayat) {
      final words = a.arabic.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final candidates = [for (var i = 0; i < words.length; i++) if (usable(words[i])) i];
      if (words.length < 3 || candidates.isEmpty) continue;
      final hidden = candidates[rnd.nextInt(candidates.length)];
      final answer = words[hidden];
      final distractors = (poolWords.where((w) => bareArabic(w) != bareArabic(answer)).toList()..shuffle(rnd))
          .fold<List<String>>([], (acc, w) {
        if (acc.length < 2 && acc.every((x) => bareArabic(x) != bareArabic(w))) acc.add(w);
        return acc;
      });
      if (distractors.length < 2) continue;
      final options = [answer, ...distractors]..shuffle(rnd);
      questions.add(MissingWordQuestion(ayah: a, words: words, hidden: hidden, options: options));
    }
    return MissingWordGame(questions);
  }

  bool get done => current >= questions.length;
  MissingWordQuestion get question => questions[current];

  /// Returns true when [option] is the hidden word. Wrong answers let the
  /// child try again; only a first-try answer counts as right.
  bool answer(String option, {required bool firstTry}) {
    final ok = bareArabic(option) == bareArabic(question.answer);
    if (ok) {
      if (firstTry) right++;
      current++;
    }
    return ok;
  }
}

class MissingWordScreen extends StatefulWidget {
  final Surah surah;
  const MissingWordScreen({super.key, required this.surah});

  @override
  State<MissingWordScreen> createState() => _MissingWordScreenState();
}

class _MissingWordScreenState extends State<MissingWordScreen> {
  late MissingWordGame game = _newGame();
  final Set<String> tried = {};
  bool showNice = false;
  Timer? _timer;

  MissingWordGame _newGame() {
    final state = AppScope.of(context);
    final rounds = roundsFor(widget.surah.ayat.length);
    final done = [for (var i = 0; i < rounds.length; i++) if (state.progress.isRoundDone(widget.surah.number, i)) i];
    final pick = done.isEmpty ? 0 : done[Random().nextInt(done.length)];
    final r = rounds[pick];
    return MissingWordGame.build(widget.surah.ayat.sublist(r.start, r.end), widget.surah.ayat);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _pick(String option) {
    final ok = game.answer(option, firstTry: tried.isEmpty);
    if (!ok) {
      setState(() => tried.add(option));
      return;
    }
    _timer?.cancel();
    setState(() {
      tried.clear();
      showNice = !game.done;
    });
    _timer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => showNice = false);
    });
    if (game.done) AppScope.of(context).markActive();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return PopPage(
      title: tr('missingWord', lang),
      subtitle: widget.surah.name,
      background: Pop.cyan,
      dot: const Color(0x66FFFFFF),
      body: game.questions.isEmpty
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
              children: game.done ? _results(lang) : _question(lang),
            ),
    );
  }

  List<Widget> _question(String lang) {
    final q = game.question;
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Caption(tr('nOfTotal', lang, {'n': game.current + 1, 'total': game.questions.length}), color: Colors.white),
      ),
      const SizedBox(height: 14),
      Stack(
        clipBehavior: Clip.none,
        children: [
          InkPanel(
            padding: const EdgeInsets.all(14),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var i = 0; i < q.words.length; i++)
                    i == q.hidden
                        ? Container(
                            width: 80,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Pop.lemon,
                              border: Border.all(color: Pop.ink, width: 3),
                            ),
                          )
                        : Text(q.words[i],
                            style: const TextStyle(fontFamily: Pop.quran, fontSize: 24, height: 1.9, color: Pop.ink)),
                ],
              ),
            ),
          ),
          if (showNice) Positioned(left: -8, bottom: -48, child: Burst(text: tr('nice', lang))),
        ],
      ),
      const SizedBox(height: 22),
      Text(tr('missingWordHint', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 15)),
      const SizedBox(height: 12),
      for (final o in q.options)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Semantics(
            button: true,
            child: InkPanel(
              color: tried.contains(o) ? const Color(0xFFDDD8E6) : Colors.white,
              shadow: tried.contains(o) ? 0 : 6,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
              onTap: tried.contains(o) ? null : () => _pick(o),
              child: Center(
                child: Text(o, style: const TextStyle(fontFamily: Pop.quran, fontSize: 28, height: 1.8, color: Pop.ink)),
              ),
            ),
          ),
        ),
    ];
  }

  List<Widget> _results(String lang) => [
        const SizedBox(height: 20),
        Center(child: Burst(text: tr('score', lang, {'n': game.right, 'total': game.questions.length}), size: 170)),
        const SizedBox(height: 24),
        ComicButton(
          label: tr('playAgain', lang),
          icon: Icons.replay_rounded,
          onPressed: () => setState(() {
            game = _newGame();
            tried.clear();
          }),
        ),
        const SizedBox(height: 14),
        ComicButton(label: tr('backToSurah', lang), color: Colors.white, onPressed: () => Navigator.of(context).maybePop()),
      ];
}
