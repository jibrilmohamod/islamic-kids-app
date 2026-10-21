// Shared set-up for widget tests: the fixed fixture bundle, a store in a
// temp folder with no write timer, a fixed clock and a phone-sized view.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/app_state.dart';
import 'package:islamic_kids_app/local_store.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/theme.dart';

/// 09:00, a morning, so "My day" marks the morning stop as now.
final testNow = DateTime(2026, 10, 20, 9);

ContentBundle fixtureBundle() => ContentBundle.fromJson(
      jsonDecode(File('test/fixtures/bundle.json').readAsStringSync()) as Map<String, dynamic>,
    );

/// An [AppState] over the fixture with a real [LocalStore] in [dir].
/// Call `tester.runAsync(state.store!.flush)` (or [flushStore]) at the end so
/// no pending write outlives the test.
Future<(AppState, LocalStore)> testState(WidgetTester tester, Directory dir) async {
  final store = (await tester.runAsync(() => LocalStore.open(dir, autoFlush: null)))!;
  final state = AppState()
    ..bundle = fixtureBundle()
    ..now = () => testNow;
  // ignore: invalid_use_of_visible_for_testing_member
  state.store = store;
  return (state, store);
}

/// A 412 x 892 phone at 2x, reset after the test.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(824, 1784);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// [home] inside the app's theme and scope, animations off.
Widget testApp(AppState state, Widget home, {double textScale = 1}) => AppScope(
      state: state,
      child: MaterialApp(
        theme: popTheme(),
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(412, 892),
            disableAnimations: true,
            textScaler: TextScaler.linear(textScale),
          ),
          child: home,
        ),
      ),
    );
