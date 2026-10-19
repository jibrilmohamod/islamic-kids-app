import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'activity.dart';
import 'audio_service.dart';
import 'content_store.dart';
import 'models.dart';
import 'mushaf.dart';
import 'progress.dart';

/// App-wide state: content, language, progress and audio. Everything is kept
/// on the device; there are no accounts.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  /// English first. Somali can be switched on once its coverage is ready.
  static const bool somaliEnabled = false;

  static const _kLang = 'lang';
  static const _kRounds = 'rounds';
  static const _kLegacyCompleted = 'completedGames';
  static const _kActiveDays = 'activeDays';
  static const _kMinutes = 'minutesByDay';
  static const _kExtra = 'extraByDay';
  static const _kLimit = 'dailyLimit';
  static const _kLastPage = 'mushafPage';

  String lang = 'en';
  ContentBundle? bundle;
  String? error;
  Progress progress = Progress();
  AudioService? audio;
  Activity activity = Activity();
  SharedPreferences? _prefs;
  Timer? _ticker;
  MushafBook? _book;

  /// The mushaf page the child was last reading, like a bookmark.
  int lastPage = 1;

  void setLastPage(int page) {
    lastPage = page;
    _prefs?.setInt(_kLastPage, page);
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
    List<String> legacy = const [];
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedLang = _prefs!.getString(_kLang);
      if (savedLang != null && (savedLang == 'en' || somaliEnabled)) lang = savedLang;
      progress = Progress(_prefs!.getStringList(_kRounds) ?? const []);
      legacy = _prefs!.getStringList(_kLegacyCompleted) ?? const [];
      activity = Activity(
        activeDays: (_prefs!.getStringList(_kActiveDays) ?? const []).toSet(),
        minutesByDay: Activity.decodeCounts(_prefs!.getStringList(_kMinutes) ?? const []),
        extraByDay: Activity.decodeCounts(_prefs!.getStringList(_kExtra) ?? const []),
        dailyLimit: _prefs!.getInt(_kLimit) ?? 0,
      )..prune(DateTime.now());
      lastPage = _prefs!.getInt(_kLastPage) ?? 1;
    } catch (_) {
      // Preferences are a convenience; the app still runs without them.
    }

    Future<Directory> support() => getApplicationSupportDirectory();
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
      _migrateLegacy(current, legacy);
      final info = current.audio;
      if (info != null) audio = AudioService(info: info, baseDir: support);
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
      _prefs?.setStringList(_kMinutes, Activity.encodeCounts(activity.minutesByDay));
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
    }
  }

  bool get timeUp => activity.timeUp(now());

  void setDailyLimit(int minutes) {
    activity.dailyLimit = minutes;
    _prefs?.setInt(_kLimit, minutes);
    notifyListeners();
  }

  void allowMoreTime(int minutes) {
    activity.allowMore(now(), minutes);
    _prefs?.setStringList(_kExtra, Activity.encodeCounts(activity.extraByDay));
    notifyListeners();
  }

  /// Counts today on the weekly dots. Called when a child finishes a round
  /// or opens a dua or hadith.
  void markActive() {
    if (!activity.markActive(now())) return;
    _prefs?.setStringList(_kActiveDays, activity.activeDays.toList());
    notifyListeners();
  }

  /// v0.1 saved finished games as "order-surah-N"; those count as all rounds.
  void _migrateLegacy(ContentBundle b, List<String> legacy) {
    if (legacy.isEmpty) return;
    for (final id in legacy) {
      final n = int.tryParse(id.replaceFirst('order-surah-', ''));
      final s = b.surahs.where((x) => x.number == n).firstOrNull;
      if (s == null) continue;
      for (var r = 0; r < roundsFor(s.ayat.length).length; r++) {
        progress.completeRound(s.number, r);
      }
    }
    _prefs?.setStringList(_kRounds, progress.toSaved());
    _prefs?.remove(_kLegacyCompleted);
  }

  void setLang(String value) {
    if (value == lang) return;
    lang = value;
    _prefs?.setString(_kLang, value);
    notifyListeners();
  }

  void completeRound(Surah s, int round) {
    markActive();
    if (!progress.completeRound(s.number, round)) return;
    _prefs?.setStringList(_kRounds, progress.toSaved());
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
