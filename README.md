# claude-code-public-skill

Public Claude Code skills.

## Skills

### [`tags-symbol-lookup`](./tags-symbol-lookup)

Symbol lookup via GNU Global (`gtags`), with fallback to ctags or `rg`. Answers "where is X defined?" and "who calls Y?" with authoritative `file:line` results instead of noisy full-text search.

- Decision flow for `-x` (definitions), `-rx` (callers), `-sx` (strings/comments), `-gx` (regex)
- Pitfalls: framework callbacks, dynamic dispatch, index staleness
- Bundled `gtags.sh` — native + pygments parser, writes db to `./tags/`, git-root safety guard
- ctags fallback via `tags.sh`

## Installation

Clone into your Claude Code skills directory:

```bash
git clone https://github.com/<user>/claude-code-public-skill ~/.claude/skills/public
```

Or symlink an individual skill:

```bash
ln -s "$PWD/tags-symbol-lookup" ~/.claude/skills/tags-symbol-lookup
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
tags-symbol-lookup/
├── SKILL.md          # skill definition + usage guidance
├── gtags.sh          # GNU Global index generator
└── evals/
    └── evals.json    # skill evaluation cases
```

## 和IDEA ACP (Agent) 調用 idea MCP 比較結果

![alt text](imgs/gtags-vs-idea-mcp.png)
