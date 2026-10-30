#!/usr/bin/env bash
set -euo pipefail

# Links the generated OpenCode port into the locations OpenCode reads:
#   agents/<name>.md    -> ~/.config/opencode/agents/<name>.md
#   commands/<name>.md  -> ~/.config/opencode/commands/<name>.md
#   skills/<name>/      -> ~/.config/opencode/skills/<name>/
#   AGENTS.md           -> ~/.config/opencode/AGENTS.md (global rules)
#   opencode.json       -> ~/.config/opencode/opencode.json (MCP servers, permission rules)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
OC_AGENTS_DIR="$SCRIPT_DIR/agents"
OC_COMMANDS_DIR="$SCRIPT_DIR/commands"
OC_SKILLS_DIR="$SCRIPT_DIR/skills"
OC_RULES="$SCRIPT_DIR/AGENTS.md"
OC_CONFIG="$SCRIPT_DIR/opencode.json"
TARGET_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
TARGET_AGENTS_DIR="$TARGET_DIR/agents"
TARGET_COMMANDS_DIR="$TARGET_DIR/commands"
TARGET_SKILLS_DIR="$TARGET_DIR/skills"
TARGET_RULES="$TARGET_DIR/AGENTS.md"
TARGET_CONFIG="$TARGET_DIR/opencode.json"

echo "Deploying OpenCode agents, commands, skills, AGENTS.md, and opencode.json via symlinks..."
echo "Source: $SCRIPT_DIR"
echo "Target: $TARGET_DIR"
echo ""

if [[ ! -d "$OC_AGENTS_DIR" || ! -d "$OC_COMMANDS_DIR" || ! -f "$OC_RULES" ]]; then
  echo "Generated OpenCode artifacts are missing. Running sync-from-claude skill script first..."
  "$SCRIPT_DIR/skills/sync-from-claude/scripts/sync-from-claude.sh"
  echo ""
fi

if ! "$SCRIPT_DIR/skills/sync-from-claude/scripts/sync-from-claude.sh" --check; then
  echo "" >&2
  echo "Refusing to deploy a stale port. Regenerate, commit, then deploy." >&2
  exit 1
fi

mkdir -p "$TARGET_AGENTS_DIR" "$TARGET_COMMANDS_DIR" "$TARGET_SKILLS_DIR"

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

# Remove links into this repo whose target no longer exists (renamed or removed
# agents, commands, and skills).
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
prune_stale "$TARGET_COMMANDS_DIR"
prune_stale "$TARGET_SKILLS_DIR"

if compgen -G "$OC_AGENTS_DIR/*.md" > /dev/null; then
  for src in "$OC_AGENTS_DIR"/*.md; do
    link_item "$src" "$TARGET_AGENTS_DIR/$(basename "$src")" "agents/$(basename "$src")"
  done
fi

if compgen -G "$OC_COMMANDS_DIR/*.md" > /dev/null; then
  for src in "$OC_COMMANDS_DIR"/*.md; do
    link_item "$src" "$TARGET_COMMANDS_DIR/$(basename "$src")" "commands/$(basename "$src")"
  done
fi

if compgen -G "$OC_SKILLS_DIR/*" > /dev/null; then
  for src in "$OC_SKILLS_DIR"/*; do
    [[ -d "$src" ]] || continue
    link_item "$src" "$TARGET_SKILLS_DIR/$(basename "$src")" "skills/$(basename "$src")"
  done
fi

# AGENTS.md and opencode.json: keep a hand-written, non-empty file as a dated backup before linking.
backup_hand_written() {
  local dst="$1"
  if [[ -f "$dst" && ! -L "$dst" && -s "$dst" ]]; then
    local backup="$dst.bak-$(date +%Y%m%d)"
    mv "$dst" "$backup"
    echo "  BACKUP $dst -> $backup"
  fi
}
backup_hand_written "$TARGET_RULES"
link_item "$OC_RULES" "$TARGET_RULES" "AGENTS.md"
backup_hand_written "$TARGET_CONFIG"
link_item "$OC_CONFIG" "$TARGET_CONFIG" "opencode.json"

echo ""
echo "Done."
