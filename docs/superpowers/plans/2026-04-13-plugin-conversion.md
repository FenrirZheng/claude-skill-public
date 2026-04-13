# Plugin Conversion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure `claude-code-public-skill` repo into a Claude Code plugin marketplace that ships `tags-symbol-lookup` as its first plugin, with a multi-plugin-ready layout.

**Architecture:** Top-level `.claude-plugin/marketplace.json` advertises plugins sourced from `./plugins/*`. Each plugin (starting with `tags-symbol-lookup`) lives in `plugins/<name>/` with its own `.claude-plugin/plugin.json` and a `skills/<name>/SKILL.md` inside. Absolute path references in the skill are replaced with `${CLAUDE_PLUGIN_ROOT}`.

**Tech Stack:** Bash, JSON, Markdown, `jq` for validation, `git mv` for history-preserving moves.

**Spec:** `docs/superpowers/specs/2026-04-13-plugin-conversion-design.md`

---

## Pre-flight

Run from the repo root `/home/fenrir/Downloads/claude-code-public-skill`.

- [ ] **Step 0: Confirm clean working tree and tooling**

```bash
cd /home/fenrir/Downloads/claude-code-public-skill
git status
command -v jq >/dev/null && echo "jq ok" || echo "INSTALL jq"
```
Expected: `git status` shows clean (or only `docs/superpowers/plans/` pending). `jq ok` prints.

---

### Task 1: Create new directory skeleton

**Files:**
- Create: `.claude-plugin/` (directory)
- Create: `plugins/tags-symbol-lookup/.claude-plugin/` (directory)
- Create: `plugins/tags-symbol-lookup/skills/tags-symbol-lookup/` (directory, target for the move)

- [ ] **Step 1: Create the directories**

```bash
mkdir -p .claude-plugin \
         plugins/tags-symbol-lookup/.claude-plugin \
         plugins/tags-symbol-lookup/skills
```

- [ ] **Step 2: Verify**

```bash
ls -d .claude-plugin plugins/tags-symbol-lookup/.claude-plugin plugins/tags-symbol-lookup/skills
```
Expected: all three paths listed, no errors.

---

### Task 2: Move the existing skill into the plugin

**Files:**
- Move: `tags-symbol-lookup/` → `plugins/tags-symbol-lookup/skills/tags-symbol-lookup/`

- [ ] **Step 1: Move with `git mv` (preserves history)**

```bash
git mv tags-symbol-lookup plugins/tags-symbol-lookup/skills/tags-symbol-lookup
```

- [ ] **Step 2: Verify layout and executable bit**

```bash
ls plugins/tags-symbol-lookup/skills/tags-symbol-lookup/
test -x plugins/tags-symbol-lookup/skills/tags-symbol-lookup/gtags.sh && echo "exec ok"
```
Expected: shows `SKILL.md`, `gtags.sh`, `evals/`. Prints `exec ok`.

- [ ] **Step 3: Commit the move alone (keeps rename detectable)**

```bash
git add -A
git commit -m "refactor: move tags-symbol-lookup skill into plugin layout"
```

---

### Task 3: Write the plugin manifest

**Files:**
- Create: `plugins/tags-symbol-lookup/.claude-plugin/plugin.json`

- [ ] **Step 1: Create the file with exactly this content**

`plugins/tags-symbol-lookup/.claude-plugin/plugin.json`:

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

- [ ] **Step 2: Validate it's well-formed JSON**

```bash
jq . plugins/tags-symbol-lookup/.claude-plugin/plugin.json
```
Expected: pretty-printed JSON, exit code 0.

- [ ] **Step 3: Validate required fields present**

```bash
jq -e '.name == "tags-symbol-lookup" and (.version | length > 0)' \
  plugins/tags-symbol-lookup/.claude-plugin/plugin.json
```
Expected: prints `true`, exit 0.

---

### Task 4: Write the marketplace manifest

**Files:**
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Create the file with exactly this content**

`.claude-plugin/marketplace.json`:

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

- [ ] **Step 2: Validate JSON**

```bash
jq . .claude-plugin/marketplace.json
```
Expected: pretty-printed JSON, exit 0.

- [ ] **Step 3: Validate required fields**

```bash
jq -e '.name == "claude-skill-public"
       and (.owner.name | length > 0)
       and (.plugins | length == 1)
       and .plugins[0].name == "tags-symbol-lookup"
       and .plugins[0].source == "tags-symbol-lookup"' \
  .claude-plugin/marketplace.json
```
Expected: prints `true`, exit 0.

- [ ] **Step 4: Commit both manifests**

```bash
git add .claude-plugin/marketplace.json \
        plugins/tags-symbol-lookup/.claude-plugin/plugin.json
git commit -m "feat: add plugin and marketplace manifests"
```

---

### Task 5: Fix absolute paths in SKILL.md

The moved `SKILL.md` has three references to the old absolute path `/home/fenrir/.claude/skills/tags-symbol-lookup/`. Replace them with `${CLAUDE_PLUGIN_ROOT}/skills/tags-symbol-lookup/`. Also drop the `tags.sh` mention per the spec (the script is not bundled in this plugin).

**Files:**
- Modify: `plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md`

- [ ] **Step 1: Find current matches**

```bash
grep -n "/home/fenrir/.claude/skills/tags-symbol-lookup" \
  plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
```
Expected: three lines reported (approximately lines 138, 145, 158).

- [ ] **Step 2: Replace the two `gtags.sh` references**

Use `sed` for a deterministic rewrite:

```bash
sed -i 's|/home/fenrir/\.claude/skills/tags-symbol-lookup/gtags\.sh|${CLAUDE_PLUGIN_ROOT}/skills/tags-symbol-lookup/gtags.sh|g' \
  plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
```

- [ ] **Step 3: Verify `gtags.sh` references updated, `tags.sh` reference remains to be hand-edited**

```bash
grep -n "CLAUDE_PLUGIN_ROOT" plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
grep -n "/home/fenrir/\.claude/skills/tags-symbol-lookup/tags\.sh" \
  plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
```
Expected: at least 2 `CLAUDE_PLUGIN_ROOT` hits; one `tags.sh` hit still present.

- [ ] **Step 4: Remove the ctags fallback paragraph**

The remaining `/home/fenrir/.claude/skills/tags-symbol-lookup/tags.sh` reference sits inside a five-line block that starts with the heading `**4. ctags fallback** (bundled \`tags.sh\`)` and ends with the closing triple-backtick fence after the `rg "^Symbol\t" tags` query line.

Use the Edit tool to replace that entire five-line block with a single line:

```
**4. ctags fallback** — only when gtags unavailable. Install `universal-ctags` and run `ctags -R` in the repo; query with `rg "^Symbol\t" tags`.
```

To locate the exact bytes to match, first run:

```bash
awk '/\*\*4\. ctags fallback\*\*/,/^```$/' \
  plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
```

Copy the printed block verbatim into the Edit tool's `old_string`, then use the single-line replacement above as `new_string`.

- [ ] **Step 5: Confirm no more absolute-path references**

```bash
! grep -n "/home/fenrir/\.claude/skills/tags-symbol-lookup" \
    plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
```
Expected: no output, exit 0 (the leading `!` inverts `grep`'s non-match exit code).

- [ ] **Step 6: Confirm frontmatter is untouched**

```bash
head -4 plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
```
Expected: lines 1–4 still contain `---`, `name: tags-symbol-lookup`, the original `description:` line, `---`.

- [ ] **Step 7: Commit**

```bash
git add plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
git commit -m "fix(skill): use CLAUDE_PLUGIN_ROOT for bundled script paths"
```

---

### Task 6: Rewrite README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the entire README with this content**

`README.md`:

````markdown
# claude-code-public-skill

Public Claude Code **plugin marketplace** by FenrirZheng. Currently ships one plugin.

## Plugins

### [`tags-symbol-lookup`](./plugins/tags-symbol-lookup)

Symbol lookup via GNU Global (`gtags`), with fallback to ctags or `rg`. Answers "where is X defined?" and "who calls Y?" with authoritative `file:line` results instead of noisy full-text search.

- Decision flow for `-x` (definitions), `-rx` (callers), `-sx` (strings/comments), `-gx` (regex)
- Pitfalls: framework callbacks, dynamic dispatch, index staleness
- Bundled `gtags.sh` — native + pygments parser, writes db to `./tags/`, git-root safety guard

## Installation

```bash
# Add this repo as a marketplace (from GitHub)
/plugin marketplace add FenrirZheng/claude-skill-public

# Install the plugin
/plugin install tags-symbol-lookup@claude-skill-public
```

For local development from a clone:

```bash
/plugin marketplace add /absolute/path/to/claude-code-public-skill
/plugin install tags-symbol-lookup@claude-skill-public
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
    └── tags-symbol-lookup/
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            └── tags-symbol-lookup/
                ├── SKILL.md
                ├── gtags.sh
                └── evals/
                    └── evals.json
```

## Comparison vs IDEA ACP (Agent) calling the idea MCP

![alt text](imgs/gtags-vs-idea-mcp.png)
````

- [ ] **Step 2: Verify README mentions the new install flow and no longer the old symlink recipe**

```bash
grep -c "/plugin marketplace add" README.md
grep -c "ln -s" README.md
```
Expected: first command ≥ 1; second command = 0.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: rewrite README for plugin marketplace install flow"
```

---

### Task 7: End-to-end validation

- [ ] **Step 1: Final tree matches spec**

```bash
fdfind -H -t f . .claude-plugin plugins | sort
```
Expected listing (order may differ):
```
.claude-plugin/marketplace.json
plugins/tags-symbol-lookup/.claude-plugin/plugin.json
plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
plugins/tags-symbol-lookup/skills/tags-symbol-lookup/gtags.sh
plugins/tags-symbol-lookup/skills/tags-symbol-lookup/evals/evals.json
```

- [ ] **Step 2: JSON parses cleanly**

```bash
jq . .claude-plugin/marketplace.json >/dev/null
jq . plugins/tags-symbol-lookup/.claude-plugin/plugin.json >/dev/null
echo "json ok"
```
Expected: `json ok`.

- [ ] **Step 3: Executable bit preserved on `gtags.sh`**

```bash
test -x plugins/tags-symbol-lookup/skills/tags-symbol-lookup/gtags.sh && echo "exec ok"
```
Expected: `exec ok`.

- [ ] **Step 4: No stray absolute paths anywhere in the plugin tree**

```bash
rg "/home/fenrir/\.claude/skills/tags-symbol-lookup" plugins/ \
  && echo "FAIL" || echo "clean"
```
Expected: `clean`.

- [ ] **Step 5: SKILL.md frontmatter intact**

```bash
head -4 plugins/tags-symbol-lookup/skills/tags-symbol-lookup/SKILL.md
```
Expected: the original frontmatter block (4 lines) unchanged from before the move.

- [ ] **Step 6: Old top-level skill dir is gone**

```bash
test ! -e tags-symbol-lookup && echo "old path removed"
```
Expected: `old path removed`.

- [ ] **Step 7: Git log is coherent**

```bash
git log --oneline -n 6
```
Expected: recent commits show, in order (newest first): README rewrite, SKILL path fix, manifests, skill move, design spec.

---

## Optional manual smoke test

Not required to mark the plan complete — run only if a Claude Code instance is available:

```bash
/plugin marketplace add /home/fenrir/Downloads/claude-code-public-skill
/plugin install tags-symbol-lookup@claude-skill-public
```

Then ask: "where is `UserRepository` defined?" in a project with a GTAGS index. Skill should activate, `global -x` should run, a `file:line` answer should appear.

If the plugin isn't discovered, fall back to `source: "./plugins/tags-symbol-lookup"` in `marketplace.json` and drop `metadata.pluginRoot` (see spec "Risks and tradeoffs").

---

## Done criteria

All seven tasks complete, all validation steps pass, commit history shows five post-spec commits: skill move, manifests, SKILL path fix, README rewrite (plus any follow-up fixes).
