# sync-from-claude Skill

Use this skill to synchronize agent and command definitions from the `claude/` directory to the `antigravity/skills/` directory. This ensures that Antigravity agents use the same core instructions as Claude Code agents, with platform-specific content swapped in where needed.

## When to use
- After you have modified files in `claude/agents/` or `claude/commands/`.
- When you want to ensure the Antigravity skills are up to date with the latest repository definitions.

## How it works
1. Reads definitions from `claude/agents/*.md` and `claude/commands/*.md`.
2. Strips the Claude-specific YAML frontmatter.
3. Translates Claude tool names to Antigravity equivalents via `TOOL_MAPPINGS` and strips Claude-only `mcp__*` tools (Antigravity reaches specialized capabilities through subagents, not parent-agent MCP tools).
4. Writes the body to `antigravity/skills/<name>/artifacts/skill.md` with an Antigravity-style header.
5. Applies **SYNC swap-block overrides**: any `<!-- SYNC:<name> -->...<!-- /SYNC:<name> -->` block in the canonical file is replaced with the contents of `overrides/<name>.md` if that override file exists. Otherwise the markers are stripped and the canonical content is kept verbatim.
6. Updates the `updated_at` timestamp in the corresponding `metadata.json`.

## Adding a platform-specific override
1. Wrap the Claude-targeted block in the canonical file with markers:
   ```markdown
   <!-- SYNC:my-block-name -->
   ... Claude-specific instructions ...
   <!-- /SYNC:my-block-name -->
   ```
2. Create `antigravity/skills/sync-from-claude/artifacts/overrides/my-block-name.md` with the Antigravity-targeted version of the same block.
3. Re-run sync.

## Usage
Run the sync script located within this skill's folder:
```bash
./antigravity/skills/sync-from-claude/artifacts/sync.sh
```

Then, deploy the updated skills to your system:
```bash
./antigravity/deploy.sh
```
