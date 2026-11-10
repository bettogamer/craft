#!/usr/bin/env python3
"""
export-icons.py — Generates the full-set Lucide icon TGA atlas for Craft
Spec: docs/components/icons.md
ADR:  docs/adr/0003-iconos-lucide-first-class.md (bundled assets)
      docs/adr/0016-atlas-lucide-completo.md (full-set import, pinned release)

Outputs (FR-137 — one atlas per density, SAME 32×64 grid in all of them):
  Craft/media/lucide-16.tga    —  512×1024 atlas, 16px cells (14px glyph, 1px gutter)
  Craft/media/lucide-32.tga    — 1024×2048 atlas, 32px cells (28px glyph, 2px gutter)
  Craft/media/lucide.tga       — 2048×4096 atlas, 64px cells (56px glyph, 4px gutter)
                                 (all RLE-compressed TGA — lossless)
  Craft/icons/Atlas.lua        — coordinate table {col, row} per icon + alias map

Catalog (ADR-0016):
  The FULL Lucide set of the pinned release (LUCIDE_TAG) — enumerated from the
  official tarball, not a hand-maintained list. The 8 system icons required by
  Craft components keep row 0, cols 0–7; everything else is alphabetical.
  Deprecated Lucide aliases (filter → funnel, …) come from the per-icon JSON
  metadata and are emitted as Craft.Icons._aliases.

Densities (FR-137):
  Each icon is rasterized ONCE at SUPERSAMPLE px (224) and box-reduced (exact area
  average, integer factor) to the glyph size of every density. Icons.lua picks, per
  call, the smallest atlas whose glyph is >= the PHYSICAL pixels the icon will cover
  (size × effective scale / pixel factor), so WoW only ever downscales by < 2×. A
  single 56px atlas shown at 10-14px (4-6× reduction) broke the strokes; the old
  pixel-exact 16/24px atlases blurred because they were chosen by UI units, not by
  physical pixels (WoW upscaled them). See docs/components/icons.md.

Requirements:
  pip install Pillow cairosvg

Usage:
  python3 scripts/export-icons.py
  python3 scripts/export-icons.py --dry-run    # sync tarball + catalog only, no TGA
  python3 scripts/export-icons.py --no-cache   # force re-download of the tarball
  python3 scripts/export-icons.py --no-rle     # uncompressed TGA (plan B, ADR-0016 §6)
"""

import os
import re
import sys
import math
import argparse
import urllib.request
from pathlib import Path

# ─── Verify dependencies ──────────────────────────────────────────────────────

try:
    from PIL import Image
except ImportError:
    print("ERROR: 'Pillow' not installed. Run: pip install Pillow")
    sys.exit(1)

try:
    import cairosvg
    _RASTER_BACKEND = "cairosvg"
except (ImportError, OSError):
    # cairosvg requires libcairo system DLL (not available on Windows by default).
    # Fall back to pycairo + svg.path which bundle their own DLLs.
    try:
        import cairo as _pycairo
        import xml.etree.ElementTree as _ET
        from svg.path import parse_path as _parse_svg_path
        _RASTER_BACKEND = "pycairo"
    except ImportError:
        print("ERROR: No SVG rasterizer found.")
        print("  Option A (Linux/macOS): pip install cairosvg")
        print("  Option B (Windows):     pip install pycairo svg.path")
        sys.exit(1)

# ─── Icon catalog (ADR-0016: full Lucide set, pinned release) ─────────────────
# The catalog is ENUMERATED from the pinned Lucide release tarball — there is no
# hand-maintained list anymore. Order defines the (col, row) position:
#   - SYSTEM_ICONS first (row 0, cols 0-7) — required by Craft components.
#   - Everything else (remaining Lucide set + LOCAL_SVGS) alphabetical.
# Bumping LUCIDE_TAG is the only step to sync with upstream; record the new tag
# in docs/components/icons.md (its hash keys the CI .icon-cache).

LUCIDE_TAG  = "1.24.0"
TARBALL_URL = f"https://github.com/lucide-icons/lucide/archive/refs/tags/{LUCIDE_TAG}.tar.gz"

# Stroke weight. Lucide ships stroke-width="2" on the 24×24 viewBox. We bake it a hair
# heavier to counter the thinning that mipmap/TRILINEAR minification applies to thin
# line-art at small display sizes (see Icons.lua) — the goal is that a 24px icon reads as
# a solid ~2px. Deliberate legibility choice by the owner, a small deviation from exact
# shadcn fidelity. Tune against the 24px display; set to 2 for pixel-exact Lucide.
ICON_STROKE_WIDTH = 2.25

SYSTEM_ICONS = [
    # System — required by Craft components
    "check",          # col=0  Checkbox checked
    "minus",          # col=1  Checkbox indeterminate
    "chevron-down",   # col=2  Select trigger caret
    "chevron-right",  # col=3  Sidebar sub-item
    "chevron-up",     # col=4  Select scroll up
    "x",              # col=5  Dialog close
    "eye",            # col=6  Input password show
    "eye-off",        # col=7  Input password hide
]

# ─── Local (non-Lucide) glyphs ────────────────────────────────────────────────
# Glyphs Lucide doesn't provide (it is stroke-only — no filled shapes). Rendered
# through the same supersampled pipeline so they stay crisp at small sizes.
# NOTE: in the pycairo fallback, <circle> reads its OWN `fill` attribute (it does
# not inherit from <svg>), so fill must live on the element. stroke-width="0"
# silences the unconditional stroke pass.
LOCAL_SVGS = {
    "disc": (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" stroke-width="0">'
        '<circle cx="12" cy="12" r="12" fill="white"/></svg>'
    ),
    # Bottom-right resize grip (Craft.Window). Lucide has no corner-grip glyph: its
    # `grip*` family is the drag-to-reorder dot grid (DragList) and `move-diagonal*`
    # are ↖↘ arrows, which read as "expand/fullscreen". This is the universal desktop
    # affordance instead — three strokes of decreasing length parallel to the corner,
    # perpendicular to the NW-SE axis the handle actually resizes along.
    # Drawn on the standard 24×24 Lucide viewBox with stroke-width="2" so prepare_svg
    # bumps it to ICON_STROKE_WIDTH like every other icon.
    "resize-corner": (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
        'stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">'
        '<line x1="20" y1="4" x2="4" y2="20"/>'
        '<line x1="20" y1="10" x2="10" y2="20"/>'
        '<line x1="20" y1="16" x2="16" y2="20"/>'
        '</svg>'
    ),
}

# ─── Atlas configuration ──────────────────────────────────────────────────────
# Single supersampled atlas. Each icon is rendered at INNER px and pasted centered
# in a CELL px cell, leaving a GUTTER of transparent pixels on every side so that
# WoW's bilinear filtering can't bleed neighbouring cells when downscaling.

# Non-square atlas: WoW's conservative texture requirement is power-of-two PER
# SIDE, not square. History: 512×512 (FR-022) → 512×1024 (curated catalog) →
# 2048×4096 (ADR-0016: full Lucide set — 32×64 = 2048 slots for ~1750 icons,
# ~300 free for upstream growth). Cell/gutter/supersampling are UNCHANGED, so
# per-icon quality is identical; there are just more cells.
CPR        = 32             # cells per row (columns) — identical in every density
ROWS       = 64             # rows → 2048 slots — identical in every density

# FR-137: one atlas per density, smallest first. (cell px, gutter px, file name).
# Every size is power-of-two per side (CPR×cell by ROWS×cell). Cell boundaries sit on
# power-of-two texel boundaries, so a mip level never averages two cells together
# while the cell is still ≥ 1 texel. The 64px atlas keeps its historical name.
DENSITIES  = [
    (16, 1, "lucide-16.tga"),
    (32, 2, "lucide-32.tga"),
    (64, 4, "lucide.tga"),
]
SUPERSAMPLE = 224           # render size; every density's glyph (cell − 2·gutter) divides it

# The densest atlas, under its historical names
CELL       = DENSITIES[-1][0]
GUTTER     = DENSITIES[-1][1]
INNER      = CELL - GUTTER * 2   # 56px
ATLAS_W    = CPR * CELL
ATLAS_H    = ROWS * CELL

for _cell, _gut, _f in DENSITIES:
    assert SUPERSAMPLE % (_cell - 2 * _gut) == 0, f"{_f}: glyph must divide SUPERSAMPLE"

# ─── Output paths ─────────────────────────────────────────────────────────────

REPO_ROOT  = Path(__file__).parent.parent
MEDIA_DIR  = REPO_ROOT / "Craft" / "media"
ATLAS_LUA  = REPO_ROOT / "Craft" / "icons" / "Atlas.lua"
SVG_CACHE  = REPO_ROOT / ".icon-cache"    # local cache of the extracted tarball

# ─── Lucide sync (pinned release tarball) ─────────────────────────────────────

def sync_lucide(force: bool = False) -> Path:
    """Downloads the pinned Lucide release tarball (once) and extracts icons/
    (SVGs + JSON metadata) into the cache. Returns the extracted icons/ dir.
    One 3 MB request instead of ~1750 raw.githubusercontent calls (rate limits)."""
    import io
    import tarfile

    icons_dir = SVG_CACHE / f"lucide-{LUCIDE_TAG}" / "icons"
    if icons_dir.is_dir() and not force and any(icons_dir.glob("*.svg")):
        return icons_dir

    print(f"  ↓ {TARBALL_URL}")
    with urllib.request.urlopen(TARBALL_URL, timeout=60) as resp:
        data = resp.read()

    icons_dir.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
        for member in tar.getmembers():
            parts = member.name.split("/")
            # lucide-<tag>/icons/<name>.{svg,json} → flat extract, no path traversal
            if len(parts) == 3 and parts[1] == "icons" and member.isfile() \
                    and (parts[2].endswith(".svg") or parts[2].endswith(".json")):
                content = tar.extractfile(member).read()
                (icons_dir / Path(parts[2]).name).write_bytes(content)
    return icons_dir

# ─── Catalog + aliases ────────────────────────────────────────────────────────

def build_catalog(icons_dir: Path) -> list:
    """Full catalog in atlas order: SYSTEM_ICONS (row 0, cols 0-7) first, then
    the rest of the Lucide set plus LOCAL_SVGS, alphabetical."""
    names = {p.stem for p in icons_dir.glob("*.svg")}
    missing = [n for n in SYSTEM_ICONS if n not in names]
    if missing:
        print(f"ERROR: system icons missing from Lucide {LUCIDE_TAG}: {', '.join(missing)}")
        sys.exit(1)
    rest = sorted((names | set(LOCAL_SVGS)) - set(SYSTEM_ICONS))
    return list(SYSTEM_ICONS) + rest

def load_aliases(icons_dir: Path, catalog: list) -> dict:
    """Deprecated-name → canonical-name map from Lucide's per-icon JSON metadata
    (e.g. filter → funnel). Aliases that collide with a canonical name are skipped."""
    import json

    catalog_set = set(catalog)
    aliases = {}
    for jf in sorted(icons_dir.glob("*.json")):
        canonical = jf.stem
        if canonical not in catalog_set:
            continue
        try:
            meta = json.loads(jf.read_text(encoding="utf-8"))
        except ValueError:
            continue
        for entry in meta.get("aliases") or []:
            name = entry.get("name") if isinstance(entry, dict) else entry
            if name and name not in catalog_set:
                aliases[name] = canonical
    return aliases

# ─── SVG read ─────────────────────────────────────────────────────────────────

def read_svg(icons_dir: Path, name: str) -> str:
    """Returns the SVG source for an icon: Craft-synthesized glyphs (LOCAL_SVGS)
    inline, everything else from the extracted tarball."""
    if name in LOCAL_SVGS:
        return LOCAL_SVGS[name]
    svg_file = icons_dir / f"{name}.svg"
    if not svg_file.exists():
        return None
    return svg_file.read_text(encoding="utf-8")

def prepare_svg(svg: str) -> str:
    """
    Prepares the SVG for rasterization:
    - Replace currentColor with white (white icons on transparent background)
    - WoW colorizes icons with SetVertexColor(r,g,b,a) afterwards
    """
    svg = re.sub(r'stroke="currentColor"', 'stroke="white"', svg)
    svg = re.sub(r'fill="currentColor"',   'fill="white"',   svg)
    # Bump the stroke weight (ICON_STROKE_WIDTH). Target exactly "2" so Craft-local
    # glyphs that set their own width (LOCAL_SVGS `disc` uses stroke-width="0") stay
    # untouched. Lucide is uniform stroke-width="2" on the root, so this is a clean swap.
    if ICON_STROKE_WIDTH != 2:
        svg = re.sub(r'stroke-width="2"', f'stroke-width="{ICON_STROKE_WIDTH}"', svg)
    # Ensure transparent background
    svg = re.sub(r'<svg([^>]*?)>', r'<svg\1>', svg)
    return svg

# ─── Rasterization ────────────────────────────────────────────────────────────

def _rasterize_pycairo(svg: str, size: int) -> Image.Image:
    """
    Renders a Lucide SVG using pycairo + svg.path (Windows fallback).
    Lucide icons are stroke-only paths on a 24×24 viewBox.
    """
    import xml.etree.ElementTree as ET
    ns = {"svg": "http://www.w3.org/2000/svg"}
    root = ET.fromstring(svg)

    # Determine viewBox scale
    vb = root.get("viewBox", "0 0 24 24").split()
    vb_w = float(vb[2]) if len(vb) >= 3 else 24.0
    vb_h = float(vb[3]) if len(vb) >= 4 else 24.0
    scale_x = size / vb_w
    scale_y = size / vb_h

    surface = _pycairo.ImageSurface(_pycairo.FORMAT_ARGB32, size, size)
    ctx     = _pycairo.Context(surface)
    ctx.scale(scale_x, scale_y)

    # Default stroke from the SVG root
    default_stroke_w = float(root.get("stroke-width", "2"))

    def draw_element(el):
        stroke_w = float(el.get("stroke-width", default_stroke_w))
        ctx.set_line_width(stroke_w)
        ctx.set_line_cap(_pycairo.LINE_CAP_ROUND)
        ctx.set_line_join(_pycairo.LINE_JOIN_ROUND)
        ctx.set_source_rgba(1, 1, 1, 1)

        tag = el.tag.split("}")[-1]  # strip namespace
        if tag == "path":
            d = el.get("d", "")
            if not d:
                return
            path = _parse_svg_path(d)
            for seg in path:
                t = type(seg).__name__
                if t == "Move":
                    ctx.move_to(seg.end.real, seg.end.imag)
                elif t == "Line":
                    ctx.line_to(seg.end.real, seg.end.imag)
                elif t in ("CubicBezier", "Arc"):
                    # Approximate with line segments. N is high because we render
                    # supersampled (INNER px); faceting must stay invisible after
                    # WoW downscales to the display size.
                    N = 64
                    for i in range(1, N + 1):
                        pt = seg.point(i / N)
                        ctx.line_to(pt.real, pt.imag)
                elif t == "Close":
                    ctx.close_path()
            fill = el.get("fill", root.get("fill", "none"))
            if fill not in ("none", "transparent", ""):
                ctx.fill_preserve()
            ctx.stroke()

        elif tag == "circle":
            cx = float(el.get("cx", 0))
            cy = float(el.get("cy", 0))
            r  = float(el.get("r",  0))
            ctx.new_sub_path()
            ctx.arc(cx, cy, r, 0, 2 * math.pi)
            fill = el.get("fill", "none")
            if fill not in ("none", "transparent", ""):
                ctx.fill_preserve()
            ctx.stroke()

        elif tag == "ellipse":
            # Full Lucide set uses <ellipse> (database family, cone, drum, …).
            # Build the unit-circle path under a scaled CTM, then restore BEFORE
            # stroking so the stroke width stays uniform (not scaled per-axis).
            cx  = float(el.get("cx", 0))
            cy  = float(el.get("cy", 0))
            erx = float(el.get("rx", 0))
            ery = float(el.get("ry", erx) or erx)
            ctx.save()
            ctx.translate(cx, cy)
            ctx.scale(erx, ery)
            ctx.new_sub_path()
            ctx.arc(0, 0, 1, 0, 2 * math.pi)
            ctx.restore()
            fill = el.get("fill", "none")
            if fill not in ("none", "transparent", ""):
                ctx.fill_preserve()
            ctx.stroke()

        elif tag == "line":
            x1 = float(el.get("x1", 0)); y1 = float(el.get("y1", 0))
            x2 = float(el.get("x2", 0)); y2 = float(el.get("y2", 0))
            ctx.move_to(x1, y1); ctx.line_to(x2, y2)
            ctx.stroke()

        elif tag == "polyline" or tag == "polygon":
            pts_str = el.get("points", "")
            pts = [float(v) for v in pts_str.replace(",", " ").split()]
            if len(pts) >= 2:
                ctx.move_to(pts[0], pts[1])
                for i in range(2, len(pts) - 1, 2):
                    ctx.line_to(pts[i], pts[i + 1])
                if tag == "polygon":
                    ctx.close_path()
                ctx.stroke()

        elif tag == "rect":
            x = float(el.get("x", 0)); y = float(el.get("y", 0))
            w = float(el.get("width", 0)); h = float(el.get("height", 0))
            # SVG spec: if only one of rx/ry is specified, the other mirrors it
            rrx = float(el.get("rx") or 0)
            rry = float(el.get("ry") or 0)
            if rrx == 0: rrx = rry
            if rry == 0: rry = rrx
            if rrx > 0 or rry > 0:
                # Rounded rect (~320 icons in the full set use rx=). Elliptical
                # corners: unit arcs under a scaled CTM (restored per corner so
                # the stroke width stays uniform); cairo joins arcs with lines.
                rrx = min(rrx, w / 2); rry = min(rry, h / 2)

                def _corner(ccx, ccy, a0, a1):
                    ctx.save()
                    ctx.translate(ccx, ccy)
                    ctx.scale(rrx, rry)
                    ctx.arc(0, 0, 1, a0, a1)
                    ctx.restore()

                ctx.new_sub_path()
                _corner(x + w - rrx, y + rry,     -math.pi / 2, 0)
                _corner(x + w - rrx, y + h - rry, 0,            math.pi / 2)
                _corner(x + rrx,     y + h - rry, math.pi / 2,  math.pi)
                _corner(x + rrx,     y + rry,     math.pi,      3 * math.pi / 2)
                ctx.close_path()
            else:
                ctx.rectangle(x, y, w, h)
            fill = el.get("fill", "none")
            if fill not in ("none", "transparent", ""):
                ctx.fill_preserve()
            ctx.stroke()

        for child in el:
            draw_element(child)

    draw_element(root)

    # Convert ARGB32 to RGBA PIL image
    buf  = surface.get_data()
    img  = Image.frombuffer("RGBA", (size, size), buf, "raw", "BGRA", 0, 1)
    return img.copy()


def rasterize_svg(svg: str, size: int) -> Image.Image:
    """Converts SVG to a PIL RGBA image of size×size."""
    if _RASTER_BACKEND == "cairosvg":
        png_bytes = cairosvg.svg2png(
            bytestring=svg.encode("utf-8"),
            output_width=size,
            output_height=size,
            background_color="transparent",
        )
        return Image.open(__import__("io").BytesIO(png_bytes)).convert("RGBA")
    else:
        return _rasterize_pycairo(svg, size)

# ─── Atlas construction ───────────────────────────────────────────────────────

def downsample(img: Image.Image, inner: int) -> Image.Image:
    """Box-reduces a SUPERSAMPLE px render to inner px (exact area average).
    Glyphs are monochrome white, tinted later by SetVertexColor, so only the alpha
    (coverage) is reduced and RGB is forced to white: averaging straight RGB would
    pull the transparent pixels' black into the edges (dark fringe)."""
    factor = img.size[0] // inner
    alpha  = img.getchannel("A")
    if factor > 1:
        alpha = alpha.reduce(factor)
    white  = Image.new("L", alpha.size, 255)
    return Image.merge("RGBA", (white, white, white, alpha))


def build_atlas(catalog: list, icons_imgs: dict, cell: int, gutter: int) -> tuple[Image.Image, dict]:
    """
    Builds one density's TGA atlas and returns (image, {name: (col, row)}).

    Layout:
      - CPR×ROWS grid of CELL px cells (32×64 = 2048 slots)
      - Each INNER px icon is pasted centered in its cell, leaving GUTTER px of
        transparent margin so bilinear downscaling can't bleed adjacent cells.
      - Icons are placed in catalog order.
    """
    atlas  = Image.new("RGBA", (CPR * cell, ROWS * cell), (0, 0, 0, 0))
    coords = {}
    inner  = cell - gutter * 2

    for idx, name in enumerate(catalog):
        img = icons_imgs.get(name)
        if img is None:
            print(f"  ⚠ {name}: icon not available, empty cell")
            continue

        col = idx % CPR
        row = idx // CPR
        x   = col * cell + gutter
        y   = row * cell + gutter

        if col >= CPR or row >= ROWS:
            print(f"  ✗ {name}: outside atlas bounds (col={col}, row={row})")
            continue

        atlas.paste(downsample(img, inner), (x, y))
        coords[name] = (col, row)

    return atlas, coords

# ─── Save TGA ─────────────────────────────────────────────────────────────────

def save_tga(atlas: Image.Image, path: Path, rle: bool = True):
    """Saves the atlas as TGA. WoW expects BGRA; Pillow writes TGA as RGBA
    but WoW accepts both formats without issue on modern versions.
    RLE (lossless, measured ratio ~7% on line-art) keeps the full-set atlas at
    ~4-5 MB instead of 32 MB; --no-rle is the plan B if the client rejects it
    (ADR-0016 §6/§7 — verify in-game after any atlas layout change)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # Convert RGBA → BGRA for maximum WoW compatibility
    r, g, b, a = atlas.split()
    bgra = Image.merge("RGBA", (b, g, r, a))
    if rle:
        bgra.save(str(path), format="TGA", compression="tga_rle")
    else:
        bgra.save(str(path), format="TGA")
    size_mb = os.path.getsize(path) / (1024 * 1024)
    print(f"  ✅ {path.relative_to(REPO_ROOT)} ({atlas.size[0]}×{atlas.size[1]}px, "
          f"{size_mb:.1f} MB, {'RLE' if rle else 'uncompressed'})")

# ─── Generate Atlas.lua ───────────────────────────────────────────────────────

def generate_atlas_lua(catalog: list, coords: dict, aliases: dict):
    """
    Generates Craft/icons/Atlas.lua with the (col, row) of each icon in the single
    supersampled atlas, plus the deprecated-alias map. Overwrites the existing file.
    """
    lines = [
        "-- Atlas.lua — grid coordinates of the Lucide icon TGA atlas",
        "-- AUTO-GENERATED by scripts/export-icons.py",
        "-- DO NOT edit manually — overwritten on each release",
        "--",
        f"-- Catalog: FULL Lucide set, release {LUCIDE_TAG} pinned (ADR-0016)",
        f"-- Layout: grid {CPR}×{ROWS} (cols×rows), the SAME in every density atlas (FR-137):",
    ] + [
        f"--   {f}: {CPR * c}×{ROWS * c}px, {c}px cells ({c - 2 * g}px glyph + {g}px gutter)"
        for c, g, f in DENSITIES
    ] + [
        f"--   UV: left=col/{CPR}, right=(col+1)/{CPR}, top=row/{ROWS}, bottom=(row+1)/{ROWS}",
        "",
        'local Craft = LibStub("Craft-2.0")',
        "local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)",
        "",
        "-- Versioned (production bug #1): skip if a newer/equal Icons atlas is already loaded.",
        "-- Atlas.lua and Icons.lua share the _buildOwner marker; Icons.lua attaches its methods",
        "-- only when _buildOwner matches its own build.",
        "if Craft.Icons and Craft.Icons._buildOwner and Craft.Icons._buildOwner >= _BUILD then return end",
        "Craft.Icons = { _buildOwner = _BUILD }",
        "",
        f'Craft.Icons._lucide = "{LUCIDE_TAG}"  -- pinned Lucide release this atlas was built from',
        f"Craft.Icons._div  = {CPR}  -- columns (horizontal UV divisor in Icons.lua)",
        f"Craft.Icons._rows = {ROWS}  -- rows (vertical UV divisor in Icons.lua — atlas is non-square)",
        "",
        "-- FR-137: one atlas file per density, smallest first. Icons.lua picks the smallest",
        "-- whose glyph (cell - 2*gutter) covers the physical pixels the icon will occupy.",
        "Craft.Icons._densities = {",
    ] + [
        f'    {{ file = "{f}", cell = {c}, gutter = {g} }},' for c, g, f in DENSITIES
    ] + [
        "}",
        "",
        "Craft.Icons._atlas = {",
    ]

    for i, name in enumerate(catalog):
        if i == 0:
            lines.append("    -- System — required by Craft components (row 0, cols 0-7)")
        elif i == len(SYSTEM_ICONS):
            lines.append(f"    -- Full Lucide {LUCIDE_TAG} import (ADR-0016) — alphabetical"
                         " (+ Craft-local glyphs)")

        if name in coords:
            col, row = coords[name]
            lines.append(f'    ["{name}"] = {{ {col}, {row} }},')
        else:
            lines.append(f'    -- ["{name}"] = MISSING,')

    lines.append("}")
    lines.append("")
    lines.append("-- Deprecated Lucide names → canonical (from upstream JSON metadata).")
    lines.append("-- Icons.Get/Has/Apply resolve these; List() returns canonical names only.")
    lines.append("Craft.Icons._aliases = {")
    for old in sorted(aliases):
        lines.append(f'    ["{old}"] = "{aliases[old]}",')
    lines.append("}")
    lines.append("")

    ATLAS_LUA.write_text("\n".join(lines), encoding="utf-8")
    print(f"  ✅ {ATLAS_LUA.relative_to(REPO_ROOT)} "
          f"({len(coords)} icons, {len(aliases)} aliases)")

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generates the full-set Lucide icon TGA atlas for Craft")
    parser.add_argument("--dry-run",  action="store_true", help="Sync tarball + build catalog only, no TGA")
    parser.add_argument("--no-cache", action="store_true", help="Force re-download of the Lucide tarball")
    parser.add_argument("--no-rle",   action="store_true", help="Save uncompressed TGA (plan B, ADR-0016 §6)")
    args = parser.parse_args()

    print(f"Craft icon atlas generator — full Lucide set, release {LUCIDE_TAG} (ADR-0016)")
    print(f"  Source: {TARBALL_URL}")
    for c, g, f in DENSITIES:
        print(f"  Output: Craft/media/{f} ({CPR * c}×{ROWS * c}, {c}px cells, {c - 2 * g}px glyph)")
    print()

    # 1. Sync the pinned Lucide release and enumerate the catalog
    print("1. Syncing Lucide tarball...")
    icons_dir = sync_lucide(force=args.no_cache)
    catalog   = build_catalog(icons_dir)
    aliases   = load_aliases(icons_dir, catalog)
    print(f"  ✓ {len(catalog)} icons in catalog ({len(LOCAL_SVGS)} Craft-local), "
          f"{len(aliases)} deprecated aliases")

    if len(catalog) > CPR * ROWS:
        print(f"ERROR: catalog ({len(catalog)}) exceeds atlas slots ({CPR * ROWS}) — "
              f"grow ATLAS_H (power-of-two) and re-run.")
        sys.exit(1)

    if args.dry_run:
        print(f"\nDry-run complete. Tarball extracted in {SVG_CACHE.relative_to(REPO_ROOT)}/")
        return

    # 2. Rasterize once, supersampled (SUPERSAMPLE px); each density box-reduces it
    print(f"\n2. Rasterizing {len(catalog)} icons to {SUPERSAMPLE}px ({_RASTER_BACKEND})...")
    imgs = {}
    failed = []
    for name in catalog:
        svg = read_svg(icons_dir, name)
        if not svg:
            failed.append(name)
            continue
        try:
            imgs[name] = rasterize_svg(prepare_svg(svg), SUPERSAMPLE)
        except Exception as e:
            print(f"  ✗ {name}: {e}")
            failed.append(name)
    print(f"  ✓ {len(imgs)} rasterized" + (f", {len(failed)} FAILED: {', '.join(failed)}" if failed else ""))
    if failed:
        print("ERROR: full-set import must not have missing cells — fix the rasterizer/tarball and re-run.")
        sys.exit(1)

    # 3-4. Build and save one atlas per density (same grid → same coords)
    coords = None
    for cell, gutter, fname in DENSITIES:
        print(f"\n3. Building {fname} ({cell}px cells)...")
        atlas, dcoords = build_atlas(catalog, imgs, cell, gutter)
        assert coords is None or dcoords == coords, "densities must share the grid"
        coords = dcoords
        print(f"  Grid: {CPR}×{ROWS} cells ({cell}px), {len(coords)}/{len(catalog)} icons placed")
        save_tga(atlas, MEDIA_DIR / fname, rle=not args.no_rle)

    # 5. Generate Atlas.lua
    print("\n5. Generating Atlas.lua...")
    generate_atlas_lua(catalog, coords, aliases)

    print(f"\n✅ Done. {len(coords)} icons in {len(DENSITIES)} density atlases.")
    print("   Run 'git diff Craft/icons/Atlas.lua' to verify coordinate changes.")


if __name__ == "__main__":
    main()
