# ADR 0002: Recitation keeps playing in the background (just_audio + audio_service)

Status: proposed, 2026-10-19 (issue #34; also fixes the gap between ayat, #23)

## Context
Jibril asked for recitation to keep playing when the child leaves the app. With `audioplayers`, each screen played one ayah file, waited for it to end, then started the next from Dart. That design has three problems:

1. Leaving the screen stopped the audio (each screen called `stop()` in `dispose`).
2. With the app in the background, Android may throttle or kill the process. No foreground service keeps it alive, and there is no media notification to control it from.
3. Each ayah was downloaded (if needed) and then started only after the previous one ended. That caused the pause between ayat Jibril heard on the A06 (#23).

## Options
| Option | For | Against |
|---|---|---|
| `just_audio` + `audio_service` | Gapless playlist; foreground media service, notification and lock-screen controls; full control of the buttons | Two dependencies; manifest and `MainActivity` changes |
| `just_audio` + `just_audio_background` | Less code | Still a beta (0.0.1-beta.17, May 2025); fewer controls; the author recommends `audio_service` for anything beyond a single simple player |
| Keep `audioplayers`, add a foreground service by hand | No new player | Native Kotlin to maintain; still no gapless playlist |

## Decision
`just_audio` and `audio_service`. Both checked on pub.dev on 2026-10-19:
- [just_audio](https://pub.dev/packages/just_audio): 0.10.6, published 2026-06-29 by ryanheise.com (verified publisher). Gapless playback on Android. `setAudioSources` and `addAudioSources` are the current playlist API in 0.10.
- [audio_service](https://pub.dev/packages/audio_service): 0.18.19, published 2026-06-29 by ryanheise.com (verified publisher).

`audioplayers` is removed.

## Design
- **`Recitation`** (`app/lib/recitation.dart`) is the single owner of playback, held in `AppState`. It plays one run at a time: a surah from an ayah on, either that ayah only or to the end of the surah.
- **No pause between ayat.** Files are saved the first time they play (as before). They are fetched up to 3 ayat ahead and appended to the player's playlist, so the next ayah is already loaded when the current one ends.
- **Slow or lost connection.** If the next ayah hasn't arrived when the current one ends, the run waits and carries on when it lands. If a fetch fails, the run plays what it has queued, then stops, and counts the failure.
- **Shared downloads.** `AudioService.ensure` shares a download already running for the same ayah. Recitation and "save surah" can now overlap; before, they would have written the same temp file twice.
- **`RecitationPlayer`** is the seam to just_audio. Tests use a fake (`app/test/recitation_test.dart`).
- **`RecitationHandler`** mirrors `Recitation` into the Android media notification: surah name, "Ayah n of N", previous / play-pause / next / stop. `androidStopForegroundOnPause: false` follows the audio_service note for Android 12+, so a paused recitation can be resumed from the notification.
- **Screens.**
  - Surah, mushaf and downloads screens no longer stop recitation when they close.
  - The book still turns pages as recitation moves on.
  - A dua's ayah still stops with its card, because it belongs to that card.
  - Home shows a "now playing" strip while something plays: tap it to open the surah, or pause or stop from there.

## Consequences
- **Android:**
  - The manifest gains `WAKE_LOCK`, `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, plus the audio_service service and media-button receiver.
  - `MainActivity` extends `AudioServiceActivity`.
  - Google Play asks apps that declare a media-playback foreground service to say what it is for. Here it is Quran recitation the child started.
- **Screen time.** The parent's daily limit counts time with the app open. The ticker already stops when the app is backgrounded, so listening with the screen off does not count. When the limit is reached in the app, the break screen covers it, and recitation keeps playing. **Open for Jibril:** should the break screen also stop recitation?
- **Notification permission (added 2026-10-20).**
  - Android's docs say media-session notifications are exempt from Android 13's notification permission ([developer.android.com](https://developer.android.com/develop/ui/views/notifications/notification-permission)). On Jibril's Galaxy A06, though, the controls did not appear in the pull-down shade.
  - So the app now declares `POST_NOTIFICATIONS` and asks once, the first time a child starts recitation.
  - The parent screen shows whether the controls are on, why not if they are off, and a button to the app's settings.
  - If the media service fails to start, its error is shown there too instead of being swallowed.
- **Not covered by CI.** CI cannot prove the notification, lock-screen controls or real audio focus. Those need checking on the A06: play, leave the app, lock the phone, use the notification buttons, take a call.
- **Notification icon.** The notification uses the launcher icon. A one-colour notification icon belongs in the design pass (#35).
