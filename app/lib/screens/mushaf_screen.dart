import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../mushaf.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';

/// Warm page colours for reading: calmer than the comic screens.
abstract final class BookColors {
  static const paper = Color(0xFFFFFBEF);
  static const desk = Color(0xFFF3E9D2);
  static const rule = Color(0xFF7A3CFF);
}

/// The whole Quran as Madina mushaf pages, Arabic only, swiped right to left
/// like a printed book.
class MushafScreen extends StatefulWidget {
  final int initialPage;
  final String? selectKey;
  const MushafScreen({super.key, this.initialPage = 1, this.selectKey});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  late final PageController _pc = PageController(initialPage: widget.initialPage - 1);
  late int _page = widget.initialPage;
  String? _selected;
  String? _playing;
  StreamSubscription<void>? _done;
  late AppState _state;

  @override
  void initState() {
    super.initState();
    _selected = widget.selectKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).markActive();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context);
    _done ??= _state.audio?.onComplete.listen((_) => _next());
  }

  @override
  void dispose() {
    _done?.cancel();
    if (_playing != null) _state.audio?.stop();
    _pc.dispose();
    super.dispose();
  }

  (Surah, Ayah)? _find(String key) {
    final parts = key.split(':');
    final s = int.tryParse(parts.first);
    final a = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (s == null || a == null) return null;
    final surah = _state.bundle!.surahs.firstWhere((x) => x.number == s);
    return a >= 1 && a <= surah.ayat.length ? (surah, surah.ayat[a - 1]) : null;
  }

  Future<void> _play(String key) async {
    final audio = _state.audio;
    final found = _find(key);
    if (audio == null || found == null) return;
    setState(() => _playing = key);
    final page = _state.book!.pageOf(key);
    if (page != _page) unawaited(_pc.animateToPage(page - 1, duration: const Duration(milliseconds: 350), curve: Curves.easeOut));
    try {
      await audio.play(found.$2);
    } catch (_) {
      if (!mounted) return;
      setState(() => _playing = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('audioFailed', _state.lang))));
    }
  }

  /// Keeps reciting to the end of the surah, turning pages as it goes.
  void _next() {
    final key = _playing;
    if (key == null || !mounted) return;
    final found = _find(key);
    if (found == null) return;
    final (surah, ayah) = found;
    if (ayah.aya < surah.ayat.length) {
      _play('${surah.number}:${ayah.aya + 1}');
    } else {
      setState(() => _playing = null);
    }
  }

  Future<void> _stop() async {
    await _state.audio?.stop();
    if (mounted) setState(() => _playing = null);
  }

  void _playFromHere() {
    final start = _selected ?? _state.book!.page(_page).ayat.firstOrNull?.key;
    if (start != null) _play(start);
  }

  Future<void> _jump() async {
    final lang = _state.lang;
    final surahs = _state.bundle!.surahs;
    final book = _state.book!;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: BookColors.paper,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(tr('jumpToSurah', lang), style: const TextStyle(fontFamily: Pop.display, fontSize: 17)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: surahs.length,
                  itemBuilder: (context, i) {
                    final s = surahs[i];
                    return ListTile(
                      leading: StarTile(size: 34, glaze: Glaze.full, color: Pop.glazeFor(s.number), label: '${s.number}', semanticsLabel: ''),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(tr('pageN', lang, {'n': book.firstPageOf(s.number)})),
                      trailing: Text(s.nameAr, style: const TextStyle(fontFamily: Pop.quran, fontSize: 20)),
                      onTap: () => Navigator.of(context).pop(book.firstPageOf(s.number)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selected = null);
      _pc.jumpToPage(picked - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final book = state.book;
    if (book == null) {
      return Scaffold(body: Center(child: Text(tr('loadError', lang))));
    }
    final current = book.page(_page);
    final selected = _selected == null ? null : _find(_selected!);
    final canPlay = state.audio != null;

    return Scaffold(
      backgroundColor: BookColors.desk,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  InkIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: tr('back', lang),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(current.surah?.name ?? '',
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: Pop.display, fontSize: 17, height: 1.1)),
                        Text(tr('pageN', lang, {'n': _page}), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  InkIconButton(icon: Icons.format_list_numbered_rounded, tooltip: tr('jumpToSurah', lang), onPressed: _jump),
                  if (canPlay) ...[
                    const SizedBox(width: 8),
                    InkIconButton(
                      icon: _playing == null ? Icons.play_arrow_rounded : Icons.stop_rounded,
                      tooltip: _playing == null ? tr('playFromHere', lang) : tr('stop', lang),
                      color: Pop.cyan,
                      onPressed: _playing == null ? _playFromHere : _stop,
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PageView.builder(
                controller: _pc,
                reverse: true, // next page comes in from the left, as in a printed mushaf
                itemCount: book.pageCount,
                onPageChanged: (i) => setState(() {
                  _page = i + 1;
                  state.setLastPage(_page);
                  if (_selected != null && book.pageOf(_selected!) != _page) _selected = null;
                }),
                itemBuilder: (context, i) => MushafPageView(
                  page: book.page(i + 1),
                  basmala: state.bundle!.surahs.first.ayat.first.arabic,
                  highlight: _playing ?? _selected,
                  onTapAyah: (key) => setState(() => _selected = _selected == key ? null : key),
                ),
                    ),
                  ),
                  if (selected != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _AyahPanel(
                        surah: selected.$1,
                        ayah: selected.$2,
                        playing: _playing == selected.$2.key,
                        canPlay: canPlay,
                        onPlay: () => _playing == selected.$2.key ? _stop() : _play(selected.$2.key),
                        onClose: () => setState(() => _selected = null),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One mushaf page: a framed sheet with its lines justified edge to edge.
class MushafPageView extends StatefulWidget {
  final MushafPage page;
  final String basmala;
  final String? highlight;
  final void Function(String ayahKey) onTapAyah;
  const MushafPageView({super.key, required this.page, required this.basmala, this.highlight, required this.onTapAyah});

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView> {
  final Map<String, TapGestureRecognizer> _taps = {};

  TapGestureRecognizer _tap(String key) =>
      _taps.putIfAbsent(key, () => TapGestureRecognizer()..onTap = () => widget.onTapAyah(key));

  @override
  void didUpdateWidget(MushafPageView old) {
    super.didUpdateWidget(old);
    if (old.onTapAyah != widget.onTapAyah) {
      for (final e in _taps.entries) {
        e.value.onTap = () => widget.onTapAyah(e.key);
      }
    }
  }

  @override
  void dispose() {
    for (final t in _taps.values) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: BookColors.paper,
                border: Border.all(color: Pop.ink, width: 2.5),
                boxShadow: const [BoxShadow(color: Pop.ink, offset: Offset(4, 4))],
              ),
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: BookColors.rule, width: 1.2)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: LayoutBuilder(builder: (context, c) => _lines(c.maxWidth, c.maxHeight)),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(arabicDigits(page.number), style: const TextStyle(fontFamily: Pop.quran, fontSize: 16, height: 1.2)),
        ],
      ),
    );
  }

  Widget _lines(double width, double height) {
    final page = widget.page;
    final opening = page.lines.length < 15; // al-Fatiha and the start of al-Baqarah
    final lineH = height / 15;
    final style = TextStyle(fontFamily: Pop.quran, fontSize: lineH * 0.5, height: 1.0, color: Pop.ink);

    // One font size for the whole page: the base size, made smaller only
    // if the longest line would not fit.
    var fontSize = style.fontSize!;
    for (final line in page.lines.where((l) => l.isWords)) {
      final w = _naturalWidth(line, style.copyWith(fontSize: fontSize), fontSize);
      if (w > width) fontSize = fontSize * width / w;
    }
    final pageStyle = style.copyWith(fontSize: fontSize);

    final children = [for (final line in page.lines) SizedBox(height: lineH, child: _line(line, pageStyle, width, justify: !opening))];
    return Column(
      mainAxisAlignment: opening ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: children,
    );
  }

  double _markerSize(double fontSize) => fontSize * 1.15;

  /// Spans for a line of words. [build] adds tap and highlight.
  (InlineSpan, int markers) _spans(MushafLine line, TextStyle style, {bool build = false}) {
    final spans = <InlineSpan>[];
    var markers = 0;
    for (var i = 0; i < line.parts.length; i++) {
      final p = line.parts[i] as AyahWords;
      if (i > 0) spans.add(const TextSpan(text: ' '));
      final lit = build && widget.highlight == p.ayah.key;
      spans.add(TextSpan(
        text: p.text,
        style: lit ? style.copyWith(background: Paint()..color = Pop.highlight) : null,
        recognizer: build ? _tap(p.ayah.key) : null,
      ));
      if (p.endsAyah) {
        spans.add(const TextSpan(text: ' '));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: AyahMarker(number: p.ayah.aya, size: _markerSize(style.fontSize!), lit: lit),
        ));
        markers++;
      }
    }
    return (TextSpan(style: style, children: spans), markers);
  }

  double _naturalWidth(MushafLine line, TextStyle style, double fontSize, {double wordSpacing = 0}) {
    final (span, markers) = _spans(line, style.copyWith(wordSpacing: wordSpacing));
    final tp = TextPainter(text: span, textDirection: TextDirection.rtl, maxLines: 1);
    final m = _markerSize(fontSize);
    tp.setPlaceholderDimensions(List.filled(
        markers, PlaceholderDimensions(size: Size(m, m), alignment: PlaceholderAlignment.middle)));
    tp.layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  Widget _line(MushafLine line, TextStyle style, double width, {required bool justify}) {
    if (line.isEmpty) return const SizedBox.shrink();
    final first = line.parts.first;
    if (first is SurahHeader) return _SurahBand(surah: first.surah, fontSize: style.fontSize!);
    if (first is Basmala) {
      return Center(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Text(widget.basmala, maxLines: 1, style: style),
        ),
      );
    }

    final fs = style.fontSize!;
    var spacing = 0.0;
    var align = TextAlign.center;
    if (justify) {
      final natural = _naturalWidth(line, style, fs);
      final text = line.parts.map((p) => p is AyahWords ? p.text : '').join(' ');
      // Spaces inside and between the ayah pieces, plus one before each marker.
      final gaps = ' '.allMatches(text).length + line.parts.where((p) => p is AyahWords && p.endsAyah).length;
      if (gaps > 0 && natural < width) {
        final extra = (width - natural - 1) / gaps;
        // A very short line (rare) is set to the right instead of stretched.
        if (extra <= fs * 2.5) {
          spacing = extra;
        } else {
          align = TextAlign.right;
        }
      }
    }
    final (span, _) = _spans(line, style.copyWith(wordSpacing: spacing), build: true);
    return Align(
      alignment: Alignment.center,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          width: width,
          child: RichText(
            text: span,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
            textAlign: align,
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }
}

/// The band that opens each surah: its name between two mosaic stars.
class _SurahBand extends StatelessWidget {
  final Surah surah;
  final double fontSize;
  const _SurahBand({required this.surah, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final star = fontSize * 1.2;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: fontSize * 0.12),
      child: Container(
        decoration: BoxDecoration(
          color: Pop.lemon,
          border: Border.all(color: Pop.ink, width: 2),
          borderRadius: BorderRadius.circular(fontSize * 0.5),
        ),
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.4),
        child: Row(
          children: [
            StarTile(size: star, glaze: Glaze.full, color: Pop.glazeFor(surah.number), semanticsLabel: ''),
            Expanded(
              child: Center(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('سُورَةُ ${surah.nameAr}',
                        style: TextStyle(fontFamily: Pop.quran, fontSize: fontSize * 0.95, height: 1.0, color: Pop.ink)),
                  ),
                ),
              ),
            ),
            StarTile(size: star, glaze: Glaze.full, color: Pop.glazeFor(surah.number + 1), semanticsLabel: ''),
          ],
        ),
      ),
    );
  }
}

/// The ayah number in a small eight-point star.
class AyahMarker extends StatelessWidget {
  final int number;
  final double size;
  final bool lit;
  const AyahMarker({super.key, required this.number, required this.size, this.lit = false});

  @override
  Widget build(BuildContext context) {
    final digits = arabicDigits(number);
    return Semantics(
      label: 'Ayah $number',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _MarkerPainter(lit),
          child: Center(
            child: Text(
              digits,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: Pop.quran,
                fontSize: size * (digits.length >= 3 ? 0.36 : 0.46),
                height: 1.0,
                color: Pop.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final bool lit;
  const _MarkerPainter(this.lit);

  @override
  void paint(Canvas canvas, Size size) {
    final path = starPath(size, inset: math.max(0.6, size.shortestSide * 0.04));
    canvas.drawPath(path, Paint()..color = lit ? Pop.lemon : BookColors.paper);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.shortestSide * 0.06)
        ..color = BookColors.rule,
    );
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.lit != lit;
}

class _AyahPanel extends StatelessWidget {
  final Surah surah;
  final Ayah ayah;
  final bool playing;
  final bool canPlay;
  final VoidCallback onPlay;
  final VoidCallback onClose;
  const _AyahPanel({
    required this.surah,
    required this.ayah,
    required this.playing,
    required this.canPlay,
    required this.onPlay,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final m = ayah.meaningFor(lang);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.34),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Pop.ink, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Caption('${surah.name} ${ayah.key}'),
                const Spacer(),
                if (canPlay && ayah.n != null)
                  InkIconButton(
                    icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    tooltip: playing ? tr('stop', lang) : tr('listen', lang, {'n': ayah.aya}),
                    color: Pop.cyan,
                    onPressed: onPlay,
                  ),
                const SizedBox(width: 8),
                InkIconButton(icon: Icons.close_rounded, tooltip: tr('close', lang), onPressed: onClose),
              ],
            ),
            if (m != null)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(m.text, style: const TextStyle(fontSize: 16, height: 1.45)),
                      SourceLabel(m.source),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
