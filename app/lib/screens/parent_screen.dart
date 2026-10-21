import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../diagnostics.dart';
import '../recitation_player.dart';
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
          Text(tr('dailyLimit', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in const [0, 20, 30, 45, 60])
                ChoiceChip(
                  label: Text(m == 0 ? tr('limitOff', lang) : tr('minutes', lang, {'n': m}),
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  selected: state.activity.dailyLimit == m,
                  selectedColor: Pop.lemon,
                  side: const BorderSide(color: Pop.ink, width: 2),
                  shape: const RoundedRectangleBorder(),
                  onSelected: (_) => state.setDailyLimit(m),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(tr('usedToday', lang, {'n': state.activity.minutesToday(state.now())}),
              style: const TextStyle(fontSize: 14, color: Pop.muted)),
          const SizedBox(height: 24),
          if (state.audio != null) ...[
            const _ControlsStatus(),
            const SizedBox(height: 18),
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
          const _ProblemReport(),
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

/// Whether recitation shows in the pull-down shade and on the lock screen,
/// and a way to turn it on when notifications are off.
class _ControlsStatus extends StatelessWidget {
  const _ControlsStatus();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final error = state.mediaError;
    final allowed = state.notificationsAllowed;
    final (text, ok) = switch ((error, allowed)) {
      (final String e, _) => (tr('controlsBroken', lang, {'reason': e}), false),
      (_, true) => (tr('controlsOn', lang), true),
      (_, false) => (tr('controlsNoPermission', lang), false),
      _ => (tr('controlsNotAsked', lang), true),
    };
    return GlazeCard(
      glaze: ok ? Pop.cyan : Pop.lemon,
      shadow: 4,
      border: 3,
      tab: tr('controlsTitle', lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.35)),
          if (allowed == false && error == null) ...[
            const SizedBox(height: 10),
            ComicButton(
              label: tr('allowNotifications', lang),
              color: Colors.white,
              // The setting is re-read when the app comes back to the front.
              onPressed: openNotificationSettings,
            ),
          ],
        ],
      ),
    );
  }
}

/// The recent log (Diagnostics), newest first, with a Copy button.
class _ProblemReport extends StatefulWidget {
  const _ProblemReport();

  @override
  State<_ProblemReport> createState() => _ProblemReportState();
}

class _ProblemReportState extends State<_ProblemReport> {
  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final lines = Diagnostics.lines.reversed.take(60).toList();
    return GlazeCard(
      glaze: Colors.white,
      shadow: 4,
      border: 3,
      tab: tr('problemReport', lang),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('problemReportHint', lang), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: SelectableText(
                lines.join('\n'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3),
              ),
            ),
          ),
          const SizedBox(height: 10),
          ComicButton(
            label: tr('copy', lang),
            color: Colors.white,
            onPressed: () async {
              // The app's lines, then Android's own log for this app.
              final android = await androidLog();
              await Clipboard.setData(ClipboardData(
                text: [...Diagnostics.lines, if (android.isNotEmpty) '--- android log ---\n$android'].join('\n'),
              ));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied', lang))));
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
