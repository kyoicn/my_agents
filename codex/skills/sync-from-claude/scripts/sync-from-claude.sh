#!/usr/bin/env bash
set -euo pipefail

# Resolve through symlinks (pwd -P) so the script works whether invoked
# directly from the repo or from its deployed symlink under ~/.codex/skills/.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
CODEX_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd -P)"
REPO_ROOT="$(cd "$CODEX_DIR/.." && pwd -P)"
CLAUDE_DIR="$REPO_ROOT/claude"

if [[ ! -d "$CLAUDE_DIR" ]]; then
  echo "Error: source directory not found: $CLAUDE_DIR" >&2
  exit 1
fi

echo "Syncing Claude definitions into Codex format..."
echo "Source: $CLAUDE_DIR"
echo "Target: $CODEX_DIR"
echo ""

export REPO_ROOT CLAUDE_DIR CODEX_DIR

python3 <<'PY'
import json
import os
import re
import shutil
from pathlib import Path

claude_dir = Path(os.environ["CLAUDE_DIR"])
codex_dir = Path(os.environ["CODEX_DIR"])
agents_dir = codex_dir / "agents"
skills_dir = codex_dir / "skills"
overrides_dir = codex_dir / "skills" / "sync-from-claude" / "overrides"
managed_skill_marker = "<!-- generated-from: claude/commands -->"

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


def toml_literal(value: str) -> str:
    if "'''" in value:
        escaped = value.replace("\\", "\\\\").replace('"', '\\"')
        return f'"""{escaped}"""'
    return f"'''\n{value}'''"


def apply_sync_overrides(body: str) -> str:
    """Replace each `<!-- SYNC:<name> -->...<!-- /SYNC:<name> -->` block with the
    contents of overrides/<name>.md if it exists. Otherwise strip only the
    markers and keep the canonical content."""

    def replace(match: re.Match) -> str:
        name = match.group(1)
        override = overrides_dir / f"{name}.md"
        if override.is_file():
            return override.read_text(encoding="utf-8").rstrip("\n")
        return match.group(2)

    return SYNC_BLOCK_RE.sub(replace, body)


def codex_body(body: str) -> str:
    return apply_sync_overrides(body).replace("CLAUDE.md", "AGENTS.md")


def write_agent(src: Path):
    metadata, body = parse_markdown(src)
    name = metadata.get("name") or src.stem
    description = metadata.get("description", "")
    target = agents_dir / f"{name}.toml"

    target.write_text(
        "\n".join(
            [
                f"description = {json.dumps(description, ensure_ascii=False)}",
                f"developer_instructions = {toml_literal(codex_body(body))}",
                f"name = {json.dumps(name, ensure_ascii=False)}",
                "",
            ]
        ),
        encoding="utf-8",
    )
    print(f"  AGENT {name} -> {target.relative_to(codex_dir)}")


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
                f"description: {json.dumps(description, ensure_ascii=False)}",
                "---",
                "",
                managed_skill_marker,
                "",
                f"# {name}",
                "",
                f"Use this skill when the user asks to run `{src.stem}`.",
                "",
                "## Command Template",
                "",
                codex_body(body).rstrip(),
                "",
            ]
        ),
        encoding="utf-8",
    )
    print(f"  SKILL {name} -> {target.relative_to(codex_dir)}")


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
    write_skill(src)
PY

echo ""
echo "Done."
