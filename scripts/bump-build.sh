#!/usr/bin/env bash
# bump-build.sh — increments CRAFT_BUILD in Craft/Craft.lua before a release
# ADR-0010: versioning strategy — build number is an always-increasing integer
#
# Usage:
#   bash scripts/bump-build.sh          # increment by 1 and commit
#   bash scripts/bump-build.sh --dry-run  # show the change without applying it

set -euo pipefail

FILE="Craft/Craft.lua"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

# Read current build
CURRENT=$(grep -E '^local CRAFT_BUILD = [0-9]+' "$FILE" | grep -oE '[0-9]+')
if [ -z "$CURRENT" ]; then
    echo "ERROR: 'local CRAFT_BUILD = <n>' not found in $FILE" >&2
    exit 1
fi

NEXT=$((CURRENT + 1))

echo "CRAFT_BUILD: $CURRENT → $NEXT"

if $DRY_RUN; then
    echo "(dry-run — no changes)"
    exit 0
fi

# Apply the change
sed -i.bak "s/^local CRAFT_BUILD = $CURRENT$/local CRAFT_BUILD = $NEXT/" "$FILE"
rm -f "${FILE}.bak"

# Verify the change was applied
VERIFY=$(grep -E '^local CRAFT_BUILD = [0-9]+' "$FILE" | grep -oE '[0-9]+')
if [ "$VERIFY" != "$NEXT" ]; then
    echo "ERROR: change was not applied correctly" >&2
    exit 1
fi

echo "Updated $FILE"

# Automatic commit
git add "$FILE"
git commit -m "chore: bump CRAFT_BUILD $CURRENT → $NEXT"

echo "Done. Next step: git tag v<MAJOR.MINOR.PATCH> && git push --tags"
