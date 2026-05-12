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

    # Add header and type logic
    local header_type="Agent"
    [[ "$type" == "commands" ]] && header_type="Command"

    # 1. Extract description for metadata summary
    # Using | as delimiter for sed to avoid issues with slashes in descriptions
    local summary=$(grep "^description:" "$src" | sed 's/^description: //' | sed 's/^"//;s/"$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$summary" ]]; then
        summary="Custom $(echo $header_type | tr '[:upper:]' '[:lower:]') definitions for $name."
    fi

    # 2. Extract content (strip YAML frontmatter)
    sed '1,/^---$/d' "$src" > "$target_file"

    # 3. Inject Antigravity-specific tool mappings and aesthetic guidelines
    local extra_instructions="
## Antigravity Environment & Tools
You are running in the Antigravity environment. Use the following tool mappings:
- **Bash** -> \`run_command\`
- **Read** -> \`view_file\`
- **Grep** -> \`grep_search\`
- **Glob** -> \`list_dir\`
- **Write** -> \`write_to_file\`
- **Edit** -> \`replace_file_content\` or \`multi_replace_file_content\`
- **WebSearch** -> \`search_web\`
- **WebFetch** -> \`read_url_content\` or \`read_browser_page\`

### Advanced Tools
- **generate_image**: Use this to create high-quality UI mockups, icons, and assets.
- **browser_subagent**: Use this for interactive browser tasks, visual debugging, and testing.

### Aesthetic Standards
Every UI you design or review must follow **Antigravity Rich Aesthetics**:
- Use vibrant, curated color palettes (not defaults).
- Prioritize visual excellence and premium feel.
- Use modern typography (e.g., Inter, Outfit).
- Implement smooth gradients, micro-animations, and hover effects.
"

    # Prepend header and extra instructions
    echo -e "# $name $header_type Instructions\n$extra_instructions\n$(cat "$target_file")" > "$target_file"

    # 4. Update or Create metadata.json
    if [[ -f "$metadata" ]]; then
        # Use | as delimiter to handle slashes in summary
        sed "s|\"summary\": \".*\"|\"summary\": \"$summary\"|" "$metadata" > "$metadata.tmp" && mv "$metadata.tmp" "$metadata"
        sed "s|\"updated_at\": \".*\"|\"updated_at\": \"$NOW\"|" "$metadata" > "$metadata.tmp" && mv "$metadata.tmp" "$metadata"
    else
        cat > "$metadata" <<EOF
{
  "title": "$name",
  "summary": "$summary",
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
