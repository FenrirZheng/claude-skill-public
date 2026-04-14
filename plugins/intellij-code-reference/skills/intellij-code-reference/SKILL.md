---
name: intellij-code-reference
description: "Use whenever investigating code in a project open in IntelliJ IDEA — finding where a symbol is defined, who calls a function, what implements an interface, where a config key/Spring bean is referenced, cross-language wiring (JPA, MyBatis), or any 'where is X used / how is X connected' question. The IntelliJ MCP (`mcp__idea__*`) gives semantic, PSI/index-aware answers — distinguishes real call sites from string literals, resolves overloads/inheritance, follows framework wiring, and won't silently miss matches the way `rg` does on monorepos with .gitignore quirks. Layer on `tags-symbol-lookup` — gtags first for plain definition/caller lookup, IntelliJ MCP for semantic queries or when text search comes back suspiciously empty, rg as last resort. Trigger broadly — any time you're about to grep through an IDEA-indexed project (any language), check what the MCP can answer first. Also use when the user mentions IntelliJ, IDEA, 'the IDE', PSI, or asks about refactoring safely."
---

# Code Reference via IntelliJ MCP

## Why this skill exists

`rg foo` returns every textual occurrence — and silently returns *nothing* when its ignore rules exclude the wrong directory or your scope is off. A tags index only knows what its parser parsed.

**The IntelliJ MCP exposes the live IDE index — the same PSI tree IDEA uses for navigation, refactoring, and inspections.** That index understands real call sites (vs same-name string literals), method overloads, interface ↔ implementer relationships, framework wiring (Spring `@Autowired`, `@Bean`, JPA `@Query`, MyBatis XML), generated sources (Lombok, MapStruct, kapt), and type hierarchy. If the project is open in IDEA, prefer MCP over text search for any *semantic* question — and even for "did this string appear anywhere" on big repos, MCP's `search_in_files_by_text` is index-backed and immune to gitignore surprises.

## Decision flow

```
"Where is X defined / who uses X / what implements X / how is X wired?"
        │
        ▼
Is the question SEMANTIC?
  (implementers, overrides, type hierarchy, framework wiring,
   refactor-grade refs, IDE diagnostics, bean names)
        │
   ┌────┴────┐
  yes        no (plain definition / caller of a code symbol)
   │             │
   │             ▼
   │      gtags first:  global -x foo   /   global -rx foo
   │             │
   │      ┌──────┴────── miss / ambiguous / framework-y
   │      │                  │
   │      hit                ▼
   │      │             Try MCP (skip ahead).
   │      ▼
   │  Report file:line — done.
   │
   ▼
Try MCP. No need to probe first — call the tool you actually need
(e.g. `search_symbol`, `search_in_files_by_text`). If it errors,
that's your signal IDEA isn't reachable; fall back to gtags then rg
and tell the user once.
```

The point: tags is faster *per query*, MCP is more *correct* for anything beyond name → file:line, and rg is the last resort. Don't burn a network round-trip when `global -x` would have answered in 5ms. Don't trust an empty rg result on a monorepo — try MCP before declaring "doesn't exist".

## Tool cheat sheet

### Symbol & reference lookup

| Intent | Tool | Notes |
|---|---|---|
| Find a symbol by name | `mcp__idea__search_symbol` | Index-backed; returns kind + location. Faster and richer than rg. |
| Get info on a known symbol (signature, definition, doc) | `mcp__idea__get_symbol_info` | Returns documentation/signature. **Does not return a usages list** — for callers/refs use `search_in_files_by_text` or `search_in_files_by_regex` after locating the symbol. |
| File-level structure (classes, methods, calls) | `mcp__idea__generate_psi_tree` | When you need to see *how* a file is shaped, not just text. |
| What's the user looking at? | `mcp__idea__get_all_open_file_paths` | Hints at current focus. |

### File & content search

| Intent | Tool |
|---|---|
| Find files by glob | `mcp__idea__find_files_by_glob` |
| Find files by name keyword | `mcp__idea__find_files_by_name_keyword` |
| Search content (literal text) | `mcp__idea__search_in_files_by_text` |
| Search content (regex) | `mcp__idea__search_in_files_by_regex` |
| List a directory tree | `mcp__idea__list_directory_tree` |

For text search on a project that's open in IDEA, MCP's `search_in_files_by_text` is often **faster** than rg (uses IntelliJ's persistent index) and **doesn't silently skip gitignored paths** the way `rg` does. Prefer it when rg returns suspiciously zero results.

### Project info

| Intent | Tool |
|---|---|
| List modules | `mcp__idea__get_project_modules` |
| List dependencies (libs/jars) | `mcp__idea__get_project_dependencies` |
| List run configurations | `mcp__idea__get_run_configurations` |

When the user asks "what version of X are we on?" or "which modules use Y?", these beat reading `pom.xml`/`build.gradle` by hand.

### Diagnostics, refactoring, DB, build

| Intent | Tool |
|---|---|
| IDE problems on a file | `mcp__idea__get_file_problems` |
| Safe rename across the project (incl. XML/properties) | `mcp__idea__rename_refactoring` — **always prefer over Edit + grep for renames** |
| Reformat / replace text via IDE | `mcp__idea__reformat_file` / `mcp__idea__replace_text_in_file` |
| Database queries / schema inspection | `mcp__idea__list_database_*`, `get_database_object_description`, `execute_sql_query` |
| Build / run via IDE | `mcp__idea__build_project`, `execute_run_configuration` |

## Patterns by question type

**"Where is `Foo` defined?"** — gtags first (`global -x Foo`); MCP `search_symbol` if miss.

**"What implements / extends `Foo`?"** — MCP only. `search_symbol("Foo")` → `search_in_files_by_regex('extends\s+Foo\b|implements\s+(\w+,\s*)*Foo\b')` to cross-check.

**"Who calls `Foo.bar`?"** — `get_symbol_info` gives the signature/docs but not callers. After you have it, use `search_in_files_by_text("Foo")` and `search_in_files_by_regex('\\.bar\\(')` together. For Spring beans wired by name, also search the bean-name string. Watch for framework dispatch (e.g. `applicationContext.getBean(name)`) — the call site may be a generic registry; trace the string keys.

**"Where is property `app.feature.x` read?"** — MCP `search_in_files_by_text` (config keys are strings; gtags can't parse them, rg may miss them on large monorepos).

**"Rename X to Y everywhere"** — `mcp__idea__rename_refactoring`. Never Edit + rg.

**"What does this file do?" (unfamiliar)** — `generate_psi_tree` for the outline before reading the body.

## Pitfalls

- **MCP unreachable ≠ project broken.** If a call errors with a connection/no-project message, fall back to tags/rg and say so once. Don't retry.
- **Index lag.** Right after a sweeping edit (or during reindex), MCP may miss new code. If results look stale, note it.
- **Generated code.** MCP usually sees Lombok/kapt/MapStruct output (a major reason to prefer it). If `search_symbol` reports "not found" for something that should exist (e.g. a Lombok `builder()`), suggest a build.
- **Framework callbacks look uncalled.** Spring `@PostConstruct`, controller methods, JUnit `@Test` — zero application call sites is normal, the framework calls them. Don't conclude "dead code" — explain the framework relationship.
- **Don't loop tools.** One `search_symbol` → cross-check → done. Don't `read_file` what MCP already returned in a snippet.
- **Both `mcp__idea__read_file` and the standard `Read` tool exist.** Default to `Read`.

## Output discipline

- Lead with `file:line — signature`. The user wants the answer, not the journey.
- For lists with >10 hits: group by package or module, highlight likely entry points.
- If you fell back from MCP to rg, say so in one short line so the user knows results aren't semantically filtered.
- Don't paste raw JSON tool output — translate it.

## Coordinating with sibling skills

- **`tags-symbol-lookup`** — try first for plain definition/caller queries on indexed languages. This skill takes over when richer semantics are needed or tags is empty.
- **`open-in-intellij`** — after you've made multi-file edits or surfaced `file:line` locations, that skill opens them in the IDE. This skill is about *finding*; that one is about *showing*.
- **`rg-fd-guide`** — last-resort textual search when neither the IDE nor tags help.
