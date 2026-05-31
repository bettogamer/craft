#!/usr/bin/env python3
"""
export-icons.py — Genera los atlas TGA de íconos Lucide para Craft
Spec: docs/components/icons.md
ADR:  docs/adr/0003-iconos-lucide-first-class.md

Salidas:
  Craft/media/lucide-16.tga    — atlas 512×512, grid 32×32, celdas de 16px
  Craft/media/lucide-24.tga    — atlas 512×512, grid 21×21, celdas de 24px
  Craft/icons/Atlas.lua        — tabla de coordenadas {col, row} por ícono

Requisitos:
  pip install Pillow cairosvg requests

Uso:
  python3 scripts/export-icons.py
  python3 scripts/export-icons.py --dry-run    # descarga SVGs, no genera TGA
  python3 scripts/export-icons.py --no-cache   # fuerza re-descarga de SVGs
"""

import os
import re
import sys
import math
import argparse
import urllib.request
from pathlib import Path

# ─── Verificar dependencias ───────────────────────────────────────────────────

try:
    from PIL import Image
except ImportError:
    print("ERROR: 'Pillow' no instalado. Ejecutar: pip install Pillow")
    sys.exit(1)

try:
    import cairosvg
except ImportError:
    print("ERROR: 'cairosvg' no instalado. Ejecutar: pip install cairosvg")
    sys.exit(1)

# ─── Catálogo de íconos ───────────────────────────────────────────────────────
# Orden exacto define la posición (col, row) en el atlas.
# Sistema (0-7) en row=0 col=0-7 — requeridos por componentes Craft.
# Conveniencia (8-23) en row=0 col=8-23.
# Fuente: docs/components/icons.md

ICONS = [
    # Sistema — requeridos por componentes Craft
    "check",          # col=0  Checkbox checked
    "minus",          # col=1  Checkbox indeterminate
    "chevron-down",   # col=2  Select trigger caret
    "chevron-right",  # col=3  Sidebar sub-item
    "chevron-up",     # col=4  Select scroll up
    "x",              # col=5  Dialog close
    "eye",            # col=6  Input password show
    "eye-off",        # col=7  Input password hide
    # Conveniencia — para devs que usan Craft
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

# ─── Configuración de atlas ───────────────────────────────────────────────────

ATLAS_SIZE   = 512          # TGA cuadrado 512×512
ICON_SIZES   = [16, 24]     # dos atlas: 16px y 24px

def cells_per_row(icon_size):
    return ATLAS_SIZE // icon_size   # 32 para 16px, 21 para 24px

# URL base de Lucide SVGs (rama main, nombres canónicos)
LUCIDE_URL = "https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/{name}.svg"

# ─── Rutas de salida ──────────────────────────────────────────────────────────

REPO_ROOT  = Path(__file__).parent.parent
MEDIA_DIR  = REPO_ROOT / "Craft" / "media"
ATLAS_LUA  = REPO_ROOT / "Craft" / "icons" / "Atlas.lua"
SVG_CACHE  = REPO_ROOT / ".icon-cache"    # cache local de SVGs descargados

# ─── Descarga de SVGs ─────────────────────────────────────────────────────────

def download_svg(name: str, force: bool = False) -> str:
    """Descarga el SVG de Lucide y lo retorna como string. Usa cache local."""
    cache_file = SVG_CACHE / f"{name}.svg"
    if not force and cache_file.exists():
        return cache_file.read_text(encoding="utf-8")

    url = LUCIDE_URL.format(name=name)
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            svg = resp.read().decode("utf-8")
    except Exception as e:
        print(f"  ✗ {name}: error de descarga — {e}")
        return None

    SVG_CACHE.mkdir(parents=True, exist_ok=True)
    cache_file.write_text(svg, encoding="utf-8")
    return svg

def prepare_svg(svg: str) -> str:
    """
    Prepara el SVG para rasterización:
    - Reemplaza currentColor con white (íconos blancos sobre fondo transparente)
    - WoW coloriza los íconos con SetVertexColor(r,g,b,a) después
    """
    svg = re.sub(r'stroke="currentColor"', 'stroke="white"', svg)
    svg = re.sub(r'fill="currentColor"',   'fill="white"',   svg)
    # Asegurar fondo transparente
    svg = re.sub(r'<svg([^>]*?)>', r'<svg\1>', svg)
    return svg

# ─── Rasterización ────────────────────────────────────────────────────────────

def rasterize_svg(svg: str, size: int) -> Image.Image:
    """Convierte SVG a imagen PIL RGBA de size×size."""
    png_bytes = cairosvg.svg2png(
        bytestring=svg.encode("utf-8"),
        output_width=size,
        output_height=size,
        background_color="transparent",
    )
    return Image.open(__import__("io").BytesIO(png_bytes)).convert("RGBA")

# ─── Construcción del atlas ───────────────────────────────────────────────────

def build_atlas(icons_imgs: dict, icon_size: int) -> tuple[Image.Image, dict]:
    """
    Construye el atlas TGA y retorna (imagen, mapa {name: (col, row)}).

    Layout:
      - Grid de celdas de icon_size × icon_size
      - cells_per_row = ATLAS_SIZE // icon_size
      - Los íconos se colocan en orden del catálogo ICONS
    """
    cpr    = cells_per_row(icon_size)
    atlas  = Image.new("RGBA", (ATLAS_SIZE, ATLAS_SIZE), (0, 0, 0, 0))
    coords = {}

    for idx, name in enumerate(ICONS):
        img = icons_imgs.get(name)
        if img is None:
            print(f"  ⚠ {name}: ícono no disponible, celda vacía")
            continue

        col = idx % cpr
        row = idx // cpr
        x   = col * icon_size
        y   = row * icon_size

        if x + icon_size > ATLAS_SIZE or y + icon_size > ATLAS_SIZE:
            print(f"  ✗ {name}: fuera de los límites del atlas (col={col}, row={row})")
            continue

        atlas.paste(img, (x, y))
        coords[name] = (col, row)

    return atlas, coords

# ─── Guardar TGA ─────────────────────────────────────────────────────────────

def save_tga(atlas: Image.Image, path: Path):
    """Guarda el atlas como TGA. WoW espera BGRA; Pillow escribe TGA como RGBA
    pero WoW acepta ambos formatos sin problema en versiones modernas."""
    path.parent.mkdir(parents=True, exist_ok=True)
    # Convertir RGBA → BGRA para máxima compatibilidad con WoW
    r, g, b, a = atlas.split()
    bgra = Image.merge("RGBA", (b, g, r, a))
    bgra.save(str(path), format="TGA")
    print(f"  ✅ {path.relative_to(REPO_ROOT)} ({atlas.size[0]}×{atlas.size[1]}px)")

# ─── Generar Atlas.lua ────────────────────────────────────────────────────────

def generate_atlas_lua(coords_16: dict, coords_24: dict):
    """
    Genera Craft/icons/Atlas.lua con las coordenadas UV reales del atlas generado.
    Sobreescribe el archivo existente.
    """
    lines = [
        "-- Atlas.lua — coordenadas UV del atlas TGA de íconos Lucide",
        "-- GENERADO AUTOMÁTICAMENTE por scripts/export-icons.py",
        "-- NO editar manualmente — se sobreescribe en cada release",
        "--",
        "-- Layout 16px: 512×512px, grid 32×32, celdas de 16px",
        "--   UV: left=col/32, right=(col+1)/32, top=row/32, bottom=(row+1)/32",
        "--",
        "-- Layout 24px: 512×512px, grid 21×21, celdas de 24px",
        "--   UV: left=col/21, right=(col+1)/21, top=row/21, bottom=(row+1)/21",
        "",
        'local Craft = LibStub("Craft-1.0")',
        "",
        "Craft.Icons = Craft.Icons or {}",
        "",
        "-- ─── Atlas 16px ────────────────────────────────────────────────────",
        "Craft.Icons._atlas16 = {",
    ]

    # Agrupar por sección sistema / conveniencia
    for i, name in enumerate(ICONS):
        if i == 0:
            lines.append("    -- Sistema (col 0-7) — requeridos por componentes Craft")
        elif i == 8:
            lines.append("    -- Conveniencia (col 8-23) — para devs que usan Craft")

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
    parser = argparse.ArgumentParser(description="Genera los atlas TGA de íconos Lucide para Craft")
    parser.add_argument("--dry-run",  action="store_true", help="Solo descargar SVGs, no generar TGA")
    parser.add_argument("--no-cache", action="store_true", help="Forzar re-descarga de SVGs")
    args = parser.parse_args()

    print(f"Craft icon atlas generator — {len(ICONS)} íconos")
    print(f"  Fuente: Lucide (github.com/lucide-icons/lucide)")
    print(f"  Salida: Craft/media/lucide-16.tga, lucide-24.tga")
    print()

    # 1. Descargar SVGs
    print("1. Descargando SVGs desde Lucide...")
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
        print(f"\n⚠ {len(failed)} íconos no descargados: {', '.join(failed)}")

    if args.dry_run:
        print("\nDry-run completado. SVGs en .icon-cache/")
        return

    # 2. Rasterizar en cada tamaño
    for icon_size in ICON_SIZES:
        print(f"\n2. Rasterizando a {icon_size}px...")
        imgs = {}
        for name, svg in svgs.items():
            try:
                imgs[name] = rasterize_svg(svg, icon_size)
                print(f"  ✓ {name}")
            except Exception as e:
                print(f"  ✗ {name}: {e}")

        # 3. Construir atlas
        print(f"\n3. Construyendo atlas {icon_size}px...")
        atlas, coords = build_atlas(imgs, icon_size)
        cpr = cells_per_row(icon_size)
        print(f"  Grid: {cpr}×{ATLAS_SIZE//icon_size} celdas, {len(coords)}/{len(ICONS)} íconos colocados")

        # 4. Guardar TGA
        print(f"\n4. Guardando TGA...")
        tga_path = MEDIA_DIR / f"lucide-{icon_size}.tga"
        save_tga(atlas, tga_path)

        # Guardar coords para Atlas.lua
        if icon_size == 16:
            coords_16 = coords
        else:
            coords_24 = coords

    # 5. Generar Atlas.lua
    print("\n5. Generando Atlas.lua...")
    generate_atlas_lua(coords_16, coords_24)

    print(f"\n✅ Completado. {len(ICONS)} íconos en atlas 16px y 24px.")
    print("   Ejecutar 'git diff Craft/icons/Atlas.lua' para verificar cambios de coords.")


if __name__ == "__main__":
    main()
