import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../progress.dart';
import '../recitation.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'missing_word_screen.dart';
import 'mushaf_screen.dart';
import 'order_game_screen.dart';

class SurahScreen extends StatefulWidget {
  final Surah surah;
  const SurahScreen({super.key, required this.surah});

  @override
  State<SurahScreen> createState() => _SurahScreenState();
}

class _SurahScreenState extends State<SurahScreen> {
  int savedCount = 0;
  (int, int)? saving;
  late AppState _state;
  Recitation? _rec;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context);
    final rec = _state.recitation;
    if (!identical(rec, _rec)) {
      _rec?.removeListener(_onRecitation);
      _rec = rec?..addListener(_onRecitation);
      _refreshSaved();
    }
  }

  @override
  void dispose() {
    // Recitation carries on after the screen closes (ADR 0002).
    _rec?.removeListener(_onRecitation);
    super.dispose();
  }

  void _onRecitation() {
    if (mounted) setState(() {});
  }

  /// Ayah index playing in this surah, or null.
  int? get playing {
    final r = _rec;
    return r != null && r.isPlaying(widget.surah) ? r.index : null;
  }

  /// True when reciting this surah to its end rather than one ayah.
  bool get playAll => playing != null && _rec!.toEnd;

  Future<void> _refreshSaved() async {
    final n = await _state.audio?.savedCount(widget.surah) ?? 0;
    if (mounted) setState(() => savedCount = n);
  }

  Future<void> _play(int i, {bool all = false}) async {
    final rec = _rec;
    if (rec == null) return;
    try {
      await rec.start(widget.surah, i, toEnd: all);
      unawaited(_refreshSaved());
    } catch (e) {
      debugPrint('Recitation failed to start: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('audioFailed', _state.lang))));
    }
  }

  Future<void> _stop() async => _rec?.stop();

  Future<void> _save() async {
    final audio = _state.audio;
    if (audio == null || saving != null) return;
    setState(() => saving = (savedCount, widget.surah.ayat.length));
    try {
      await audio.saveSurah(widget.surah, (n, total) {
        if (mounted) setState(() => saving = (n, total));
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('audioSaved', _state.lang))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('audioFailed', _state.lang))));
      }
    }
    if (!mounted) return;
    setState(() => saving = null);
    await _refreshSaved();
  }

  void _openGame() {
    final rounds = roundsFor(widget.surah.ayat.length);
    if (rounds.length == 1) {
      go(context, OrderGameScreen(surah: widget.surah, round: 0));
    } else {
      go(context, RoundPickerScreen(surah: widget.surah));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final s = widget.surah;
    final rounds = roundsFor(s.ayat.length);
    final done = state.progress.roundsDone(s);
    final allSaved = savedCount == s.ayat.length;
    final sv = saving;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(surah: s)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            sliver: SliverList.list(
              children: [
                if (state.audio != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ComicButton(
                          label: playAll ? tr('stop', lang) : tr('listenAll', lang),
                          icon: playAll ? Icons.stop_rounded : Icons.volume_up_rounded,
                          color: Pop.cyan,
                          onPressed: playAll ? _stop : () => _play(0, all: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkIconButton(
                        icon: allSaved ? Icons.download_done_rounded : Icons.download_rounded,
                        tooltip: allSaved ? tr('audioSaved', lang) : tr('saveAudio', lang),
                        color: allSaved ? Pop.lemon : Colors.white,
                        onPressed: allSaved ? null : _save,
                      ),
                    ],
                  ),
                  if (sv != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(tr('savingAudio', lang, {'n': sv.$1, 'total': sv.$2}),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 18),
                ],
                InkPanel(
                  color: Pop.lemon,
                  halftone: true,
                  dotColor: const Color(0x55FF3D8B),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(tr('roundsProgress', lang, {'n': done, 'total': rounds.length}),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ComicButton(label: tr('play', lang), icon: Icons.extension_rounded, onPressed: _openGame),
                      const SizedBox(height: 12),
                      ComicButton(
                        label: tr('missingWord', lang),
                        icon: Icons.search_rounded,
                        color: Pop.cyan,
                        onPressed: () => go(context, MissingWordScreen(surah: s)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (s.ayat.isNotEmpty && s.ayat.first.meaningFor(lang) != null)
                  SourceLabel(s.ayat.first.meaningFor(lang)!.source),
                if (state.audio != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${tr('recitation', lang)}: ${state.audio!.info.reciter}, ${state.audio!.info.publisher}',
                      style: const TextStyle(fontSize: 13, color: Pop.muted),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
            sliver: SliverList.builder(
              itemCount: s.ayat.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _AyahCard(
                  ayah: s.ayat[i],
                  playing: playing == i,
                  canPlay: state.audio != null && s.ayat[i].n != null,
                  onPlay: () => playing == i ? _stop() : _play(i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Surah surah;
  const _Header({required this.surah});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final next = state.progress.nextUp(state.bundle!.surahs);
    return SceneBands(
      height: 250,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: tr('back', lang),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  if (state.book != null) ...[
                    const SizedBox(width: 10),
                    InkIconButton(
                      icon: Icons.menu_book_rounded,
                      tooltip: tr('bookView', lang),
                      color: Pop.lemon,
                      onPressed: () => go(context, MushafScreen(initialPage: state.book!.firstPageOf(surah.number))),
                    ),
                  ],
                  const Spacer(),
                  StarTile(
                    size: 72,
                    glaze: state.progress.glazeOf(surah, next: next),
                    color: Pop.glazeFor(surah.number),
                    label: '${surah.number}',
                    semanticsLabel: tr('surahNumber', lang, {'n': surah.number}),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Caption(tr('ayat', lang, {'n': surah.ayat.length}), color: Colors.white),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: MisprintText(surah.name, size: 38, color: Colors.white, heavyShadow: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Text(surah.nameAr,
                        style: const TextStyle(fontFamily: Pop.quran, fontSize: 30, height: 1.3, color: Pop.ink)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  final Ayah ayah;
  final bool playing;
  final bool canPlay;
  final VoidCallback onPlay;
  const _AyahCard({required this.ayah, required this.playing, required this.canPlay, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final m = ayah.meaningFor(lang);
    return InkPanel(
      border: 3,
      shadow: 0,
      color: playing ? Pop.highlight : Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              StarTile(
                size: 42,
                glaze: Glaze.full,
                color: Pop.lemon,
                label: '${ayah.aya}',
                semanticsLabel: ayah.key,
              ),
              const Spacer(),
              if (canPlay)
                InkIconButton(
                  icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  tooltip: tr('listen', lang, {'n': ayah.aya}),
                  color: Pop.cyan,
                  onPressed: onPlay,
                ),
            ],
          ),
          ArabicText(ayah.arabic),
          if (m != null) ...[
            const SizedBox(height: 4),
            Text(m.text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, height: 1.5)),
            if (m.footnotes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(m.footnotes, style: const TextStyle(fontSize: 13, color: Pop.muted, height: 1.4)),
              ),
          ],
        ],
      ),
    );
  }
}
