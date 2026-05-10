#!/bin/bash

# Configuration
REPO_KNOWLEDGE_DIR="$(cd "$(dirname "$0")/knowledge" && pwd)"
SYSTEM_KNOWLEDGE_DIR="$HOME/.gemini/antigravity/knowledge"

echo "🚀 Deploying Antigravity Knowledge Items (KIs) via symlinks..."
echo "Source: $REPO_KNOWLEDGE_DIR"
echo "Target: $SYSTEM_KNOWLEDGE_DIR"
echo ""

# Ensure target directory exists
mkdir -p "$SYSTEM_KNOWLEDGE_DIR"

# Iterate through all folders in the repo knowledge directory
for agent_dir in "$REPO_KNOWLEDGE_DIR"/*/; do
    if [ -d "$agent_dir" ]; then
        agent_name=$(basename "$agent_dir")
        target_link="$SYSTEM_KNOWLEDGE_DIR/$agent_name"

        echo "📦 Deploying agent: $agent_name"

        # Remove existing file, directory, or symlink at the target
        if [ -e "$target_link" ] || [ -L "$target_link" ]; then
            rm -rf "$target_link"
        fi

        # Create the symlink
        ln -s "$agent_dir" "$target_link"
        echo "✅ Linked: $target_link -> $agent_dir"
    fi
done

echo ""
echo "✨ Deployment complete! Your custom agents are now live in Antigravity."
