#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   sync-from-claude.sh            regenerate the Codex port into codex/
#   sync-from-claude.sh --check    regenerate into a temp dir; exit 1 if codex/ differs
#   sync-from-claude.sh --out DIR  regenerate into DIR instead of codex/
#
# Inputs:  claude/ (canonical) and codex/skills/sync-from-claude/ (platform-notes.md, overrides/).
# Outputs: codex/agents/*.toml, codex/skills/<name>/SKILL.md (marked), codex/AGENTS.md.

# Resolve through symlinks (pwd -P) so the script works whether invoked
# directly from the repo or from its deployed symlink under ~/.codex/skills/.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
SYNC_SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
CODEX_DIR="$(cd "$SYNC_SKILL_DIR/../.." && pwd -P)"
REPO_ROOT="$(cd "$CODEX_DIR/.." && pwd -P)"
CLAUDE_DIR="$REPO_ROOT/claude"

CHECK=0
OUT_DIR="$CODEX_DIR"
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
  echo "Syncing Claude definitions into Codex format..."
  echo "Source: $CLAUDE_DIR"
  echo "Target: $OUT_DIR"
  echo ""
fi

export REPO_ROOT CLAUDE_DIR CODEX_DIR SYNC_SKILL_DIR OUT_DIR CHECK

python3 <<'PY'
import json
import os
import re
import shutil
import sys
from pathlib import Path

claude_dir = Path(os.environ["CLAUDE_DIR"])
codex_dir = Path(os.environ["CODEX_DIR"])            # the committed port; --check compares against it
out_dir = Path(os.environ["OUT_DIR"])                # where this run writes
check = os.environ.get("CHECK") == "1"
sync_skill_dir = Path(os.environ["SYNC_SKILL_DIR"])  # inputs: notes + overrides, never regenerated
agents_dir = out_dir / "agents"
skills_dir = out_dir / "skills"
overrides_dir = sync_skill_dir / "overrides"
notes_path = sync_skill_dir / "platform-notes.md"

managed_skill_marker = "<!-- generated-from: claude/commands -->"
managed_agent_marker = "# generated-from: claude/agents — do not edit; regenerate with codex/skills/sync-from-claude"
managed_agents_md_marker = "<!-- generated-from: claude/CLAUDE.md — do not edit; regenerate with codex/skills/sync-from-claude -->"

# Claude commands with no Codex counterpart. Everything else is ported.
SKIP_SKILLS = {
    "worktree-start",  # opens a new Antigravity window
}

SYNC_BLOCK_RE = re.compile(
    r"<!-- SYNC:([a-z0-9-]+) -->\n?(.*?)\n?<!-- /SYNC:\1 -->",
    re.DOTALL,
)

command_names = sorted(p.stem for p in (claude_dir / "commands").glob("*.md"))
# `/dev-cycle` → `$dev-cycle`, but never inside a path or URL (`docs/design-feature`, `x/dev-cycle`).
SLASH_RE = re.compile(
    r"(?<![\w/.\-])/(" + "|".join(re.escape(n) for n in command_names) + r")(?![\w\-])"
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


def toml_literal(value: str) -> str:
    if "'''" in value:
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"""{escaped}"""'
    return f"'''\n{value}'''"


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
    """Deterministic Claude→Codex rewrites. Anything semantic that cannot be a
    textual rewrite is explained once in platform-notes.md, which is prepended
    to every generated artifact."""
    text = apply_sync_overrides(text)
    text = SLASH_RE.sub(r"$\1", text)
    text = text.replace("~/.claude/commands/", "~/.codex/skills/")
    text = text.replace("~/.claude/agents/", "~/.codex/agents/")
    text = text.replace("~/.claude/", "~/.codex/")
    text = re.sub(r"\bclaude/agents/([a-z0-9-]+)\.md", r"~/.codex/agents/\1.toml", text)
    text = re.sub(r"\bclaude/commands/([a-z0-9-]+)\.md", r"~/.codex/skills/\1/SKILL.md", text)
    text = text.replace("subagent_type", "agent_type")
    text = text.replace("CLAUDE.md", "AGENTS.md")
    return text


notes = notes_path.read_text(encoding="utf-8").strip() + "\n" if notes_path.exists() else ""


def codex_override(kind: str, name: str) -> str:
    """overrides/agents/<name>.md or overrides/skills/<name>.md, appended to the
    generated artifact so Codex-specific behavior survives every regeneration."""
    path = overrides_dir / kind / f"{name}.md"
    if path.exists():
        return "\n" + path.read_text(encoding="utf-8").strip() + "\n"
    return ""


def write_agent(src: Path):
    metadata, body = parse_markdown(src)
    name = metadata.get("name") or src.stem
    description = metadata.get("description", "")
    target = agents_dir / f"{name}.toml"
    instructions = notes + "\n" + map_platform(body) + codex_override("agents", name)

    target.write_text(
        "\n".join(
            [
                managed_agent_marker,
                f"description = {json.dumps(description, ensure_ascii=False)}",
                f"developer_instructions = {toml_literal(instructions)}",
                f"name = {json.dumps(name, ensure_ascii=False)}",
                "",
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
                f"name: {json.dumps(name, ensure_ascii=False)}",
                f"description: {json.dumps(map_platform(description), ensure_ascii=False)}",
                "---",
                "",
                managed_skill_marker,
                "",
                f"# {name}",
                "",
                f"Use this skill when the user asks to run `${name}`.",
                "",
                notes,
                "## Command Template",
                "",
                map_platform(body).rstrip(),
                codex_override("skills", name),
            ]
        ),
        encoding="utf-8",
    )
    if not check:
        print(f"  SKILL {name} -> {target.relative_to(out_dir)}")


def write_agents_md(src: Path):
    target = out_dir / "AGENTS.md"
    body = src.read_text(encoding="utf-8")
    target.write_text(
        managed_agents_md_marker + "\n\n" + notes + "\n" + map_platform(body).rstrip() + "\n",
        encoding="utf-8",
    )
    if not check:
        print(f"  AGENTS.md -> {target.relative_to(out_dir)}")


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
            print(f"  SKIP  {src.stem} (no Codex counterpart)")
        continue
    write_skill(src)

claude_md = claude_dir / "CLAUDE.md"
if claude_md.exists():
    write_agents_md(claude_md)


def managed_outputs(root: Path):
    """Relative paths of every generated artifact under root, found by marker."""
    rels = set()
    for p in (root / "agents").glob("*.toml"):
        if managed_agent_marker in p.read_text(encoding="utf-8"):
            rels.add(p.relative_to(root).as_posix())
    for p in (root / "skills").glob("*/SKILL.md"):
        if managed_skill_marker in p.read_text(encoding="utf-8"):
            rels.add(p.relative_to(root).as_posix())
    p = root / "AGENTS.md"
    if p.exists() and managed_agents_md_marker in p.read_text(encoding="utf-8"):
        rels.add("AGENTS.md")
    return rels


if check:
    stale = []
    for rel in sorted(managed_outputs(out_dir) | managed_outputs(codex_dir)):
        fresh, current = out_dir / rel, codex_dir / rel
        if not current.exists():
            stale.append(f"{rel}  (missing)")
        elif not fresh.exists():
            stale.append(f"{rel}  (no longer generated; delete it)")
        elif fresh.read_bytes() != current.read_bytes():
            stale.append(f"{rel}  (differs)")
    if stale:
        print(f"Codex port is stale ({len(stale)} files):")
        for line in stale:
            print(f"  codex/{line}")
        print("Run: ./codex/skills/sync-from-claude/scripts/sync-from-claude.sh && git add -A codex")
        sys.exit(1)
    print("Codex port is up to date.")
PY

if [[ $CHECK -eq 0 ]]; then
  echo ""
  echo "Done."
fi
