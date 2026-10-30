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
| *(hand-written)* | `opencode/opencode.json` — global config: Playwright MCP with `"codemode": false`, `shell` allow rules for the QA scripts | `~/.config/opencode/opencode.json` |
| *(hand-written)* | `opencode/commands/loop.md` — `/loop /dev-cycle [args]`, OpenCode's stand-in for Claude Code's `/loop` | `~/.config/opencode/commands/loop.md` |

The two hand-written files carry no marker, so the generator leaves them alone. `opencode.json` is in the repo so MCP and permission changes are reviewed like any other change; `deploy.sh` backs up a hand-written one before linking.

OpenCode v2 reads only `AGENTS.md` for rules (no `CLAUDE.md` fallback) and does not read `~/.claude/agents` or `~/.claude/commands`, so the Claude setup and this port do not double-load. It does read `~/.claude/skills`.

## How OpenCode behavior is preserved

Never hand-edit a generated file. The translation lives in three places that survive every regeneration:

1. **Deterministic rewrites** inside the script (`RENAMES`): Claude parameter and tool names become OpenCode's — `subagent_type` → `agent`, `run_in_background` → `background`, `` `isolation: "worktree"` `` → "own worktree `.worktrees/<branch>`", `AskUserQuestion` → `question`, "Agent tool" → "`subagent` tool", "Read tool" → "`read` tool", `mcp__playwright__` → `playwright_`, "Claude session" → "OpenCode session"; `` `Bash(<pattern>)` `` allowlist entries become `shell` allow rules in `opencode.json`; the Playwright install line points at `deploy.sh`. Paths: `CLAUDE.md` → `AGENTS.md`, `~/.claude/...` → `~/.config/opencode/...`, `claude/agents/x.md` and `claude/commands/x.md` → their deployed paths. Slash commands keep their names.
2. **`platform-notes.md`**, prepended to every generated artifact, for what a rename cannot carry: spawning several subagents in one turn, creating the worktree before a spawn, roles that deny `question`, Claude tool names left in prose, MCP naming and Code Mode.
3. **Overrides**: `overrides/<name>.md` replaces a `<!-- SYNC:<name> -->` block in a Claude source; `overrides/agents/<name>.md` and `overrides/commands/<name>.md` are appended to that artifact as an "OpenCode adaptations" section (`coder` and `dev-cycle`: the worktree recipe; `worktree-start`: start OpenCode in the new window).

**No Claude-only construct survives.** After mapping, the generator fails if a body still contains `subagent_type`, `run_in_background`, `isolation: "worktree"`, `AskUserQuestion`, `mcp__`, `` `Bash( ``, "Agent tool", "Read tool", or `claude mcp add`. A new one in a Claude source needs a rename, an override, or a SYNC block before the port regenerates.

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

Checked on 2026-10-30 against OpenCode v2.2.3: the agents parse with their deny rules (`opencode debug agents`); all commands and this skill load (`command.list`, `skill.list` API); `opencode.json` parses, Playwright MCP connects with Code Mode off, and the QA `shell` allow rules reach the agents. The `playwright_browser_*` names come from an OpenCode session's own review of this port, not from a tool listing. Not yet exercised: a full `/dev-cycle` run, parallel background `subagent` calls, and a browser walk. Anything that fails goes into the mapping layer.

## Ground rules

- Treat `claude/` as read-only canonical input.
- Keep the script structural and deterministic. New semantics go in `platform-notes.md` or an override file, not in regex.
- Do not deploy to `~/.config/opencode` unless the user explicitly asks. `./opencode/deploy.sh` links agents, commands, skills, `AGENTS.md`, and `opencode.json` (backing up a hand-written `AGENTS.md` or `opencode.json`), and prunes links into this repo whose targets no longer exist.
