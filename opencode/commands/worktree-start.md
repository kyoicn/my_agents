---
description: "Create a new git worktree on a fresh feature branch and open it in a new Antigravity window. Use this to run a parallel OpenCode session on a different concern (UI, data pipeline, mocks, etc.) without disturbing your current window."
---
<!-- generated-from: claude/commands — do not edit; regenerate with opencode/skills/sync-from-claude -->

> **OpenCode runtime notes** — this text was written for Claude Code and adapted for OpenCode; read what remains as follows.
> - Slash commands keep their names: `/dev-cycle` is the OpenCode command `dev-cycle`, and `/loop` is the `loop` command. When the text tells *you* to run a command (for example, run `/loop /dev-cycle` when the owner says "continue"), read `~/.config/opencode/commands/<name>.md` and follow it with the arguments.
> - "Spawn a `<role>` subagent" → the `subagent` tool with `agent: "<role>"`, a short `description`, and the full prompt; `background: true` when several run at once. The roles are the `~/.config/opencode/agents/*.md` agents: tl, planner, coder, qa, reporter, pm, evaluator, researcher, gorilla. A subagent's final message is its return summary.
> - "Spawn all in a single message" → issue every `subagent` call in the same turn, then wait for all their results before going on.
> - Worktrees: OpenCode subagents share your checkout. "Own worktree `.worktrees/<branch>`" means you create it with `git worktree add .worktrees/<branch> -b <branch> HEAD` before the spawn and tell the subagent to work and commit only there; the `/dev-cycle` command's "OpenCode adaptations" section has the full recipe.
> - `question` is OpenCode's question tool. A role whose permissions deny it never asks: it returns `BLOCKER:` or files an owner-queue entry, as its text says.
> - Claude tool names left in prose (Read, Grep, Glob, Edit, Write, Bash, WebSearch, WebFetch) are OpenCode's read, grep, glob, edit, shell, websearch, and webfetch tools. MCP tools are named `<server>_<tool>`; Playwright's are `playwright_browser_*`, exposed as direct tools because `~/.config/opencode/opencode.json` runs the server with `"codemode": false`.

# Worktree Start

You are creating a new git worktree so the user can work on a parallel concern in a separate editor window. After this skill runs, the user will switch to the new window and continue work there.

## Input

- **With a name** (e.g., `worktree-start data pipeline`, `worktree-start "building UI features"`): use the words as the basis for a slug.
- **Without arguments**: ask the user "What concern is this worktree for?" before continuing.

## Process

### 1. Derive a slug from the name

Turn the user's phrase into a short kebab-case slug:
- Lowercase the phrase, replace non-alphanumeric runs with `-`, strip leading/trailing hyphens.
- Strip leading filler words: `building-`, `for-`, `the-`, `a-`, `an-`, `new-`.
- If the result is over 3 words, trim to the most meaningful 1-2 words.

Show the proposed slug to the user in one line and let them override:
> Proposing slug `<slug>` → branch `feature/<slug>`. Reply with a different slug to change, or anything else to proceed.

If the input phrase was already a short slug-like token (e.g., `data`, `ui`), skip the confirmation and proceed.

### 2. Locate the main worktree

Run `git worktree list --porcelain`. Parse the output and find the worktree whose `branch` is `refs/heads/main` (or `refs/heads/master` if no `main` exists). This is the **main worktree**, regardless of which worktree the user is currently in.

Store:
- `<main-path>` — absolute path of the main worktree
- `<main-basename>` — the basename of `<main-path>` (e.g., `my_agents`)
- `<main-parent>` — the parent directory of `<main-path>`

### 3. Pre-flight checks

- **Branch collision**: run `git branch --list feature/<slug>`. If it returns a result, tell the user the branch already exists and ask for a different slug.
- **Path collision**: check `<main-parent>/<main-basename>-<slug>` doesn't already exist as a directory. If it does, tell the user and ask for a different slug.

### 4. Create the worktree

Run from any directory (worktree commands work from any worktree in the repo):

```bash
git -C <main-path> worktree add "<main-parent>/<main-basename>-<slug>" -b feature/<slug>
```

Confirm it succeeded by running `git -C <main-path> worktree list` and checking the new entry appears.

### 5. Open Antigravity on the new worktree

Antigravity bundles a CLI binary inside its app. Call it directly — this passes the folder path through to the IDE, which opens it as a workspace in a new window. `open -a` can launch the app without actually opening the folder, so prefer the direct binary.

Primary command:

```bash
"/Applications/Antigravity IDE.app/Contents/Resources/app/bin/antigravity-ide" "<main-parent>/<main-basename>-<slug>"
```

If the binary doesn't exist at that path (Antigravity IDE not installed, or installed in `~/Applications/` or another non-standard location), fall back to `open -a "Antigravity IDE" "<path>"` and warn the user that the app may launch without opening the folder — in that case they'll need to open it manually.

If everything fails, surface the error and tell the user the new worktree path so they can open it manually. The worktree itself is fully created at that point — only the auto-open step failed.

Note: `Antigravity.app` (without "IDE" in the name) is a separate non-IDE product and doesn't bundle a CLI — don't try to use its app bundle as a fallback.

### 6. Report

Tell the user, concisely:
- New worktree: `<new-worktree-path>`
- New branch: `feature/<slug>`
- A new Antigravity window is opening — switch to it to start the new session.
- When the work is done, run `/worktree-finish` from that window's OpenCode session to merge back into `main` and clean up.

## What NOT to do

- Don't `cd` into the new worktree in this session — this session stays in its original directory. The new worktree gets its own session in its own window.
- Don't seed `docs/`, copy state files, or modify anything in the new worktree — git already populated it with the full project tree.
- Don't run any commits, merges, or pushes — this skill only creates the worktree.
- Don't reuse a branch name that already exists. Always create a fresh `feature/<slug>` branch.
- Don't place the new worktree anywhere other than as a sibling of the main worktree — keep the convention so `/worktree-finish` and future tooling can find it predictably.
## OpenCode adaptations

The new Antigravity window is an editor, not an OpenCode session. In your report, tell the user to start OpenCode in that window's integrated terminal (`opencode`); that session works in the worktree, and `/worktree-finish` runs from it. This session stays where it is.

ARGUMENTS: $ARGUMENTS
