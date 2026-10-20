# ADR 0003: On-device store as one atomic JSON file, not SQLite

Status: proposed, 2026-10-19 (issue #33)

## Context
Jibril asked for three things:
- reading and listening history;
- bookmarks and favourites;
- sturdier storage for what the app already keeps.

The app already keeps:
- language;
- game rounds;
- active days;
- minutes per day and extra minutes;
- the parent's daily limit;
- the last mushaf page;
- the day Home's opening last played.

All of it lives in SharedPreferences under nine keys, written one key at a time. Nothing is relational. Even with history and bookmarks the data is small: at most a few hundred short strings, a few kilobytes.

The Flutter persistence guidance we follow says to use SQLite (Drift) for relations, indexed queries, transactions across records or reactive queries, and plain files otherwise. Its reference for small apps is `persistence-drift/references/persistence-without-drift.md`.

## Options
| Option | For | Against |
|---|---|---|
| One JSON file, atomic write + backup copy | No new dependency or codegen; one versioned document is easy to export later (backup/restore); fits the data | Whole file rewritten on each save (a few KB, batched) |
| Drift (SQLite) | Queries, indexes, migrations framework | build_runner codegen step in CI, native SQLite in the APK, a schema to migrate for data that has no relations |
| Keep SharedPreferences, add keys | Nothing new | Writes are per key, so related values can land half-saved; no version, no backup copy, awkward to export |

## Decision
`LocalStore` (`app/lib/local_store.dart`) is one file, `store/store.json`, in the app's private support folder.
- **Versioned envelope.** The file is `{"formatVersion": 1, "data": {...}}`. A file with a newer `formatVersion` is not read.
- **Atomic write.** Each save writes `store.json.tmp`, flushed to disk, then moves the current file to `store.json.bak` and the temp file into place. A crash mid-write never leaves a half file.
- **Backup fallback.** If the main file is unreadable, the backup is used.
- **Batched writes.** Changes are written 400 ms after the last change. When the app goes to the background, pending changes are flushed at once.
- **Lenient reading.** A wrong or missing field falls back to its default. One bad value never loses the rest.
- **Migration.** On the first launch with no store file, the nine SharedPreferences keys are read once, written out immediately, and left in place. That way a reinstall of the old version still finds them.

New data:
- **Bookmarks:** ayah keys, newest first, capped at 200.
- **Favourites:** `dua:<id>`, `hadith:<id>` or `surah:<n>`.
- **History:** one line per surah per kind (read, listen), newest first, capped at 50, with UTC milliseconds.
  - Listening is recorded as recitation moves on.
  - Reading is recorded when the book turns to a page (its first ayah).

## Consequences
- **Revisit trigger.** If the app gains accounts, sync or real queries (search across notes, for example), move to Drift. Reading this file's `formatVersion` 1 becomes that migration's first step.
- **UI still to design.** Bookmarks, favourites and history have no screens yet. They go on the design canvas with the rest of the design pass (#35) before they are built.
- **Tests.** `app/test/local_store_test.dart` covers:
  - surviving a reopen;
  - batching;
  - falling back to the backup after a cut-off write;
  - newer files ignored;
  - field-by-field leniency;
  - one-time migration from SharedPreferences;
  - history and bookmark rules.
