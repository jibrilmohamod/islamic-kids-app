# Architecture

Status: v0.1, 19 Oct 2026. English-first launch; Somali follows when its
coverage is good enough.

## 1. Requirements

### Functional

| Area | v1 | Later |
|---|---|---|
| Learn | 11 surahs (Al-Fatiha, 105 to 114), hadith on daily manners | Rest of Juz Amma, 40 Nawawi |
| Duas | "My day" duas, memorise mode, "Dua for now" | Audio, badges per dua |
| Play | Order the ayat | Pick the missing word, hadith match |
| Watch | 30 to 50 allowlisted YouTube videos | Licensed originals |
| Islam Basics | Pillars of iman, wudu, salah (hadith-backed steps) | Fasting, more how-tos |
| Parents | Language, video on/off, sources and versions | PIN, progress view |

### Non-functional

| Need | Target | Why |
|---|---|---|
| Works offline | All text and games with no network | Data costs for target families |
| Runs on low-end Android | Android 7+ (API 24), 2 GB RAM, APK under 40 MB | Typical phones in the market |
| Running cost | Near zero, no servers | Free app, personal project |
| Privacy | No accounts, no analytics SDKs, no ads, no location | Play Families Policy, parent trust |
| Content integrity | Religious text verbatim, sourced, versioned | Core product rule |

### Constraints

- One developer plus Claude. Builds run in GitHub Actions; the Windows PC has no Flutter.
- iOS needs macOS to build: out of scope until there is a Mac or paid macOS CI.
- QuranEnc terms: no modification, credit and version shown, keep up to date.

## 2. High-level design

```
 BUILD (GitHub Actions, main branch)
 ───────────────────────────────────
 QuranEnc ─┐
           ├─► pipeline ─► bundle.json ─► commit to git (reviewable diff)
 HadeethEnc┘   fail closed      │
                                ├─► flutter analyze · test · build APK (bundle inside)
                                │
                                └─► POST publish-content (Supabase Edge Function)
                                      auth: GitHub OIDC token, this repo + main only
                                      writes with service role:
                                        content/v1/bundles/<sha256>.json  (immutable, 1 y cache)
                                        content/v1/manifest.json          (60 s cache)

 PHONE
 ─────
 launch ─► ContentStore.loadBest()
             cached download newer than APK copy?  yes ─► use it
                                                   no  ─► use APK copy
        └─► background: GET manifest (public URL, no key)
              newer + same schema? ─► GET bundle, check size, parse, atomic write
              used from the NEXT launch (text never changes mid-lesson)
```

Runtime network calls: the public manifest and bundle URLs, and the YouTube
player. No API keys ship in the app.

## 3. Deep dive

### Content bundle

One JSON file, built from config, committed to git.

- `languages`: languages every item must have (v1: `en`).
- `optionalLanguages`: added per item when the source has them (v1: `so`).
  The app falls back to English when an item lacks the chosen language.
- `sources`: publisher, title, version per source, shown in the app.
- `surahs[]`, `hadith[]`, `duas[]`: text plus a source key on every field.

Fail-closed rule: the pipeline writes nothing if any required text is empty or
an id repeats. CI commits the bundle only when its content (not its timestamp)
changes, so every text change is a reviewable commit.

### Mushaf (book) view

- Line and page breaks of the Madina Mushaf, 1441H print (604 pages, 15
  lines): from the `quran-qcf4` npm package, MIT, which takes them from King
  Fahd Complex page data. `tool/make-mushaf-layout.mjs` turns it into
  `pipeline/data/madina-1441h-layout.json` (committed, ~250 KB, with the MIT
  notice beside it).
- The words on those lines are the bundle's own QuranEnc Arabic. Nothing of
  the layout package's text is used.
- The two texts split 18 ayat into different numbers of words (for example
  لوما as one word or two, the sajda sign as its own word). Those words are
  placed by letter position; every ayah ends up on exactly the lines the print
  uses (checked in the pipeline tests for all 6,236).
- Each ayah carries `ml`, e.g. `"3.1.9 3.2.2"`: 9 words on page 3 line 1, 2
  on line 2. `mushaf` holds lines per page and where surah headers and
  basmalas go.
- The app sets the lines in Amiri Quran (OFL) and justifies each by widening
  the spaces. The KFGQPC fonts are not used: their licence forbids
  reproduction without written approval.

### Hadith shelves and numbers

- `shelves[]`: our kid-friendly groups (Good manners, Good character, ...) of
  HadeethEnc categories. Topic names are HadeethEnc's own category titles.
- Hadith from bulk categories are screened for adult topics
  (`needsAdultReview`); hits are left out and listed in
  `pipeline/reports/hadith-report.json` for a person to decide.
- HadeethEnc names the collection ("Narrated by Muslim") but not the number.
  The pipeline looks for the Prophet's words (the «...» quote) in the Arabic
  of Sahih al-Bukhari and Sahih Muslim (hadith-api, pinned commit), only in
  the collections HadeethEnc names. A number ships only on a strong match
  (80%+ of the quote's word triples, at least 4) or when a person checked it
  on sunnah.com (`pipeline/hadith-refs.json`, which also blocks numbers).
- Numbering: Bukhari by the Fath al-Bari numbers, Muslim by Muhammad Fu'ad
  Abd al-Baqi's, the same as sunnah.com's main reference (spot-checked).

### Recitation audio
- **Ownership.** One `Recitation` object in `AppState` owns playback. Screens start it and show its state, but they don't stop it when they close.
- **Playback.** Ayat play as one gapless just_audio playlist, fetched and saved up to 3 ayat ahead.
- **Background.** `audio_service` runs a foreground media service with a notification, so recitation continues with the app in the background or the screen off.
- **Details.** See ADR 0002.

### App structure

| Layer | Now | Revisit when |
|---|---|---|
| State | `AppState` (ChangeNotifier) via `InheritedNotifier` | More than ~5 screens share mutable state |
| Content | `ContentStore`: APK copy, replaced by a newer published bundle on the next launch | Content grows past a few MB: split into packs |
| Progress | `shared_preferences` (games completed, language) | Streaks and badges need a schema |
| Navigation | `Navigator.push` | Deep links or more than ~15 routes |
| Strings | Map in `strings.dart` | Somali launch: move to ARB files and `flutter gen-l10n` |

### Watch (YouTube)

- Official IFrame player in a WebView, self-designated child-directed.
- Allowlist of video IDs lives in the bundle, curated by hand.
- No search, no related videos surfaced by the app, player stops at video end.

### Islam Basics

Each how-to step references the hadith it comes from (HadeethEnc id). Where
schools differ, the step uses the Shafi'i position from a named Shafi'i source,
quoted verbatim. No step ships without reviewer sign-off.

### Media budget

| Asset | Format | Budget |
|---|---|---|
| Scene illustrations | WebP, 3 layers, max 1080 px wide | ~150 KB per lesson |
| Quran font | One licensed Uthmani font | ~1 MB |
| Audio | Not in v1 APK; downloadable packs later | ~0.5 MB per short surah |

## 4. Scale and reliability

There is no server, so load is not a concern. Risks are upstream:

| Risk | Effect | Mitigation |
|---|---|---|
| QuranEnc or HadeethEnc down during CI | Fetch fails | CI falls back to the committed bundle and still builds |
| Bad bundle published | Phones could get broken text | Fail-closed pipeline, edge function checks schema, app re-validates and keeps the old copy on any error |
| New bundle shape | Old app versions misread it | `schemaVersion`: apps ignore bundles they do not understand |
| Supabase project paused or down | No updates | App keeps working on its last bundle |
| API field renamed | Validation fails closed | Fixture tests; fix the mapping |
| Translation updated upstream | Bundle text changes | Shows up as a bot commit to review |
| YouTube video removed | Blank player | Weekly CI check of the allowlist (to build) |

Monitoring: Play Console crash and ANR reports only. No in-app analytics.

## 5. Trade-offs

| Decision | Chosen | Alternative | Why |
|---|---|---|---|
| Content delivery | APK copy plus Supabase Storage updates | APK only; GitHub Pages | Offline first, text fixes reach phones without a Play release, free tier |
| Publish auth | GitHub OIDC verified in an edge function | Service key stored as a CI secret | No long-lived secret anywhere |
| Update timing | Next launch | Swap immediately | Text never changes under a child mid-lesson |
| Language coverage | English required, Somali optional with fallback | Only items in both languages | Full English launch now; Somali grows as sources add it |
| State management | Built-in `InheritedNotifier` | Riverpod, Bloc | No dependency to vet; small app |
| Build | GitHub Actions | Local Flutter | No local Flutter; reproducible builds |
| Video | YouTube embed | Self-hosted video | Free; costs control over ads and removals |

## 6. Revisit as it grows

1. Streaks and badges on top of the saved progress.
2. Hash check on the phone (needs the `crypto` package) in addition to the size check.
3. ARB-based localization for the Somali launch.
4. Audio packs downloaded on demand.
5. iOS once macOS build capacity exists.
