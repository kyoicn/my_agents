#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sync-from-claude.sh            regenerate the OpenCode port into opencode/
#   sync-from-claude.sh --check    regenerate into a temp dir; exit 1 if opencode/ differs
#   sync-from-claude.sh --out DIR  regenerate into DIR instead of opencode/
#
# Inputs:  claude/ (canonical) and opencode/skills/sync-from-claude/ (platform-notes.md, overrides/).
# Outputs: opencode/agents/<name>.md, opencode/commands/<name>.md (marked), opencode/AGENTS.md.
#
# Target format: OpenCode v2 — agents are Markdown with YAML frontmatter (description, mode,
# permissions) and the body as system prompt; commands are Markdown templates invoked as /name;
# global rules are AGENTS.md.

# Resolve through symlinks (pwd -P) so the script works whether invoked
# directly from the repo or from its deployed symlink under ~/.config/opencode/skills/.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SYNC_SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OC_DIR="$(cd "$SYNC_SKILL_DIR/../.." && pwd -P)"
REPO_ROOT="$(cd "$OC_DIR/.." && pwd -P)"
CLAUDE_DIR="$REPO_ROOT/claude"

CHECK=0
OUT_DIR="$OC_DIR"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) CHECK=1 ;;
    --out) OUT_DIR="$2"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ ! -d "$CLAUDE_DIR" ]]; then
  echo "Error: source directory not found: $CLAUDE_DIR" >&2
  exit 1
fi

if [[ $CHECK -eq 1 ]]; then
  OUT_DIR="$(mktemp -d)"
  trap 'rm -rf "$OUT_DIR"' EXIT
else
  echo "Syncing Claude definitions into OpenCode format..."
  echo "Source: $CLAUDE_DIR"
  echo "Target: $OUT_DIR"
  echo ""
fi

export REPO_ROOT CLAUDE_DIR OC_DIR SYNC_SKILL_DIR OUT_DIR CHECK

python3 <<'PY'
import json
import os
import re
import sys
from pathlib import Path

claude_dir = Path(os.environ["CLAUDE_DIR"])
oc_dir = Path(os.environ["OC_DIR"])                  # the committed port; --check compares against it
out_dir = Path(os.environ["OUT_DIR"])                # where this run writes
check = os.environ.get("CHECK") == "1"
sync_skill_dir = Path(os.environ["SYNC_SKILL_DIR"])  # inputs: notes + overrides, never regenerated
agents_dir = out_dir / "agents"
commands_dir = out_dir / "commands"
overrides_dir = sync_skill_dir / "overrides"
notes_path = sync_skill_dir / "platform-notes.md"

managed_agent_marker = "<!-- generated-from: claude/agents — do not edit; regenerate with opencode/skills/sync-from-claude -->"
managed_command_marker = "<!-- generated-from: claude/commands — do not edit; regenerate with opencode/skills/sync-from-claude -->"
managed_rules_marker = "<!-- generated-from: claude/CLAUDE.md — do not edit; regenerate with opencode/skills/sync-from-claude -->"

# Claude commands with no OpenCode counterpart. Everything else is ported.
SKIP_COMMANDS = set()

# Claude tool → OpenCode v2 permission action. Action names verified with
# `opencode debug agents` on OpenCode v2.2.3.
TOOL_ACTIONS = {
    "Read": "read",
    "Grep": "grep",
    "Glob": "glob",
    "Bash": "shell",
    "Edit": "edit",
    "Write": "edit",
    "NotebookEdit": "edit",
    "WebSearch": "websearch",
    "WebFetch": "webfetch",
    "AskUserQuestion": "question",
    "Agent": "subagent",
    "Task": "subagent",
}
ACTION_ORDER = ["read", "grep", "glob", "shell", "edit", "websearch", "webfetch", "question", "subagent"]

SYNC_BLOCK_RE = re.compile(
    r"<!-- SYNC:([a-z0-9-]+) -->\n?(.*?)\n?<!-- /SYNC:\1 -->",
    re.DOTALL,
)

# OpenCode expands these in a command template; a literal one in a Claude command would be
# replaced by user arguments or run as a shell command.
TEMPLATE_HAZARD_RE = re.compile(r"\$\d|\$ARGUMENTS|!`")

# Claude Code names → OpenCode names. Parameter and tool renames only; behavior that has no
# OpenCode equivalent is explained in platform-notes.md or an override.
RENAMES = [
    ("claude mcp add --scope user playwright -- npx -y @playwright/mcp@latest",
     '<setup repo>/opencode/deploy.sh   # links ~/.config/opencode/opencode.json: Playwright MCP with "codemode": false'),
    ("mcp__playwright__", "playwright_"),          # MCP tools are <server>_<tool> with Code Mode off
    ("subagent_type", "agent"),                    # the subagent tool's parameter
    ("run_in_background", "background"),
    ('`isolation: "worktree"`', "own worktree `.worktrees/<branch>`"),
    ("AskUserQuestion", "question"),
    ("Agent tool", "`subagent` tool"),
    ("Read tool", "`read` tool"),
    ("Claude sessions", "OpenCode sessions"),
    ("Claude session", "OpenCode session"),
]
# Claude permission syntax: `Bash(<pattern>)` is a shell allow rule in opencode.json.
BASH_RULE_RE = re.compile(r"`Bash\(([^)`]*)\)`")

# Claude-only constructs that must not survive mapping. Checked on everything but the
# platform notes, which name them on purpose.
RESIDUE_RE = re.compile(
    r'subagent_type|run_in_background|isolation: *"worktree"|AskUserQuestion|mcp__|`Bash\(|\bAgent tool\b|\bRead tool\b|claude mcp add'
)


def parse_markdown(path: Path):
    text = path.read_text(encoding="utf-8")
    metadata = {}
    body = text

    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end != -1:
            frontmatter = text[4:end]
            body = text[end + len("\n---\n") :]
            for line in frontmatter.splitlines():
                if ":" not in line:
                    continue
                key, value = line.split(":", 1)
                value = value.strip()
                if (
                    len(value) >= 2
                    and value[0] == value[-1]
                    and value[0] in {"'", '"'}
                ):
                    value = value[1:-1]
                metadata[key.strip()] = value

    return metadata, body.strip() + "\n"


def yaml_string(value: str) -> str:
    # A JSON string is a valid YAML double-quoted scalar.
    return json.dumps(value, ensure_ascii=False)


def apply_sync_overrides(body: str) -> str:
    """Replace each `<!-- SYNC:<name> -->...<!-- /SYNC:<name> -->` block with the
    contents of overrides/<name>.md if it exists. Otherwise strip only the
    markers and keep the canonical content."""

    def replace(match):
        override = overrides_dir / f"{match.group(1)}.md"
        if override.exists():
            return override.read_text(encoding="utf-8").rstrip("\n")
        return match.group(2)

    return SYNC_BLOCK_RE.sub(replace, body)


def map_platform(text: str) -> str:
    """Deterministic Claude→OpenCode rewrites. Slash commands keep their names.
    Anything semantic that cannot be a textual rewrite is explained once in
    platform-notes.md, which is prepended to every generated artifact."""
    text = apply_sync_overrides(text)
    for old, new in RENAMES:
        text = text.replace(old, new)
    text = BASH_RULE_RE.sub(r"`\1` (a `shell` allow rule in opencode.json)", text)
    text = text.replace("~/.claude/commands/", "~/.config/opencode/commands/")
    text = text.replace("~/.claude/agents/", "~/.config/opencode/agents/")
    text = text.replace("~/.claude/", "~/.config/opencode/")
    text = re.sub(r"\bclaude/agents/([a-z0-9-]+)\.md", r"~/.config/opencode/agents/\1.md", text)
    text = re.sub(r"\bclaude/commands/([a-z0-9-]+)\.md", r"~/.config/opencode/commands/\1.md", text)
    text = text.replace("CLAUDE.md", "AGENTS.md")
    return text


notes = notes_path.read_text(encoding="utf-8").strip() + "\n" if notes_path.exists() else ""


def platform_override(kind: str, name: str) -> str:
    """overrides/agents/<name>.md or overrides/commands/<name>.md, appended to the
    generated artifact so OpenCode-specific behavior survives every regeneration."""
    path = overrides_dir / kind / f"{name}.md"
    if path.exists():
        return "\n" + path.read_text(encoding="utf-8").strip() + "\n"
    return ""


def assert_native(text: str, origin: str):
    residue = RESIDUE_RE.search(text)
    if residue:
        sys.exit(
            f"Error: {origin} still contains the Claude-only construct {residue.group(0)!r} after "
            "mapping. Add a rename, an override, or a SYNC block."
        )


def denied_actions(tools: str):
    """Claude's `tools:` list is an allow-list. Carry it as deny rules for the mapped
    actions it leaves out, so tools OpenCode adds (MCP servers, skills) stay available."""
    if not tools:
        return []
    granted = {TOOL_ACTIONS[t.strip()] for t in tools.split(",") if t.strip() in TOOL_ACTIONS}
    return [a for a in ACTION_ORDER if a not in granted]


def remove_marked(directory: Path, marker: str):
    if directory.is_symlink() or directory.is_file():
        directory.unlink()
    directory.mkdir(parents=True, exist_ok=True)
    for p in directory.glob("*.md"):
        if marker in p.read_text(encoding="utf-8"):
            p.unlink()


def write_agent(src: Path):
    metadata, body = parse_markdown(src)
    name = metadata.get("name") or src.stem
    description = metadata.get("description", "")
    target = agents_dir / f"{name}.md"
    mapped = map_platform(body).rstrip() + platform_override("agents", name)
    assert_native(mapped, f"claude/agents/{src.name}")
    # No `model:` field: a subagent then runs on the model of the session that invoked it.
    frontmatter = ["---", f"description: {yaml_string(description)}", "mode: subagent"]
    denied = denied_actions(metadata.get("tools", ""))
    if denied:
        frontmatter.append("permissions:")
        for action in denied:
            frontmatter += [f"  - action: {action}", '    resource: "*"', "    effect: deny"]
    frontmatter.append("---")
    target.write_text(
        "\n".join(
            frontmatter
            + [
                managed_agent_marker,
                "",
                notes,
                mapped,
            ]
        ),
        encoding="utf-8",
    )
    if not check:
        print(f"  AGENT   {name} -> {target.relative_to(out_dir)}")


def command_name(src: Path) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "-", src.stem).strip("-").lower()


def write_command(src: Path):
    metadata, body = parse_markdown(src)
    name = command_name(src)
    description = metadata.get("description", f"Migrated source command `{src.stem}`.")
    target = commands_dir / f"{name}.md"
    mapped = map_platform(body).rstrip() + platform_override("commands", name)
    assert_native(mapped, f"claude/commands/{src.name}")
    template = notes + "\n" + mapped
    hazard = TEMPLATE_HAZARD_RE.search(template)
    if hazard:
        sys.exit(
            f"Error: claude/commands/{src.name} contains {hazard.group(0)!r}, which OpenCode "
            "expands in a command template. Reword the source or extend the generator."
        )
    target.write_text(
        "\n".join(
            [
                "---",
                f"description: {yaml_string(map_platform(description))}",
                "---",
                managed_command_marker,
                "",
                template.rstrip(),
                "",
                "ARGUMENTS: $ARGUMENTS",
                "",
            ]
        ),
        encoding="utf-8",
    )
    if not check:
        print(f"  COMMAND {name} -> {target.relative_to(out_dir)}")


def write_rules(src: Path):
    target = out_dir / "AGENTS.md"
    mapped = map_platform(src.read_text(encoding="utf-8")).rstrip()
    assert_native(mapped, "claude/CLAUDE.md")
    target.write_text(
        managed_rules_marker + "\n\n" + notes + "\n" + mapped + "\n",
        encoding="utf-8",
    )
    if not check:
        print(f"  AGENTS.md -> {target.relative_to(out_dir)}")


remove_marked(agents_dir, managed_agent_marker)
remove_marked(commands_dir, managed_command_marker)

for src in sorted((claude_dir / "agents").glob("*.md")):
    write_agent(src)

for src in sorted((claude_dir / "commands").glob("*.md")):
    if command_name(src) in SKIP_COMMANDS:
        if not check:
            print(f"  SKIP    {src.stem} (no OpenCode counterpart)")
        continue
    write_command(src)

claude_md = claude_dir / "CLAUDE.md"
if claude_md.exists():
    write_rules(claude_md)


def managed_outputs(root: Path):
    """Relative paths of every generated artifact under root, found by marker."""
    rels = set()
    for sub, marker in (("agents", managed_agent_marker), ("commands", managed_command_marker)):
        for p in (root / sub).glob("*.md"):
            if marker in p.read_text(encoding="utf-8"):
                rels.add(p.relative_to(root).as_posix())
    p = root / "AGENTS.md"
    if p.exists() and managed_rules_marker in p.read_text(encoding="utf-8"):
        rels.add("AGENTS.md")
    return rels


if check:
    stale = []
    for rel in sorted(managed_outputs(out_dir) | managed_outputs(oc_dir)):
        fresh, current = out_dir / rel, oc_dir / rel
        if not current.exists():
            stale.append(f"{rel}  (missing)")
        elif not fresh.exists():
            stale.append(f"{rel}  (no longer generated; delete it)")
        elif fresh.read_bytes() != current.read_bytes():
            stale.append(f"{rel}  (differs)")
    if stale:
        print(f"OpenCode port is stale ({len(stale)} files):")
        for line in stale:
            print(f"  opencode/{line}")
        print("Run: ./opencode/skills/sync-from-claude/scripts/sync-from-claude.sh && git add -A opencode")
        sys.exit(1)
    print("OpenCode port is up to date.")
PY

if [[ $CHECK -eq 0 ]]; then
  echo ""
  echo "Done."
fi
