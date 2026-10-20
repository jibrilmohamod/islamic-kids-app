# Manual checks before a release

Things CI cannot prove: real audio, Android's notification shade, lock screen, Bluetooth, phone calls, the system font size, and how a cheap phone actually feels. Run these on the Galaxy A06 (Jibril's test phone) with the release APK, and tick them in the release PR.

Automated tests cover the logic behind these. This list covers what only a real phone shows.

## Install and data
- [ ] Install over the previous release. Mosaic progress, week stars, daily limit, book page, bookmarks and favourites are all still there.
- [ ] Fresh install (uninstall first). The app opens on Home with no errors.
- [ ] Airplane mode from the start. Home, the book, surahs, duas and hadith all open (content ships in the APK).

## Recitation
- [ ] Play a surah. The first time, the app asks to allow notifications. Allow.
- [ ] No pause between ayat (issue #23).
- [ ] Go Home: the now-playing strip shows. Leave the app: recitation keeps going.
- [ ] Pull down the notification shade: surah name, "Ayah n of N", previous, pause, next and stop all work.
- [ ] Lock the phone: the same controls work on the lock screen.
- [ ] Bluetooth headset or earbuds (if available): play and pause buttons work.
- [ ] Phone call during recitation: audio pauses or ducks, then can be resumed.
- [ ] Airplane mode mid-surah: it plays what is saved, then stops without crashing.
- [ ] Parent area → Recitation controls says "On".
- [ ] Deny notifications on a fresh install. Parent area says "Off" and its button opens the app's settings.

## Look and fit
- [ ] Phone font size at the largest setting. Home, My shelf, hadith shelves and a hadith topic: nothing cut off or overlapping.
- [ ] Reduce animations / remove animations on in accessibility settings. Home opens with no motion.
- [ ] Book: page turns right to left; tapping an ayah selects it; bookmarking from the panel shows in My shelf.

## Parent features
- [ ] Set a 5-minute limit. After 5 minutes the break screen covers the app. The grown-up question adds 15 minutes.
- [ ] The parent gate question blocks a child guessing at random (wrong answer does nothing).

## Speed
- [ ] Cold start (swipe the app away, open it): Home shows within about two seconds, with no long white screen.
- [ ] Scrolling the surah list and the book is smooth.
