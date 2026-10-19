import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_store.dart';
import 'models.dart';

/// App-wide state: content, language and progress. Progress is saved on the
/// device only; there are no accounts.
class AppState extends ChangeNotifier {
  /// English first. Somali can be switched on once its coverage is ready.
  static const bool somaliEnabled = false;

  static const _kLang = 'lang';
  static const _kCompleted = 'completedGames';

  String lang = 'en';
  ContentBundle? bundle;
  String? error;
  final Set<String> completedGames = {};
  SharedPreferences? _prefs;

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final savedLang = _prefs!.getString(_kLang);
      if (savedLang != null && (savedLang == 'en' || somaliEnabled)) lang = savedLang;
      completedGames.addAll(_prefs!.getStringList(_kCompleted) ?? const []);
    } catch (_) {
      // Preferences are a convenience; the app still runs without them.
    }

    final store = ContentStore(
      loadAsset: () => rootBundle.loadString('assets/content/bundle.json'),
      cacheDir: () async => Directory('${(await getApplicationSupportDirectory()).path}/content'),
    );
    try {
      bundle = await store.loadBest();
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();

    final current = bundle;
    if (current != null) unawaited(store.checkForUpdate(current.version));
  }

  void setLang(String value) {
    if (value == lang) return;
    lang = value;
    _prefs?.setString(_kLang, value);
    notifyListeners();
  }

  void completeGame(String id) {
    if (!completedGames.add(id)) return;
    _prefs?.setStringList(_kCompleted, completedGames.toList());
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
