import 'package:flutter/material.dart';

import '../app_state.dart';
import '../arch.dart';
import '../models.dart';
import '../pop_icons.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'dua_screen.dart' show MemoriseView;

/// Colour and icon per shelf. Topic ids start with their shelf id. Icons
/// are objects only (canvas row F): no people.
({Color color, PopIcon icon, bool dark}) shelfStyle(String id) => switch (id) {
      'manners' => (color: Pop.cyan, icon: PopIcon.shelfManners, dark: false),
      'character' => (color: Pop.lemon, icon: PopIcon.shelfCharacter, dark: false),
      'family' => (color: Pop.pink, icon: PopIcon.shelfFamily, dark: false),
      'prophet' => (color: Pop.violet, icon: PopIcon.shelfProphet, dark: true),
      'worship' => (color: Pop.cyan, icon: PopIcon.shelfWorship, dark: false),
      'learning' => (color: Pop.lemon, icon: PopIcon.shelfLearning, dark: false),
      _ => (color: Pop.pink, icon: PopIcon.hadith, dark: false),
    };

/// Older bundles name topics without shelves.
({Color color, PopIcon icon}) groupStyle(String group) {
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

String shelfTitle(ContentBundle bundle, String shelfId, String lang) {
  final key = 'shelf.$shelfId';
  return tr(key, lang) == key ? topicTitle(bundle, shelfId, lang) : tr(key, lang);
}

Map<String, int> _countByTopic(List<Hadith> hadith) {
  final count = <String, int>{};
  for (final h in hadith) {
    count[h.group] = (count[h.group] ?? 0) + 1;
  }
  return count;
}

/// Hadith by shelf, as niches in the wall (canvas row F): Good manners, Good
/// character, Family and kindness... Each shelf opens into its topics.
class HadithListScreen extends StatelessWidget {
  const HadithListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle!;
    final hadith = bundle.hadith;
    final count = _countByTopic(hadith);
    // Shelves from the bundle, or one shelf per old group.
    final shelves = (bundle.shelves.isNotEmpty
            ? bundle.shelves
            : [
                for (final g in {for (final h in hadith) h.group})
                  HadithShelf(id: g, topics: [HadithTopic(id: g, title: const {})]),
              ])
        .where((sh) => sh.topics.any((t) => (count[t.id] ?? 0) > 0))
        .toList();
    final short = hadith.where((h) => h.isShort).length;

    return PopPage(
      title: tr('hadith', lang),
      subtitle: tr('hadithSubtitle', lang),
      body: LayoutBuilder(builder: (context, c) {
        const gap = 14.0;
        const pad = 18.0;
        final w = ((c.maxWidth - 2 * pad - gap) / 2 - 4).floorToDouble();
        final band = MediaQuery.textScalerOf(context).scale(16) * 2.3 + MediaQuery.textScalerOf(context).scale(14) * 1.4 + 10;
        final h = w * 0.72 + band;
        return ListView(
          padding: const EdgeInsets.fromLTRB(pad, 8, pad, 32),
          children: [
            Wrap(
              spacing: gap,
              runSpacing: gap + 4,
              children: [
                for (var i = 0; i < shelves.length; i++)
                  Entrance(
                    index: i,
                    pop: true,
                    child: ArchNiche(
                      icon: shelfStyle(_shelfOf(shelves[i].id)).icon,
                      glaze: shelfStyle(_shelfOf(shelves[i].id)).color,
                      label: shelfTitle(bundle, shelves[i].id, lang),
                      sublabel: tr('topicsCount', lang, {
                        'n': shelves[i].topics.where((t) => (count[t.id] ?? 0) > 0).length,
                      }),
                      width: w,
                      height: h,
                      band: band,
                      onTap: () => go(context, ShelfScreen(shelf: shelves[i])),
                    ),
                  ),
              ],
            ),
            if (short > 0) ...[
              const SizedBox(height: 22),
              Entrance(
                index: shelves.length,
                child: GlazeCard(
                  glaze: Pop.pink,
                  tab: tr('shortHadithTitle', lang),
                  tabColor: Pop.lemon,
                  tilt: 1,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  onTap: () => go(context, const TopicScreen(topicId: TopicScreen.shortOnes)),
                  child: Row(
                    children: [
                      const PopIconView(PopIcon.week, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(tr('shortHadithSub', lang, {'n': short}),
                            style: const TextStyle(fontFamily: Pop.display, fontSize: 15, height: 1.2)),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Pop.ink, size: 30),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}

/// One shelf's topics.
class ShelfScreen extends StatelessWidget {
  final HadithShelf shelf;
  const ShelfScreen({super.key, required this.shelf});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle!;
    final count = _countByTopic(bundle.hadith);
    final topics = shelf.topics.where((t) => (count[t.id] ?? 0) > 0).toList();
    final st = shelfStyle(_shelfOf(shelf.id));
    return PopPage(
      bandTop: st.color,
      bandBottom: st.color == Pop.violet ? Pop.pink : Pop.violet,
      title: shelfTitle(bundle, shelf.id, lang),
      subtitle: tr('topicsCount', lang, {'n': topics.length}),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        itemCount: topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => Entrance(
          index: i,
          child: GlazeCard(
            glaze: Pop.cardGlaze(i),
            shadow: 5,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            onTap: () => go(context, TopicScreen(topicId: topics[i].id)),
            child: Row(
              children: [
                PopIconView(st.icon, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(topicTitle(bundle, topics[i].id, lang),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.25)),
                ),
                const SizedBox(width: 8),
                Chip2(tr('hadithCount', lang, {'n': count[topics[i].id] ?? 0}), color: Colors.white),
                Icon(Icons.chevron_right_rounded, color: Pop.onGlaze(Pop.cardGlaze(i))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The hadith of one topic. Short ones are marked for learning by heart.
class TopicScreen extends StatelessWidget {
  /// A HadeethEnc topic id, or [shortOnes] for every short hadith.
  final String topicId;
  const TopicScreen({super.key, required this.topicId});

  static const shortOnes = '_short';

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle!;
    final shortOnly = topicId == shortOnes;
    final all = bundle.hadith.where((h) => shortOnly ? h.isShort : h.group == topicId);
    // Short ones first, otherwise HadeethEnc's order.
    final list = [...all.where((h) => h.isShort), ...all.where((h) => !h.isShort)];
    final band = shortOnly ? Pop.pink : groupStyle(topicId).color;
    return PopPage(
      bandTop: band,
      bandBottom: band == Pop.violet ? Pop.pink : Pop.violet,
      title: shortOnly ? tr('shortHadithTitle', lang) : topicTitle(bundle, topicId, lang),
      subtitle: tr('hadithCount', lang, {'n': list.length}),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final h = list[i];
          final fav = state.isFavourite(favouriteId(h));
          return Entrance(
            index: i.clamp(0, 6),
            child: GlazeCard(
              glaze: Pop.cardGlaze(i),
              tab: h.isShort ? tr('shortHadith', lang) : null,
              tabColor: Pop.cardGlaze(i) == Pop.lemon ? Colors.white : Pop.lemon,
              tilt: i == 0 ? -1 : 0,
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
              onTap: () => go(context, HadithScreen(hadith: h)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarTile(size: 34, glaze: Glaze.full, color: Colors.white, label: '${i + 1}', semanticsLabel: ''),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.t(lang).title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.3)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final r in h.refs) Chip2(r.short, color: Colors.white),
                            if (h.refs.isEmpty) Chip2(h.t(lang).attribution, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ToggleIconButton(
                    on: fav,
                    onIcon: PopIcon.heartOn,
                    offIcon: PopIcon.heartOff,
                    tooltip: tr(fav ? 'removeFavourite' : 'addFavourite', lang),
                    onPressed: () => state.toggleFavourite(favouriteId(h)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The favourites key for a hadith (see LocalStore).
String favouriteId(Hadith h) => 'hadith:${h.id}';

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
    final state = AppScope.of(context);
    final lang = state.lang;
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
                            ToggleIconButton(
                              on: state.isFavourite(favouriteId(h)),
                              onIcon: PopIcon.heartOn,
                              offIcon: PopIcon.heartOff,
                              tooltip: tr(state.isFavourite(favouriteId(h)) ? 'removeFavourite' : 'addFavourite', lang),
                              onPressed: () => state.toggleFavourite(favouriteId(h)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Pop.ink, width: 3)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  PopIconView(style.icon, size: 20, shadow: false),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 170),
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
            // ExpansionTile's ListTile needs its own Material inside a coloured
            // panel, or Flutter reports its ink as hidden behind the panel.
            child: Material(
              type: MaterialType.transparency,
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
          ),
        ],
      ],
    );
  }
}
