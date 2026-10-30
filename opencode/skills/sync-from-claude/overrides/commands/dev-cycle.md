## OpenCode adaptations

**Phase 3 on OpenCode.** Subagents share this checkout; there is no per-agent worktree isolation. Reproduce it:

1. Once per cycle: `mkdir -p .worktrees`, and make sure `.worktrees/` is listed in `.gitignore` (commit that line if you add it, before Checkpoint A).
2. For each task in the group, in this same turn: `git worktree add .worktrees/<branch> -b <branch> HEAD`, then call the `subagent` tool with `agent: "coder"`, `description: "<worktree-label>: <task id>"`, and the self-contained task prompt followed by: "Work only inside `.worktrees/<branch>`: run every command with that directory as the working directory, commit there, and end your reply with the branch name and commit hash."
3. Wait for all of them. A coder's final message is its return summary; `BLOCKER:` handling is unchanged.
4. Phase 3.5 merges the reported branches exactly as written, then `git worktree remove .worktrees/<branch>` (`--force` for a rejected branch) and deletes the branch.

If `git worktree add` fails, fall back to running the group's tasks sequentially in this checkout — one coder at a time, each committing before the next starts — and say so in the exit report.

**`/loop`.** OpenCode has no loop primitive. "`/loop /dev-cycle`" means: after a `continue` status, run this command again in the same turn, until the status is `checkpoint`, `done`, or `blocked`, or the `--until` target is reached.
