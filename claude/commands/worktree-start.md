---
description: Create a new git worktree on a fresh feature branch and open it in a new Antigravity window. Use this to run a parallel Claude session on a different concern (UI, data pipeline, mocks, etc.) without disturbing your current window.
---

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

```bash
antigravity "<main-parent>/<main-basename>-<slug>"
```

If `antigravity` is not on PATH (`command -v antigravity` fails), surface the error and tell the user to open `<new-worktree-path>` manually in a new Antigravity window — the worktree is created, only the auto-open step failed.

### 6. Report

Tell the user, concisely:
- New worktree: `<new-worktree-path>`
- New branch: `feature/<slug>`
- A new Antigravity window is opening — switch to it to start the new session.
- When the work is done, run `/worktree-finish` from that window's Claude session to merge back into `main` and clean up.

## What NOT to do

- Don't `cd` into the new worktree in this session — this session stays in its original directory. The new worktree gets its own session in its own window.
- Don't seed `docs/`, copy state files, or modify anything in the new worktree — git already populated it with the full project tree.
- Don't run any commits, merges, or pushes — this skill only creates the worktree.
- Don't reuse a branch name that already exists. Always create a fresh `feature/<slug>` branch.
- Don't place the new worktree anywhere other than as a sibling of the main worktree — keep the convention so `/worktree-finish` and future tooling can find it predictably.
