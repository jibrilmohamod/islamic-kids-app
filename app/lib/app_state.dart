import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity.dart';
import 'audio_service.dart';
import 'content_store.dart';
import 'local_store.dart';
import 'models.dart';
import 'mushaf.dart';
import 'progress.dart';
import 'recitation.dart';
import 'recitation_player.dart';
import 'strings.dart';

/// App-wide state: content, language, progress and audio. Everything is kept
/// on the device; there are no accounts.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  /// English first. Somali can be switched on once its coverage is ready.
  static const bool somaliEnabled = false;

  // SharedPreferences keys from app 0.3 and earlier, read once to carry
  // values over into LocalStore (ADR 0003).
  static const _kLang = 'lang';
  static const _kRounds = 'rounds';
  static const _kLegacyCompleted = 'completedGames';
  static const _kActiveDays = 'activeDays';
  static const _kMinutes = 'minutesByDay';
  static const _kExtra = 'extraByDay';
  static const _kLimit = 'dailyLimit';
  static const _kLastPage = 'mushafPage';
  static const _kHomeIntro = 'homeIntroDay';

  String lang = 'en';
  ContentBundle? bundle;
  String? error;
  Progress progress = Progress();
  AudioService? audio;

  /// Plays recitation; keeps going after the child leaves the screen.
  Recitation? recitation;

  /// Android media notification, set by main() before load().
  RecitationHandler? media;
  Activity activity = Activity();
  LocalStore? _store;
  Timer? _ticker;
  MushafBook? _book;

  /// The mushaf page the child was last reading, like a bookmark.
  int lastPage = 1;

  /// The day Home last played its opening animation (dayKey), so it plays
  /// in full once a day and only fades in after that.
  String? homeIntroDay;

  void setHomeIntroDay(String day) {
    homeIntroDay = day;
    _store?.update((s) => s.homeIntroDay = day);
  }

  void setLastPage(int page) {
    lastPage = page;
    _store?.update((s) => s.lastPage = page);
    final first = book?.page(page).ayat.firstOrNull?.key.split(':');
    if (first != null && first.length == 2) {
      recordHistory(HistoryKind.read, int.parse(first[0]), int.parse(first[1]) - 1);
    }
  }

  ContentBundle? _bookFor;

  /// The Madina mushaf pages for the current bundle, built once. Null when
  /// the bundle carries no page layout.
  MushafBook? get book {
    final b = bundle;
    if (b == null) return null;
    if (!identical(_bookFor, b)) {
      _bookFor = b;
      _book = MushafBook.from(b);
    }
    return _book;
  }

  /// Injectable clock for tests.
  DateTime Function() now = DateTime.now;

  Future<void> load() async {
    Future<Directory> support() => getApplicationSupportDirectory();
    try {
      final store = await LocalStore.open(
        Directory('${(await support()).path}/store'),
        legacy: _readLegacyPrefs,
      );
      _store = store;
      final saved = store.state;
      if (saved.lang != null && (saved.lang == 'en' || somaliEnabled)) lang = saved.lang!;
      progress = Progress(saved.rounds);
      activity = Activity(
        activeDays: {...saved.activeDays},
        minutesByDay: {...saved.minutesByDay},
        extraByDay: {...saved.extraByDay},
        dailyLimit: saved.dailyLimit,
      )..prune(DateTime.now());
      lastPage = saved.lastPage;
      homeIntroDay = saved.homeIntroDay;
    } catch (e) {
      // Saving is a convenience; the app still runs without it.
      debugPrint('Local store unavailable: $e');
    }

    final store = ContentStore(
      loadAsset: () => rootBundle.loadString('assets/content/bundle.json'),
      cacheDir: () async => Directory('${(await support()).path}/content'),
    );
    try {
      bundle = await store.loadBest();
    } catch (e) {
      error = e.toString();
    }

    final current = bundle;
    if (current != null) {
      _migrateLegacy(current);
      final info = current.audio;
      if (info != null) {
        final files = AudioService(info: info, baseDir: support);
        audio = files;
        final rec = recitation = Recitation(files: files, player: JustAudioRecitationPlayer());
        rec.addListener(() {
          final s = rec.surah;
          if (s != null) recordHistory(HistoryKind.listen, s.number, rec.index);
        });
        final m = media;
        if (m != null) {
          m.ayahLabel = (n, total) => tr('ayahOf', lang, {'n': n, 'total': total});
          m.attach(recitation!);
        }
      }
      unawaited(store.checkForUpdate(current.version));
    }
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
    notifyListeners();
  }

  // ---- Time on screen, for the parent's daily limit ----

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      final wasUp = activity.timeUp(now());
      activity.addMinute(now());
      _store?.update((s) => s.minutesByDay = {...activity.minutesByDay});
      if (activity.timeUp(now()) != wasUp) notifyListeners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTicker();
      notifyListeners();
    } else {
      _ticker?.cancel();
      _ticker = null;
      // The app may be killed from here on: write pending changes now.
      unawaited(_store?.flush());
    }
  }

  bool get timeUp => activity.timeUp(now());

  void setDailyLimit(int minutes) {
    activity.dailyLimit = minutes;
    _store?.update((s) => s.dailyLimit = minutes);
    notifyListeners();
  }

  void allowMoreTime(int minutes) {
    activity.allowMore(now(), minutes);
    _store?.update((s) => s.extraByDay = {...activity.extraByDay});
    notifyListeners();
  }

  /// Counts today on the weekly dots. Called when a child finishes a round
  /// or opens a dua or hadith.
  void markActive() {
    if (!activity.markActive(now())) return;
    _store?.update((s) => s.activeDays = {...activity.activeDays});
    notifyListeners();
  }

  /// v0.1 saved finished games as "order-surah-N"; those count as all rounds.
  void _migrateLegacy(ContentBundle b) {
    final legacy = _store?.state.legacyCompleted ?? const <String>[];
    if (legacy.isEmpty) return;
    for (final id in legacy) {
      final n = int.tryParse(id.replaceFirst('order-surah-', ''));
      final s = b.surahs.where((x) => x.number == n).firstOrNull;
      if (s == null) continue;
      for (var r = 0; r < roundsFor(s.ayat.length).length; r++) {
        progress.completeRound(s.number, r);
      }
    }
    _store?.update((s) {
      s.rounds = progress.toSaved();
      s.legacyCompleted = [];
    });
  }

  void setLang(String value) {
    if (value == lang) return;
    lang = value;
    _store?.update((s) => s.lang = value);
    notifyListeners();
  }

  void completeRound(Surah s, int round) {
    markActive();
    if (!progress.completeRound(s.number, round)) return;
    _store?.update((x) => x.rounds = progress.toSaved());
    notifyListeners();
  }

  /// Reads app 0.3's SharedPreferences, or null when there are none.
  static Future<LegacyPrefs?> _readLegacyPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (p.getKeys().isEmpty) return null;
    return LegacyPrefs(
      lang: p.getString(_kLang),
      rounds: p.getStringList(_kRounds) ?? const [],
      legacyCompleted: p.getStringList(_kLegacyCompleted) ?? const [],
      activeDays: p.getStringList(_kActiveDays) ?? const [],
      minutes: p.getStringList(_kMinutes) ?? const [],
      extra: p.getStringList(_kExtra) ?? const [],
      dailyLimit: p.getInt(_kLimit),
      lastPage: p.getInt(_kLastPage),
      homeIntroDay: p.getString(_kHomeIntro),
    );
  }

  // ---- Bookmarks, favourites and history (#33) ----

  bool isBookmarked(String ayahKey) => _store?.isBookmarked(ayahKey) ?? false;

  List<String> get bookmarks => List.unmodifiable(_store?.state.bookmarks ?? const <String>[]);

  void toggleBookmark(String ayahKey) {
    _store?.toggleBookmark(ayahKey);
    notifyListeners();
  }

  bool isFavourite(String id) => _store?.isFavourite(id) ?? false;

  void toggleFavourite(String id) {
    _store?.toggleFavourite(id);
    notifyListeners();
  }

  /// Most recent first, one line per surah and kind.
  List<HistoryEntry> get history => List.unmodifiable(_store?.state.history ?? const <HistoryEntry>[]);

  /// Notes that the child read or listened to [surah] at ayah index [ayah].
  void recordHistory(HistoryKind kind, int surah, int ayah) {
    _store?.record(HistoryEntry(kind: kind, surah: surah, ayah: ayah, atMs: now().toUtc().millisecondsSinceEpoch));
  }

  /// For tests: use [store] as if load() had opened it.
  @visibleForTesting
  set store(LocalStore store) => _store = store;
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
