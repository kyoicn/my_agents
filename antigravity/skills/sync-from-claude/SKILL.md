---
name: sync-from-claude
description: "Regenerate the Antigravity port (custom agents, skills, GEMINI.md) from the canonical Claude definitions in this repo, with Antigravity-native behavior carried by the generator's mapping layer rather than by hand edits."
---

# sync-from-claude

Use this skill when asked to sync, refresh, regenerate, or update the `antigravity/` target from the canonical `claude/` definitions.

## What it produces

Antigravity's customization system, as documented for the App, IDE, and CLI:

| Claude source | Antigravity artifact | Deployed to |
|---|---|---|
| `claude/agents/<name>.md` | `antigravity/agents/<name>.md` — custom agent: YAML frontmatter (`name`, `description`), body = system prompt | `~/.gemini/config/agents/<name>.md` |
| `claude/commands/<name>.md` | `antigravity/skills/<name>/SKILL.md` — a skill, which Antigravity exposes as the slash command `/<name>` | `~/.gemini/config/skills/<name>/` (App) and `~/.gemini/antigravity-cli/skills/<name>/` (CLI) |
| `claude/CLAUDE.md` | `antigravity/GEMINI.md` — global rules | `~/.gemini/GEMINI.md` |

The previous port wrote IDE "knowledge items" into `~/.gemini/antigravity/knowledge/`. That location is the IDE's own knowledge store and is not part of the customization system; `deploy.sh` removes the old links.

## How Antigravity behavior is preserved

Never hand-edit a generated file. The translation lives in three places that survive every regeneration:

1. **Deterministic rewrites** inside the script: `CLAUDE.md` → `GEMINI.md`, `~/.claude/...` → `~/.gemini/config/...`, `claude/agents/x.md` → `~/.gemini/config/agents/x.md`. Slash commands keep their names, since every skill is a `/name` command on Antigravity.
2. **`platform-notes.md`**, prepended to every generated artifact: `invoke_subagent` for spawning, the `branch` workspace mode for `isolation: "worktree"`, "ask in the reply and end the turn" for `AskUserQuestion`, `/x` repeated in-turn for `/loop`.
3. **Overrides**: `overrides/<name>.md` replaces a `<!-- SYNC:<name> -->` block in a Claude source; `overrides/agents/<name>.md` and `overrides/skills/<name>.md` are appended to that artifact as an "Antigravity adaptations" section.

Generated files carry a `generated-from` marker; the script deletes and recreates them. This skill has no marker and is left alone.

**Tool restrictions are not carried over.** Generated agents have no `tools:` field, so each keeps Antigravity's default tool access. Claude's per-role lists (e.g. coder without web tools) are a narrowing that the role text already enforces; writing a `tools:` list would need tool names verified against the running product, because an unmapped name can hang a subagent.

## Workflow

1. Run `./antigravity/skills/sync-from-claude/scripts/sync-from-claude.sh`.
2. Verify: `bash -n` both scripts, then `./antigravity/skills/sync-from-claude/scripts/sync-from-claude.sh --check`.
3. Read one generated agent and `antigravity/skills/dev-cycle/SKILL.md` for Claude-only constructs the mapping layer missed. Fix them **in the mapping layer** (script rewrite, `platform-notes.md`, or an override file), then re-run — not in the generated file.
4. Report what changed, what the mapping layer still does not cover, and whether deployment was performed.

## Verification still owed

This port was built to the documented format on 2026-10-28 while the Antigravity CLI could not run on the build machine (`agy` reported the account ineligible in its location). The first time Antigravity is usable, check: the `/agents` panel lists the nine roles; `/dev-cycle` appears as a slash command; an agent with no `tools:` field has normal tool access; `invoke_subagent` offers the `branch` workspace mode. Anything that fails goes into the mapping layer.

## Ground rules

- Treat `claude/` as read-only canonical input.
- Keep the script structural and deterministic. New semantics go in `platform-notes.md` or an override file, not in regex.
- Do not deploy to `~/.gemini` unless the user explicitly asks. `./antigravity/deploy.sh` links agents, skills, and `GEMINI.md`, prunes links into this repo whose targets no longer exist, and removes the legacy knowledge-item links.
