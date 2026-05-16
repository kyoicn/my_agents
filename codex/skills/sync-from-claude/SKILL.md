---
name: "sync-from-claude"
description: "Sync Codex agents and skills from the canonical Claude definitions in this repo, preserving Codex-native behavior and target-local Codex skills."
---

# sync-from-claude

Use this skill when asked to sync, refresh, regenerate, or update the `codex/` target from the canonical `claude/` definitions.

## Ground Rules

- Treat `claude/` as read-only canonical input.
- Keep target-local Codex skills, including this skill, under `codex/skills/`.
- Keep `codex/skills/sync-from-claude/scripts/sync-from-claude.sh` simple and deterministic. It should do structural conversion only: parse Claude frontmatter, emit Codex files, preserve target-local skills, and apply obvious path wording such as `CLAUDE.md` to `AGENTS.md`.
- Regenerate Codex-native instruction quality in the LLM review pass after running the script. Do not add semantic rewrite tables or large target-specific templates to the script unless the user explicitly asks.
- Do not deploy to `~/.codex` unless the user explicitly asks.

## Workflow

1. Read `codex/skills/sync-from-claude/scripts/sync-from-claude.sh` and relevant files under `claude/agents/` and `claude/commands/`.
2. Run `./codex/skills/sync-from-claude/scripts/sync-from-claude.sh`.
3. Verify shell syntax with `bash -n codex/skills/sync-from-claude/scripts/sync-from-claude.sh codex/deploy.sh`.
4. Inspect and rewrite representative generated files as needed:
   - `codex/agents/planner.toml`
   - `codex/skills/dev-cycle/SKILL.md`
   - `codex/skills/quick-fix/SKILL.md`
   - `codex/skills/triage/SKILL.md`
5. During the LLM rewrite pass, preserve the Claude source intent but translate runtime assumptions into Codex-native behavior. Check especially for:
   - slash-command-only language
   - `CLAUDE.md` references
   - `isolation: "worktree"`
   - `run_in_background: true`
   - guaranteed per-agent branches or automatic branch merges
   - Claude tool names or model names presented as Codex configuration
6. If a generated file needs a Codex-native rewrite, edit that generated file directly after sync. This is expected: generated command and agent contents are refreshed by the LLM each sync for quality.
7. Keep changes focused on generated Codex artifacts and this skill's workflow. Do not modify `claude/`.
8. If the user asks to deploy, run `./codex/deploy.sh` and verify the relevant symlinks under `~/.codex`.

## Output Standard

Report what changed, what was generated, whether any Codex-native concerns remain, and whether deployment was performed.
