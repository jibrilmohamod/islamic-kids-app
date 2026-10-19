import 'models.dart';
import 'widgets.dart' show Glaze;

/// Ayat per game round. Long surahs are played in rounds of consecutive ayat.
const roundSize = 5;

/// Splits [count] ayat into rounds of [roundSize]. A short last round (under
/// 3 ayat) joins the one before it, so no round is too easy.
List<({int start, int end})> roundsFor(int count) {
  if (count <= 0) return const [];
  final rounds = <({int start, int end})>[];
  for (var s = 0; s < count; s += roundSize) {
    rounds.add((start: s, end: s + roundSize > count ? count : s + roundSize));
  }
  if (rounds.length > 1 && rounds.last.end - rounds.last.start < 3) {
    final last = rounds.removeLast();
    final prev = rounds.removeLast();
    rounds.add((start: prev.start, end: last.end));
  }
  return rounds;
}

/// Order children usually learn in: Al-Fatiha, then from An-Nas backwards.
List<int> learningOrder() => [1, for (var n = 114; n >= 2; n--) n];

/// Rounds finished per surah, saved as "surah:round" strings.
class Progress {
  final Map<int, Set<int>> _done = {};

  Progress([Iterable<String> saved = const []]) {
    for (final s in saved) {
      final parts = s.split(':');
      if (parts.length != 2) continue;
      final surah = int.tryParse(parts[0]);
      final round = int.tryParse(parts[1]);
      if (surah == null || round == null) continue;
      _done.putIfAbsent(surah, () => {}).add(round);
    }
  }

  List<String> toSaved() => [
        for (final e in _done.entries)
          for (final r in e.value) '${e.key}:$r',
      ];

  bool isRoundDone(int surah, int round) => _done[surah]?.contains(round) ?? false;

  /// Returns true when this was new.
  bool completeRound(int surah, int round) => _done.putIfAbsent(surah, () => {}).add(round);

  int roundsDone(Surah s) {
    final total = roundsFor(s.ayat.length).length;
    return (_done[s.number] ?? const {}).where((r) => r < total).length;
  }

  bool isGlazed(Surah s) => roundsDone(s) == roundsFor(s.ayat.length).length;

  int glazedCount(List<Surah> surahs) => surahs.where(isGlazed).length;

  /// The first surah in learning order that is not glazed yet.
  Surah? nextUp(List<Surah> surahs) {
    final byNumber = {for (final s in surahs) s.number: s};
    for (final n in learningOrder()) {
      final s = byNumber[n];
      if (s != null && !isGlazed(s)) return s;
    }
    return null;
  }

  Glaze glazeOf(Surah s, {Surah? next}) {
    if (isGlazed(s)) return Glaze.full;
    if (roundsDone(s) > 0) return Glaze.partial;
    if (next != null && next.number == s.number) return Glaze.next;
    return Glaze.empty;
  }
}
