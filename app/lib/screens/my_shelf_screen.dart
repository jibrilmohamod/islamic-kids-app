import 'package:flutter/material.dart';

import '../app_state.dart';
import '../arch.dart';
import '../local_store.dart';
import '../models.dart';
import '../pop_icons.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'downloads_screen.dart';
import 'dua_screen.dart';
import 'duas_screen.dart';
import 'hadith_screen.dart';
import 'home_screen.dart' show homeDuaTitle;
import 'mushaf_screen.dart';
import 'surah_screen.dart';

/// What the child keeps and where they were (canvas row F): carry on
/// reading or listening, bookmarked ayat, favourite duas and hadith, and the
/// surahs saved for offline listening.
class MyShelfScreen extends StatelessWidget {
  const MyShelfScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final bundle = state.bundle!;
    final surahs = {for (final s in bundle.surahs) s.number: s};

    HistoryEntry? last(HistoryKind k) => state.history.where((e) => e.kind == k && surahs.containsKey(e.surah)).firstOrNull;
    final read = last(HistoryKind.read);
    final listen = last(HistoryKind.listen);
    final marks = [
      for (final k in state.bookmarks)
        if (_ayahFor(surahs, k) case final found?) found,
    ];
    final favDuas = [for (final d in bundle.duas) if (state.isFavourite('dua:${d.id}')) d];
    final favHadith = [for (final h in bundle.hadith) if (state.isFavourite(favouriteId(h))) h];
    // Favourite ayat in Quran order.
    final favAyat = [
      for (final id in state.favourites)
        if (id.startsWith('ayah:'))
          if (_ayahFor(surahs, id.substring(5)) case final found?) found,
    ]..sort((x, y) => x.$1.number != y.$1.number ? x.$1.number - y.$1.number : x.$2.aya - y.$2.aya);
    final empty =
        read == null && listen == null && marks.isEmpty && favDuas.isEmpty && favHadith.isEmpty && favAyat.isEmpty;

    var n = 0;
    Widget enter(Widget child) => Entrance(index: n++, child: child);

    return PopPage(
      bandTop: Pop.lemon,
      bandBottom: Pop.cyan,
      title: tr('myShelf', lang),
      subtitle: tr('myShelfSub', lang),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          if (empty) enter(_Empty(lang: lang)),
          if (read != null || listen != null) ...[
            _Heading(tr('carryOn', lang)),
            enter(Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (read != null)
                  Expanded(
                    child: _CarryOn(
                      glaze: Pop.cyan,
                      tilt: -1,
                      icon: PopIcon.quran,
                      kind: tr('reading', lang),
                      title: surahs[read.surah]!.name,
                      detail: _readDetail(state, read, lang),
                      onTap: () => _openRead(context, state, read),
                    ),
                  ),
                if (read != null && listen != null) const SizedBox(width: 12),
                if (listen != null)
                  Expanded(
                    child: _CarryOn(
                      glaze: Pop.violet,
                      tilt: 1,
                      icon: PopIcon.downloads,
                      kind: tr('listening', lang),
                      title: surahs[listen.surah]!.name,
                      detail: tr('ayahOf', lang, {'n': listen.ayah + 1, 'total': surahs[listen.surah]!.ayat.length}),
                      onTap: () => go(context, SurahScreen(surah: surahs[listen.surah]!)),
                    ),
                  ),
              ],
            )),
          ],
          if (marks.isNotEmpty) ...[
            _Heading(tr('bookmarks', lang)),
            enter(Wrap(
              spacing: 8,
              runSpacing: 10,
              children: [
                for (final (i, (s, a)) in marks.indexed)
                  GlazeCard(
                    glaze: [Pop.lemon, Pop.cyan, Pop.pink][i % 3],
                    border: 3,
                    shadow: 3,
                    padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
                    onTap: () => _openAyah(context, state, s, a),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PopIconView(i % 3 == 2 ? PopIcon.bookmarkOff : PopIcon.bookmarkOn, size: 22, shadow: false),
                        const SizedBox(width: 6),
                        // Long names wrap inside the chip at large text sizes.
                        Flexible(child: Text('${s.name} ${a.key}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                      ],
                    ),
                  ),
              ],
            )),
          ],
          if (favAyat.isNotEmpty || favDuas.isNotEmpty || favHadith.isNotEmpty) ...[
            _Heading(tr('favourites', lang)),
            for (final (s, a) in favAyat)
              enter(_Favourite(
                glaze: Pop.cyan,
                kind: '${tr('ayahKind', lang)} · ${s.name} ${a.key}',
                title: a.meaningFor(lang)?.text ?? a.arabic,
                onTap: () => _openAyah(context, state, s, a),
              )),
            for (final (i, h) in favHadith.indexed)
              enter(_Favourite(
                glaze: i.isEven ? Pop.pink : Pop.lemon,
                kind: '${tr('hadith', lang)} · ${topicTitle(bundle, h.group, lang)}',
                title: h.t(lang).title,
                onTap: () => go(context, HadithScreen(hadith: h)),
              )),
            for (final (i, d) in favDuas.indexed)
              enter(_Favourite(
                glaze: (favHadith.length + i).isEven ? Pop.pink : Pop.lemon,
                kind: tr('dua', lang),
                title: homeDuaTitle(d, bundle, lang),
                onTap: () => go(context, DuaScreen(duas: [d], index: 0, stop: stopFor(d, state.now()))),
              )),
          ],
          if (state.audio != null) ...[
            const SizedBox(height: 10),
            enter(GlazeCard(
              glaze: Pop.violet,
              shadow: 5,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              onTap: () => go(context, const DownloadsScreen()),
              child: Row(
                children: [
                  const PopIconView(PopIcon.downloads, size: 34),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tr('downloads', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 15))),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  static (Surah, Ayah)? _ayahFor(Map<int, Surah> surahs, String key) {
    final parts = key.split(':');
    if (parts.length != 2) return null;
    final s = surahs[int.tryParse(parts[0])];
    final a = int.tryParse(parts[1]);
    if (s == null || a == null || a < 1 || a > s.ayat.length) return null;
    return (s, s.ayat[a - 1]);
  }

  static String _readDetail(AppState state, HistoryEntry e, String lang) {
    final book = state.book;
    if (book == null) return tr('ayahOf', lang, {'n': e.ayah + 1, 'total': state.bundle!.surahs.firstWhere((s) => s.number == e.surah).ayat.length});
    return tr('pageN', lang, {'n': book.pageOf('${e.surah}:${e.ayah + 1}')});
  }

  static void _openRead(BuildContext context, AppState state, HistoryEntry e) {
    final book = state.book;
    final s = state.bundle!.surahs.firstWhere((x) => x.number == e.surah);
    if (book == null) {
      go(context, SurahScreen(surah: s));
    } else {
      go(context, MushafScreen(initialPage: book.pageOf('${e.surah}:${e.ayah + 1}')));
    }
  }

  static void _openAyah(BuildContext context, AppState state, Surah s, Ayah a) {
    final book = state.book;
    if (book == null) {
      go(context, SurahScreen(surah: s));
    } else {
      go(context, MushafScreen(initialPage: book.pageOf(a.key), selectKey: a.key));
    }
  }
}

class _Heading extends StatelessWidget {
  final String text;
  const _Heading(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Semantics(
          header: true,
          child: Align(alignment: AlignmentDirectional.centerStart, child: StickerTab(text)),
        ),
      );
}

class _CarryOn extends StatelessWidget {
  final Color glaze;
  final double tilt;
  final PopIcon icon;
  final String kind;
  final String title;
  final String detail;
  final VoidCallback onTap;
  const _CarryOn({
    required this.glaze,
    required this.tilt,
    required this.icon,
    required this.kind,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GlazeCard(
        glaze: glaze,
        tab: kind,
        tabColor: glaze == Pop.violet ? Pop.lemon : Colors.white,
        tilt: tilt,
        shadow: 5,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        semanticsLabel: '$kind: $title, $detail',
        onTap: onTap,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PopIconView(icon, size: 34),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontFamily: Pop.display, fontSize: 16, height: 1.1)),
              Text(detail, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _Favourite extends StatelessWidget {
  final Color glaze;
  final String kind;
  final String title;
  final VoidCallback onTap;
  const _Favourite({required this.glaze, required this.kind, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlazeCard(
          glaze: glaze,
          shadow: 5,
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          onTap: onTap,
          child: Row(
            children: [
              PopIconView(glaze == Pop.pink ? PopIcon.heartOff : PopIcon.heartOn, size: 30, shadow: false),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(kind, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, height: 1.25)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  final String lang;
  const _Empty({required this.lang});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            const PopIconView(PopIcon.shelf, size: 96),
            const SizedBox(height: 16),
            Text(tr('shelfEmpty', lang),
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4)),
          ],
        ),
      );
}
