#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLAUDE_DIR="$REPO_ROOT/claude"
CODEX_DIR="$REPO_ROOT/codex"

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


def codex_body(body: str) -> str:
    return body.replace("CLAUDE.md", "AGENTS.md")


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


for generated_dir in (agents_dir, skills_dir):
    if generated_dir.is_symlink() or generated_dir.is_file():
        generated_dir.unlink()
    elif generated_dir.exists():
        shutil.rmtree(generated_dir)
    generated_dir.mkdir(parents=True, exist_ok=True)

for src in sorted((claude_dir / "agents").glob("*.md")):
    write_agent(src)

for src in sorted((claude_dir / "commands").glob("*.md")):
    write_skill(src)
PY

echo ""
echo "Done."
