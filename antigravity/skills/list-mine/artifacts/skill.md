# list-mine Skill

Use this skill to dynamically discover and list all custom agents and commands currently registered in the workspace.

## Instructions for the Agent
When the user asks to "list my agents" or uses the `/list-mine` command, follow these steps to provide an accurate, up-to-date menu:

1. **Scan the Knowledge Directory**: Run `ls -d antigravity/knowledge/*/` to find all custom Knowledge Item folders.
2. **Read Metadata**: For each folder found, read its `metadata.json` to get the `title` and `summary`.
3. **Categorize and Present**:
   - **Agents**: Usually items with short names (e.g., `pm`, `tl`, `qa`, `planner`).
   - **Commands**: Usually items with hyphenated names (e.g., `dev-cycle`, `sync-from-claude`, `list-mine`).
4. **Output**: Generate a clean, formatted list for the user with descriptions.

## Example Output Format
"Here are your currently available custom tools:
### Agents
- **pm**: <summary from metadata>
- **tl**: <summary from metadata>
...
### Commands
- **/dev-cycle**: <summary from metadata>
..."
