#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CODEX_AGENTS_DIR="$SCRIPT_DIR/agents"
CODEX_SKILLS_DIR="$SCRIPT_DIR/skills"
CODEX_AGENTS_MD="$SCRIPT_DIR/AGENTS.md"
TARGET_AGENTS_DIR="$HOME/.codex/agents"
TARGET_SKILLS_DIR="$HOME/.codex/skills"
TARGET_AGENTS_MD="$HOME/.codex/AGENTS.md"

echo "Deploying Codex agents, skills, and AGENTS.md via symlinks..."
echo "Source: $SCRIPT_DIR"
echo "Target: $HOME/.codex"
echo ""

if [[ ! -d "$CODEX_AGENTS_DIR" || ! -d "$CODEX_SKILLS_DIR" || ! -f "$CODEX_AGENTS_MD" ]]; then
  echo "Generated Codex artifacts are missing. Running sync-from-claude skill script first..."
  "$SCRIPT_DIR/skills/sync-from-claude/scripts/sync-from-claude.sh"
  echo ""
fi

if ! "$SCRIPT_DIR/skills/sync-from-claude/scripts/sync-from-claude.sh" --check; then
  echo "" >&2
  echo "Refusing to deploy a stale port. Regenerate, commit, then deploy." >&2
  exit 1
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

# Remove links into this repo whose target no longer exists (renamed or
# removed agents and skills, e.g. status -> reporter).
prune_stale() {
  local dir="$1"
  local link target
  for link in "$dir"/* "$dir"/.[!.]*; do
    [[ -L "$link" ]] || continue
    target="$(readlink "$link")"
    if [[ "$target" == "$SCRIPT_DIR"/* && ! -e "$link" ]]; then
      rm "$link"
      echo "  PRUNE $link (-> $target no longer exists)"
    fi
  done
}

prune_stale "$TARGET_AGENTS_DIR"
prune_stale "$TARGET_SKILLS_DIR"

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

# AGENTS.md: keep a hand-written file as a dated backup before linking.
if [[ -f "$TARGET_AGENTS_MD" && ! -L "$TARGET_AGENTS_MD" ]]; then
  backup="$TARGET_AGENTS_MD.bak-$(date +%Y%m%d)"
  mv "$TARGET_AGENTS_MD" "$backup"
  echo "  BACKUP $TARGET_AGENTS_MD -> $backup"
fi
link_item "$CODEX_AGENTS_MD" "$TARGET_AGENTS_MD" "AGENTS.md"

echo ""
echo "Done."
