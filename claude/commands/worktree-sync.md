---
description: Two-way sync between the current feature worktree and main without closing the worktree. Pushes the feature's committed work onto main, then pulls main's updates back into the feature. Use this mid-feature to land shared changes (e.g., design docs, PRDs) so other worktrees can pick them up — and to absorb their updates into this worktree.
---

# Worktree Sync

You are syncing the current feature worktree with main in both directions, while keeping the feature worktree and branch alive.

After this skill runs:
- `main` contains the feature's committed work-so-far.
- The feature branch has any updates other worktrees landed on `main` in the meantime.
- The feature worktree is still open — the user keeps working in it.

This skill is local-only. It does not push to a remote.

This skill must be run from **inside** the feature worktree (the window `/worktree-start` opened), not from the main worktree.

## When to use this skill

- The user is collaborating across worktrees on shared files (design docs, PRDs, configs) and wants this worktree's edits visible to the others.
- The user wants to pull in updates other worktrees have landed on `main` without ending the current feature.
- The user wants a clean intermediate checkpoint on `main` rather than one giant merge at the end.

When NOT to use:
- If the feature worktree contains broken or unfinished code that would break `main` for other worktrees. For partial work that isn't main-safe, stay on the feature branch and use `/worktree-finish` at a clean checkpoint instead.

## Precondition checks

### 1. Refuse if run from the main worktree

Run `git worktree list --porcelain`. Find the entry whose `worktree` line matches the current working directory (use `pwd`). Read its `branch` line.

If the branch is `refs/heads/main` or `refs/heads/master`: STOP. Tell the user:
> This command runs from inside a feature worktree, not the main one. There's nothing to sync from main into itself.

### 2. Identify the current feature branch & worktree

From the current worktree's porcelain entry, extract:
- `<feature-branch>` — e.g. `feature/data` (strip `refs/heads/`)
- `<feature-path>` — the current absolute path

### 3. Identify the main worktree

Find the worktree entry whose branch is `refs/heads/main` (or `refs/heads/master` if no `main`). Store:
- `<main-path>` — absolute path
- `<main-branch>` — `main` or `master`

If no such worktree exists, STOP: main isn't checked out anywhere, so the sync target is missing.

### 4. Check for uncommitted changes in the feature worktree

Run `git status --porcelain`. If non-empty:
- Show the user a summary of the changes (file count, staged vs unstaged).
- Ask: "Commit these before syncing? Reply with a conventional commit subject (e.g. `docs: update architecture diagram`), or `abort` to stop."
- If they give a subject: `git add -A`, then commit with that subject.
- If `abort`: STOP. Tell them to deal with the uncommitted work first.

### 5. Check the main worktree is clean

Run `git -C <main-path> status --porcelain`. If non-empty, STOP:
> The main worktree at `<main-path>` has uncommitted changes. Resolve those first (commit or stash) — syncing on top of dirty state risks losing work.

## Decide which direction(s) to sync

### 6. Compute the divergence

Run:
- `git -C <main-path> rev-parse <main-branch>` → `<main-head>`
- `git rev-parse <feature-branch>` → `<feature-head>`
- `git merge-base <feature-branch> <main-branch>` → `<base>` (run from current worktree, which sees both refs)

Determine:
- **Forward needed**: `<feature-head>` ≠ `<base>` (feature has commits not on main).
- **Reverse needed**: `<main-head>` ≠ `<base>` (main has commits not on feature).

If neither is needed: tell the user "Already in sync. Nothing to do." STOP.

## Forward: feature → main

### 7. If forward is needed

Run from the main worktree, with an explicit `--no-ff` so the sync point is a recognizable merge commit on `main`:

```bash
git -C <main-path> merge --no-ff <feature-branch> -m "Sync <feature-branch> into <main-branch>"
```

If conflicts:
- STOP. Tell the user:
  > Conflicts merging `<feature-branch>` into `<main-branch>`. The main worktree at `<main-path>` is in a conflicted state. Open its Antigravity window, resolve there, complete the merge. Then re-run `/worktree-sync` to handle the reverse direction.
- Do not auto-resolve, do not `git merge --abort`.

If forward fails for any other reason (e.g., `<main-branch>` doesn't exist in that worktree), surface the error verbatim and stop.

After a successful forward merge, `<main-head>` has advanced. The reverse direction now has work to do even if it didn't before — recompute or just always proceed to step 8.

## Reverse: main → feature

### 8. If reverse is needed (or always after a successful forward)

Run from the current feature worktree. Use a default merge (no `--no-ff`) so a fast-forward is taken when possible — that keeps the feature branch's history clean:

```bash
git merge <main-branch> -m "Sync <main-branch> into <feature-branch>"
```

When the feature is now a strict ancestor of main (which is true right after a successful forward), git will fast-forward without creating a merge commit. When main has its own commits the forward step didn't touch, git creates a regular merge commit on the feature branch.

If conflicts:
- STOP. Tell the user:
  > Conflicts merging `<main-branch>` into `<feature-branch>`. Resolve them here in this worktree, commit the resolution, then continue your work. The forward direction already landed — `<main-branch>` has your earlier work-so-far.
- Do not auto-resolve or auto-abort.

## Report

Tell the user concisely:
- Forward: `merged <feature-branch> into <main-branch>` (or `no forward changes` if skipped)
- Reverse: `merged <main-branch> into <feature-branch>` / `fast-forwarded <feature-branch> to <main-branch>` / `no reverse changes`
- The feature worktree is still alive at `<feature-path>` — continue working.
- Reminder: nothing was pushed to the remote.

## What NOT to do

- Don't push to a remote. This skill is local-only by design.
- Don't remove the worktree or delete the branch — that's `/worktree-finish`'s job. After `/worktree-sync`, the worktree continues to exist and you keep working in it.
- Don't run this from the main worktree — refuse cleanly per step 1.
- Don't auto-resolve or auto-abort merge conflicts in either direction. Hand them back to the user with clear instructions about which window to resolve them in.
- Don't squash or rebase. Forward uses `--no-ff` to mark sync points clearly on `main`; reverse uses default merge so fast-forwards stay linear.
- Don't sync if either worktree has uncommitted changes that haven't been addressed in steps 4 / 5.
- Don't run this on partially broken code that would break `main` for other worktrees — recommend the user finish a clean checkpoint first.
