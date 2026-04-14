# claude-code-public-skill

Public Claude Code **plugin marketplace** by FenrirZheng.

## Plugins

### [`tags-symbol-lookup`](./plugins/tags-symbol-lookup)

Symbol lookup via GNU Global (`gtags`), with fallback to ctags or `rg`. Answers "where is X defined?" and "who calls Y?" with authoritative `file:line` results instead of noisy full-text search.

- Decision flow for `-x` (definitions), `-rx` (callers), `-sx` (strings/comments), `-gx` (regex)
- Pitfalls: framework callbacks, dynamic dispatch, index staleness
- Bundled `gtags.sh` — native + pygments parser, writes db to `./tags/`, git-root safety guard

### [`open-in-zed`](./plugins/open-in-zed)

Slash command `/open-in-zed` that collects every file read, edited, or created during the current session and opens them all in Zed with a single `zed ...` invocation. Skips non-existent paths and noise directories (`node_modules`, `.git`, `target`, etc.).

### [`open-in-intellij`](./plugins/open-in-intellij)

Slash command `/open-in-intellij` plus a companion skill that opens session-touched files in IntelliJ IDEA through the IntelliJ MCP server (`mcp__idea__open_file_in_editor`).

### [`intellij-code-reference`](./plugins/intellij-code-reference)

Skill that routes semantic code investigation ("where is X defined?", "who calls Y?", "what implements Z?", "how is this wired?") through the IntelliJ MCP server when a project is open in IDEA. Uses IntelliJ's live PSI/index — distinguishes real call sites from string literals, resolves overloads and framework wiring (Spring, JPA, MyBatis), and avoids the gitignore/scope pitfalls of `rg`. Layers with `tags-symbol-lookup` (gtags first for plain lookups) and `rg` (last resort).

## Installation

```bash
# Add this repo as a marketplace (from GitHub)
/plugin marketplace add FenrirZheng/fenrir-claude-public-skills

# Install plugins
/plugin install tags-symbol-lookup@fenrir-claude-public-skills
/plugin install open-in-zed@fenrir-claude-public-skills
/plugin install open-in-intellij@fenrir-claude-public-skills
/plugin install intellij-code-reference@fenrir-claude-public-skills
```

For local development from a clone:

```bash
/plugin marketplace add /absolute/path/to/claude-code-public-skill
/plugin install tags-symbol-lookup@fenrir-claude-public-skills
/plugin install open-in-zed@fenrir-claude-public-skills
/plugin install open-in-intellij@fenrir-claude-public-skills
/plugin install intellij-code-reference@fenrir-claude-public-skills
```

### System dependencies (for `tags-symbol-lookup`)

```bash
sudo apt install global universal-ctags python3-pygments
```

## Usage

Skills activate automatically based on their `description` frontmatter. For `tags-symbol-lookup`, trigger phrases like:

- "where is `UserRepository` defined?"
- "who calls `processOrder`?"
- "find the `validate` function"

## Layout

```
claude-code-public-skill/
├── .claude-plugin/
│   └── marketplace.json
└── plugins/
    ├── tags-symbol-lookup/
    │   ├── .claude-plugin/
    │   │   └── plugin.json
    │   └── skills/
    │       └── tags-symbol-lookup/
    │           ├── SKILL.md
    │           ├── gtags.sh
    │           └── evals/
    │               └── evals.json
    ├── open-in-zed/
    │   ├── .claude-plugin/
    │   │   └── plugin.json
    │   └── commands/
    │       └── open-in-zed.md
    ├── open-in-intellij/
    │   ├── .claude-plugin/
    │   │   └── plugin.json
    │   ├── commands/
    │   │   └── open-in-intellij.md
    │   └── skills/
    │       └── open-in-intellij/
    │           └── SKILL.md
    └── intellij-code-reference/
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            └── intellij-code-reference/
                ├── SKILL.md
                └── evals/
                    └── evals.json
```

## Comparison vs IDEA ACP (Agent) calling the idea MCP

![alt text](imgs/gtags-vs-idea-mcp.png)
