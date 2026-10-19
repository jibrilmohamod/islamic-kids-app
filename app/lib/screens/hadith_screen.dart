import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

/// Colour and icon per hadith topic.
({Color color, IconData icon}) groupStyle(String group) => switch (group) {
      'manners-eating' => (color: Pop.cyan, icon: Icons.restaurant_rounded),
      'manners-sleeping' => (color: Pop.violet, icon: Icons.bedtime_rounded),
      _ => (color: Pop.pink, icon: Icons.format_quote_rounded),
    };

class HadithListScreen extends StatelessWidget {
  const HadithListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final hadith = state.bundle!.hadith;
    final groups = <String>{for (final h in hadith) h.group}.toList();

    return PopPage(
      title: tr('hadith', lang),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 12),
              child: InkPanel(
                color: groupStyle(g).color,
                halftone: true,
                dotColor: const Color(0x55FFFFFF),
                shadow: 4,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(groupStyle(g).icon, color: g == 'manners-sleeping' ? Colors.white : Pop.ink),
                    const SizedBox(width: 10),
                    Text(tr('group.$g', lang),
                        style: TextStyle(
                            fontFamily: Pop.display,
                            fontSize: 15,
                            color: g == 'manners-sleeping' ? Colors.white : Pop.ink)),
                  ],
                ),
              ),
            ),
            for (final h in hadith.where((x) => x.group == g))
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkPanel(
                  border: 3,
                  shadow: 4,
                  padding: const EdgeInsets.all(14),
                  onTap: () => go(context, HadithScreen(hadith: h)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.t(lang).title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
                      const SizedBox(height: 6),
                      Chip2(h.t(lang).grade),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class HadithScreen extends StatefulWidget {
  final Hadith hadith;
  const HadithScreen({super.key, required this.hadith});

  @override
  State<HadithScreen> createState() => _HadithScreenState();
}

class _HadithScreenState extends State<HadithScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).markActive();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final h = widget.hadith;
    final style = groupStyle(h.group);
    final ink = h.group == 'manners-sleeping' ? Colors.white : Pop.ink;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Pop.ink, width: 4))),
            child: ColoredBox(
              color: style.color,
              child: CustomPaint(
                painter: const HalftonePainter(Color(0x66FFFFFF)),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            InkIconButton(
                              icon: Icons.arrow_back_rounded,
                              tooltip: tr('back', lang),
                              onPressed: () => Navigator.of(context).maybePop(),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Pop.ink, width: 3)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(style.icon, size: 18, color: Pop.ink),
                                  const SizedBox(width: 6),
                                  Text(tr('group.${h.group}', lang),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(h.t(lang).title,
                            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.25, color: ink)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                InkPanel(border: 3, shadow: 0, padding: const EdgeInsets.all(14), child: QuotedArabic(h.arabic)),
                const SizedBox(height: 16),
                HadithDetails(hadith: h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Meaning, grade, HadeethEnc's lessons and explanation, all verbatim.
/// Shared by the hadith and dua screens.
class HadithDetails extends StatelessWidget {
  final Hadith hadith;
  const HadithDetails({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final t = hadith.t(lang);
    const stars = [Pop.pink, Pop.cyan, Pop.lemon, Pop.violet];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkPanel(
          border: 3,
          shadow: 0,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Heading(tr('meaning', lang)),
              Text(t.text, style: const TextStyle(fontSize: 17, height: 1.5)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip2(t.grade, color: const Color(0xFF1FA187), textColor: Colors.white),
                  Text(t.attribution, style: const TextStyle(fontSize: 13, color: Pop.muted)),
                ],
              ),
              SourceLabel('hadeethenc', extra: '#${hadith.hadeethencId}'),
            ],
          ),
        ),
        if (t.hints.isNotEmpty) ...[
          const SizedBox(height: 18),
          Align(alignment: Alignment.centerLeft, child: Caption(tr('lessons', lang))),
          const SizedBox(height: 10),
          for (var i = 0; i < t.hints.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarTile(size: 28, glaze: Glaze.full, color: stars[i % stars.length], semanticsLabel: ''),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.hints[i], style: const TextStyle(fontSize: 16, height: 1.4))),
                ],
              ),
            ),
          SourceLabel('hadeethenc', extra: '#${hadith.hadeethencId}'),
        ],
        if (t.explanation.isNotEmpty) ...[
          const SizedBox(height: 16),
          InkPanel(
            border: 3,
            shadow: 0,
            color: Pop.highlight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                iconColor: Pop.ink,
                collapsedIconColor: Pop.ink,
                title: Text(tr('understand', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 16)),
                children: [
                  Text(t.explanation, style: const TextStyle(fontSize: 16, height: 1.5)),
                  SourceLabel('hadeethenc', extra: '#${hadith.hadeethencId}'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
