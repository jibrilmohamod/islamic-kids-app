// Run: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:islamic_kids_app/diagnostics.dart';

void main() {
  tearDown(Diagnostics.clear);

  test('keeps the newest lines with a time, up to the cap', () {
    for (var i = 0; i < Diagnostics.cap + 5; i++) {
      Diagnostics.log('line $i');
    }
    final lines = Diagnostics.lines;
    expect(lines, hasLength(Diagnostics.cap));
    expect(lines.first, endsWith('line 5'));
    expect(lines.last, matches(RegExp(r'^\d\d:\d\d:\d\d line 304$')));
  });
}
