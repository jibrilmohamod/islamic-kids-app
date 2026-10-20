import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'audio_service.dart';
import 'models.dart';

/// The bits of a media player that [Recitation] needs. The app uses
/// just_audio (see recitation_player.dart); tests use a fake.
abstract interface class RecitationPlayer {
  /// Index in the playlist of the file now playing.
  Stream<int?> get indexStream;

  /// Fires when the last file in the playlist has finished.
  Stream<void> get endStream;

  Stream<bool> get playingStream;

  /// Replaces the playlist with [path] and loads it.
  Future<void> load(String path);

  /// Adds a file to the end of the playlist (played gaplessly).
  Future<void> add(String path);

  Future<void> seekToIndex(int index);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> dispose();
}

/// Recitation that keeps going when the child leaves the screen or the app.
///
/// One playlist at a time: a surah from an ayah on, either just that ayah or
/// on to the end of the surah. Files are saved the first time they play and
/// fetched a few ayat ahead, then added to the player's playlist so ayat
/// follow each other without a pause (#23). The Android notification and the
/// in-app controls both drive this one object.
class Recitation extends ChangeNotifier {
  final AudioService files;
  final RecitationPlayer player;

  /// How many ayat to have saved and queued ahead of the one playing.
  static const ahead = 3;

  Recitation({required this.files, required this.player}) {
    _subs = [
      player.indexStream.listen(_onIndex),
      player.playingStream.listen((p) {
        if (p == playing) return;
        playing = p;
        notifyListeners();
      }),
      player.endStream.listen((_) => _onEnd()),
    ];
  }

  late final List<StreamSubscription<Object?>> _subs;

  /// The surah being recited, or null when nothing is.
  Surah? surah;

  /// Index into [Surah.ayat] of the ayah playing now.
  int index = 0;

  bool playing = false;

  /// True while the next ayah is still being fetched and nothing plays.
  bool waiting = false;

  /// Bumped when a fetch fails mid-surah, so screens can say so.
  final ValueNotifier<int> failures = ValueNotifier(0);

  int _first = 0; // ayah index of playlist item 0
  int _last = 0; // last ayah index the child asked for
  int _queued = 0; // ayah indexes _first.._queued are in the playlist
  int _session = 0;
  Completer<void>? _room;

  bool get active => surah != null;

  /// Whether this run goes on to the end of the surah.
  bool get toEnd => _last > _first;

  /// The ayah playing now, as "surah:ayah".
  String? get key => surah == null ? null : '${surah!.number}:${index + 1}';

  bool isPlaying(Surah s, [int? i]) => surah?.number == s.number && (i == null || i == index);

  /// Starts reciting [s] at [from]. With [toEnd] it carries on to the last
  /// ayah; otherwise it stops after this one. Throws if the first ayah
  /// cannot be fetched.
  Future<void> start(Surah s, int from, {bool toEnd = true}) async {
    final session = ++_session;
    _room?.complete(); // release the previous run's prefetch loop
    _room = null;
    await player.stop();
    surah = s;
    index = from;
    _first = from;
    _queued = from;
    _last = toEnd ? s.ayat.length - 1 : from;
    waiting = true;
    notifyListeners();
    final File f;
    try {
      f = await files.ensure(s.ayat[from]);
    } catch (_) {
      if (session == _session) unawaited(_clear());
      rethrow;
    }
    if (session != _session) return;
    await player.load(f.path);
    waiting = false;
    notifyListeners();
    unawaited(player.play());
    unawaited(_fill(session));
  }

  /// Fetches and queues the following ayat, staying [ahead] in front.
  Future<void> _fill(int session) async {
    final s = surah!;
    while (session == _session && _queued < _last) {
      if (_queued - index >= ahead) {
        _room = Completer<void>();
        await _room!.future;
        continue;
      }
      final next = _queued + 1;
      final File f;
      try {
        f = await files.ensure(s.ayat[next]);
      } catch (_) {
        if (session != _session) return;
        _last = _queued; // play what is queued, then stop
        failures.value++;
        if (waiting) unawaited(_clear());
        return;
      }
      if (session != _session) return;
      await player.add(f.path);
      _queued = next;
      if (waiting) {
        // The player ran out before this ayah arrived: carry on.
        waiting = false;
        await player.seekToIndex(next - _first);
        unawaited(player.play());
        notifyListeners();
      }
    }
  }

  void _onIndex(int? i) {
    if (i == null || surah == null) return;
    final now = _first + i;
    if (now == index) return;
    index = now;
    _room?.complete();
    _room = null;
    notifyListeners();
  }

  void _onEnd() {
    if (surah == null) return;
    if (index < _last) {
      // The next ayah is still downloading; _fill resumes when it lands.
      waiting = true;
      notifyListeners();
    } else {
      unawaited(_clear());
    }
  }

  /// Ends the run. Stopping the player also resets just_audio's "playing"
  /// flag, which otherwise stays on after the playlist completes.
  Future<void> _clear() {
    _session++;
    _room?.complete();
    _room = null;
    surah = null;
    playing = false;
    waiting = false;
    notifyListeners();
    return player.stop();
  }

  Future<void> pause() => player.pause();

  Future<void> resume() => player.play();

  Future<void> stop() => _clear();

  /// Moves to the next ayah, starting a fresh playlist from there.
  Future<void> next() async {
    final s = surah;
    if (s == null || index >= s.ayat.length - 1) return;
    await start(s, index + 1, toEnd: _last > index);
  }

  Future<void> previous() async {
    final s = surah;
    if (s == null) return;
    await start(s, index > 0 ? index - 1 : 0, toEnd: _last > index);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    failures.dispose();
    player.dispose();
    super.dispose();
  }
}
