---
name: sync-from-claude
description: "Regenerate the OpenCode port (agents, commands, AGENTS.md) from the canonical Claude definitions in this repo, with OpenCode-native behavior carried by the generator's mapping layer rather than by hand edits."
---

# sync-from-claude

Use this skill when asked to sync, refresh, regenerate, or update the `opencode/` target from the canonical `claude/` definitions.

## What it produces

OpenCode v2's customization system (built against OpenCode v2.2.3):

| Claude source | OpenCode artifact | Deployed to |
|---|---|---|
| `claude/agents/<name>.md` | `opencode/agents/<name>.md` — agent: YAML frontmatter (`description`, `mode: subagent`, `permissions`), body = system prompt | `~/.config/opencode/agents/<name>.md` |
| `claude/commands/<name>.md` | `opencode/commands/<name>.md` — command template, invoked as `/<name>` | `~/.config/opencode/commands/<name>.md` |
| `claude/CLAUDE.md` | `opencode/AGENTS.md` — global rules | `~/.config/opencode/AGENTS.md` |

OpenCode v2 reads only `AGENTS.md` for rules (no `CLAUDE.md` fallback) and does not read `~/.claude/agents` or `~/.claude/commands`, so the Claude setup and this port do not double-load. It does read `~/.claude/skills`.

## How OpenCode behavior is preserved

Never hand-edit a generated file. The translation lives in three places that survive every regeneration:

1. **Deterministic rewrites** inside the script: `CLAUDE.md` → `AGENTS.md`, `~/.claude/...` → `~/.config/opencode/...`, `claude/agents/x.md` → `~/.config/opencode/agents/x.md`, `claude/commands/x.md` → `~/.config/opencode/commands/x.md`, and the Playwright install line `claude mcp add --scope user playwright` → `opencode mcp add --global playwright`. Slash commands keep their names.
2. **`platform-notes.md`**, prepended to every generated artifact: the `subagent` tool (`agent` parameter) for spawning, in-repo `git worktree` for `isolation: "worktree"`, the `question` tool for `AskUserQuestion`, reading the command file to run a command yourself, `/x` repeated in-turn for `/loop`.
3. **Overrides**: `overrides/<name>.md` replaces a `<!-- SYNC:<name> -->` block in a Claude source; `overrides/agents/<name>.md` and `overrides/commands/<name>.md` are appended to that artifact as an "OpenCode adaptations" section (used by `coder` and `dev-cycle` for the worktree recipe).

Generated files carry a `generated-from` marker; the script deletes and recreates them. This skill has no marker and is left alone.

**Tool restrictions become deny rules.** A Claude `tools:` list is an allow-list. The generator maps it onto OpenCode's permission actions (`read`, `grep`, `glob`, `shell`, `edit`, `websearch`, `webfetch`, `question`, `subagent`) and writes a `deny` rule for each mapped action the role lacks. Unmapped tools — MCP servers such as Playwright, skills — stay allowed, so qa and gorilla keep their browser tools.

**No model is set.** Claude's `model:` hints (opus, fable, sonnet) name Anthropic models and OpenCode needs `provider/model`. Without a `model:` field a subagent runs on the model of the session that invoked it.

**Command templates are guarded.** OpenCode expands `$1`…, `$ARGUMENTS`, and `` !`cmd` `` in a command template. The generator refuses a Claude command whose text contains one, and ends every template with `ARGUMENTS: $ARGUMENTS`.

## Workflow

1. Run `./opencode/skills/sync-from-claude/scripts/sync-from-claude.sh`.
2. Verify: `bash -n` both scripts, then `--check`. To confirm OpenCode parses the agents without deploying, make a scratch directory with `.opencode/agents` linked to `opencode/agents` and run `opencode debug agents` there: the nine roles must appear with `mode: subagent` and their deny rules.
3. Read one generated agent and `opencode/commands/dev-cycle.md` for Claude-only constructs the mapping layer missed. Fix them **in the mapping layer** (script rewrite, `platform-notes.md`, or an override file), then re-run — not in the generated file.
4. Report what changed, what the mapping layer still does not cover, and whether deployment was performed.

## Verification still owed

Checked on 2026-10-30 against OpenCode v2.2.3: the agents parse with their deny rules (`opencode debug agents`). Not yet exercised in a working session: a full `/dev-cycle` run, parallel `subagent` calls, and the Playwright MCP tool names. Anything that fails goes into the mapping layer.

## Ground rules

- Treat `claude/` as read-only canonical input.
- Keep the script structural and deterministic. New semantics go in `platform-notes.md` or an override file, not in regex.
- Do not deploy to `~/.config/opencode` unless the user explicitly asks. `./opencode/deploy.sh` links agents, commands, skills, and `AGENTS.md` (backing up a hand-written `AGENTS.md`), and prunes links into this repo whose targets no longer exist.
