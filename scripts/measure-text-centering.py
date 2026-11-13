"""measure-text-centering.py — measures how centred text sits inside boxes in a screenshot.

Born from FR-140/FR-146 (Badge, 2026-11-13): judging 1px centring BY EYE looped for three
rounds; measuring the pixels settled it in one. Use it on an UNSCALED in-game screenshot
taken at PIXEL-PERFECT scale (Craft_Browser button → CraftBrowser.PixelPerfectDemo(): 1 UI
unit = 1 physical px). Check first that a known box measures what it should (Badge h-5 =
20 px), otherwise the screenshot was rescaled and the numbers mean nothing.

Usage:
  python -I scripts/measure-text-centering.py shot.png "name,y0,y1[,x0,x1]" ...
Each band is a horizontal strip (in ORIGINAL image px) holding one row of components; the
script finds every box in it (column runs that differ from the band's background), then
reports, per box: box rows, ink rows (pixels clearly brighter than the box fill), and the
free rows above/below the ink. `diff` = above - below: 0 = centred, ±1 = the best possible
split when the free space is odd, |diff| >= 2 = really off.

Judge ONLY text with no descenders/accents (caps, "Default", "Normal"): a 'y', 'g' or 'É'
moves the ink box and fakes an off-centre result. Boxes over a coloured stage (non-black
background) are not detected well — use a plain band.
"""
import sys

from PIL import Image


def measure(im, name, y0, y1, x0=0, x1=None, gap_max=5, min_w=12, ink_delta=80):
    px = im.load()
    x1 = x1 or im.size[0]
    lum = lambda x, y: sum(px[x, y][:3]) / 3
    bg = sorted(lum(x, y0) for x in range(x0, x1))[(x1 - x0) // 2]
    diff_bg = lambda x, y: abs(lum(x, y) - bg) > 10

    cols = [any(diff_bg(x, y) for y in range(y0, y1)) for x in range(x0, x1)]
    segs, start, end, gap = [], None, None, 0
    for i, on in enumerate(cols):
        if on:
            if start is None:
                start = i
            end, gap = i, 0
        elif start is not None:
            gap += 1
            if gap > gap_max:
                segs.append((start + x0, end + x0))
                start = None
    if start is not None:
        segs.append((start + x0, end + x0))

    print(f"== {name} (bg {int(bg)})")
    for a, b in segs:
        if b - a < min_w:
            continue
        rows = [y for y in range(y0, y1) if any(diff_bg(x, y) for x in range(a, b + 1))]
        bt, bb = min(rows), max(rows)
        mid = range(a + 4, b - 3)
        fills = sorted(lum(x, y) for y in range(bt + 1, bb) for x in mid)
        fill = fills[len(fills) // 4] if fills else bg
        ink = [y for y in range(bt + 1, bb) if max(lum(x, y) for x in mid) > fill + ink_delta]
        if not ink:
            print(f"  x{a:5d}-{b:5d}  no ink")
            continue
        above, below = min(ink) - bt - 1, bb - max(ink) - 1
        print(f"  x{a:5d}-{b:5d}  box {bt}..{bb} h={bb - bt + 1}  ink {min(ink)}..{max(ink)} "
              f"({max(ink) - min(ink) + 1})  above {above} below {below}  diff {above - below:+d}")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    im = Image.open(sys.argv[1]).convert("RGB")
    print(f"image {im.size[0]}x{im.size[1]}")
    for spec in sys.argv[2:]:
        parts = spec.split(",")
        name, nums = parts[0], [int(v) for v in parts[1:]]
        measure(im, name, *nums)


if __name__ == "__main__":
    main()
