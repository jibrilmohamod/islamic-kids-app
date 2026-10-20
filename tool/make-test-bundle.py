#!/usr/bin/env python3
"""Cuts a small, fixed content bundle for widget tests (test audit T1).

Widget tests used the real 6 MB bundle, so a content change could break UI
tests that have nothing to do with it. This fixture is real text, cut once
and committed, so tests are fast and only change when someone reruns this.

    python3 tool/make-test-bundle.py app/assets/content/bundle.json

Writes app/test/fixtures/bundle.json.
"""
import json
import os
import sys

SURAHS = {1, 2, 18, 36, 67, 112, 113, 114}
HADITH_PER_TOPIC = 4

src = sys.argv[1] if len(sys.argv) > 1 else 'app/assets/content/bundle.json'
b = json.load(open(src, encoding='utf-8'))

b['surahs'] = [s for s in b['surahs'] if s['number'] in SURAHS]
mushaf = b.get('mushaf')
if mushaf:
    # Keep surah headers and basmalas only for the surahs kept.
    mushaf['specials'] = {
        page: [sp for sp in items if sp[2] in SURAHS]
        for page, items in mushaf['specials'].items()
    }
    mushaf['specials'] = {p: v for p, v in mushaf['specials'].items() if v}

# The first few hadith of each topic, in HadeethEnc's order.
kept, per_topic = [], {}
for h in b['hadith']:
    t = h['group']
    if per_topic.get(t, 0) < HADITH_PER_TOPIC:
        per_topic[t] = per_topic.get(t, 0) + 1
        kept.append(h)
b['hadith'] = kept

# Duas that point at a surah that was cut would have no audio; keep the rest.
b['duas'] = [d for d in b['duas'] if 'key' not in d or int(d['key'].split(':')[0]) in SURAHS]
b['bundleVersion'] = 'test-' + b['bundleVersion']

out = os.path.join('app', 'test', 'fixtures', 'bundle.json')
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, 'w', encoding='utf-8') as f:
    json.dump(b, f, ensure_ascii=False, separators=(',', ':'))
print(f'{out}: {len(b["surahs"])} surahs, {len(b["hadith"])} hadith, {len(b["duas"])} duas, {os.path.getsize(out) // 1024} KB')
