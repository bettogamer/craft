#!/usr/bin/env bash
# bump-build.sh — increments CRAFT_BUILD (and updates Craft.VERSION) in Craft/Craft.lua before a release
# ADR-0010: versioning strategy — build number is an always-increasing integer
# FR-029: Craft.VERSION is the runtime version contract for consumers — it MUST match
#         the release tag. The script updates it when given the new version, and refuses
#         to cut a release whose Craft.VERSION still equals the last tag.
#
# Usage:
#   bash scripts/bump-build.sh 2.8.0            # bump CRAFT_BUILD + set Craft.VERSION, commit
#   bash scripts/bump-build.sh 2.8.0 --dry-run  # show the changes without applying them
#   bash scripts/bump-build.sh                  # legacy: build only — aborts if Craft.VERSION
#                                               # was not already bumped past the last v* tag

set -euo pipefail

FILE="Craft/Craft.lua"
DRY_RUN=false
NEW_VERSION=""

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *)
            if [[ "$arg" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                NEW_VERSION="$arg"
            else
                echo "ERROR: unrecognized argument '$arg' (expected X.Y.Z or --dry-run)" >&2
                exit 1
            fi
            ;;
    esac
done

# Read current build. head -1: the trailing comment on that line also contains
# digits ("Reset to 1", "+1 per release") — only the first number is the build.
CURRENT=$(grep -E '^local CRAFT_BUILD = [0-9]+' "$FILE" | grep -oE '[0-9]+' | head -1)
if [ -z "$CURRENT" ]; then
    echo "ERROR: 'local CRAFT_BUILD = <n>' not found in $FILE" >&2
    exit 1
fi

# Read current runtime version string.
CURRENT_VERSION=$(grep -E '^Craft\.VERSION = "[0-9]+\.[0-9]+\.[0-9]+"' "$FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "$CURRENT_VERSION" ]; then
    echo "ERROR: 'Craft.VERSION = \"X.Y.Z\"' not found in $FILE" >&2
    exit 1
fi

NEXT=$((CURRENT + 1))

if [ -n "$NEW_VERSION" ]; then
    if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
        echo "ERROR: Craft.VERSION is already \"$CURRENT_VERSION\" — pass the NEW release version" >&2
        exit 1
    fi
else
    # FR-029 guard: v2.7.0 shipped with Craft.VERSION = "2.6.0" because the release
    # process only bumped CRAFT_BUILD. If Craft.VERSION still equals the last release
    # tag, cutting a new release now would repeat that miss — demand the new version.
    LAST_TAG=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)
    if [ -n "$LAST_TAG" ] && [ "${LAST_TAG#v}" = "$CURRENT_VERSION" ]; then
        echo "ERROR: Craft.VERSION (\"$CURRENT_VERSION\") still equals the last release tag ($LAST_TAG)." >&2
        echo "       Pass the new version so it gets bumped too (FR-029):" >&2
        echo "       bash scripts/bump-build.sh <X.Y.Z>" >&2
        exit 1
    fi
fi

echo "CRAFT_BUILD:   $CURRENT → $NEXT"
if [ -n "$NEW_VERSION" ]; then
    echo "Craft.VERSION: $CURRENT_VERSION → $NEW_VERSION"
else
    echo "Craft.VERSION: $CURRENT_VERSION (unchanged — already bumped past the last tag)"
fi

if $DRY_RUN; then
    echo "(dry-run — no changes)"
    exit 0
fi

# Apply the changes. Match the number with a trailing boundary ([^0-9]|$) so the
# inline comment after `local CRAFT_BUILD = N` is preserved and "2" never matches "20".
sed -i.bak -E "s/^(local CRAFT_BUILD = )$CURRENT([^0-9]|$)/\1$NEXT\2/" "$FILE"
if [ -n "$NEW_VERSION" ]; then
    sed -i.bak -E "s/^(Craft\.VERSION = )\"$CURRENT_VERSION\"/\1\"$NEW_VERSION\"/" "$FILE"
fi
rm -f "${FILE}.bak"

# Verify the changes were applied (head -1: same comment-digits caveat as above)
VERIFY=$(grep -E '^local CRAFT_BUILD = [0-9]+' "$FILE" | grep -oE '[0-9]+' | head -1)
if [ "$VERIFY" != "$NEXT" ]; then
    echo "ERROR: CRAFT_BUILD change was not applied correctly" >&2
    exit 1
fi
if [ -n "$NEW_VERSION" ]; then
    VERIFY_VERSION=$(grep -E '^Craft\.VERSION = "[0-9]+\.[0-9]+\.[0-9]+"' "$FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    if [ "$VERIFY_VERSION" != "$NEW_VERSION" ]; then
        echo "ERROR: Craft.VERSION change was not applied correctly" >&2
        exit 1
    fi
fi

echo "Updated $FILE"

# Automatic commit
git add "$FILE"
if [ -n "$NEW_VERSION" ]; then
    git commit -m "chore: bump CRAFT_BUILD $CURRENT → $NEXT, Craft.VERSION → $NEW_VERSION"
    echo "Done. Next step: git tag v$NEW_VERSION && git push --tags"
else
    git commit -m "chore: bump CRAFT_BUILD $CURRENT → $NEXT"
    echo "Done. Next step: git tag v$CURRENT_VERSION && git push --tags"
fi
