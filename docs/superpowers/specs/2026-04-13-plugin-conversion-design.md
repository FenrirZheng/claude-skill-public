# Plugin Conversion Design — claude-code-public-skill

Date: 2026-04-13
Status: Approved for implementation planning

## Goal

Convert the `claude-code-public-skill` repo from a loose skills collection into a Claude Code **plugin marketplace** that ships `tags-symbol-lookup` as its first plugin. Layout must accommodate additional plugins later without restructuring.

## Non-goals

- Adding new slash commands, agents, hooks, or MCP servers in this conversion.
- Changing the `tags-symbol-lookup` skill's behavior, query semantics, or bundled scripts.
- Publishing to any third-party registry beyond the repo itself.

## Final layout

```
claude-code-public-skill/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── tags-symbol-lookup/
│       ├── .claude-plugin/
│       │   └── plugin.json
│       └── skills/
│           └── tags-symbol-lookup/
│               ├── SKILL.md
│               ├── gtags.sh
│               └── evals/
│                   └── evals.json
├── imgs/
│   └── gtags-vs-idea-mcp.png
├── docs/superpowers/specs/
│   └── 2026-04-13-plugin-conversion-design.md
└── README.md
```

Top-level `tags-symbol-lookup/` is removed; its contents move into `plugins/tags-symbol-lookup/skills/tags-symbol-lookup/`.

## `marketplace.json`

Path: `.claude-plugin/marketplace.json`

```json
{
  "name": "claude-skill-public",
  "owner": {
    "name": "FenrirZheng",
    "email": "fenrir.zheng@al88tw.com"
  },
  "metadata": {
    "description": "Public Claude Code skills by FenrirZheng",
    "pluginRoot": "./plugins"
  },
  "plugins": [
    {
      "name": "tags-symbol-lookup",
      "source": "tags-symbol-lookup",
      "description": "Symbol lookup via GNU Global (gtags); fallback to ctags or rg",
      "category": "productivity",
      "tags": ["symbols", "navigation", "gtags", "ctags"]
    }
  ]
}
```

Notes:
- `name` `claude-skill-public` matches the GitHub repo and is not on the reserved-names list.
- `metadata.pluginRoot: "./plugins"` lets plugin `source` be just `tags-symbol-lookup`.

## `plugin.json`

Path: `plugins/tags-symbol-lookup/.claude-plugin/plugin.json`

```json
{
  "name": "tags-symbol-lookup",
  "version": "0.1.0",
  "description": "Symbol lookup via GNU Global (gtags); fallback to ctags or rg",
  "author": {
    "name": "FenrirZheng",
    "email": "fenrir.zheng@al88tw.com"
  },
  "repository": "https://github.com/FenrirZheng/claude-skill-public",
  "license": "MIT",
  "keywords": ["gtags", "ctags", "symbols", "navigation"]
}
```

No `skills` field — Claude Code auto-discovers `skills/<name>/SKILL.md`.

## `SKILL.md` path fixes

Three references to the hardcoded path `/home/fenrir/.claude/skills/tags-symbol-lookup/` must become `${CLAUDE_PLUGIN_ROOT}/skills/tags-symbol-lookup/`:

- Line ~138: generator path inside "Bundled `gtags.sh`" section.
- Line ~145: the example invocation path in the same section.
- Line ~158: the ctags fallback path (`tags.sh`).

Note: `tags.sh` is referenced in `SKILL.md` but is not present in the repo today. Either:
- drop that reference (recommended — the bundle shipped is gtags-focused), or
- leave the reference and note the script lives in the user's private skills dir.

Decision: drop the `tags.sh` reference to avoid advertising a file the plugin doesn't ship.

## README updates

Replace the "Installation" and "Layout" sections with:

````markdown
## Installation

```bash
/plugin marketplace add FenrirZheng/claude-skill-public
/plugin install tags-symbol-lookup@claude-skill-public
```

## Layout

```
claude-code-public-skill/
├── .claude-plugin/marketplace.json
└── plugins/
    └── tags-symbol-lookup/
        ├── .claude-plugin/plugin.json
        └── skills/tags-symbol-lookup/
            ├── SKILL.md
            ├── gtags.sh
            └── evals/evals.json
```
````

Keep the "System dependencies" and "Usage" sections. Drop the symlink install example (no longer a supported layout).

## Validation

After conversion, verify:
1. `jq . .claude-plugin/marketplace.json` parses cleanly.
2. `jq . plugins/tags-symbol-lookup/.claude-plugin/plugin.json` parses cleanly.
3. `SKILL.md` frontmatter (`name`, `description`) is unchanged.
4. `gtags.sh` remains executable (`chmod +x`).
5. `grep -n CLAUDE_PLUGIN_ROOT plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md` returns 2 matches (the two `gtags.sh` references; the third original absolute path was the `tags.sh` block, intentionally dropped — see the "Decision" note under "SKILL.md path fixes").
6. No remaining `/home/fenrir/.claude/skills/` references in the plugin tree.

Manual smoke test (optional):
```
/plugin marketplace add .
/plugin install tags-symbol-lookup@claude-skill-public
```
from a fresh clone — then trigger the skill with a "where is X defined?" query.

## Risks and tradeoffs

- **Breaks old symlink install.** Any user who did `ln -s .../tags-symbol-lookup ~/.claude/skills/...` will have a broken link after the move. Mitigation: README calls out the new install path; the old symlink recipe is removed.
- **`pluginRoot` compatibility.** Older Claude Code clients may not honor `metadata.pluginRoot`. Mitigation: if any tester reports the plugin is not discovered, change plugin `source` to the full path `"./plugins/tags-symbol-lookup"` and drop `pluginRoot`.
- **Scope creep temptation.** A `/gtags-build` command is easy to add but explicitly out of scope for this change. Leave as a follow-up.

## Out-of-scope follow-ups (not in this spec)

- Slash command `/gtags-build` that wraps `gtags.sh`.
- Post-edit hook that re-runs `gtags` incrementally.
- Adding a second plugin (the layout is already ready for it).
