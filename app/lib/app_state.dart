import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import 'models.dart';

/// App-wide state. Progress lives in memory for now; saving it on the device
/// comes with the first storage package, once one is checked.
class AppState extends ChangeNotifier {
  String lang = 'so';
  ContentBundle? bundle;
  String? error;
  final Set<String> completedGames = {};

  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/content/bundle.json');
      bundle = ContentBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      error = e.toString();
    }
    notifyListeners();
  }

  void setLang(String value) {
    if (value == lang) return;
    lang = value;
    notifyListeners();
  }

  void completeGame(String id) {
    if (completedGames.add(id)) notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
