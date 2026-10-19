import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'dua_screen.dart' show MemoriseView;

/// Colour and icon per shelf. Topic ids start with their shelf id.
({Color color, IconData icon, bool dark}) shelfStyle(String id) => switch (id) {
      'manners' => (color: Pop.cyan, icon: Icons.emoji_people_rounded, dark: false),
      'character' => (color: Pop.pink, icon: Icons.favorite_rounded, dark: false),
      'family' => (color: Pop.lemon, icon: Icons.diversity_3_rounded, dark: false),
      'prophet' => (color: Pop.violet, icon: Icons.auto_awesome_rounded, dark: true),
      'worship' => (color: const Color(0xFF1FA187), icon: Icons.water_drop_rounded, dark: true),
      'learning' => (color: Pop.lemon, icon: Icons.menu_book_rounded, dark: false),
      _ => (color: Pop.pink, icon: Icons.format_quote_rounded, dark: false),
    };

/// Older bundles name topics without shelves.
({Color color, IconData icon}) groupStyle(String group) {
  final st = shelfStyle(group.split('-').first);
  return (color: st.color, icon: st.icon);
}

String _shelfOf(String topicId) => topicId.split('-').first;

/// Topic name: HadeethEnc's own category title when the bundle has it.
String topicTitle(ContentBundle bundle, String topicId, String lang) {
  for (final sh in bundle.shelves) {
    for (final t in sh.topics) {
      if (t.id == topicId) return t.titleFor(lang);
    }
  }
  return tr('group.$topicId', lang);
}

/// Hadith by shelf: Good manners, Good character, Family and kindness...
/// Each shelf opens into HadeethEnc topics.
class HadithListScreen extends StatelessWidget {
  const HadithListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle!;
    final hadith = bundle.hadith;
    final count = <String, int>{};
    for (final h in hadith) {
      count[h.group] = (count[h.group] ?? 0) + 1;
    }
    // Shelves from the bundle, or one shelf per old group.
    final shelves = bundle.shelves.isNotEmpty
        ? bundle.shelves
        : [
            for (final g in {for (final h in hadith) h.group})
              HadithShelf(id: g, topics: [HadithTopic(id: g, title: const {})]),
          ];

    return PopPage(
      title: tr('hadith', lang),
      subtitle: tr('hadithCount', lang, {'n': hadith.length}),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          for (final sh in shelves)
            if (sh.topics.any((t) => (count[t.id] ?? 0) > 0))
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _ShelfPanel(shelf: sh, count: count),
              ),
        ],
      ),
    );
  }
}

class _ShelfPanel extends StatelessWidget {
  final HadithShelf shelf;
  final Map<String, int> count;
  const _ShelfPanel({required this.shelf, required this.count});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final st = shelfStyle(_shelfOf(shelf.id));
    final ink = st.dark ? Colors.white : Pop.ink;
    final topics = shelf.topics.where((t) => (count[t.id] ?? 0) > 0).toList();
    final key = 'shelf.${shelf.id}';
    final title = tr(key, lang) == key ? topicTitle(state.bundle!, shelf.id, lang) : tr(key, lang);
    return InkPanel(
      color: st.color,
      halftone: true,
      dotColor: st.dark ? const Color(0x33FFFFFF) : const Color(0x381B1035),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(st.icon, color: ink, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(fontFamily: Pop.display, fontSize: 18, color: ink))),
            ],
          ),
          const SizedBox(height: 12),
          for (final t in topics)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: InkPanel(
                border: 3,
                shadow: 3,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                onTap: () => go(context, TopicScreen(topicId: t.id)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(topicTitle(state.bundle!, t.id, lang),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.25)),
                    ),
                    const SizedBox(width: 8),
                    Chip2('${count[t.id]}'),
                    const Icon(Icons.chevron_right_rounded, color: Pop.ink),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The hadith of one topic. Short ones are marked for learning by heart.
class TopicScreen extends StatelessWidget {
  final String topicId;
  const TopicScreen({super.key, required this.topicId});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final all = state.bundle!.hadith.where((h) => h.group == topicId);
    // Short ones first, otherwise HadeethEnc's order.
    final list = [...all.where((h) => h.isShort), ...all.where((h) => !h.isShort)];
    final st = groupStyle(topicId);
    return PopPage(
      title: topicTitle(state.bundle!, topicId, lang),
      subtitle: tr('hadithCount', lang, {'n': list.length}),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final h = list[i];
          return InkPanel(
            border: 3,
            shadow: 4,
            padding: const EdgeInsets.all(14),
            onTap: () => go(context, HadithScreen(hadith: h)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarTile(size: 34, glaze: Glaze.full, color: st.color, label: '${i + 1}', semanticsLabel: ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.t(lang).title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (h.isShort) Chip2(tr('shortHadith', lang), color: Pop.lemon),
                          for (final r in h.refs) Chip2(r.short, color: Pop.highlight),
                          if (h.refs.isEmpty) Chip2(h.t(lang).attribution),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
  bool _memorise = false;

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
    final ink = shelfStyle(_shelfOf(h.group)).dark ? Colors.white : Pop.ink;
    final bundle = AppScope.of(context).bundle!;

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
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 200),
                                    child: Text(topicTitle(bundle, h.group, lang),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                                  ),
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
                InkPanel(
                  border: 3,
                  shadow: 0,
                  padding: const EdgeInsets.all(14),
                  child: _memorise ? MemoriseView(arabic: h.quote) : QuotedArabic(h.arabic),
                ),
                if (h.isShort) ...[
                  const SizedBox(height: 12),
                  ComicButton(
                    label: _memorise ? tr('showAll', lang) : tr('memorise', lang),
                    icon: _memorise ? Icons.visibility_rounded : Icons.psychology_alt_rounded,
                    color: Pop.lemon,
                    onPressed: () => setState(() => _memorise = !_memorise),
                  ),
                ],
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
                  for (final r in hadith.refs) Chip2(r.full, color: Pop.highlight),
                  Text(t.attribution, style: const TextStyle(fontSize: 13, color: Pop.muted)),
                ],
              ),
              if (hadith.refs.isNotEmpty) SourceLabel('hadithRefs'),
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
