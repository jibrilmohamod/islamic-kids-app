// Run: flutter test
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/activity.dart';
import 'package:islamic_kids_app/app_state.dart';
import 'package:islamic_kids_app/models.dart';
import 'package:islamic_kids_app/screens/duas_screen.dart';
import 'package:islamic_kids_app/screens/home_screen.dart';
import 'package:islamic_kids_app/theme.dart';

AppState stateAt(DateTime now) {
  final raw = File('assets/content/bundle.json').readAsStringSync();
  return AppState()
    ..bundle = ContentBundle.fromJson(jsonDecode(raw) as Map<String, dynamic>)
    ..now = () => now;
}

Widget app(AppState state, {bool reduceMotion = false}) => AppScope(
      state: state,
      child: MaterialApp(
        theme: popTheme(),
        home: MediaQuery(
          data: MediaQueryData(size: const Size(412, 892), disableAnimations: reduceMotion),
          child: const HomeScreen(),
        ),
      ),
    );

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(824, 1784);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

void main() {
  test('the sky follows the time of day', () {
    expect(skyFor(DateTime(2026, 10, 19, 5)), Sky.morning);
    expect(skyFor(DateTime(2026, 10, 19, 10, 59)), Sky.morning);
    expect(skyFor(DateTime(2026, 10, 19, 11)), Sky.afternoon);
    expect(skyFor(DateTime(2026, 10, 19, 16)), Sky.evening);
    expect(skyFor(DateTime(2026, 10, 19, 2)), Sky.evening);
    expect(greetingKey(Sky.afternoon), 'goodAfternoon');
  });

  testWidgets('reduced motion: everything is in place at once', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(stateAt(DateTime(2026, 10, 19, 7)), reduceMotion: true));
    await tester.pumpAndSettle();
    expect(find.text('Good morning'), findsOneWidget);
    for (final label in ['Surahs', 'Duas', 'Hadith', 'Games']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Keep going'), findsOneWidget);
    expect(find.text('Dua for this morning'), findsOneWidget);
  });

  testWidgets('the opening plays once a day and is remembered', (tester) async {
    phone(tester);
    final now = DateTime(2026, 10, 19, 20);
    final state = stateAt(now);
    await tester.pumpWidget(app(state));
    expect(state.homeIntroDay, dayKey(now));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Good evening'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
  });

  testWidgets('a niche opens its section', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(stateAt(DateTime(2026, 10, 19, 13)), reduceMotion: true));
    await tester.pumpAndSettle();
    // Tap the middle of the niche, where a child's finger lands.
    final niche = find.ancestor(of: find.text('Duas'), matching: find.byType(GestureDetector)).first;
    await tester.ensureVisible(niche);
    await tester.pumpAndSettle();
    await tester.tap(niche);
    await tester.pumpAndSettle();
    expect(find.byType(DuasScreen), findsOneWidget);
  });
}
