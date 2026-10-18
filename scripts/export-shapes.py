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

SHAPES = [
    # name          file                       fw    fh   kind     target (w,h)  extra
    ("pill_32x18", "shape_pill_32x18.tga",     128,   64, "pill",  (32, 18),     None),
    ("pill_24x14", "shape_pill_24x14.tga",     128,   64, "pill",  (24, 14),     None),
    ("circle",     "shape_circle.tga",          64,   64, "circle", (16, 16),    None),
] + [
    ("ring_%d" % n, "shape_ring_%d.tga" % n,
     RING_FILE_SIZE, RING_FILE_SIZE, "ring", (RING_FILE_SIZE, RING_FILE_SIZE), n)
    for n in RING_DENOMS
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
        else:
            print(f"  ✗ {name}: unknown kind {kind}")
            sys.exit(1)
        save_tga(img, MEDIA_DIR / file, rle=not args.no_rle)

    print("\n2. Generating Shapes.lua...")
    generate_shapes_lua()

    print("\n✅ Done. Reboot the client (not /reload) to see new/changed TGAs (ADR-0018 §7).")


if __name__ == "__main__":
    main()
