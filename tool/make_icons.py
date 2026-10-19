#!/usr/bin/env python3
"""The app's icon set (design canvas row E), written once as SVG and exported
to app/lib/pop_icons.dart for flutter_svg. Change icons here, then run:

    python3 tool/make_icons.py

Style: ink outline, flat glaze fills, hard 3px shadow. Objects and places only:
no people, no faces.
"""
import math
import os

INK = '#1B1035'
PINK = '#FF3D8B'
CYAN = '#19C3FF'
LEMON = '#FFD93B'
VIOLET = '#7A3CFF'


def star(cx, cy, r, inner=None):
    inner = inner or r * math.cos(math.pi / 4) / math.cos(math.pi / 8)
    pts = []
    for i in range(16):
        a = math.pi / 8 * i - math.pi / 2
        rad = r if i % 2 == 0 else inner
        pts.append(f'{cx + rad * math.cos(a):.1f},{cy + rad * math.sin(a):.1f}')
    return ' '.join(pts)


# Shapes on a 64x64 grid; {pink} etc. are the glaze fills.
ICONS = {
    'quran': [
        '<polygon points="20,31 27,31 52,60 45,60" fill="{pink}"/>',
        '<polygon points="37,31 44,31 19,60 12,60" fill="{pink}"/>',
        '<polygon points="5,24 32,32 59,24 59,28 32,36 5,28" fill="{cyan}"/>',
        '<polygon points="5,24 32,32 32,11 5,4" fill="#fff"/>',
        '<polygon points="59,24 32,32 32,11 59,4" fill="#fff"/>',
        '<path d="M11 11l15 4M11 16l15 4M38 15l15-4M38 20l15-4" fill="none" stroke-width="2"/>',
    ],
    'surahs': [
        f'<polygon points="{star(22, 24, 17)}" fill="{{lemon}}"/>',
        f'<polygon points="{star(44, 26, 14)}" fill="{{cyan}}"/>',
        f'<polygon points="{star(32, 46, 14)}" fill="{{pink}}"/>',
    ],
    'duas': [
        '<path d="M32 2v6" fill="none"/>',
        '<circle cx="32" cy="10" r="3" fill="{lemon}"/>',
        '<path d="M20 20q12-12 24 0z" fill="{violet}"/>',
        '<polygon points="20,20 44,20 49,36 44,51 20,51 15,36" fill="{lemon}"/>',
        '<path d="M32 20v31M15 36h34" fill="none" stroke-width="2"/>',
        '<polygon points="24,51 40,51 36,60 28,60" fill="{violet}"/>',
    ],
    'hadith': [
        '<rect x="9" y="12" width="36" height="42" fill="#fff"/>',
        '<rect x="6" y="6" width="42" height="9" rx="4" fill="{cyan}"/>',
        '<rect x="6" y="51" width="42" height="9" rx="4" fill="{cyan}"/>',
        '<path d="M15 23h24M15 30h24M15 37h16" fill="none" stroke-width="2"/>',
        '<polygon points="48,8 54,8 60,44 56,52 52,44" fill="{pink}"/>',
    ],
    'games': [
        '<path d="M14 10h14v6a5 5 0 1 0 10 0v-6h14v14h-6a5 5 0 1 0 0 10h6v20H38v-6a5 5 0 1 0-10 0v6H14V34h6a5 5 0 1 0 0-10h-6z" fill="{pink}"/>',
    ],
    'downloads': [
        '<path d="M20 22q12-16 24 0" fill="none" stroke-width="4"/>',
        '<rect x="9" y="22" width="46" height="34" rx="5" fill="{cyan}"/>',
        '<path d="M9 30h46v6q-23 8-46 0z" fill="{violet}"/>',
        '<circle cx="32" cy="45" r="8" fill="#fff"/>',
        '<path d="M32 40v9M28 45l4 4 4-4" fill="none" stroke-width="2.5"/>',
    ],
    'parents': [
        '<circle cx="21" cy="32" r="13" fill="{lemon}"/>',
        '<circle cx="21" cy="32" r="4" fill="#fff"/>',
        '<polygon points="33,28 59,28 59,36 54,36 54,42 48,42 48,36 33,36" fill="{lemon}"/>',
    ],
    'week': [
        f'<polygon points="{star(32, 32, 26)}" fill="{{lemon}}"/>',
        '<path d="M22 33l7 7 13-14" fill="none" stroke-width="4"/>',
    ],
    # My shelf: a bookmark ribbon holding a heart (canvas row F).
    'shelf': [
        '<path d="M16 4h32v54L32 46 16 58z" fill="{pink}"/>',
        '<path d="M32 33c-7-5-10-9-10-13a5 5 0 0 1 10-2 5 5 0 0 1 10 2c0 4-3 8-10 13z" fill="#fff" stroke-width="2.5"/>',
    ],
    # Hadith shelves (canvas row F): objects only, no figures.
    'shelfManners': [
        '<path d="M24 6q-5 5 0 10t0 10M34 6q-5 5 0 10t0 10" fill="none" stroke-width="2.5"/>',
        '<path d="M44 30h4a7 7 0 0 1 0 14h-5" fill="none"/>',
        '<path d="M12 26h32v16a14 14 0 0 1-14 14h-4a14 14 0 0 1-14-14z" fill="{cyan}"/>',
        '<rect x="6" y="55" width="46" height="5" rx="2" fill="{lemon}"/>',
    ],
    'shelfCharacter': [
        '<path d="M32 58C14 46 6 35 6 24a12 12 0 0 1 26-6 12 12 0 0 1 26 6c0 11-8 22-26 34z" fill="{pink}"/>',
        '<path d="M16 22q2-6 8-6" fill="none" stroke="#FFFFFF"/>',
        '<path d="M54 4v8M50 8h8" fill="none" stroke-width="2.5"/>',
    ],
    'shelfFamily': [
        '<rect x="10" y="28" width="44" height="30" fill="{lemon}"/>',
        '<polygon points="4,30 32,6 60,30" fill="{violet}"/>',
        '<rect x="27" y="40" width="10" height="18" fill="{cyan}"/>',
        '<rect x="15" y="35" width="8" height="8" fill="#fff" stroke-width="2.5"/>',
        '<rect x="41" y="35" width="8" height="8" fill="#fff" stroke-width="2.5"/>',
    ],
    'shelfProphet': [
        '<path d="M32 21V9" fill="none"/>',
        '<path d="M36 4a5 5 0 1 0 0 8a4 4 0 1 1 0-8z" fill="{lemon}" stroke-width="2"/>',
        '<path d="M13 40a19 19 0 0 1 38 0z" fill="{cyan}"/>',
        '<rect x="10" y="40" width="44" height="18" fill="#fff"/>',
        '<path d="M22 58v-8a4 4 0 0 1 8 0v8M34 58v-8a4 4 0 0 1 8 0v8" fill="{violet}" stroke-width="2.5"/>',
    ],
    'shelfWorship': [
        '<rect x="14" y="4" width="36" height="52" rx="3" fill="{pink}"/>',
        '<path d="M22 48V26a10 10 0 0 1 20 0v22z" fill="{lemon}"/>',
        '<path d="M18 60v-4M24 60v-4M30 60v-4M36 60v-4M42 60v-4M48 60v-4" fill="none" stroke-width="2"/>',
    ],
    'shelfLearning': [
        '<path d="M46 2L33 34" fill="none" stroke-width="4"/>',
        '<rect x="22" y="28" width="20" height="8" fill="{cyan}"/>',
        '<path d="M16 36h32l5 22H11z" fill="{violet}"/>',
        '<path d="M18 46h28" fill="none" stroke="#FFD93B"/>',
    ],
    # Toggles: bookmark ribbon and favourite heart, on (glazed) and off.
    'bookmarkOn': ['<path d="M18 6h28v52L32 46 18 58z" fill="{pink}" stroke-width="4"/>'],
    'bookmarkOff': ['<path d="M18 6h28v52L32 46 18 58z" fill="#fff" stroke-width="4"/>'],
    'heartOn': ['<path d="M32 54C16 43 9 34 9 25a11 11 0 0 1 23-5 11 11 0 0 1 23 5c0 9-7 18-23 29z" fill="{pink}" stroke-width="4"/>'],
    'heartOff': ['<path d="M32 54C16 43 9 34 9 25a11 11 0 0 1 23-5 11 11 0 0 1 23 5c0 9-7 18-23 29z" fill="#fff" stroke-width="4"/>'],
}

FILLS = dict(pink=PINK, cyan=CYAN, lemon=LEMON, violet=VIOLET)


def svg(name, shadow=True):
    """One standalone SVG: 64x64, or 67x67 with the 3px shadow."""
    shapes = ICONS[name]
    parts = []
    if shadow:
        dark = ''.join(
            e.replace('{pink}', INK).replace('{cyan}', INK).replace('{lemon}', INK)
             .replace('{violet}', INK).replace('fill="#fff"', f'fill="{INK}"')
            for e in shapes if 'fill="none"' not in e)
        parts.append(f'<g transform="translate(3 3)" fill="{INK}">{dark}</g>')
    colour = ''.join(e.format(**FILLS) for e in shapes)
    parts.append(f'<g stroke="{INK}" stroke-width="3" stroke-linejoin="round" stroke-linecap="round">{colour}</g>')
    box = 67 if shadow else 64
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {box} {box}">{"".join(parts)}</svg>'


DART_TAIL = """
/// One icon at [size] logical pixels; [shadow] adds the hard offset shadow.
class PopIconView extends StatelessWidget {
  final PopIcon icon;
  final double size;
  final bool shadow;
  final String? semanticsLabel;
  const PopIconView(this.icon, {super.key, this.size = 48, this.shadow = true, this.semanticsLabel});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      (shadow ? _withShadow : _flat)[icon]!,
      width: size,
      height: size,
      semanticsLabel: semanticsLabel,
      excludeFromSemantics: semanticsLabel == null,
    );
  }
}
"""


def main():
    out = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', 'app', 'lib', 'pop_icons.dart'))
    lines = [
        '// GENERATED by tool/make_icons.py from the design canvas icon set. Do not edit by hand.',
        '',
        "import 'package:flutter/widgets.dart';",
        "import 'package:flutter_svg/flutter_svg.dart';",
        '',
        '/// The app icons: ink outline, flat glaze, hard shadow. No people or faces.',
        'enum PopIcon { ' + ', '.join(ICONS) + ' }',
        '',
        'const Map<PopIcon, String> _withShadow = {',
        *[f"  PopIcon.{n}: '{svg(n)}'," for n in ICONS],
        '};',
        '',
        'const Map<PopIcon, String> _flat = {',
        *[f"  PopIcon.{n}: '{svg(n, shadow=False)}'," for n in ICONS],
        '};',
    ]
    with open(out, 'w') as f:
        f.write('\n'.join(lines) + '\n' + DART_TAIL)
    print(f'wrote {out} ({len(ICONS)} icons)')


if __name__ == '__main__':
    main()
