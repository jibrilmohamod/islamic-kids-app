import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../recitation.dart';
import '../strings.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'surah_screen.dart';

/// How much of a surah is saved on the phone.
class SavedSurah {
  final Surah surah;
  final int saved;
  final int bytes;
  const SavedSurah(this.surah, this.saved, this.bytes);

  bool get complete => saved == surah.ayat.length;
}

/// Groups saved ayah files by surah. Surahs with nothing saved are left out.
List<SavedSurah> savedSurahs(List<Surah> surahs, Map<int, int> files) {
  final out = <SavedSurah>[];
  for (final s in surahs) {
    var n = 0;
    var bytes = 0;
    for (final a in s.ayat) {
      final size = a.n == null ? null : files[a.n];
      if (size != null) {
        n++;
        bytes += size;
      }
    }
    if (n > 0) out.add(SavedSurah(s, n, bytes));
  }
  return out;
}

String megabytes(int bytes) {
  final mb = bytes / (1024 * 1024);
  return mb < 10 ? mb.toStringAsFixed(1) : mb.round().toString();
}

/// Surahs saved for offline listening: play them without internet, finish
/// half-saved ones, or free up space.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<SavedSurah>? _list;
  final Map<int, (int, int)> _saving = {};
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
    }
    if (_list == null && _state.audio != null) _refresh();
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

  /// (surah number, ayah index) being recited, or null.
  (int, int)? get _playing {
    final s = _rec?.surah;
    return s == null ? null : (s.number, _rec!.index);
  }

  Future<void> _refresh() async {
    final files = await _state.audio!.savedFiles();
    if (!mounted) return;
    setState(() => _list = savedSurahs(_state.bundle!.surahs, files));
  }

  Surah _surah(int number) => _state.bundle!.surahs.firstWhere((s) => s.number == number);

  Future<void> _play(int surah, int index) async {
    try {
      await _rec?.start(_surah(surah), index);
    } catch (e) {
      debugPrint('Recitation failed to start: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('audioFailed', _state.lang))));
    }
  }

  Future<void> _stop() async => _rec?.stop();

  Future<void> _finish(Surah s) async {
    if (_saving.containsKey(s.number)) return;
    setState(() => _saving[s.number] = (0, s.ayat.length));
    try {
      await _state.audio!.saveSurah(s, (n, total) {
        if (mounted) setState(() => _saving[s.number] = (n, total));
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('audioFailed', _state.lang))));
      }
    }
    if (!mounted) return;
    setState(() => _saving.remove(s.number));
    await _refresh();
  }

  Future<void> _delete(Surah s) async {
    final lang = _state.lang;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('deleteAudioQ', lang, {'name': s.name})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('cancel', lang))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(tr('deleteAudio', lang))),
        ],
      ),
    );
    if (ok != true) return;
    if (_playing?.$1 == s.number) await _stop();
    await _state.audio!.deleteSurah(s);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final lang = state.lang;
    final list = _list;
    final total = list?.fold<int>(0, (t, x) => t + x.bytes) ?? 0;

    return PopPage(
      title: tr('downloads', lang),
      subtitle: list == null || list.isEmpty ? null : tr('downloadsSize', lang, {'n': list.length, 'mb': megabytes(total)}),
      body: state.audio == null
          ? Center(child: Text(tr('loadError', lang)))
          : list == null
              ? const Center(child: CircularProgressIndicator(color: Pop.ink))
              : list.isEmpty
                  ? _Empty(lang: lang)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final x = list[i];
                        final s = x.surah;
                        final playingHere = _playing?.$1 == s.number;
                        final sv = _saving[s.number];
                        return InkPanel(
                          border: 3,
                          shadow: 4,
                          color: playingHere ? Pop.highlight : Colors.white,
                          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                          onTap: () => go(context, SurahScreen(surah: s)),
                          child: Row(
                            children: [
                              StarTile(
                                size: 44,
                                glaze: x.complete ? Glaze.full : Glaze.partial,
                                color: Pop.glazeFor(s.number),
                                label: '${s.number}',
                                semanticsLabel: s.name,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: const TextStyle(fontFamily: Pop.display, fontSize: 15)),
                                    Text(
                                      sv != null
                                          ? tr('savingAudio', lang, {'n': sv.$1, 'total': sv.$2})
                                          : x.complete
                                              ? tr('readyOffline', lang, {'mb': megabytes(x.bytes)})
                                              : tr('partlySaved', lang, {'n': x.saved, 'total': s.ayat.length}),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Pop.muted),
                                    ),
                                    if (playingHere)
                                      Text(tr('nowPlaying', lang, {'n': _playing!.$2 + 1}),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                              if (!x.complete && sv == null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkIconButton(
                                    icon: Icons.download_rounded,
                                    tooltip: tr('finishSaving', lang),
                                    onPressed: () => _finish(s),
                                  ),
                                ),
                              if (x.complete)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkIconButton(
                                    icon: playingHere ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                    tooltip: playingHere ? tr('stop', lang) : tr('listenAll', lang),
                                    color: Pop.cyan,
                                    onPressed: playingHere ? _stop : () => _play(s.number, 0),
                                  ),
                                ),
                              InkIconButton(
                                icon: Icons.delete_outline_rounded,
                                tooltip: tr('deleteAudio', lang),
                                onPressed: sv == null ? () => _delete(s) : null,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String lang;
  const _Empty({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.download_for_offline_outlined, size: 56, color: Pop.ink),
          const SizedBox(height: 12),
          Text(tr('noDownloads', lang), textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
