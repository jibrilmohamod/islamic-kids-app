import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'strings.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL-licenses.txt');
    yield LicenseEntryWithLineBreaks(const ['Bungee', 'Baloo 2', 'Amiri Quran'], text);
  });
  final state = AppState()..load();
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
    );
  }
}
