---
name: tags-symbol-lookup
description: Use when locating a symbol's definition or callers — phrases like "where is X defined", "find class/function Foo", "jump to symbol", "who calls Y", "list references of Z". Defaults to GNU Global (gtags); falls back to ctags `tags` file or rg only if no index exists.
---

# Symbol Lookup with GNU Global (gtags)

## Why this skill exists

`rg foo` returns every mention — imports, call sites, comments, string literals. **A tags index returns just definitions (and on demand, just references).** One query, authoritative answers.

The user's primary indexer is **GNU Global** (`gtags` to build, `global` to query). This skill defaults to gtags. Falls back to ctags `tags` file or raw `rg` if no index is present.

## Decision flow

```
User asks: find / locate / jump-to / who-calls <symbol>
        │
        ▼
Try first:  global -x <symbol>
        │
   ┌────┴────┐
  hit       miss / "GTAGS not found"
   │             │
   │             ▼
   │      Look for db elsewhere:
   │        ./tags/GTAGS  → set GTAGSDBPATH/GTAGSROOT (see below)
   │        ./tags (file) → ctags-style; use  rg "^foo\t" tags
   │        none of above → offer to generate via the bundled gtags.sh
   ▼
Report file:line — matched line / kind
```

Always try `global -x` FIRST — it's fast, silent on miss, and auto-discovers `GTAGS` walking up from cwd.

## Query cheat sheet

| Intent | Command |
|---|---|
| **Definitions** of `foo` | `global -x foo` |
| **References / callers** of `foo` | `global -rx foo` |
| Other appearances (strings, comments) | `global -sx foo` |
| Regex grep across indexed files | `global -gx 'pattern'` |
| Symbols starting with `foo` (completion) | `global -c foo` |
| List a file's symbols | `global -f path/to/file` |
| Path completion | `global -P pattern` |

The `-x` flag emits `name  line  file  definition-line` — much more useful than bare paths. Use it by default.

Example output:
```
UserRepository  18  src/db/user.py  class UserRepository:
```

## Finding usages — picking the right flag

`global` exposes three different "where is X used" queries. They answer different questions; picking the wrong one either hides real hits or floods you with noise.

| Question | Flag | What it returns |
|---|---|---|
| Who **calls** this function / instantiates this class? | `-rx` | Reference sites the parser classified as code uses |
| Where does the name appear in **strings, comments, or unparsed contexts**? | `-sx` | Symbol-table occurrences not classified as def or ref |
| Find a **pattern** (regex, method-on-any-receiver, partial name) | `-gx` | Raw regex grep across indexed files — fast, no parsing |

### Decision shortcut

```
"who uses X?"
   ├─ X is a function/method/class — you want call sites    →  -rx
   ├─ X is a config key / error string / route / suspect    →  -sx  (then -gx if empty)
   │  dynamic use (reflection, getattr, string-keyed)
   └─ X has many overloads, or you want X on any receiver   →  -gx 'X\('
```

### Patterns

**Direct callers of a function or method:**
```bash
global -rx processOrder
```
Each line is a call site with the matched code. Calls via reflection, dynamic dispatch, and *every* same-named method across unrelated classes will be lumped together — narrow by directory or with `-gx`.

**Mentions in strings or comments** (e.g., a deprecated flag, a config key, an error message):
```bash
global -sx LEGACY_AUTH_MODE
```
Catches `"LEGACY_AUTH_MODE"` in a config map, `// LEGACY_AUTH_MODE deprecated` in a comment, doc references — none of which `-rx` sees.

**Method name on any receiver** (when `-rx` overwhelms you with one class's usages but you wanted all):
```bash
global -gx '\.save\('         # any .save( call
global -gx '->execute\b'      # PHP method calls
global -gx '\bexecute\s*\('   # word-boundary execute(
```
`-gx` is regex-grep over indexed files — faster than `rg` (skips ignored files automatically) but loses semantic awareness.

**Sweep for every trace** (useful when removing a deprecated symbol):
```bash
{ global -x X; global -rx X; global -sx X; } | sort -u
```
Definitions + references + other appearances, deduped. Reasonable confidence nothing slips through.

### Pitfalls

- **`-rx` returns zero for framework-invoked callbacks** (React lifecycle, Spring `@PostConstruct`, decorator-based routes, signal handlers). Not a bug — the framework calls them, not application code. Don't conclude "no callers"; explain the framework relationship and offer to find what registers/mounts the symbol instead.
- **Same-named methods across classes collapse** — `global -rx execute` returns every `execute()` call in the codebase. If only one class's method matters, filter by file path or use `-gx 'ClassName[^.]*\.execute\('`.
- **Dynamic dispatch is invisible to `-rx`** — interface calls, virtual methods resolved at runtime, `getattr(obj, name)`, JS bracket access — the parser can't follow them. Combine with `-sx` / `-gx` or fall back to `rg` for refactor-grade certainty.
- **Index lag affects references too** — call sites added after the last `gtags` run are missing. If `-rx` returns suspiciously few hits and the user just edited code, regenerate the index before trusting the result.

## Querying a db stored in `./tags/` subdir

If `global -x foo` says `GTAGS not found.` but `./tags/GTAGS` exists (the layout produced by the bundled `gtags.sh`), point global at it:

```bash
GTAGSDBPATH=$PWD/tags GTAGSROOT=$PWD global -x foo
# or export once per shell:
export GTAGSDBPATH=$PWD/tags GTAGSROOT=$PWD
```

## Reporting results to the user

Format each hit as `file:line` (clickable in Claude Code) plus the matched line / kind:

```
src/orders/service.py:42 — class OrderService
src/orders/legacy.py:178 — function processOrder (in class LegacyHandler)
```

For >10 hits: group by directory, or narrow with `global -gx 'class \w+Service'`. For exactly 1 hit: state it plainly — no ceremony.

## Generating an index

**1. Repo-local generator** (if exists, prefer it — matches team setup):
```bash
[ -x ./gtags.sh ] && ./gtags.sh
```

**2. Bundled `gtags.sh`** at `/home/fenrir/.claude/skills/tags-symbol-lookup/gtags.sh`:
- `GTAGSLABEL=native-pygments` — native parser for C/C++/Java/PHP, pygments fallback for JS/TS/Vue/Go/Rust/Kotlin/Swift/etc.
- Writes db to `./tags/` subdir (query needs `GTAGSDBPATH`/`GTAGSROOT` as above)
- Refuses to run outside a git repo root (safety guard against stray `rm -rf`)
- Indexes Java/JS/TS/Go/Python/Rust/Ruby/PHP/C/C++/Kotlin/Swift/SQL/Gradle/Proto/Terraform/TOML/YAML/XML

```bash
/home/fenrir/.claude/skills/tags-symbol-lookup/gtags.sh
```

Don't auto-run without asking — `tags/` and `gtags.files` become repo-root artifacts; some teams gitignore them, some don't.

**3. Bare one-shot** (writes db at cwd; queryable with no env):
```bash
GTAGSLABEL=native-pygments gtags
```
Requires `apt install global universal-ctags python3-pygments`.

**4. ctags fallback** (bundled `tags.sh`) — only when gtags unavailable or specifically requested:
```bash
/home/fenrir/.claude/skills/tags-symbol-lookup/tags.sh   # writes ./tags
rg "^Symbol\t" tags                                       # query
```

## When NOT to use the index

- **Renaming** — need *every* use including dynamic refs; use `rg` or LSP.
- **Reading code flow** — once you have file:line, open the file. Don't keep grepping.
- **Just-added symbols** — index is frozen at last `gtags` run. If the symbol isn't there but the user just wrote it, regenerate or fall back to `rg`. Don't say "doesn't exist".
- **Framework lifecycle hooks** (React `componentDidMount`, `useEffect`, Spring `@PostConstruct`, etc.) — they're called by the framework, not by application code. `-rx` will return zero or misleading results. Explain the framework relationship instead of pretending no caller exists.
- **Non-indexed artifacts** — only files in `gtags.files` are known. Generated code or extensions not in the indexed set won't appear.

## Staleness check

```bash
newest=$(fdfind -e java -e go -e ts -e py -e js --exec-batch ls -t {} + 2>/dev/null | head -1)
[ -n "$newest" ] && [ GTAGS -ot "$newest" ] && echo "GTAGS may be stale"
```

If stale and the user is doing serious navigation, offer to regenerate. For a one-off lookup, note the staleness and proceed — usually still right.

## Examples

**Happy path:**
```
User: where is UserRepository defined?
$ global -x UserRepository
UserRepository  18  src/db/user.py  class UserRepository:
→ src/db/user.py:18 — class UserRepository
```

**Multi-hit definitions:**
```
User: find the validate function
$ global -x validate
→ three hits in auth/, forms/, api/ — list all three, ask which context they meant
```

**Callers:**
```
User: who calls processOrder?
$ global -rx processOrder
→ 12 hits in 8 files — summarize by directory, highlight likely entry points
```

**No index:**
```
$ global -x foo
global: GTAGS not found.
→ Reply: "no gtags index in this repo. I can run the bundled gtags.sh
   (~30s on most repos), or rg directly. Which?"
```

**Framework callback (don't be fooled by zero `-rx` hits):**
```
User: who calls componentDidMount?
→ Don't say "no callers". Explain: React lifecycle hook, framework-invoked
   on mount. Offer to find what mounts the component instead.
```

## Output discipline

- Lead with the `file:line — signature` answer. First thing the user sees is the concrete answer.
- Show the matched definition line if `-x` provides it.
- Don't dump raw GTAGS records or paste full files; lookup ≠ explanation.
- If you fall back to `rg`, say so in one short line so the user knows results may include non-definitions.
