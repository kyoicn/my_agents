#!/usr/bin/env bash
set -euo pipefail

# Links the generated Antigravity port into the locations Antigravity's
# customization system reads (App, IDE, and CLI):
#   agents/<name>.md        -> ~/.gemini/config/agents/<name>.md
#   skills/<name>/          -> ~/.gemini/config/skills/<name>/ (App, IDE)
#                              ~/.gemini/antigravity-cli/skills/<name>/ (CLI)
#   GEMINI.md               -> ~/.gemini/GEMINI.md (global rules)
# and removes the previous port's links from the IDE knowledge store.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
AG_AGENTS_DIR="$SCRIPT_DIR/agents"
AG_SKILLS_DIR="$SCRIPT_DIR/skills"
AG_RULES="$SCRIPT_DIR/GEMINI.md"
TARGET_AGENTS_DIR="$HOME/.gemini/config/agents"
TARGET_APP_SKILLS_DIR="$HOME/.gemini/config/skills"
TARGET_CLI_SKILLS_DIR="$HOME/.gemini/antigravity-cli/skills"
TARGET_RULES="$HOME/.gemini/GEMINI.md"
LEGACY_KNOWLEDGE_DIR="$HOME/.gemini/antigravity/knowledge"

echo "Deploying Antigravity agents, skills, and GEMINI.md via symlinks..."
echo "Source: $SCRIPT_DIR"
echo "Target: $HOME/.gemini"
echo ""

if [[ ! -d "$AG_AGENTS_DIR" || ! -d "$AG_SKILLS_DIR" || ! -f "$AG_RULES" ]]; then
  echo "Generated Antigravity artifacts are missing. Running sync-from-claude skill script first..."
  "$SCRIPT_DIR/skills/sync-from-claude/scripts/sync-from-claude.sh"
  echo ""
fi

if ! "$SCRIPT_DIR/skills/sync-from-claude/scripts/sync-from-claude.sh" --check; then
  echo "" >&2
  echo "Refusing to deploy a stale port. Regenerate, commit, then deploy." >&2
  exit 1
fi

mkdir -p "$TARGET_AGENTS_DIR" "$TARGET_APP_SKILLS_DIR" "$TARGET_CLI_SKILLS_DIR"

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
# agents and skills).
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
prune_stale "$TARGET_APP_SKILLS_DIR"
prune_stale "$TARGET_CLI_SKILLS_DIR"

# The previous port linked knowledge items into the IDE's knowledge store.
if [[ -d "$LEGACY_KNOWLEDGE_DIR" ]]; then
  for link in "$LEGACY_KNOWLEDGE_DIR"/*; do
    [[ -L "$link" ]] || continue
    if [[ "$(readlink "$link")" == "$SCRIPT_DIR"/* ]]; then
      rm "$link"
      echo "  REMOVE legacy knowledge-item link $link"
    fi
  done
fi

if compgen -G "$AG_AGENTS_DIR/*.md" > /dev/null; then
  for src in "$AG_AGENTS_DIR"/*.md; do
    link_item "$src" "$TARGET_AGENTS_DIR/$(basename "$src")" "agents/$(basename "$src")"
  done
fi

if compgen -G "$AG_SKILLS_DIR/*" > /dev/null; then
  for src in "$AG_SKILLS_DIR"/*; do
    [[ -d "$src" ]] || continue
    name="$(basename "$src")"
    link_item "$src" "$TARGET_APP_SKILLS_DIR/$name" "skills/$name (app)"
    link_item "$src" "$TARGET_CLI_SKILLS_DIR/$name" "skills/$name (cli)"
  done
fi

# GEMINI.md: keep a hand-written, non-empty file as a dated backup before linking.
if [[ -f "$TARGET_RULES" && ! -L "$TARGET_RULES" && -s "$TARGET_RULES" ]]; then
  backup="$TARGET_RULES.bak-$(date +%Y%m%d)"
  mv "$TARGET_RULES" "$backup"
  echo "  BACKUP $TARGET_RULES -> $backup"
fi
link_item "$AG_RULES" "$TARGET_RULES" "GEMINI.md"

echo ""
echo "Done."
