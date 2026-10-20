import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'recitation_player.dart';
import 'screens/home_screen.dart';
import 'screens/parent_gate.dart';
import 'strings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL-licenses.txt');
    yield LicenseEntryWithLineBreaks(const ['Bungee', 'Baloo 2', 'Scheherazade New'], text);
  });
  // Mushaf line and page breaks (data only; the Quran text is QuranEnc's).
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['quran-qcf4 (mushaf page layout)'], _qcf4License);
  });
  // Before load(): the media service must exist when recitation is created.
  final (media, mediaError) = await startMediaService();
  final state = AppState()
    ..media = media
    ..mediaError = mediaError
    ..load();
  runApp(AppScope(state: state, child: const KidsApp()));
}

class KidsApp extends StatelessWidget {
  const KidsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return MaterialApp(
      title: tr('appName', state.lang),
      debugShowCheckedModeBanner: false,
      theme: popTheme(),
      home: const HomeScreen(),
      // When the parent's daily limit is used up, a break screen covers the
      // app. It has its own navigator so the parent question can open on it.
      builder: (context, child) => Stack(
        children: [
          if (child != null) child,
          if (state.timeUp)
            Positioned.fill(
              // Its own hero scope: two navigators may not share the app's
              // HeroController (Flutter asserts, found by flows_test).
              child: HeroControllerScope.none(
                child: Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const BreakScreen())),
              ),
            ),
        ],
      ),
    );
  }
}

const _qcf4License = '''
MIT License

Copyright (c) 2026 Mohamad Hajj Rabee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';
