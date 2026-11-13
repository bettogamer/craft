#!/usr/bin/env python3
"""
export-shapes.py — Generates the prefab rounded-shape masks for Craft
Spec: docs/components/switch.md (FR-052/FR-053)
ADR:  docs/adr/0018-formas-redondeadas-texturas-prefabricadas.md
      docs/adr/0016-atlas-lucide-completo.md (TGA-RLE pipeline, reused here)

Outputs (one WHITE anti-aliased shape per file, on a transparent background):
  Craft/media/shape_pill_32x18.tga   256×128  — Switch default track
  Craft/media/shape_pill_24x14.tga   256×128  — Switch sm track
  Craft/media/shape_circle.tga       128×128  — Switch thumb
  Craft/media/shape_ring_<n>.tga     128×128  — ProgressRing track/arc, band = D/n (FR-087)
  Craft/media/shape_cring_<d>.tga    128×128  — 1px corner outline shown d px across (FR-141)
  Craft/media/shape_arrow.tga        256×256  — solid arrow pointing UP (FR-120)
  Craft/media/shape_chevron.tga      256×256  — chevron (head, no shaft) pointing UP (FR-120)
  Craft/media/shape_arrow_curved.tga 256×256  — U-turn arrow, head pointing UP (FR-120)
  Craft/theme/Shapes.lua             — name → filename descriptor (+ geometry for rings)

Why ONE FILE PER SHAPE (not a sub-atlas):
  A WoW MaskTexture applied via AddMaskTexture masks the target by the mask's
  ALPHA stretched over the target rect. In 12.0.7 the mask IGNORES SetTexCoord —
  a shared atlas gets mapped whole onto every target, producing garbage ("garabatos"
  in the pill edge, a broken thumb). The reliable pattern (used across UI addons)
  is a dedicated single-shape file per mask, sampled whole with NO SetTexCoord.
  The same files also serve hypothesis B (baked): SetTexture + SetVertexColor.

Why POWER-OF-TWO files with pre-distorted caps:
  POT-per-side textures are guaranteed to load. The Switch tracks are not square,
  so the pill's circular caps would squash when the POT file is stretched to the
  track rect. We PRE-DISTORT the caps into ellipses (rx computed from the target
  aspect) so they land perfectly circular AFTER WoW stretches the file to the
  on-screen size. The thumb circle is a square file → no distortion.

Edge quality (mipmaps via POT + TRILINEAR):
  The shape is displayed much smaller than its native size, so naive minification
  aliases the edge ("pixelated"). The real fix is MIPMAPS: WoW auto-generates a mip
  chain for POWER-OF-TWO textures, and the consumer requests TRILINEAR filtering so
  minification samples the mip chain — a smooth downscale at any UIScale. That is the
  main reason these files are POT. We keep a MODERATE base size (≈4× the on-screen
  size) rendered at a high internal oversample for a clean base + mip chain, and leave
  a small transparent GUTTER around the shape (like the icon cells) so the edge has
  room to fade. The gutter insets the shape ≈0.5px on screen — which also matches the
  Switch's real 1px transparent border in Lyra.

Requirements:
  pip install Pillow

Usage:
  python3 scripts/export-shapes.py
  python3 scripts/export-shapes.py --no-rle   # uncompressed TGA (plan B, ADR-0016 §6)
"""

import os
import sys
import argparse
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("ERROR: 'Pillow' not installed. Run: pip install Pillow")
    sys.exit(1)

# Windows consoles default to cp1252, which can't encode the status glyphs below.
try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

# ─── Configuration ────────────────────────────────────────────────────────────

RENDER_SCALE = 8            # internal oversample before LANCZOS → clean base + mip chain
GUTTER       = 2            # transparent margin (file px) so the edge can fade

REPO_ROOT  = Path(__file__).parent.parent
MEDIA_DIR  = REPO_ROOT / "Craft" / "media"
SHAPES_LUA = REPO_ROOT / "Craft" / "theme" / "Shapes.lua"

# ─── Shape catalog ────────────────────────────────────────────────────────────
# Each shape: logical name, output file, POT file dimensions, kind, and the
# on-screen target size (the rect the mask will be stretched onto) — used to
# pre-distort the pill caps so they render circular after the stretch. File sizes
# are kept MODERATE (≈4× the on-screen size) so WoW's un-mipmapped downscale stays
# gentle and the baked AA survives (8× looked pixelated — see module docstring).

# ─── Ring family (FR-087, Craft.ProgressRing) ─────────────────────────────────
# An annulus whose band is 1/n of the FILE side. The file is stretched 1:1 onto the
# component's square rect, so a "ring_8" drawn at size S has a band of S/8 — which is
# exactly the `thickness = size/8` default the FR asks for. Thickness is therefore
# QUANTISED to this family (the component snaps to the nearest ratio): a mask/fill file
# bakes its own hole radius, and WoW cannot inset one at runtime.
RING_DENOMS     = [4, 6, 8, 12, 16]
RING_FILE_SIZE  = 128          # POT → mip chain; ≈4× the 32px sweet spot, fine down to 16px

# ─── Corner-ring family (FR-141, Craft.RoundedSurface) ─────────────────────────
# A 1px OUTLINE for a rounded corner: an annulus whose band is 1/D of the visible
# DISC (not of the file), so when the disc is shown D physical px across the band
# is exactly 1 physical px. A baked band scales with the piece, so there is one file
# per on-screen diameter; the primitive picks the nearest D from the corner's real
# radius in physical px (Theme.px), like Icons picks its atlas density (FR-137).
# ±1 around D keeps the band within 1±1/D px, so the list thins out as D grows.
CRING_DIAMS     = list(range(3, 25)) + list(range(26, 41, 2)) + [44, 48, 56, 64]
CRING_FILE_SIZE = 128

SHAPES = [
    # name          file                       fw    fh   kind     target (w,h)  extra
    ("pill_32x18", "shape_pill_32x18.tga",     128,   64, "pill",  (32, 18),     None),
    ("pill_24x14", "shape_pill_24x14.tga",     128,   64, "pill",  (24, 14),     None),
    ("circle",     "shape_circle.tga",          64,   64, "circle", (16, 16),    None),
] + [
    ("ring_%d" % n, "shape_ring_%d.tga" % n,
     RING_FILE_SIZE, RING_FILE_SIZE, "ring", (RING_FILE_SIZE, RING_FILE_SIZE), n)
    for n in RING_DENOMS
] + [
    # ─── Direction family (FR-120, consumer textures — e.g. SMRT aura picker) ─────
    # Shown LARGE (up to ~200px, rotated freely by the consumer with SetRotation), so
    # the files are 256² and drawn in a single orientation (UP). Square file, square
    # rect: no pre-distortion. Never SetTexCoord'd (whole-file sampling, like masks).
    ("arrow",        "shape_arrow.tga",        256, 256, "arrow",        (256, 256), None),
    ("chevron",      "shape_chevron.tga",      256, 256, "chevron",      (256, 256), None),
    ("arrow_curved", "shape_arrow_curved.tga", 256, 256, "arrow_curved", (256, 256), None),
] + [
    ("cring_%d" % d, "shape_cring_%d.tga" % d,
     CRING_FILE_SIZE, CRING_FILE_SIZE, "cring", (d, d), d)
    for d in CRING_DIAMS
]

# ─── Drawing ──────────────────────────────────────────────────────────────────

def draw_pill(fw: int, fh: int, target) -> Image.Image:
    """Renders a WHITE stadium inside an fw×fh file, inset by GUTTER on every side.
    The caps are ellipses whose horizontal radius is chosen so that, once WoW
    stretches the WHOLE file onto the target (tw×th) rect, the caps become perfect
    half-circles. The content box is (fw-2g)×(fh-2g):
      vertical   ry = ch/2
      horizontal rx = (ch/2) · (th·fw) / (fh·tw)   (circular on screen after stretch)
    """
    tw, th = target
    cw, ch = fw - 2 * GUTTER, fh - 2 * GUTTER
    ry = ch / 2.0
    rx = (ch / 2.0) * (th * fw) / (fh * tw)     # pre-distorted cap radius (file px)
    rx = min(rx, cw / 2.0)                       # caps must not overlap

    os_ = RENDER_SCALE
    W, H, G = fw * os_, fh * os_, GUTTER * os_
    RX = rx * os_
    x0, y0, x1, y1 = G, G, W - G - 1, H - G - 1
    img  = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    white = (255, 255, 255, 255)

    # Center rectangle + two elliptical caps (their inner halves overlap the rect).
    draw.rectangle([x0 + RX, y0, x1 - RX, y1], fill=white)
    draw.ellipse([x0, y0, x0 + 2 * RX, y1], fill=white)             # left cap
    draw.ellipse([x1 - 2 * RX, y0, x1, y1], fill=white)            # right cap

    return img.resize((fw, fh), Image.LANCZOS)

def draw_circle(fw: int, fh: int) -> Image.Image:
    """Renders a WHITE disc inside a square file, inset by GUTTER (thumb — no
    aspect distortion; the gutter gives the edge room to anti-alias)."""
    os_ = RENDER_SCALE
    W, H, G = fw * os_, fh * os_, GUTTER * os_
    img  = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    ImageDraw.Draw(img).ellipse([G, G, W - G - 1, H - G - 1], fill=(255, 255, 255, 255))
    return img.resize((fw, fh), Image.LANCZOS)

def draw_ring(fw: int, fh: int, denom: int) -> Image.Image:
    """Renders a WHITE annulus inside a square file, inset by GUTTER, with a band of
    fw/denom file px. The hole is PUNCHED (ImageDraw writes values, it does not
    composite) before the LANCZOS downscale, so BOTH edges come out anti-aliased.

    The consumer stretches the whole file onto its square rect and never crops the
    circle, so `inset` and `1/denom` are all the geometry Craft.ProgressRing needs to
    know where the band actually lives (see Shapes.lua `_geom`)."""
    os_ = RENDER_SCALE
    W, H, G = fw * os_, fh * os_, GUTTER * os_
    band = (fw / float(denom)) * os_
    img  = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([G, G, W - G - 1, H - G - 1], fill=(255, 255, 255, 255))
    draw.ellipse([G + band, G + band, W - G - 1 - band, H - G - 1 - band], fill=(0, 0, 0, 0))
    return img.resize((fw, fh), Image.LANCZOS)

def draw_cring(fw: int, fh: int, diam: int) -> Image.Image:
    """Corner-ring outline (FR-141): like draw_ring, but the band is 1/diam of the
    visible DISC (file side minus both gutters), so shown `diam` physical px wide
    it is 1 physical px thick. Hole punched before LANCZOS: both edges AA'd."""
    os_ = RENDER_SCALE
    W, H, G = fw * os_, fh * os_, GUTTER * os_
    band = ((fw - 2 * GUTTER) / float(diam)) * os_
    img  = Image.new("RGBA", (W, H), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    draw.ellipse([G, G, W - G - 1, H - G - 1], fill=(255, 255, 255, 255))
    draw.ellipse([G + band, G + band, W - G - 1 - band, H - G - 1 - band], fill=(0, 0, 0, 0))
    return img.resize((fw, fh), Image.LANCZOS)

def _canvas(fw: int, fh: int):
    os_ = RENDER_SCALE
    img = Image.new("RGBA", (fw * os_, fh * os_), (255, 255, 255, 0))
    return img, ImageDraw.Draw(img), os_

def draw_arrow(fw: int, fh: int) -> Image.Image:
    """Solid arrow pointing UP: a triangular head over a shaft, centred, the whole
    figure inside a 1/16 margin (bigger than GUTTER: the consumer rotates it freely,
    and a corner-touching tip would clip against the rect on the diagonal)."""
    img, draw, os_ = _canvas(fw, fh)
    W, H = fw * os_, fh * os_
    m = W / 16.0
    cx = W / 2.0
    head_h = (H - 2 * m) * 0.48         # head takes ~half the height
    half_w = (W - 2 * m) / 2.0          # head spans the full width
    shaft = (W - 2 * m) * 0.36 / 2.0    # shaft half-width
    top, base = m, m + head_h
    draw.polygon([(cx, top), (cx + half_w, base), (cx - half_w, base)], fill=(255, 255, 255, 255))
    draw.rectangle([cx - shaft, base - os_, cx + shaft, H - m], fill=(255, 255, 255, 255))
    return img.resize((fw, fh), Image.LANCZOS)

def draw_chevron(fw: int, fh: int) -> Image.Image:
    """Chevron pointing UP (a head without a shaft, like lucide chevron-up but
    solid-weight): the band between two nested carets, mitred at the tip."""
    img, draw, os_ = _canvas(fw, fh)
    W, H = fw * os_, fh * os_
    m = W / 16.0
    cx = W / 2.0
    half_w = (W - 2 * m) / 2.0
    tip, foot = H * 0.22, H * 0.74      # outer caret: tip and the feet's outer edge
    band = H * 0.20                     # vertical thickness of the band
    draw.polygon([
        (cx, tip), (cx + half_w, foot), (cx + half_w, foot + band * 0.35),
        (cx + half_w - band * 0.55, foot + band * 0.35),
        (cx, tip + band * 1.25),
        (cx - half_w + band * 0.55, foot + band * 0.35),
        (cx - half_w, foot + band * 0.35), (cx - half_w, foot),
    ], fill=(255, 255, 255, 255))
    return img.resize((fw, fh), Image.LANCZOS)

def draw_arrow_curved(fw: int, fh: int) -> Image.Image:
    """U-turn arrow («gira» / «cambia de lado»): a half-ring band on the left that
    comes back up into an arrowhead on the right, pointing UP like the others."""
    img, draw, os_ = _canvas(fw, fh)
    W, H = fw * os_, fh * os_
    m = W / 16.0
    band = W * 0.14
    # Arc: the lower half of a ring whose outer box spans [m, ~0.80W] horizontally.
    ox0, ox1 = m, W * 0.80
    r_out = (ox1 - ox0) / 2.0
    acx, acy = (ox0 + ox1) / 2.0, H * 0.56
    white, clear = (255, 255, 255, 255), (0, 0, 0, 0)
    draw.ellipse([acx - r_out, acy - r_out, acx + r_out, acy + r_out], fill=white)
    r_in = r_out - band
    draw.ellipse([acx - r_in, acy - r_in, acx + r_in, acy + r_in], fill=clear)
    draw.rectangle([0, 0, W, acy], fill=clear)              # keep only the lower half
    # Left leg: straight up from the arc to the top margin area (the "tail").
    draw.rectangle([ox0, H * 0.30, ox0 + band, acy + os_], fill=white)
    # Right leg: up from the arc into the head.
    rx0 = ox1 - band
    head_base = H * 0.40
    draw.rectangle([rx0, head_base - os_, ox1, acy + os_], fill=white)
    hcx = (rx0 + ox1) / 2.0
    hw = band * 1.55
    draw.polygon([(hcx, m), (hcx + hw, head_base), (hcx - hw, head_base)], fill=white)
    return img.resize((fw, fh), Image.LANCZOS)

# ─── Save TGA ─────────────────────────────────────────────────────────────────

def save_tga(img: Image.Image, path: Path, rle: bool = True):
    """Saves a shape as a BGRA TGA (WoW-friendly). RLE is lossless; --no-rle is
    the plan B if the client rejects the compression (ADR-0016 §6)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    r, g, b, a = img.split()
    bgra = Image.merge("RGBA", (b, g, r, a))
    if rle:
        bgra.save(str(path), format="TGA", compression="tga_rle")
    else:
        bgra.save(str(path), format="TGA")
    kb = os.path.getsize(path) / 1024
    print(f"  ✅ {path.relative_to(REPO_ROOT)} ({img.size[0]}×{img.size[1]}px, "
          f"{kb:.1f} KB, {'RLE' if rle else 'uncompressed'})")

# ─── Generate Shapes.lua ──────────────────────────────────────────────────────

def generate_shapes_lua():
    """Writes Craft/theme/Shapes.lua — the name → filename descriptor consumed by
    Switch (and future round components). Versioned like Atlas.lua (production bug
    #1): an older embedded copy loading later must not clobber a newer descriptor.
    No UVs: each mask uses its whole file (12.0.7 ignores SetTexCoord on masks)."""
    lines = [
        "-- Shapes.lua — prefab rounded-shape files for Craft (ADR-0018)",
        "-- AUTO-GENERATED by scripts/export-shapes.py",
        "-- DO NOT edit manually — overwritten on each regeneration",
        "--",
        "-- One WHITE anti-aliased shape PER FILE (a MaskTexture ignores SetTexCoord in",
        "-- 12.0.7, so a shared atlas can't be sub-sampled — each mask uses its whole file).",
        "-- Used as a MaskTexture (hypothesis A) or a baked fill (hypothesis B).",
        "-- Resolve via Craft.mediaPath .. file in the consumer (see Icons.lua).",
        "",
        'local Craft = LibStub("Craft-2.0")',
        "local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)",
        "",
        "-- Versioned (production bug #1): skip if a newer/equal Shapes descriptor is loaded.",
        "if Craft.Shapes and Craft.Shapes._buildOwner and Craft.Shapes._buildOwner >= _BUILD then return end",
        "Craft.Shapes = { _buildOwner = _BUILD }",
        "",
        "-- Logical shape name → media filename.",
        "Craft.Shapes._file = {",
    ]
    for name, file, _fw, _fh, _kind, _target, _extra in SHAPES:
        lines.append(f'    ["{name}"] = "{file}",')
    lines += [
        "}",
        "",
        "-- Geometry of the shapes whose consumer has to do maths against the drawn",
        "-- figure (rings — Craft.ProgressRing crops the band into sectors). Fractions",
        "-- of the SIDE of the file, which the consumer stretches 1:1 onto its rect:",
        "--   inset     — transparent gutter per side, so outerRadius = (0.5-inset)*size",
        "--   thickness — band width, so midRadius = (0.5-inset-thickness/2)*size",
        "Craft.Shapes._geom = {",
    ]
    for name, _file, fw, _fh, kind, _target, extra in SHAPES:
        if kind != "ring":
            continue
        lines.append(
            f'    ["{name}"] = {{ inset = {GUTTER / float(fw):.10g}, '
            f'thickness = {1.0 / float(extra):.10g} }},')
    lines += [
        "}",
        "",
        "-- Get(name) → filename (or nil). The consumer prepends Craft.mediaPath and",
        "-- passes it to a MaskTexture (hypothesis A) or a fill Texture (hypothesis B).",
        "function Craft.Shapes.Get(name)",
        "    return Craft.Shapes._file[name]",
        "end",
        "",
        "-- GetGeometry(name) → { inset, thickness } (or nil). Only rings carry it.",
        "function Craft.Shapes.GetGeometry(name)",
        "    return Craft.Shapes._geom[name]",
        "end",
        "",
        "-- Corner-ring outlines (FR-141): the on-screen DISC diameters, in physical px,",
        "-- that have a file whose band is exactly 1px at that size. Every file shares",
        "-- the gutter `cringInset` (fraction of the file side per edge).",
        "Craft.Shapes._cringDiams = {",
    ] + [
        "    " + ", ".join(str(d) for d in CRING_DIAMS[i:i + 16]) + ","
        for i in range(0, len(CRING_DIAMS), 16)
    ] + [
        "}",
        f"Craft.Shapes.cringInset = {GUTTER / float(CRING_FILE_SIZE):.10g}",
        "",
        "-- NearestCornerRing(d) → name, diam of the corner-ring file closest to a disc",
        "-- `d` physical px across (nil below the smallest: draw the corner square).",
        "function Craft.Shapes.NearestCornerRing(d)",
        "    local list = Craft.Shapes._cringDiams",
        "    if not d or d < list[1] - 0.5 then return nil end",
        "    local best = list[1]",
        "    for i = 2, #list do",
        "        if math.abs(list[i] - d) < math.abs(best - d) then best = list[i] end",
        "    end",
        '    return "cring_" .. best, best',
        "end",
        "",
    ]
    SHAPES_LUA.write_text("\n".join(lines), encoding="utf-8")
    print(f"  ✅ {SHAPES_LUA.relative_to(REPO_ROOT)} ({len(SHAPES)} shapes)")

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generates the prefab rounded-shape masks for Craft")
    parser.add_argument("--no-rle", action="store_true", help="Save uncompressed TGA (plan B, ADR-0016 §6)")
    args = parser.parse_args()

    print("Craft shape generator — prefab rounded shapes, one file per shape (ADR-0018)")
    print()

    print("1. Rendering + saving shapes...")
    for name, file, fw, fh, kind, target, extra in SHAPES:
        if kind == "pill":
            img = draw_pill(fw, fh, target)
        elif kind == "circle":
            img = draw_circle(fw, fh)
        elif kind == "ring":
            img = draw_ring(fw, fh, extra)
        elif kind == "cring":
            img = draw_cring(fw, fh, extra)
        elif kind == "arrow":
            img = draw_arrow(fw, fh)
        elif kind == "chevron":
            img = draw_chevron(fw, fh)
        elif kind == "arrow_curved":
            img = draw_arrow_curved(fw, fh)
        else:
            print(f"  ✗ {name}: unknown kind {kind}")
            sys.exit(1)
        save_tga(img, MEDIA_DIR / file, rle=not args.no_rle)

    print("\n2. Generating Shapes.lua...")
    generate_shapes_lua()

    print("\n✅ Done. Reboot the client (not /reload) to see new/changed TGAs (ADR-0018 §7).")


if __name__ == "__main__":
    main()
