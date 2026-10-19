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
