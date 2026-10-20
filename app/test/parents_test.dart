// Run: flutter test
//
// The grown-ups' side: the question gate, the parents' screen (daily limit,
// recitation-controls status, sources) and more time on the break screen
// (test audit T4, issue #6).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/activity.dart';
import 'package:islamic_kids_app/app_state.dart';
import 'package:islamic_kids_app/audio_service.dart';
import 'package:islamic_kids_app/local_store.dart';
import 'package:islamic_kids_app/screens/parent_gate.dart';
import 'package:islamic_kids_app/screens/parent_screen.dart';

import 'harness.dart';

/// Reads the two numbers from the gate's question and returns their product.
int gateAnswer(WidgetTester tester) {
  final q = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data ?? '').firstWhere((s) => s.startsWith('What is'));
  final m = RegExp(r'(\d+) × (\d+)').firstMatch(q)!;
  return int.parse(m[1]!) * int.parse(m[2]!);
}

/// The card only shows once recitation audio is set up.
void withAudio(AppState state, Directory dir) => state.audio = AudioService(
      info: state.bundle!.audio!,
      baseDir: () async => dir,
      download: (url, file) async => file.writeAsBytes([1]),
    );

void main() {
  test('gate questions are two-digit times one-digit, never trivial', () {
    for (var seed = 0; seed < 200; seed++) {
      final q = ParentGateQuestion.random(seed);
      expect(q.a, inInclusiveRange(12, 19));
      expect(q.b, inInclusiveRange(3, 9));
      expect(q.answer, q.a * q.b);
    }
  });

  late Directory dir;
  late LocalStore store;
  setUp(() => dir = Directory.systemTemp.createTempSync('parents_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  testWidgets('the gate refuses a wrong answer and lets the right one through', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    bool? result;
    await tester.pumpWidget(testApp(
      state,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () async => result = await askParent(context), child: const Text('open')),
          ),
        ),
      ),
    ));

    // Cancel gives false.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('For grown-ups'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final answer = gateAnswer(tester);
    await tester.enterText(find.byType(TextField), '${answer + 1}');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('That is not right. Ask a grown-up.'), findsOneWidget);
    // Only digits are accepted.
    await tester.enterText(find.byType(TextField), 'abc');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    await tester.enterText(find.byType(TextField), '$answer');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.text('For grown-ups'), findsNothing);
    await tester.runAsync(store.flush);
  });

  testWidgets('a grown-up can give more time from the break screen', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    state.activity = Activity(dailyLimit: 30, minutesByDay: {dayKey(testNow): 30});
    expect(state.timeUp, isTrue);
    await tester.pumpWidget(testApp(state, const BreakScreen()));
    await tester.tap(find.textContaining('For grown-ups'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '${gateAnswer(tester)}');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(state.timeUp, isFalse);
    expect(store.state.extraByDay[dayKey(testNow)], 15);
    await tester.runAsync(store.flush);
  });

  testWidgets('the daily limit is chosen with chips and saved', (tester) async {
    usePhone(tester);
    final (state, s) = await testState(tester, dir);
    store = s;
    await tester.pumpWidget(testApp(state, const ParentScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('45 min'));
    await tester.pumpAndSettle();
    expect(state.activity.dailyLimit, 45);
    expect(store.state.dailyLimit, 45);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '45 min')).selected, isTrue);
    await tester.tap(find.text('Off'));
    await tester.pumpAndSettle();
    expect(state.activity.dailyLimit, 0);
    // Every source in the bundle is credited.
    for (final src in state.bundle!.sources.values) {
      expect(find.text(src.title), findsOneWidget);
    }
    await tester.runAsync(store.flush);
  });

  // The recitation-controls card says why the shade has no controls.
  for (final (label, error, allowed, expected, button) in [
    ('not asked yet', null, null, 'Not set up yet: play a surah once to be asked.', false),
    ('allowed', null, true, 'On: pull down from the top of the screen to pause or stop.', false),
    ('refused', null, false, 'Off: notifications are not allowed for this app.', true),
    ('service failed', 'boom', true, 'Off: the phone did not start them (boom).', false),
  ]) {
    testWidgets('controls status: $label', (tester) async {
      usePhone(tester);
      final (state, s) = await testState(tester, dir);
      store = s;
      withAudio(state, dir);
      state
        ..mediaError = error
        ..notificationsAllowed = allowed;
      await tester.pumpWidget(testApp(state, const ParentScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(expected), 200);
      expect(find.text(expected), findsOneWidget);
      expect(find.text('Allow notifications'), button ? findsOneWidget : findsNothing);
      await tester.runAsync(store.flush);
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('grown-up pages fit their text at ${scale}x', (tester) async {
      usePhone(tester);
      final (state, s) = await testState(tester, dir);
      store = s;
      withAudio(state, dir);
      state.notificationsAllowed = false;
      for (final page in const <Widget>[ParentScreen(), BreakScreen()]) {
        await tester.pumpWidget(testApp(state, page, textScale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$page at ${scale}x');
      }
      await tester.runAsync(store.flush);
    });
  }
}
