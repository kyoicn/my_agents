---
name: "sync-from-claude"
description: "Sync Codex agents and skills from the canonical Claude definitions in this repo, preserving Codex-native behavior and target-local Codex skills."
---

# sync-from-claude

Use this skill when asked to sync, refresh, regenerate, or update the `codex/` target from the canonical `claude/` definitions.

## Ground Rules

- Treat `claude/` as read-only canonical input.
- Keep target-local Codex skills, including this skill, under `codex/skills/`.
- Do not hand-edit generated agents or command skills as a lasting fix. Update `codex/skills/sync-from-claude/scripts/sync-from-claude.sh`, rerun it, then review the generated output.
- Do not deploy to `~/.codex` unless the user explicitly asks.

## Workflow

1. Read `codex/skills/sync-from-claude/scripts/sync-from-claude.sh` and relevant files under `claude/agents/` and `claude/commands/`.
2. Run `./codex/skills/sync-from-claude/scripts/sync-from-claude.sh`.
3. Verify shell syntax with `bash -n codex/skills/sync-from-claude/scripts/sync-from-claude.sh codex/deploy.sh`.
4. Inspect representative generated files:
   - `codex/agents/planner.toml`
   - `codex/skills/dev-cycle/SKILL.md`
   - `codex/skills/quick-fix/SKILL.md`
   - `codex/skills/triage/SKILL.md`
5. Check for Claude-only runtime assumptions that are not Codex-native, especially:
   - slash-command-only language
   - `CLAUDE.md` references
   - `isolation: "worktree"`
   - `run_in_background: true`
   - guaranteed per-agent branches or automatic branch merges
   - Claude tool names or model names presented as Codex configuration
6. If generated content is not Codex-native, update the sync transform or Codex-specific templates in `codex/skills/sync-from-claude/scripts/sync-from-claude.sh`, rerun the sync, and inspect again.
7. If the user asks to deploy, run `./codex/deploy.sh` and verify the relevant symlinks under `~/.codex`.

## Output Standard

Report what changed, what was generated, whether any Codex-native concerns remain, and whether deployment was performed.
