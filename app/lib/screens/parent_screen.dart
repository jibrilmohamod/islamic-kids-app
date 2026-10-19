import 'package:flutter/material.dart';

import '../app_state.dart';
import '../strings.dart';

/// Settings for parents. A PIN lock comes in a later step.
class ParentScreen extends StatelessWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle;

    return Scaffold(
      appBar: AppBar(title: Text(tr('parents', lang))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (AppState.somaliEnabled) ...[
            Text(tr('language', lang), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'so', label: Text('Soomaali')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {lang},
              onSelectionChanged: (s) => state.setLang(s.first),
            ),
            const SizedBox(height: 28),
          ],
          Text(tr('sources', lang), style: Theme.of(context).textTheme.titleMedium),
          if (bundle != null) ...[
            for (final s in bundle.sources.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.title),
                subtitle: Text([s.publisher, if (s.version.isNotEmpty) 'v${s.version}', s.url].join(' · ')),
              ),
            const SizedBox(height: 8),
            Text('${tr('bundleVersion', lang)}: ${bundle.version}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
