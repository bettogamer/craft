#!/usr/bin/env python3
"""
export-icons.py — Generates Lucide icon TGA atlases for Craft
Spec: docs/components/icons.md
ADR:  docs/adr/0003-iconos-lucide-first-class.md

Outputs:
  Craft/media/lucide-16.tga    — 512×512 atlas, 32×32 grid, 16px cells
  Craft/media/lucide-24.tga    — 512×512 atlas, 21×21 grid, 24px cells
  Craft/icons/Atlas.lua        — coordinate table {col, row} per icon

Requirements:
  pip install Pillow cairosvg requests

Usage:
  python3 scripts/export-icons.py
  python3 scripts/export-icons.py --dry-run    # download SVGs only, no TGA generated
  python3 scripts/export-icons.py --no-cache   # force re-download of SVGs
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

# ─── Icon catalog ─────────────────────────────────────────────────────────────
# Exact order defines the position (col, row) in the atlas.
# System (0-7) in row=0 col=0-7 — required by Craft components.
# Convenience (8-23) in row=0 col=8-23.
# Source: docs/components/icons.md

ICONS = [
    # System — required by Craft components
    "check",          # col=0  Checkbox checked
    "minus",          # col=1  Checkbox indeterminate
    "chevron-down",   # col=2  Select trigger caret
    "chevron-right",  # col=3  Sidebar sub-item
    "chevron-up",     # col=4  Select scroll up
    "x",              # col=5  Dialog close
    "eye",            # col=6  Input password show
    "eye-off",        # col=7  Input password hide
    # Convenience — for devs using Craft
    "info",           # col=8
    "circle-check",   # col=9
    "circle-alert",   # col=10
    "triangle-alert", # col=11
    "loader-circle",  # col=12
    "search",         # col=13
    "plus",           # col=14
    "chevron-left",   # col=15
    "arrow-left",     # col=16
    "arrow-right",    # col=17
    "settings",       # col=18
    "user",           # col=19
    "menu",           # col=20
    "panel-left",     # col=21
    "grip-vertical",  # col=22
    "square-check",   # col=23
]

# ─── Atlas configuration ──────────────────────────────────────────────────────

ATLAS_SIZE   = 512          # Square TGA 512×512
ICON_SIZES   = [16, 24]     # two atlases: 16px and 24px

def cells_per_row(icon_size):
    return ATLAS_SIZE // icon_size   # 32 for 16px, 21 for 24px

# Base URL for Lucide SVGs (main branch, canonical names)
LUCIDE_URL = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/{name}.svg"

# ─── Output paths ─────────────────────────────────────────────────────────────

REPO_ROOT  = Path(__file__).parent.parent
MEDIA_DIR  = REPO_ROOT / "Craft" / "media"
ATLAS_LUA  = REPO_ROOT / "Craft" / "icons" / "Atlas.lua"
SVG_CACHE  = REPO_ROOT / ".icon-cache"    # local cache of downloaded SVGs

# ─── SVG download ─────────────────────────────────────────────────────────────

def download_svg(name: str, force: bool = False) -> str:
    """Downloads the Lucide SVG and returns it as a string. Uses local cache."""
    cache_file = SVG_CACHE / f"{name}.svg"
    if not force and cache_file.exists():
        return cache_file.read_text(encoding="utf-8")

    url = LUCIDE_URL.format(name=name)
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            svg = resp.read().decode("utf-8")
    except Exception as e:
        print(f"  ✗ {name}: download error — {e}")
        return None

    SVG_CACHE.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(svg, encoding="utf-8")
    return svg

def prepare_svg(svg: str) -> str:
    """
    Prepares the SVG for rasterization:
    - Replace currentColor with white (white icons on transparent background)
    - WoW colorizes icons with SetVertexColor(r,g,b,a) afterwards
    """
    svg = re.sub(r'stroke="currentColor"', 'stroke="white"', svg)
    svg = re.sub(r'fill="currentColor"',   'fill="white"',   svg)
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
                    # Approximate with line segments
                    N = 20
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
            ctx.arc(cx, cy, r, 0, 2 * 3.14159265)
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

def build_atlas(icons_imgs: dict, icon_size: int) -> tuple[Image.Image, dict]:
    """
    Builds the TGA atlas and returns (image, map {name: (col, row)}).

    Layout:
      - Grid of icon_size × icon_size cells
      - cells_per_row = ATLAS_SIZE // icon_size
      - Icons are placed in ICONS catalog order
    """
    cpr    = cells_per_row(icon_size)
    atlas  = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (0, 0, 0, 0))
    coords = {}

    for idx, name in enumerate(ICONS):
        img = icons_imgs.get(name)
        if img is None:
            print(f"  ⚠ {name}: icon not available, empty cell")
            continue

        col = idx % cpr
        row = idx // cpr
        x   = col * icon_size
        y   = row * icon_size

        if x + icon_size > ATLAS_SIZE or y + icon_size > ATLAS_SIZE:
            print(f"  ✗ {name}: outside atlas bounds (col={col}, row={row})")
            continue

        atlas.paste(img, (x, y))
        coords[name] = (col, row)

    return atlas, coords

# ─── Save TGA ─────────────────────────────────────────────────────────────────

def save_tga(atlas: Image.Image, path: Path):
    """Saves the atlas as TGA. WoW expects BGRA; Pillow writes TGA as RGBA
    but WoW accepts both formats without issue on modern versions."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # Convert RGBA → BGRA for maximum WoW compatibility
    r, g, b, a = atlas.split()
    bgra = Image.merge("RGBA", (b, g, r, a))
    bgra.save(str(path), format="TGA")
    print(f"  ✅ {path.relative_to(REPO_ROOT)} ({atlas.size[0]}×{atlas.size[1]}px)")

# ─── Generate Atlas.lua ───────────────────────────────────────────────────────

def generate_atlas_lua(coords_16: dict, coords_24: dict):
    """
    Generates Craft/icons/Atlas.lua with the real UV coordinates of the generated atlas.
    Overwrites the existing file.
    """
    lines = [
        "-- Atlas.lua — UV coordinates of the Lucide icon TGA atlas",
        "-- AUTO-GENERATED by scripts/export-icons.py",
        "-- DO NOT edit manually — overwritten on each release",
        "--",
        "-- Layout 16px: 512×512px, grid 32×32, 16px cells",
        "--   UV: left=col/32, right=(col+1)/32, top=row/32, bottom=(row+1)/32",
        "--",
        "-- Layout 24px: 512×512px, grid 21×21, 24px cells",
        "--   UV: left=col/21, right=(col+1)/21, top=row/21, bottom=(row+1)/21",
        "",
        'local Craft = LibStub("Craft-1.0")',
        "local _BUILD = ((select(2, ...)) or {}).CRAFT_BUILD or 0  -- this copy's build (see Craft.register)",
        "",
        "-- Versioned (production bug #1): skip if a newer/equal Icons atlas is already loaded.",
        "-- Atlas.lua and Icons.lua share the _buildOwner marker; Icons.lua attaches its methods",
        "-- only when _buildOwner matches its own build.",
        "if Craft.Icons and Craft.Icons._buildOwner and Craft.Icons._buildOwner >= _BUILD then return end",
        "Craft.Icons = { _buildOwner = _BUILD }",
        "",
        "-- ─── Atlas 16px ────────────────────────────────────────────────────",
        "Craft.Icons._atlas16 = {",
    ]

    # Group by system / convenience section
    for i, name in enumerate(ICONS):
        if i == 0:
            lines.append("    -- System (col 0-7) — required by Craft components")
        elif i == 8:
            lines.append("    -- Convenience (col 8-23) — for devs using Craft")

        if name in coords_16:
            col, row = coords_16[name]
            lines.append(f'    ["{name}"] = {{ {col}, {row} }},')
        else:
            lines.append(f'    -- ["{name}"] = MISSING,')

    lines += [
        "}",
        "",
        "-- ─── Atlas 24px ────────────────────────────────────────────────────",
        "Craft.Icons._atlas24 = {",
    ]

    for name in ICONS:
        if name in coords_24:
            col, row = coords_24[name]
            lines.append(f'    ["{name}"] = {{ {col}, {row} }},')
        else:
            lines.append(f'    -- ["{name}"] = MISSING,')

    lines.append("}")
    lines.append("")

    ATLAS_LUA.write_text("\n".join(lines), encoding="utf-8")
    print(f"  ✅ {ATLAS_LUA.relative_to(REPO_ROOT)}")

# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Generates Lucide icon TGA atlases for Craft")
    parser.add_argument("--dry-run",  action="store_true", help="Download SVGs only, do not generate TGA")
    parser.add_argument("--no-cache", action="store_true", help="Force re-download of SVGs")
    args = parser.parse_args()

    print(f"Craft icon atlas generator — {len(ICONS)} icons")
    print(f"  Source: Lucide (github.com/lucide-icons/lucide)")
    print(f"  Output: Craft/media/lucide-16.tga, lucide-24.tga")
    print()

    # 1. Download SVGs
    print("1. Downloading SVGs from Lucide...")
    svgs = {}
    failed = []
    for name in ICONS:
        svg = download_svg(name, force=args.no_cache)
        if svg:
            svgs[name] = prepare_svg(svg)
            print(f"  ✓ {name}")
        else:
            failed.append(name)

    if failed:
        print(f"\n⚠ {len(failed)} icons not downloaded: {', '.join(failed)}")

    if args.dry_run:
        print("\nDry-run complete. SVGs in .icon-cache/")
        return

    # 2. Rasterize at each size
    for icon_size in ICON_SIZES:
        print(f"\n2. Rasterizing to {icon_size}px...")
        imgs = {}
        for name, svg in svgs.items():
            try:
                imgs[name] = rasterize_svg(svg, icon_size)
                print(f"  ✓ {name}")
            except Exception as e:
                print(f"  ✗ {name}: {e}")

        # 3. Build atlas
        print(f"\n3. Building {icon_size}px atlas...")
        atlas, coords = build_atlas(imgs, icon_size)
        cpr = cells_per_row(icon_size)
        print(f"  Grid: {cpr}×{ATLAS_SIZE//icon_size} cells, {len(coords)}/{len(ICONS)} icons placed")

        # 4. Save TGA
        print(f"\n4. Saving TGA...")
        tga_path = MEDIA_DIR / f"lucide-{icon_size}.tga"
        save_tga(atlas, tga_path)

        # Save coords for Atlas.lua
        if icon_size == 16:
            coords_16 = coords
        else:
            coords_24 = coords

    # 5. Generate Atlas.lua
    print("\n5. Generating Atlas.lua...")
    generate_atlas_lua(coords_16, coords_24)

    print(f"\n✅ Done. {len(ICONS)} icons in 16px and 24px atlases.")
    print("   Run 'git diff Craft/icons/Atlas.lua' to verify coordinate changes.")


if __name__ == "__main__":
    main()
