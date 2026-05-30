#!/usr/bin/env bash
# bump-build.sh — incrementa CRAFT_BUILD en Craft/Craft.lua antes de un release
# ADR-0010: versioning strategy — el build number es un integer siempre creciente
#
# Uso:
#   bash scripts/bump-build.sh          # incrementa en 1 y hace commit
#   bash scripts/bump-build.sh --dry-run  # muestra el cambio sin aplicarlo

set -euo pipefail

FILE="Craft/Craft.lua"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

# Leer build actual
CURRENT=$(grep -E '^local CRAFT_BUILD = [0-9]+' "$FILE" | grep -oE '[0-9]+')
if [ -z "$CURRENT" ]; then
    echo "ERROR: no se encontró 'local CRAFT_BUILD = <n>' en $FILE" >&2
    exit 1
fi

NEXT=$((CURRENT + 1))

echo "CRAFT_BUILD: $CURRENT → $NEXT"

if $DRY_RUN; then
    echo "(dry-run — sin cambios)"
    exit 0
fi

# Aplicar el cambio
sed -i.bak "s/^local CRAFT_BUILD = $CURRENT$/local CRAFT_BUILD = $NEXT/" "$FILE"
rm -f "${FILE}.bak"

# Verificar que el cambio se aplicó
VERIFY=$(grep -E '^local CRAFT_BUILD = [0-9]+' "$FILE" | grep -oE '[0-9]+')
if [ "$VERIFY" != "$NEXT" ]; then
    echo "ERROR: el cambio no se aplicó correctamente" >&2
    exit 1
fi

echo "Actualizado $FILE"

# Commit automático
git add "$FILE"
git commit -m "chore: bump CRAFT_BUILD $CURRENT → $NEXT"

echo "Listo. Próximo paso: git tag v<MAJOR.MINOR.PATCH> && git push --tags"
