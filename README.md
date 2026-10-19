# Islamic Kids App (working name)

Free Android app for children aged 8 to 12: short surahs, hadith and duas in
Somali and English, with games. Spec: the "Kids Islamic App: Build Spec v1" doc.

## The one rule

Every religious sentence is verbatim from a named source (QuranEnc, HadeethEnc).
Nothing religious is written, reworded or summarised in this code. The pipeline
refuses to write a bundle with any empty text field.

## Layout

| Folder | What |
|---|---|
| `pipeline/` | Node script that fetches content and writes `app/assets/content/bundle.json` |
| `app/` | Flutter app (Android first) |

## First run on Windows

1. **Build the content** (needs Node 18+, no npm packages):

   ```powershell
   node pipeline/build-bundle.mjs
   ```

   It prints each surah, hadith group and dua moment, then writes the bundle.
   If any text is missing it stops and writes nothing.

2. **Install Flutter** (once): https://docs.flutter.dev/get-started/install/windows
   then run `flutter doctor` until the Android toolchain is green.

3. **Add the Android project files** (once), from inside `app/`:

   ```powershell
   cd app
   flutter create --platforms android --org com.example --project-name islamic_kids_app .
   ```

   This only adds the missing `android/` folder; it does not touch `lib/`.
   Change `com.example` to your own reverse domain before publishing.

4. **Check and run**:

   ```powershell
   flutter analyze
   flutter test
   flutter run
   ```

## Tests

```powershell
node --test pipeline/pipeline.test.mjs   # pipeline, uses fake API data
cd app; flutter test                      # models, order game, dua-for-now
```

## Languages

English is required for every item and is the launch language. Somali is
added per item wherever QuranEnc or HadeethEnc has it; the app falls back to
English otherwise. The Somali switch is hidden (`AppState.somaliEnabled`)
until coverage is good enough. Each pipeline run prints the Somali coverage.

Design and trade-offs: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## What is in v0.1

- Learn: 11 surahs (Al-Fatiha, 105 to 114), hadith on eating and sleeping manners
- Duas: morning and evening, home, bathroom, mosque, plus three Quranic duas,
  with a memorise mode that hides and reveals words
- Play: put the ayat in order (repeated ayat such as Al-Kafirun 3 and 5 count either way)
- Parents: language switch, sources and versions
- Home: "Dua for now" based on the time of day

Not yet: audio, illustrations, YouTube, saved progress, PIN, Islam Basics track.

## Content to check before release

- Somali UI strings in `app/lib/strings.dart` are a first draft.
- Hadith-based duas show the full hadith text, including the narrator's
  introduction. Showing the dua words alone needs a verified source that gives
  them separately; the text is not cut by hand.
- Arabic uses the phone's system font. A proper Quran font (licence checked)
  should be added before release.
