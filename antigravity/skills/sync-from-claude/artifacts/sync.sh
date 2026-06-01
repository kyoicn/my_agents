#!/bin/bash

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# The repo root is 4 levels up from antigravity/skills/sync-from-claude/artifacts/
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

CLAUDE_DIR="$REPO_ROOT/claude"
ANTIGRAVITY_DIR="$REPO_ROOT/antigravity/skills"
OVERRIDES_DIR="$SCRIPT_DIR/overrides"

# Current timestamp for metadata
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Centralized Tool Mapping Table
# Format: "ClaudeToolName:AntigravityToolName"
# Tools matching `mcp__*` are stripped (Antigravity has no parent-agent MCP surface;
# specialized capabilities like the browser are reached via subagents such as `/browser`).
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

# Strip mcp__* tokens from a comma-separated tool list.
strip_mcp_tools() {
    echo "$1" | tr ',' '\n' \
        | sed -E 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        | grep -v '^mcp__' \
        | grep -v '^$' \
        | paste -sd ',' - \
        | sed 's/,/, /g'
}

# Apply SYNC swap-block overrides to a synced file in place.
# For each `<!-- SYNC:<name> -->...<!-- /SYNC:<name> -->` block found:
#   - If overrides/<name>.md exists, replace the whole block (markers included) with its content.
#   - Otherwise, strip just the marker lines and keep the canonical content.
apply_sync_overrides() {
    local file=$1
    local names
    names=$(grep -oE '<!-- SYNC:[a-z0-9-]+ -->' "$file" 2>/dev/null \
        | sed -E 's/<!-- SYNC:(.*) -->/\1/' | sort -u)
    [[ -z "$names" ]] && return 0

    local tmp
    for name in $names; do
        local override="$OVERRIDES_DIR/$name.md"
        tmp=$(mktemp)
        if [[ -f "$override" ]]; then
            awk -v name="$name" -v overrideFile="$override" '
                $0 ~ "<!-- SYNC:" name " -->" {
                    in_block = 1
                    while ((getline line < overrideFile) > 0) print line
                    close(overrideFile)
                    next
                }
                $0 ~ "<!-- /SYNC:" name " -->" {
                    in_block = 0
                    next
                }
                !in_block { print }
            ' "$file" > "$tmp" && mv "$tmp" "$file"
        else
            awk -v name="$name" '
                $0 ~ "<!-- SYNC:" name " -->" { next }
                $0 ~ "<!-- /SYNC:" name " -->" { next }
                { print }
            ' "$file" > "$tmp" && mv "$tmp" "$file"
        fi
    done
}

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
    # Strip Claude-only MCP tools (no Antigravity parent-agent equivalent)
    translated_tools=$(strip_mcp_tools "$translated_tools")

    # 2. Extract content (strip YAML frontmatter) - LEAVE UNTOUCHED
    sed '1,/^---$/d' "$src" > "$target_file"

    # 3. Construct the final skill.md (Header + Tools + Original Body)
    echo -e "# $name $header_type Instructions\n\n**Tools**: $translated_tools\n\n$(cat "$target_file")" > "$target_file"

    # 4. Apply SYNC swap-block overrides (platform-specific content swaps)
    apply_sync_overrides "$target_file"

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
