## Prerequisites

You require a real browser to verify any web UI. Codex uses its **bundled `browser@openai-bundled` plugin** to drive an in-app browser (IAB) via the Node REPL JavaScript tool (`mcp__node_repl__js`). The browser API is exposed as a JavaScript runtime — `agent.browsers.get("iab")` returns a `browser` handle whose `tabs`, `tab.playwright`, `tab.screenshot`, and `tab.dev.logs` methods drive verification.

Before starting any web-UI verification:

1. Confirm the bundled browser plugin is enabled. Check `~/.codex/config.toml` for the entry:
   ```toml
   [plugins."browser@openai-bundled"]
   enabled = true
   ```
2. Confirm the bundled **Browser** skill is loaded for this session — its `SKILL.md` is mandatory reading before browser work. If you cannot locate the skill or the `mcp__node_repl__js` tool is missing, the plugin is not available.

If the browser plugin is not available:
- **Do not proceed with web UI verification.** Do not downgrade to reading HTML, inspecting source files, or guessing.
- Set the affected CUJ Results to `BLOCKED` and FAIL the gate.
- Tell the user to enable the bundled browser plugin in `~/.codex/config.toml` and restart Codex.

Do NOT substitute Computer Use, Puppeteer MCP, or a separate Playwright MCP server for the bundled `@browser` plugin — the bundled plugin is the supported surface and the only one this skill is calibrated for.

The same rule applies for non-web verification: if you lack the capability to drive the real product (mobile emulator, CLI, etc.), set Result to `BLOCKED`, do not fabricate verification.
