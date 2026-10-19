#!/usr/bin/env python3
"""Fails when the bundled Quran font has no glyph for a character the app
shows in Arabic (Quran, hadith, duas). A missing glyph draws an empty box in
religious text, so this runs in CI after the fonts are fetched.

Usage: python3 tool/check-font-coverage.py app/assets/fonts/ScheherazadeNew-Regular.ttf app/assets/content/bundle.json
"""
import json
import sys
import unicodedata

from fontTools.ttLib import TTFont


def arabic_texts(bundle):
    for s in bundle.get('surahs', []):
        for a in s.get('ayat', []):
            yield a.get('key', '?'), a.get('arabic', '')
    for h in bundle.get('hadith', []) + bundle.get('duas', []):
        yield h.get('id', '?'), (h.get('ar') or {}).get('text') or h.get('arabic', '')


def missing(font_path, bundle):
    cmap = TTFont(font_path).getBestCmap()
    out = {}
    for where, text in arabic_texts(bundle):
        for ch in text:
            cp = ord(ch)
            # Only the Arabic blocks: punctuation and digits may come from other fonts.
            arabic = 0x0600 <= cp <= 0x06FF or 0x0750 <= cp <= 0x077F or 0x08A0 <= cp <= 0x08FF or 0xFB50 <= cp <= 0xFDFF or 0xFE70 <= cp <= 0xFEFF
            if arabic and cp not in cmap:
                out.setdefault(cp, []).append(where)
    return out


def main(font_path, bundle_path):
    bundle = json.load(open(bundle_path, encoding='utf-8'))
    gaps = missing(font_path, bundle)
    if not gaps:
        print(f'{font_path}: covers every Arabic character in the bundle')
        return 0
    for cp, where in sorted(gaps.items()):
        print(f'U+{cp:04X} {unicodedata.name(chr(cp), "?")}: {len(where)} times, e.g. {", ".join(where[:3])}')
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
