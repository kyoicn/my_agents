# sync-from-claude Skill

Use this skill to synchronize agent and command definitions from the `claude/` directory to the `antigravity/knowledge/` directory. This ensures that Antigravity agents use the same core instructions as Claude Code agents.

## When to use
- After you have modified files in `claude/agents/` or `claude/commands/`.
- When you want to ensure the Antigravity knowledge base is up to date with the latest repository definitions.

## How it works
1. It reads definitions from `claude/agents/*.md` and `claude/commands/*.md`.
2. It strips the Claude-specific YAML frontmatter.
3. It adds Antigravity-style headers (e.g., `# <name> Agent Instructions`).
4. It updates the `skill.md` files in `antigravity/knowledge/<name>/artifacts/`.
5. It updates the `updated_at` timestamp in the corresponding `metadata.json`.

## Usage
Run the sync script located within this skill's folder:
```bash
./antigravity/knowledge/sync-from-claude/artifacts/sync.sh
```

Then, deploy the updated Knowledge Items to your system:
```bash
./antigravity/deploy.sh
```
