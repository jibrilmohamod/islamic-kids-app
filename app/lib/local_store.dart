import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// What the child did last, for "carry on where you left off".
enum HistoryKind { read, listen }

/// One line of reading or listening history. [atMs] is UTC epoch millis.
@immutable
class HistoryEntry {
  final HistoryKind kind;
  final int surah;

  /// Ayah index in the surah (0-based).
  final int ayah;
  final int atMs;

  const HistoryEntry({required this.kind, required this.surah, required this.ayah, required this.atMs});

  static HistoryEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = HistoryKind.values.where((k) => k.name == j['kind']).firstOrNull;
    final surah = j['surah'];
    final ayah = j['ayah'];
    final at = j['at'];
    if (kind == null || surah is! int || ayah is! int || at is! int) return null;
    if (surah < 1 || surah > 114 || ayah < 0) return null;
    return HistoryEntry(kind: kind, surah: surah, ayah: ayah, atMs: at);
  }

  Map<String, Object> toJson() => {'kind': kind.name, 'surah': surah, 'ayah': ayah, 'at': atMs};

  @override
  bool operator ==(Object other) =>
      other is HistoryEntry && other.kind == kind && other.surah == surah && other.ayah == ayah && other.atMs == atMs;

  @override
  int get hashCode => Object.hash(kind, surah, ayah, atMs);
}

/// Everything the app keeps on the phone. Plain values only; the JSON shape
/// stays inside this file.
class SavedState {
  String? lang;
  List<String> rounds;
  Set<String> activeDays;
  Map<String, int> minutesByDay;
  Map<String, int> extraByDay;
  int dailyLimit;
  int lastPage;
  String? homeIntroDay;

  /// Bookmarked ayat as "surah:ayah", newest first.
  List<String> bookmarks;

  /// Favourites as "dua:<id>", "hadith:<id>" or "surah:<n>".
  Set<String> favourites;

  /// Newest first; one entry per surah and kind (see [LocalStore.historyCap]).
  List<HistoryEntry> history;

  /// v0.1 finished games ("order-surah-N"), expanded to rounds by AppState
  /// once the content bundle is loaded, then cleared.
  List<String> legacyCompleted;

  SavedState({
    this.lang,
    List<String>? rounds,
    Set<String>? activeDays,
    Map<String, int>? minutesByDay,
    Map<String, int>? extraByDay,
    this.dailyLimit = 0,
    this.lastPage = 1,
    this.homeIntroDay,
    List<String>? bookmarks,
    Set<String>? favourites,
    List<HistoryEntry>? history,
    List<String>? legacyCompleted,
  })  : rounds = rounds ?? [],
        activeDays = activeDays ?? {},
        minutesByDay = minutesByDay ?? {},
        extraByDay = extraByDay ?? {},
        bookmarks = bookmarks ?? [],
        favourites = favourites ?? {},
        history = history ?? [],
        legacyCompleted = legacyCompleted ?? [];

  /// Reads leniently: a field that is missing or the wrong type falls back
  /// to its default instead of failing the whole file.
  factory SavedState.fromJson(Map<String, Object?> j) {
    List<String> strings(Object? v) => v is List ? [for (final x in v) if (x is String) x] : [];
    Map<String, int> counts(Object? v) => v is Map ? {for (final e in v.entries) if (e.key is String && e.value is int) e.key as String: e.value as int} : {};
    int intOr(Object? v, int d) => v is int ? v : d;
    final h = j['history'];
    return SavedState(
      lang: j['lang'] is String ? j['lang'] as String : null,
      rounds: strings(j['rounds']),
      activeDays: strings(j['activeDays']).toSet(),
      minutesByDay: counts(j['minutesByDay']),
      extraByDay: counts(j['extraByDay']),
      dailyLimit: intOr(j['dailyLimit'], 0).clamp(0, 24 * 60),
      lastPage: intOr(j['lastPage'], 1).clamp(1, 604),
      homeIntroDay: j['homeIntroDay'] is String ? j['homeIntroDay'] as String : null,
      bookmarks: strings(j['bookmarks']),
      favourites: strings(j['favourites']).toSet(),
      history: h is List ? h.map(HistoryEntry.fromJson).whereType<HistoryEntry>().toList() : [],
      legacyCompleted: strings(j['legacyCompleted']),
    );
  }

  Map<String, Object?> toJson() => {
        'lang': lang,
        'rounds': rounds,
        'activeDays': activeDays.toList()..sort(),
        'minutesByDay': minutesByDay,
        'extraByDay': extraByDay,
        'dailyLimit': dailyLimit,
        'lastPage': lastPage,
        'homeIntroDay': homeIntroDay,
        'bookmarks': bookmarks,
        'favourites': favourites.toList()..sort(),
        'history': [for (final e in history) e.toJson()],
        if (legacyCompleted.isNotEmpty) 'legacyCompleted': legacyCompleted,
      };
}

/// The values SharedPreferences held before this store (app 0.3 and
/// earlier), so the first launch after the update carries them over.
class LegacyPrefs {
  final String? lang;
  final List<String> rounds;
  final List<String> legacyCompleted;
  final List<String> activeDays;
  final List<String> minutes;
  final List<String> extra;
  final int? dailyLimit;
  final int? lastPage;
  final String? homeIntroDay;

  const LegacyPrefs({
    this.lang,
    this.rounds = const [],
    this.legacyCompleted = const [],
    this.activeDays = const [],
    this.minutes = const [],
    this.extra = const [],
    this.dailyLimit,
    this.lastPage,
    this.homeIntroDay,
  });
}

/// The app's on-device store: one small JSON file, written atomically.
///
/// - Writes go to a temp file that is flushed to disk and then renamed over
///   the real one, so a crash mid-write never leaves a half file.
/// - The previous good file is kept as a backup and used if the main one is
///   unreadable.
/// - Changes are batched for [debounce] and flushed at once when the app goes
///   to the background (AppState calls [flush]).
///
/// See ADR 0003 for why this is a JSON file and not SQLite.
class LocalStore {
  static const formatVersion = 1;
  static const fileName = 'store.json';
  static const historyCap = 50;
  static const bookmarksCap = 200;
  static const debounce = Duration(milliseconds: 400);

  final Directory dir;
  final SavedState state;

  /// True when this launch carried values over from SharedPreferences.
  final bool migrated;

  Timer? _timer;
  Future<void>? _writing;
  bool _dirty = false;

  LocalStore._(this.dir, this.state, {this.migrated = false});

  File get _main => File('${dir.path}/$fileName');
  File get _backup => File('${dir.path}/$fileName.bak');
  File get _temp => File('${dir.path}/$fileName.tmp');

  /// Opens the store in [dir]. With no store file yet, [legacy] supplies
  /// the old SharedPreferences values, which are written out at once.
  static Future<LocalStore> open(Directory dir, {Future<LegacyPrefs?> Function()? legacy}) async {
    await dir.create(recursive: true);
    final probe = LocalStore._(dir, SavedState());
    for (final f in [probe._main, probe._backup]) {
      final s = await _read(f);
      if (s != null) return LocalStore._(dir, s);
    }
    final old = await legacy?.call();
    if (old == null) return LocalStore._(dir, SavedState());
    final store = LocalStore._(dir, fromLegacy(old), migrated: true);
    store._dirty = true;
    await store.flush();
    return store;
  }

  static Future<SavedState?> _read(File f) async {
    try {
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map<String, Object?>) return null;
      final v = j['formatVersion'];
      // A file from a newer app version is not read; its shape is unknown.
      if (v is! int || v > formatVersion) return null;
      final data = j['data'];
      return data is Map<String, Object?> ? SavedState.fromJson(data) : null;
    } catch (e) {
      debugPrint('Store file ${f.path} unreadable: $e');
      return null;
    }
  }

  static SavedState fromLegacy(LegacyPrefs p) {
    Map<String, int> counts(List<String> raw) {
      final out = <String, int>{};
      for (final s in raw) {
        final parts = s.split(':');
        final n = parts.length == 2 ? int.tryParse(parts[1]) : null;
        if (n != null) out[parts[0]] = n;
      }
      return out;
    }

    return SavedState(
      lang: p.lang,
      rounds: List.of(p.rounds),
      legacyCompleted: List.of(p.legacyCompleted),
      activeDays: p.activeDays.toSet(),
      minutesByDay: counts(p.minutes),
      extraByDay: counts(p.extra),
      dailyLimit: p.dailyLimit ?? 0,
      lastPage: p.lastPage ?? 1,
      homeIntroDay: p.homeIntroDay,
    );
  }

  /// Changes [state] and schedules a write.
  void update(void Function(SavedState s) change) {
    change(state);
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  /// Writes now if anything changed. Safe to call often.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    while (_writing != null) {
      await _writing;
    }
    if (!_dirty) return;
    _dirty = false;
    final text = jsonEncode({'formatVersion': formatVersion, 'data': state.toJson()});
    final w = _write(text);
    _writing = w;
    try {
      await w;
    } catch (e) {
      _dirty = true; // try again on the next change or flush
      debugPrint('Store write failed: $e');
    } finally {
      _writing = null;
    }
  }

  Future<void> _write(String text) async {
    final tmp = _temp;
    await tmp.writeAsString(text, flush: true);
    if (await _main.exists()) await _main.rename(_backup.path);
    await tmp.rename(_main.path);
  }

  // ---- Bookmarks, favourites, history ----

  bool isBookmarked(String ayahKey) => state.bookmarks.contains(ayahKey);

  /// Adds or removes a bookmark; returns whether it is now bookmarked.
  bool toggleBookmark(String ayahKey) {
    final on = !isBookmarked(ayahKey);
    update((s) {
      s.bookmarks.remove(ayahKey);
      if (on) {
        s.bookmarks.insert(0, ayahKey);
        if (s.bookmarks.length > bookmarksCap) s.bookmarks.removeLast();
      }
    });
    return on;
  }

  bool isFavourite(String id) => state.favourites.contains(id);

  /// Adds or removes a favourite; returns whether it is now a favourite.
  bool toggleFavourite(String id) {
    final on = !isFavourite(id);
    update((s) => on ? s.favourites.add(id) : s.favourites.remove(id));
    return on;
  }

  /// Records reading or listening, keeping one line per surah and kind.
  void record(HistoryEntry e) {
    update((s) {
      s.history
        ..removeWhere((x) => x.kind == e.kind && x.surah == e.surah)
        ..insert(0, e);
      if (s.history.length > historyCap) s.history.removeRange(historyCap, s.history.length);
    });
  }

  /// The most recent entry of [kind], if any.
  HistoryEntry? last(HistoryKind kind) => state.history.where((e) => e.kind == kind).firstOrNull;
}
