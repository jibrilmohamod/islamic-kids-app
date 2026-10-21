import 'dart:async';

import 'package:audio_service/audio_service.dart' as bg;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart' show MethodChannel;

import 'recitation.dart';

/// [RecitationPlayer] on just_audio: one gapless playlist of saved files.
class JustAudioRecitationPlayer implements RecitationPlayer {
  final AudioPlayer _p = AudioPlayer();

  @override
  Stream<int?> get indexStream => _p.currentIndexStream;

  @override
  Stream<void> get endStream =>
      _p.processingStateStream.where((s) => s == ProcessingState.completed).map((_) {});

  @override
  Stream<bool> get playingStream => _p.playingStream.distinct();

  @override
  Future<void> load(String path) async {
    await _p.setAudioSources([AudioSource.file(path)]);
  }

  @override
  Future<void> add(String path) => _p.addAudioSources([AudioSource.file(path)]);

  @override
  Future<void> seekToIndex(int index) => _p.seek(Duration.zero, index: index);

  @override
  Future<void> play() => _p.play();

  @override
  Future<void> pause() => _p.pause();

  @override
  Future<void> stop() => _p.stop();

  @override
  Future<void> dispose() => _p.dispose();
}

/// Bridges [Recitation] to Android's media notification and lock screen,
/// and keeps the app's process alive in the background while it plays.
class RecitationHandler extends bg.BaseAudioHandler {
  Recitation? _r;

  /// Second line of the notification, in the child's language.
  String Function(int ayah, int total) ayahLabel = (a, t) => 'Ayah $a of $t';

  void attach(Recitation r) {
    _r?.removeListener(_publish);
    _r = r..addListener(_publish);
    _publish();
  }

  String? _lastLogged;

  void _publish() {
    final r = _r;
    final s = r?.surah;
    final summary = s == null || r == null ? 'idle' : '${r.key} playing=${r.playing} waiting=${r.waiting}';
    if (summary != _lastLogged) {
      _lastLogged = summary;
      debugPrint('media session: $summary');
    }
    if (r == null || s == null) {
      playbackState.add(bg.PlaybackState(processingState: bg.AudioProcessingState.idle));
      mediaItem.add(null);
      return;
    }
    mediaItem.add(bg.MediaItem(
      id: r.key!,
      title: s.name,
      album: ayahLabel(r.index + 1, s.ayat.length),
    ));
    playbackState.add(bg.PlaybackState(
      controls: [
        bg.MediaControl.skipToPrevious,
        if (r.playing) bg.MediaControl.pause else bg.MediaControl.play,
        bg.MediaControl.skipToNext,
        bg.MediaControl.stop,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      processingState: r.waiting ? bg.AudioProcessingState.buffering : bg.AudioProcessingState.ready,
      playing: r.playing,
    ));
  }

  @override
  Future<void> play() async => _r?.resume();

  @override
  Future<void> pause() async => _r?.pause();

  @override
  Future<void> stop() async {
    await _r?.stop();
    await super.stop();
  }

  @override
  Future<void> skipToNext() async => _r?.next();

  @override
  Future<void> skipToPrevious() async => _r?.previous();
}

/// Starts the Android media service. Call once, before runApp. Returns the
/// handler, or null and the reason when the platform has no media service
/// (tests, desktop) or it failed to start. The reason is shown to parents.
Future<(RecitationHandler?, String?)> startMediaService() async {
  try {
    final handler = await bg.AudioService.init(
      builder: RecitationHandler.new,
      config: const bg.AudioServiceConfig(
        androidNotificationChannelId: 'com.jibrilmohamod.islamic_kids_app.recitation',
        androidNotificationChannelName: 'Quran recitation',
        // Paused recitation keeps its notification so it can be resumed
        // from there on Android 12+ (audio_service setup notes).
        androidStopForegroundOnPause: false,
      ),
    );
    return (handler, null);
  } catch (e) {
    debugPrint('Media service unavailable, recitation stops with the app: $e');
    return (null, '$e');
  }
}

/// Android side: MainActivity.kt, channel "app/notifications".
const _notifications = MethodChannel('app/notifications');

/// Asks for Android 13+'s notification permission, so the recitation
/// controls show in the pull-down shade. Android exempts media-session
/// notifications, but phones differ in how they apply that, so we ask.
/// With [ask] false it only reads the current setting. Returns whether
/// notifications are allowed; false where there is no Android side (tests).
Future<bool> askNotificationPermission({bool ask = true}) async {
  try {
    return await _notifications.invokeMethod<bool>(ask ? 'request' : 'status') ?? false;
  } catch (e) {
    debugPrint('Notification permission check failed: $e');
    return false;
  }
}

/// Opens the app's notification settings, where a parent can allow them
/// after saying no to the dialog.
Future<void> openNotificationSettings() async {
  try {
    await _notifications.invokeMethod<bool>('openSettings');
  } catch (e) {
    debugPrint('Could not open notification settings: $e');
  }
}
