## Codex adaptations

You run as a Codex subagent inside the parent's checkout and sandbox. The orchestrator assigns you a worktree directory (`.worktrees/<branch>`): run every command with that directory as the working directory and never touch files outside it. Commit there with a conventional commit message. Your final message is your return summary — end it with the branch name and commit hash. `BLOCKER:` lines are read by the orchestrator exactly as the role text describes.
