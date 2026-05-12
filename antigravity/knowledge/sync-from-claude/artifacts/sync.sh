#!/bin/bash

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# The repo root is 3 levels up from antigravity/knowledge/sync-from-claude/artifacts/
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

CLAUDE_DIR="$REPO_ROOT/claude"
ANTIGRAVITY_DIR="$REPO_ROOT/antigravity/knowledge"

# Current timestamp for metadata
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Centralized Tool Mapping Table
# Format: "ClaudeToolName:AntigravityToolName"
TOOL_MAPPINGS=(
    "Bash:run_command"
    "Read:view_file"
    "Grep:grep_search"
    "Glob:list_dir"
    "Write:write_to_file"
    "Edit:replace_file_content"
    "WebSearch:search_web"
    "WebFetch:read_url_content"
)

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

    # 1. Extract description and tools for metadata/header
    # Using | as delimiter for sed to avoid issues with slashes in descriptions
    local summary=$(grep "^description:" "$src" | sed 's/^description: //' | sed 's/^"//;s/"$//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ -z "$summary" ]]; then
        summary="Custom $(echo $header_type | tr '[:upper:]' '[:lower:]') definitions for $name."
    fi

    local raw_tools=$(grep "^tools:" "$src" | sed 's/^tools: //')
    local translated_tools="$raw_tools"
    for mapping in "${TOOL_MAPPINGS[@]}"; do
        claude_tool="${mapping%%:*}"
        antigravity_tool="${mapping#*:}"
        # Mac sed uses [[:<:]] and [[:>:]] for word boundaries
        translated_tools=$(echo "$translated_tools" | sed "s/[[:<:]]$claude_tool[[:>:]]/$antigravity_tool/g")
    done

    # 2. Extract content (strip YAML frontmatter)
    sed '1,/^---$/d' "$src" > "$target_file"

    # 3. Perform tool name replacement (Claude -> Antigravity) in the body
    for mapping in "${TOOL_MAPPINGS[@]}"; do
        claude_tool="${mapping%%:*}"
        antigravity_tool="${mapping#*:}"
        # Using [[:<:]] and [[:>:]] for Mac compatibility
        sed -i '' "s/[[:<:]]$claude_tool[[:>:]]/$antigravity_tool/g" "$target_file"
    done

    # 4. Add minimal header with Tool Capabilities
    echo -e "# $name $header_type Instructions\n\n**Tool Capabilities**: $translated_tools\n\n$(cat "$target_file")" > "$target_file"

    # 5. Update or Create metadata.json
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
