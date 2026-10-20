# Working on this app

A free Islamic learning app for children aged 8 to 12, built in Flutter and released on Android first. Read `docs/ARCHITECTURE.md` for how it fits together, and the ADRs in `docs/adr/` for the decisions behind it.

## Content rules (these come first)

- **Religious text is copied verbatim from verified sources only.** Sources: QuranEnc for Quran text and translations, HadeethEnc for hadith, AlQuran.cloud for surah metadata and audio, and sunnah.com for hadith numbers. Nothing religious is written, paraphrased or generated.
- **AI is used for illustrations and code only.**
- **No figures of prophets or companions, and no faces.** The icons are objects and places.
- **How-to steps follow the Shafi'i school.** Hadith content is not tied to any school.
- **Every new source needs a citation, a licence, and a line in the parent screen's sources list.**

## How work flows

1. **One GitHub issue per piece of work,** inside a milestone (M0 to M5).
2. **One branch and one PR per issue.** Nobody pushes to `main` directly. PRs may stack (base on the PR below); they merge in order.
3. **Design before code.** Anything a child sees is drawn on the design canvas first and approved there. Rows E to G define the look: glazed cards with halftone dots, ink borders, hard shadows, sticker tabs and arched niches.
4. **Merging:**
   - CI-only and docs-only PRs merge on green CI after a written self-review.
   - PRs that change app behaviour, content or religious text wait for Jibril's approval, usually after he has tried the APK on his phone.
5. **Decisions that are hard to undo** (a dependency, storage, a source) get an ADR in `docs/adr/`.

## Definition of done

A PR is done when every box applies or is explained in the PR:

- [ ] **CI is green:** content pipeline tests, analyze, Flutter tests, previews, APK build, permission check.
- [ ] **Tests:** new logic has tests at the cheapest level that can check it: plain logic tests first, widget tests for screens, and one end-to-end flow (`test/flows_test.dart`). Widget tests use `test/fixtures/bundle.json`, not the shipped bundle. No `pumpAndSettle` on endless animations or real timers.
- [ ] **Text fits:** new screens are added to the 1.3x and 2x text-size tests. Text wraps; it is never shrunk or cut off.
- [ ] **Motion:** new motion has a reduce-motion version (none, or a short fade), and repeating animation stops when the screen is gone.
- [ ] **Accessibility:** tap targets are at least 44 px; every button has a label; colour is never the only signal.
- [ ] **Errors:** no silent `catch (_)`. Errors are logged, shown to the parent, or returned.
- [ ] **Time:** code reads time from the app's injected clock, not `DateTime.now()`.
- [ ] **Strings:** every visible string is in `strings.dart` in English. Somali drafts are marked for Jibril's review.
- [ ] **Dependencies:** a new package is checked first (publisher, last release, licence) and noted in `pubspec.yaml`. Prefer no new dependency.
- [ ] **Permissions:** a new Android permission is explained in the PR and added to CI's reviewed list.
- [ ] **Previews:** if a screen changed, its preview was looked at, and the canvas still matches the app.
- [ ] **Manual checks:** if the change touches audio, notifications or the phone itself, the relevant lines of `docs/MANUAL_CHECKS.md` are listed in the PR for testing on the A06.

## Commit and PR text

- **Commits:** say what changed and why, in plain words. Reference the issue (`Refs #28`).
- **PR descriptions:** say what a child or parent will notice, how it was checked, and what still needs a phone test.
