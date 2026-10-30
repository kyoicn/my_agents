---
description: "Merge the current feature worktree's branch back into main with a regular merge commit, then remove the worktree and delete the branch. Run from inside the feature worktree's OpenCode session — not from the main session."
---
<!-- generated-from: claude/commands — do not edit; regenerate with opencode/skills/sync-from-claude -->

> **OpenCode runtime notes** — this text was written for Claude Code and adapted for OpenCode; read what remains as follows.
> - Slash commands keep their names: `/dev-cycle` is the OpenCode command `dev-cycle`, and `/loop` is the `loop` command. When the text tells *you* to run a command (for example, run `/loop /dev-cycle` when the owner says "continue"), read `~/.config/opencode/commands/<name>.md` and follow it with the arguments.
> - "Spawn a `<role>` subagent" → the `subagent` tool with `agent: "<role>"`, a short `description`, and the full prompt; `background: true` when several run at once. The roles are the `~/.config/opencode/agents/*.md` agents: tl, planner, coder, qa, reporter, pm, evaluator, researcher, gorilla. A subagent's final message is its return summary.
> - "Spawn all in a single message" → issue every `subagent` call in the same turn, then wait for all their results before going on.
> - Worktrees: OpenCode subagents share your checkout. "Own worktree `.worktrees/<branch>`" means you create it with `git worktree add .worktrees/<branch> -b <branch> HEAD` before the spawn and tell the subagent to work and commit only there; the `/dev-cycle` command's "OpenCode adaptations" section has the full recipe.
> - `question` is OpenCode's question tool. A role whose permissions deny it never asks: it returns `BLOCKER:` or files an owner-queue entry, as its text says.
> - Claude tool names left in prose (Read, Grep, Glob, Edit, Write, Bash, WebSearch, WebFetch) are OpenCode's read, grep, glob, edit, shell, websearch, and webfetch tools. MCP tools are named `<server>_<tool>`; Playwright's are `playwright_browser_*`, exposed as direct tools because `~/.config/opencode/opencode.json` runs the server with `"codemode": false`.

# Worktree Finish

You are finishing a feature worktree: merging its branch into `main` with a no-ff merge commit, removing the worktree directory, and deleting the branch. This skill is local-only — it does not push to a remote or open a PR.

This skill must be run from **inside** the feature worktree (the window `/worktree-start` opened), not from the main worktree.

## Precondition checks

### 1. Refuse if run from the main worktree

Run `git worktree list --porcelain`. Find the entry whose `worktree` line matches the current working directory (use `pwd`). Read its `branch` line.

If the branch is `refs/heads/main` or `refs/heads/master`: STOP. Tell the user:
> This command runs from inside the feature worktree, not the main one. Switch to the worktree's Antigravity window and run it there.

### 2. Identify the current feature branch

From the current worktree's porcelain entry, extract the branch (e.g., `refs/heads/feature/data` → `feature/data`). Store as `<feature-branch>`.

Also store `<feature-path>` — the absolute path of the current worktree.

### 3. Identify the main worktree

Find the worktree entry whose branch is `refs/heads/main` (or `refs/heads/master`). Store:
- `<main-path>` — the absolute path
- `<main-branch>` — the main branch name (`main` or `master`)

If no such worktree exists, STOP and tell the user: their main worktree isn't on `main`/`master`, so the skill can't decide where to merge.

### 4. Check for uncommitted changes in the feature worktree

Run `git status --porcelain`. If the output is non-empty:
- Show the user a summary of the changes (file count, staged vs unstaged).
- Ask: "Commit these before merging? Reply with a conventional commit subject (e.g. `feat: add filter UI`), or `abort` to stop."
- If they give a commit subject: stage all changes (`git add -A`), commit with that subject as the message.
- If `abort`: STOP. Tell them to deal with the uncommitted work before re-running.

### 5. Check the main worktree is clean

Run `git -C <main-path> status --porcelain`. If non-empty, STOP:
> The main worktree at `<main-path>` has uncommitted changes. Resolve those first (commit or stash) — merging on top of dirty state risks losing work.

## Merge

### 6. Run a no-ff merge from the main worktree

```bash
git -C <main-path> merge --no-ff <feature-branch> -m "Merge branch '<feature-branch>'"
```

If the merge fails with conflicts:
- STOP. Tell the user:
  > Merge conflicts. The main worktree at `<main-path>` is now in a conflicted state. Open its Antigravity window, resolve the conflicts there, complete the merge, and the feature worktree can be cleaned up afterward (re-run `/worktree-finish` once main is merged).
- Do not attempt to auto-resolve. Do not `git merge --abort` — the user may want to inspect the conflicted state.

If the merge fails for any other reason (e.g., main has diverged in a way that needs a pull), surface the error verbatim and stop.

## Cleanup

### 7. Remove the worktree

You cannot remove a worktree from inside itself. Run from the main worktree:

```bash
git -C <main-path> worktree remove "<feature-path>"
```

If git refuses (e.g., it thinks the worktree is dirty even though step 4 passed), surface the error and stop. Don't force the removal with `--force` unless the user explicitly asks.

### 8. Delete the merged branch

The feature branch is fully merged, so safe delete will succeed:

```bash
git -C <main-path> branch -d <feature-branch>
```

If `-d` refuses (claims unmerged commits), STOP and tell the user — that means the merge didn't actually land everything, and the branch still has work. Do not use `-D`.

## Report

Tell the user, concisely:
- Merged `<feature-branch>` into `<main-branch>` with a no-ff merge commit.
- Removed worktree directory at `<feature-path>`.
- Deleted local branch `<feature-branch>`.
- This Antigravity window is now pointing at a deleted folder — close it. Continue work in the main window.
- Reminder: nothing was pushed to the remote. The main worktree has the merge commit locally; push when you're ready.

## What NOT to do

- Don't push to a remote. This skill is local-only by design.
- Don't open a PR via `gh`. The user can do that manually if they want one for some other reason.
- Don't run this from the main worktree — refuse cleanly per step 1.
- Don't force-delete the branch (`-D`). If safe-delete refuses, the merge didn't complete; investigate, don't paper over it.
- Don't `git merge --abort` automatically on conflict. Leave the conflicted state for the user to resolve in the main window.
- Don't `rm -rf` the worktree directory. `git worktree remove` is the only safe path; raw delete leaves dangling refs in `.git/worktrees/`.
- Don't squash, rebase, or fast-forward the merge — this skill is configured for `--no-ff` to preserve a clear merge boundary in history.

ARGUMENTS: $ARGUMENTS
