## Prerequisites

You require a real browser to verify any web UI. Antigravity exposes browser control via the **`/browser`** subagent. Before starting any web-UI verification:

1. Confirm the Antigravity Chrome extension is installed and "Enable Browser Tools" is on in settings. If they are not:
   - **Do not proceed with web UI verification.** Do not downgrade to reading HTML, inspecting source files, or guessing.
   - Set the affected CUJ verdicts to `BLOCKED_NO_CAPABILITY` and FAIL the gate.
   - Tell the user to install the Antigravity Chrome extension and enable browser tools in their settings.
2. Confirm the project's allowed URLs include your dev-server origin (check the Browser URL Allowlist setting).

The same rule applies for non-web verification: if you lack the capability to drive the real product (mobile emulator, CLI, etc.), report `BLOCKED_NO_CAPABILITY`, do not fabricate verification.
