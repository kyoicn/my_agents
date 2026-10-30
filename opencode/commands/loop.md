---
description: "Run a command again and again in this turn until it reports a stopping status — OpenCode's stand-in for Claude Code's /loop. Usage: /loop /dev-cycle [args]"
---
Run the command named at the start of the arguments repeatedly, in this same turn.

1. The first argument is the command, with or without its slash (for example `/dev-cycle`). Everything after it is that command's arguments (for example `--until done`), passed through unchanged every time.
2. Read `~/.config/opencode/commands/<command>.md` and follow it with those arguments.
3. When it stops, read the status it reports. `continue` → go back to step 2. `checkpoint`, `done`, or `blocked`, or no status at all → stop, and give that stop's report as the command describes it.

The command itself decides where to pause: `/dev-cycle` reads `--until` and the checkpoint rules and reports `checkpoint` when the owner should look.

ARGUMENTS: $ARGUMENTS
