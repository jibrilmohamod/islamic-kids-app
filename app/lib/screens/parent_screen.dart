import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

/// Settings and credits for parents. A PIN lock comes in a later step.
class ParentScreen extends StatelessWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle;
    final audio = bundle?.audio;

    return PopPage(
      title: tr('parents', lang),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          if (AppState.somaliEnabled) ...[
            Text(tr('language', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 16)),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'so', label: Text('Soomaali')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {lang},
              onSelectionChanged: (s) => state.setLang(s.first),
            ),
            const SizedBox(height: 24),
          ],
          Text(tr('sources', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 16)),
          const SizedBox(height: 10),
          if (bundle != null)
            InkPanel(
              border: 3,
              shadow: 0,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in bundle.sources.values) ...[
                    Text(s.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text([s.publisher, if (s.version.isNotEmpty) 'v${s.version}', s.url].join(', '),
                        style: const TextStyle(fontSize: 14, color: Pop.muted)),
                    const SizedBox(height: 10),
                  ],
                  if (audio != null) ...[
                    Text('${tr('recitation', lang)}: ${audio.reciter}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('${audio.publisher}, ${audio.bitrate} kbps, ${audio.terms}',
                        style: const TextStyle(fontSize: 14, color: Pop.muted)),
                    const SizedBox(height: 10),
                  ],
                  Text('${tr('bundleVersion', lang)}: ${bundle.version}',
                      style: const TextStyle(fontSize: 13, color: Pop.muted)),
                ],
              ),
            ),
          const SizedBox(height: 18),
          ComicButton(
            label: tr('fontLicenses', lang),
            color: Colors.white,
            onPressed: () => showLicensePage(context: context, applicationName: tr('appName', lang)),
          ),
        ],
      ),
    );
  }
}
