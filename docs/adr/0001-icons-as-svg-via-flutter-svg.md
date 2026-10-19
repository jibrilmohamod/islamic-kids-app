# ADR 0001: App icons as SVG, drawn with flutter_svg

Status: accepted, 2026-10-19 (Jibril approved the icon set on the design canvas, row E)

## Context
The app needs its own icon set (issue #26): ink outline, flat glaze, hard shadow, no people or faces. The same drawings must appear on the design canvas and in the app, so design and code never drift.

## Options
| Option | For | Against |
|---|---|---|
| SVG strings + `flutter_svg` | One source (`tool/make_icons.py`) feeds both canvas and app; exact match | One dependency |
| Hand-ported `CustomPainter` paths | No dependency | Every icon written twice; drift between canvas and app |
| Icon font | Tints easily | Single colour only; our icons use several glazes and a shadow |

## Decision
SVG, generated into `app/lib/pop_icons.dart` by `tool/make_icons.py`, rendered with `flutter_svg`.

`flutter_svg` checked on 2026-10-19 ([pub.dev](https://pub.dev/packages/flutter_svg)): version 2.3.0, published 2026-05-08 by flutter.dev (verified publisher), 160 pub points, MIT. Its documented limit, partial CSS support, does not affect us: the SVGs use presentation attributes only, and all motion is done in Flutter.

## Consequences
- Change icons only in `tool/make_icons.py`, then regenerate.
- Animation lives in Flutter widgets (sway, wobble, pop), never in the SVG.
