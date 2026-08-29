#!/usr/bin/env python3
# ---------------------------------------------------------------------------
# gen_pause_assets.py - pack pause_src/pause.txt into the pause-overlay ROMs.
# Copyright (c) 2026 XelaNotPu   SPDX-License-Identifier: GPL-3.0-or-later
#
# Emits two Quartus .mif ROMs consumed by rtl/pause_overlay.v at synthesis:
#   rtl/pause_assets/patreon_text.mif   COLS x ROWS ASCII grid (space-padded)
#   rtl/pause_assets/patreon_color.mif  ROWS per-line tier colour index
# and prints the line count so TEXT_LOOP in pause_overlay.v can be set.
#
# Colour index -> RGB is decoded in pause_overlay.v (kept in sync there):
#   0 white(names/body)  1 amber(--- banners ---)  2 gold(Hall of Fame)
#   3 cyan(High Score)   4 green(Insert Coin)
# ---------------------------------------------------------------------------
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC  = os.path.join(ROOT, "pause_src", "pause.txt")
OUT  = os.path.join(ROOT, "rtl", "pause_assets")

COLS = 40    # chars per line; MUST equal TEXT_WIDTH/8 in pause_overlay.v
ROWS = 128   # ROM rows (text grid height)
WHITE, AMBER, GOLD, CYAN, GREEN = 0, 1, 2, 3, 4

def line_colour(line, tier):
    """(colour for THIS line, tier carried to following lines)."""
    s = line.strip()
    if s.startswith('---'):        return AMBER, WHITE   # banner amber; reset tier
    if 'Hall of Fame' in line:     return GOLD,  GOLD
    if 'High Score'   in line:     return CYAN,  CYAN
    if 'Insert Coin'  in line:     return GREEN, GREEN
    if s == '':                    return WHITE, tier    # blank: colour irrelevant
    return tier, tier                                    # name/body inherits tier

def write_mif(path, width, depth, values):
    with open(path, 'w') as f:
        f.write("WIDTH=%d;\nDEPTH=%d;\nADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n"
                % (width, depth))
        for addr, v in enumerate(values):
            f.write("%X : %02X;\n" % (addr, v))
        f.write("END;\n")

lines = open(SRC, encoding='utf-8').read().split('\n')
if lines and lines[-1] == '':
    lines = lines[:-1]                     # drop the single trailing-newline element

text, colour, tier = [], [], WHITE
for row in range(ROWS):
    if row < len(lines):
        raw = lines[row][:COLS]            # clip to grid width (all lines fit in COLS)
        c, tier = line_colour(lines[row], tier)
    else:
        raw, c = '', WHITE                 # blank padding rows after the text
    text.extend(ord(ch) & 0x7F for ch in raw.ljust(COLS))
    colour.append(c)

write_mif(os.path.join(OUT, "patreon_text.mif"),  8, COLS * ROWS, text)
write_mif(os.path.join(OUT, "patreon_color.mif"), 8, ROWS,        colour)
print("content lines: %d  (set TEXT_LOOP = lines + gap in pause_overlay.v)" % len(lines))
print("wrote patreon_text.mif (%dx%d=%d) + patreon_color.mif (%d)"
      % (COLS, ROWS, COLS * ROWS, ROWS))
