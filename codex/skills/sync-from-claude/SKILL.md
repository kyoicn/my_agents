---
name: "sync-from-claude"
description: "Regenerate the Codex port (agents, skills, AGENTS.md) from the canonical Claude definitions in this repo, with Codex-native behavior carried by the generator's mapping layer rather than by hand edits."
---

# sync-from-claude

Use this skill when asked to sync, refresh, regenerate, or update the `codex/` target from the canonical `claude/` definitions.

## How Codex behavior is preserved

The Claude sources are written for Claude Code. The generator (`scripts/sync-from-claude.sh`) carries the Codex translation in three places, all of which survive every regeneration — never hand-edit a generated file:

1. **Deterministic rewrites** inside the script: `/command` → `$command` (for every `claude/commands/*.md` stem, never inside paths), `CLAUDE.md` → `AGENTS.md`, `~/.claude/...` → `~/.codex/...`, `claude/agents/x.md` → `~/.codex/agents/x.toml`, `subagent_type` → `agent_type`. A short skip list (`SKIP_SKILLS`) names Claude commands with no Codex counterpart.
2. **`platform-notes.md`**, prepended to every generated agent, skill, and `AGENTS.md`: how to read the remaining Claude constructs on Codex — `spawn_agent`/`wait_agent` for subagents, in-repo `git worktree` for `isolation: "worktree"`, "ask in the final message and end the turn" for `AskUserQuestion`, `$x` repeated in-turn for `/loop`.
3. **Overrides**: `overrides/<name>.md` replaces a `<!-- SYNC:<name> -->` block in a Claude source (used by qa for browser tooling); `overrides/agents/<name>.md` and `overrides/skills/<name>.md` are appended to that artifact as a "Codex adaptations" section (used by `coder` and `dev-cycle` for the worktree recipe and owner questions).

Generated files carry a `generated-from` marker; the script deletes and recreates them. Skills without the marker (this one) are left alone.

## Workflow

1. Run `./codex/skills/sync-from-claude/scripts/sync-from-claude.sh`.
2. Verify: `bash -n` both scripts; parse every `codex/agents/*.toml` (`tomllib` on Python ≥ 3.11, otherwise `tomli`): `python3 -c 'import sys\ntry: import tomllib as t\nexcept ModuleNotFoundError: import tomli as t\n[t.load(open(p,"rb")) for p in sys.argv[1:]]' codex/agents/*.toml`.
3. Read the generated `codex/skills/dev-cycle/SKILL.md` and one agent (e.g. `codex/agents/coder.toml`) for Claude-only constructs the mapping layer missed: a tool name, a path, a slash command, an isolation flag. Fix them **in the mapping layer** (script rewrite, `platform-notes.md`, or an override file), then re-run — not in the generated file.
4. Report what changed, what the mapping layer still does not cover, and whether deployment was performed.

## Ground rules

- Treat `claude/` as read-only canonical input.
- Keep the script structural and deterministic. New semantics go in `platform-notes.md` or an override file, not in regex.
- Do not deploy to `~/.codex` unless the user explicitly asks. `./codex/deploy.sh` links agents, skills, and `AGENTS.md` (backing up a hand-written `~/.codex/AGENTS.md`), and prunes links into this repo whose targets no longer exist.
