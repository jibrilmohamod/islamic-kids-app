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
 BUILD TIME (GitHub Actions)                         RUN TIME (phone)
 ───────────────────────────                         ────────────────
 QuranEnc API ──┐                                    ┌──────────────────────────┐
                ├─► pipeline/build-bundle.mjs ──┐    │ Flutter app              │
 HadeethEnc API ┘   fetch · validate · fail     │    │                          │
                    closed on any empty text    │    │  ContentRepository       │
                                                ▼    │    └ bundle.json (asset) │
                          app/assets/content/bundle.json ──► Learn / Duas / Play │
                          (committed to git, reviewable)│    Basics / Parents     │
                                                ▼    │                          │
                          flutter analyze, test, build  │  Watch ──► YouTube      │
                                                ▼    │   IFrame (allowlist only)│
                                     APK artifact ──────►  Local progress store   │
                                                     └──────────────────────────┘
```

The only runtime network call in v1 is the YouTube player. Content updates
ship as app updates.

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

### App structure

| Layer | Now | Revisit when |
|---|---|---|
| State | `AppState` (ChangeNotifier) via `InheritedNotifier` | More than ~5 screens share mutable state |
| Content | Loaded once from the asset bundle | Remote bundle (below) |
| Progress | In memory | Next step: a local key-value store, package vetted first |
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
| QuranEnc or HadeethEnc down during CI | Pipeline fails, no APK | Fall back to the committed bundle when the fetch fails (to build) |
| API field renamed | Validation fails closed | Fixture tests; fix the mapping |
| Translation updated upstream | Bundle text changes | Shows up as a bot commit to review |
| YouTube video removed | Blank player | Weekly CI check of the allowlist (to build) |

Monitoring: Play Console crash and ANR reports only. No in-app analytics.

## 5. Trade-offs

| Decision | Chosen | Alternative | Why |
|---|---|---|---|
| Content delivery | Bundled in APK | Remote bundle on GitHub Pages | Offline by default, zero hosting; costs an app update per content change |
| Language coverage | English required, Somali optional with fallback | Only items in both languages | Full English launch now; Somali grows as sources add it |
| State management | Built-in `InheritedNotifier` | Riverpod, Bloc | No dependency to vet; small app |
| Build | GitHub Actions | Local Flutter | No local Flutter; reproducible builds |
| Video | YouTube embed | Self-hosted video | Free; costs control over ads and removals |

## 6. Revisit as it grows

1. Remote content bundle (GitHub Pages or Releases) so text updates skip the Play review cycle.
2. Persistent progress, streaks and badges.
3. ARB-based localization for the Somali launch.
4. Audio packs downloaded on demand.
5. iOS once macOS build capacity exists.
