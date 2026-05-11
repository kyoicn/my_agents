#!/bin/bash

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# The repo root is 3 levels up from antigravity/knowledge/sync-from-claude/artifacts/
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

CLAUDE_DIR="$REPO_ROOT/claude"
ANTIGRAVITY_DIR="$REPO_ROOT/antigravity/knowledge"

# Current timestamp for metadata
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

sync_item() {
    local type=$1 # "agents" or "commands"
    local name=$2
    local src="$CLAUDE_DIR/$type/$name.md"
    local target_dir="$ANTIGRAVITY_DIR/$name"
    local target_file="$target_dir/artifacts/skill.md"
    local metadata="$target_dir/metadata.json"

    echo "Syncing $type: $name"

    # Create directory if it doesn't exist
    mkdir -p "$target_dir/artifacts"

    # Extract content (strip YAML frontmatter)
    # This sed command deletes from the first line until the second occurrence of '---'
    sed '1,/^---$/d' "$src" > "$target_file"

    # Add header
    local header_type="Agent"
    [[ "$type" == "commands" ]] && header_type="Command"
    
    if ! head -n 1 "$target_file" | grep -q "^# $name $header_type Instructions"; then
        echo -e "# $name $header_type Instructions\n\n$(cat "$target_file")" > "$target_file"
    fi

    # Update metadata.json updated_at
    if [[ -f "$metadata" ]]; then
        # Only update updated_at if file exists
        sed -i '' "s/\"updated_at\": \".*\"/\"updated_at\": \"$NOW\"/" "$metadata"
    else
        # Create new metadata.json with stable created_at
        cat > "$metadata" <<EOF
{
  "title": "$name",
  "summary": "Custom $(echo $header_type | tr '[:upper:]' '[:lower:]') definitions for $name.",
  "created_at": "$NOW",
  "updated_at": "$NOW"
}
EOF
    fi
}

echo "🔄 Starting dynamic sync from $CLAUDE_DIR to $ANTIGRAVITY_DIR..."

# Sync all agents
if [[ -d "$CLAUDE_DIR/agents" ]]; then
    for f in "$CLAUDE_DIR/agents"/*.md; do
        [[ -e "$f" ]] || continue
        name=$(basename "$f" .md)
        sync_item "agents" "$name"
    done
fi

# Sync all commands
if [[ -d "$CLAUDE_DIR/commands" ]]; then
    for f in "$CLAUDE_DIR/commands"/*.md; do
        [[ -e "$f" ]] || continue
        name=$(basename "$f" .md)
        sync_item "commands" "$name"
    done
fi

echo "✨ Sync complete!"
