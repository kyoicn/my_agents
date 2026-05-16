#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_AGENTS_DIR="$SCRIPT_DIR/agents"
CODEX_SKILLS_DIR="$SCRIPT_DIR/skills"
TARGET_AGENTS_DIR="$HOME/.codex/agents"
TARGET_SKILLS_DIR="$HOME/.codex/skills"

echo "Deploying Codex agents and skills via symlinks..."
echo "Source: $SCRIPT_DIR"
echo "Target: $HOME/.codex"
echo ""

if [[ ! -d "$CODEX_AGENTS_DIR" || ! -d "$CODEX_SKILLS_DIR" ]]; then
  echo "Generated Codex artifacts are missing. Running sync-from-claude.sh first..."
  "$SCRIPT_DIR/sync-from-claude.sh"
  echo ""
fi

mkdir -p "$TARGET_AGENTS_DIR" "$TARGET_SKILLS_DIR"

link_item() {
  local src="$1"
  local dst="$2"
  local label="$3"

  if [[ -L "$dst" || -e "$dst" ]]; then
    rm -rf "$dst"
  fi

  ln -s "$src" "$dst"
  echo "  LINK  $label -> $src"
}

if compgen -G "$CODEX_AGENTS_DIR/*.toml" > /dev/null; then
  for src in "$CODEX_AGENTS_DIR"/*.toml; do
    link_item "$src" "$TARGET_AGENTS_DIR/$(basename "$src")" "agents/$(basename "$src")"
  done
fi

if compgen -G "$CODEX_SKILLS_DIR/*" > /dev/null; then
  for src in "$CODEX_SKILLS_DIR"/*; do
    [[ -d "$src" ]] || continue
    link_item "$src" "$TARGET_SKILLS_DIR/$(basename "$src")" "skills/$(basename "$src")"
  done
fi

echo ""
echo "Done."
