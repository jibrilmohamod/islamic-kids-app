// Kept so `flutter create .` does not add its default counter-app test,
// which would not compile against this app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/app_state.dart';
import 'package:islamic_kids_app/main.dart';

void main() {
  testWidgets('app starts and shows the loading state', (tester) async {
    await tester.pumpWidget(AppScope(state: AppState(), child: const KidsApp()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
