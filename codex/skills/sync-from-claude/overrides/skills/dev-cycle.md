## Codex adaptations

**Phase 3 on Codex.** Subagents share this checkout and sandbox; there is no per-agent worktree isolation. Reproduce it:

1. Once per cycle: `mkdir -p .worktrees`, and make sure `.worktrees/` is listed in `.gitignore` (commit that line if you add it, before Checkpoint A).
2. For each task in the group, in this same turn: `git worktree add .worktrees/<branch> -b <branch> HEAD`, then `spawn_agent(agent_type="coder", task_name="<worktree-label>: <task id>", message=<the self-contained task prompt> + "Work only inside `.worktrees/<branch>`: run every command with that directory as the working directory, commit there, and end your reply with the branch name and commit hash.")`.
3. `wait_agent` on all of them. A coder's final message is its return summary; `BLOCKER:` handling is unchanged.
4. Phase 3.5 merges the reported branches exactly as written, then `git worktree remove .worktrees/<branch>` (`--force` for a rejected branch) and deletes the branch.

If the sandbox refuses `git worktree add`, fall back to running the group's tasks sequentially in this checkout — one coder at a time, each committing before the next starts — and say so in the exit report.

**Owner questions.** Every `AskUserQuestion` step (Mocks Check, Phase 1.5): register the queue entry as written, then print the question with its options as your final message and end the turn, leaving `docs/loop-state.md` in the state the text prescribes for "unanswered" (`blocked` for the Mocks Check, `checkpoint` with `Pause: plan-review` for the plan review). The next `$dev-cycle` run's Setup sweep reads the answer.

**`/loop`.** Codex has no loop primitive. "`/loop $dev-cycle`" means: after a `continue` status, run this skill again in the same turn, until the status is `checkpoint`, `done`, or `blocked`, or the `--until` target is reached.
