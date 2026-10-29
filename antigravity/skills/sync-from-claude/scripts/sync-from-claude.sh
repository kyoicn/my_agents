#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sync-from-claude.sh            regenerate the Antigravity port into antigravity/
#   sync-from-claude.sh --check    regenerate into a temp dir; exit 1 if antigravity/ differs
#   sync-from-claude.sh --out DIR  regenerate into DIR instead of antigravity/
#
# Inputs:  claude/ (canonical) and antigravity/skills/sync-from-claude/ (platform-notes.md, overrides/).
# Outputs: antigravity/agents/<name>.md, antigravity/skills/<name>/SKILL.md (marked), antigravity/GEMINI.md.
#
# Target format: Antigravity's customization system — custom agents are Markdown with YAML
# frontmatter (name, description), skills are skills/<name>/SKILL.md, rules are GEMINI.md.

# Resolve through symlinks (pwd -P) so the script works whether invoked
# directly from the repo or from its deployed symlink under ~/.gemini/config/skills/.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SYNC_SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AG_DIR="$(cd "$SYNC_SKILL_DIR/../.." && pwd -P)"
REPO_ROOT="$(cd "$AG_DIR/.." && pwd -P)"
CLAUDE_DIR="$REPO_ROOT/claude"

CHECK=0
OUT_DIR="$AG_DIR"
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
  echo "Syncing Claude definitions into Antigravity format..."
  echo "Source: $CLAUDE_DIR"
  echo "Target: $OUT_DIR"
  echo ""
fi

export REPO_ROOT CLAUDE_DIR AG_DIR SYNC_SKILL_DIR OUT_DIR CHECK

python3 <<'PY'
import json
import os
import re
import shutil
import sys
from pathlib import Path

claude_dir = Path(os.environ["CLAUDE_DIR"])
ag_dir = Path(os.environ["AG_DIR"])                  # the committed port; --check compares against it
out_dir = Path(os.environ["OUT_DIR"])                # where this run writes
check = os.environ.get("CHECK") == "1"
sync_skill_dir = Path(os.environ["SYNC_SKILL_DIR"])  # inputs: notes + overrides, never regenerated
agents_dir = out_dir / "agents"
skills_dir = out_dir / "skills"
overrides_dir = sync_skill_dir / "overrides"
notes_path = sync_skill_dir / "platform-notes.md"

managed_skill_marker = "<!-- generated-from: claude/commands — do not edit; regenerate with antigravity/skills/sync-from-claude -->"
managed_agent_marker = "<!-- generated-from: claude/agents — do not edit; regenerate with antigravity/skills/sync-from-claude -->"
managed_rules_marker = "<!-- generated-from: claude/CLAUDE.md — do not edit; regenerate with antigravity/skills/sync-from-claude -->"

# Claude commands with no Antigravity counterpart. Everything else is ported.
SKIP_SKILLS = set()

SYNC_BLOCK_RE = re.compile(
    r"<!-- SYNC:([a-z0-9-]+) -->\n?(.*?)\n?<!-- /SYNC:\1 -->",
    re.DOTALL,
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
    """Deterministic Claude→Antigravity rewrites. Slash commands keep their names.
    Anything semantic that cannot be a textual rewrite is explained once in
    platform-notes.md, which is prepended to every generated artifact."""
    text = apply_sync_overrides(text)
    text = text.replace("~/.claude/commands/", "~/.gemini/config/skills/")
    text = text.replace("~/.claude/agents/", "~/.gemini/config/agents/")
    text = text.replace("~/.claude/", "~/.gemini/config/")
    text = re.sub(r"\bclaude/agents/([a-z0-9-]+)\.md", r"~/.gemini/config/agents/\1.md", text)
    text = re.sub(r"\bclaude/commands/([a-z0-9-]+)\.md", r"~/.gemini/config/skills/\1/SKILL.md", text)
    text = text.replace("CLAUDE.md", "GEMINI.md")
    return text


notes = notes_path.read_text(encoding="utf-8").strip() + "\n" if notes_path.exists() else ""


def platform_override(kind: str, name: str) -> str:
    """overrides/agents/<name>.md or overrides/skills/<name>.md, appended to the
    generated artifact so Antigravity-specific behavior survives every regeneration."""
    path = overrides_dir / kind / f"{name}.md"
    if path.exists():
        return "\n" + path.read_text(encoding="utf-8").strip() + "\n"
    return ""


def write_agent(src: Path):
    metadata, body = parse_markdown(src)
    name = metadata.get("name") or src.stem
    description = metadata.get("description", "")
    target = agents_dir / f"{name}.md"
    # No `tools:` field: an agent then keeps Antigravity's default tool access.
    # Claude's per-role tool restrictions are not carried over (see SKILL.md).
    target.write_text(
        "\n".join(
            [
                "---",
                f"name: {name}",
                f"description: {yaml_string(description)}",
                "---",
                managed_agent_marker,
                "",
                notes,
                map_platform(body).rstrip(),
                platform_override("agents", name),
            ]
        ),
        encoding="utf-8",
    )
    if not check:
        print(f"  AGENT {name} -> {target.relative_to(out_dir)}")


def command_skill_name(src: Path) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "-", src.stem).strip("-").lower()


def write_skill(src: Path):
    metadata, body = parse_markdown(src)
    name = command_skill_name(src)
    description = metadata.get("description", f"Migrated source command `{src.stem}`.")
    target_dir = skills_dir / name
    target_dir.mkdir(parents=True, exist_ok=True)
    target = target_dir / "SKILL.md"

    target.write_text(
        "\n".join(
            [
                "---",
                f"name: {name}",
                f"description: {yaml_string(map_platform(description))}",
                "---",
                "",
                managed_skill_marker,
                "",
                f"# {name}",
                "",
                f"Use this skill when the user runs `/{name}`.",
                "",
                notes,
                "## Command Template",
                "",
                map_platform(body).rstrip(),
                platform_override("skills", name),
            ]
        ),
        encoding="utf-8",
    )
    if not check:
        print(f"  SKILL {name} -> {target.relative_to(out_dir)}")


def write_rules(src: Path):
    target = out_dir / "GEMINI.md"
    body = src.read_text(encoding="utf-8")
    target.write_text(
        managed_rules_marker + "\n\n" + notes + "\n" + map_platform(body).rstrip() + "\n",
        encoding="utf-8",
    )
    if not check:
        print(f"  GEMINI.md -> {target.relative_to(out_dir)}")


if agents_dir.is_symlink() or agents_dir.is_file():
    agents_dir.unlink()
elif agents_dir.exists():
    shutil.rmtree(agents_dir)
agents_dir.mkdir(parents=True, exist_ok=True)

if skills_dir.is_symlink() or skills_dir.is_file():
    skills_dir.unlink()
skills_dir.mkdir(parents=True, exist_ok=True)

for skill_file in skills_dir.glob("*/SKILL.md"):
    if managed_skill_marker in skill_file.read_text(encoding="utf-8"):
        shutil.rmtree(skill_file.parent)

for src in sorted((claude_dir / "agents").glob("*.md")):
    write_agent(src)

for src in sorted((claude_dir / "commands").glob("*.md")):
    if command_skill_name(src) in SKIP_SKILLS:
        if not check:
            print(f"  SKIP  {src.stem} (no Antigravity counterpart)")
        continue
    write_skill(src)

claude_md = claude_dir / "CLAUDE.md"
if claude_md.exists():
    write_rules(claude_md)


def managed_outputs(root: Path):
    """Relative paths of every generated artifact under root, found by marker."""
    rels = set()
    for p in (root / "agents").glob("*.md"):
        if managed_agent_marker in p.read_text(encoding="utf-8"):
            rels.add(p.relative_to(root).as_posix())
    for p in (root / "skills").glob("*/SKILL.md"):
        if managed_skill_marker in p.read_text(encoding="utf-8"):
            rels.add(p.relative_to(root).as_posix())
    p = root / "GEMINI.md"
    if p.exists() and managed_rules_marker in p.read_text(encoding="utf-8"):
        rels.add("GEMINI.md")
    return rels


if check:
    stale = []
    for rel in sorted(managed_outputs(out_dir) | managed_outputs(ag_dir)):
        fresh, current = out_dir / rel, ag_dir / rel
        if not current.exists():
            stale.append(f"{rel}  (missing)")
        elif not fresh.exists():
            stale.append(f"{rel}  (no longer generated; delete it)")
        elif fresh.read_bytes() != current.read_bytes():
            stale.append(f"{rel}  (differs)")
    if stale:
        print(f"Antigravity port is stale ({len(stale)} files):")
        for line in stale:
            print(f"  antigravity/{line}")
        print("Run: ./antigravity/skills/sync-from-claude/scripts/sync-from-claude.sh && git add -A antigravity")
        sys.exit(1)
    print("Antigravity port is up to date.")
PY

if [[ $CHECK -eq 0 ]]; then
  echo ""
  echo "Done."
fi
