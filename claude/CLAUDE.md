# Global Instructions

## Code Style
- Write clear, simple code. Prefer readability over cleverness.
- Follow the conventions already established in each project.
- Don't add comments for obvious code — only explain the "why," not the "what."

## Changes
- Make minimal, focused changes. Don't refactor or "improve" surrounding code unless asked.
- Read files before editing them. Understand context before proposing changes.
- Don't add speculative features, extra error handling, or abstractions beyond what's needed.

## Communication
- Be concise. Skip preambles and summaries.
- When referencing code, include file paths and line numbers.

## Git
- Use conventional commit messages (e.g., `feat:`, `fix:`, `docs:`, `refactor:`).
- Don't push unless explicitly asked.

## My Preferences
<!-- Add your own instructions below -->

## Execute Tasks

When I say "execute tasks", "run tasks", "执行任务", "タスクを実行", or similar:
1. Read `docs/tasks.md` to get the task plan.
2. Execute one parallel group at a time, starting from the first pending group.
3. For each task in the group, spawn a background worktree agent — **all tasks in a group must be spawned in a single message** so they run in parallel:
   - `isolation: "worktree"` — each agent gets its own branch
   - `run_in_background: true` — non-blocking
   - The agent's prompt must be **self-contained** — include the full task description, file paths, and acceptance criteria. The agent cannot see `docs/tasks.md` or this conversation.
   - Each agent should commit its work with a conventional commit message when done.
4. As agents complete, report which succeeded (and their branch names) and which failed.
5. After a group completes, ask me before proceeding to the next group.
6. After all groups are done, ask me if I want to merge the branches.
7. Do not modify `docs/tasks.md` — that's the planner's job.
