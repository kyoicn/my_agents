#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/claude"
TARGET_DIR="$HOME/.claude"

# Items to symlink: each becomes ~/.claude/<item> -> claude/<item>
LINK_ITEMS=(agents commands CLAUDE.md settings.json)

echo "Linking: $SOURCE_DIR -> $TARGET_DIR"
echo ""

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: source directory not found: $SOURCE_DIR" >&2
  exit 1
fi

for item in "${LINK_ITEMS[@]}"; do
  src="$SOURCE_DIR/$item"
  dst="$TARGET_DIR/$item"

  if [[ ! -e "$src" ]]; then
    echo "  SKIP  $item (not found in source)"
    continue
  fi

  # Remove existing target (file, dir, or old symlink)
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    rm -rf "$dst"
  fi

  ln -s "$src" "$dst"
  echo "  LINK  $item -> $src"
done

echo ""
echo "Done."
