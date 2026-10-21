import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A small in-memory log of what the app did and what went wrong, shown to
/// parents (Parents > Problem report) so a fault on a phone can be reported
/// without a computer. Nothing leaves the phone unless a parent copies it.
class Diagnostics {
  Diagnostics._();

  /// Lines kept; older ones drop off.
  static const cap = 300;

  static final List<String> _lines = [];

  static List<String> get lines => List.unmodifiable(_lines);

  static void log(String message) {
    final t = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    _lines.add('${two(t.hour)}:${two(t.minute)}:${two(t.second)} $message');
    if (_lines.length > cap) _lines.removeRange(0, _lines.length - cap);
  }

  /// Sends debugPrint, Flutter errors and uncaught errors to the log as
  /// well as to the usual places. Call first thing in main().
  static void install() {
    final print = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) log(message);
      print(message, wrapWidth: wrapWidth);
    };
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      log('ERROR ${details.exceptionAsString()}\n${_top(details.stack)}');
      previous?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      log('UNCAUGHT $error\n${_top(stack)}');
      return false; // keep the default handling (it is logged there too)
    };
  }

  static String _top(StackTrace? s) =>
      (s?.toString() ?? '').split('\n').where((l) => l.trim().isNotEmpty).take(6).join('\n');

  @visibleForTesting
  static void clear() => _lines.clear();
}
