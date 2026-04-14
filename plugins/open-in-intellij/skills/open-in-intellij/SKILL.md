---
name: open-in-intellij
description: Use whenever opening files in IntelliJ IDEA through the IntelliJ MCP server (`mcp__idea__open_file_in_editor`). Triggers on explicit asks — "open X in intellij / IDEA / IDE", "show me this in the editor", "jump to these files", "load them in my IDE", "打開在 intellij", "在 IDEA 裡打開" — and proactively after Claude has finished multi-file edits, produced a call hierarchy, or surfaced a handful of code locations the user will clearly want to inspect visually. Covers when to open vs. just emit `file:line` links, how to batch calls efficiently in a single turn, how to dedupe against already-open tabs, path handling (absolute vs. project-relative), failure handling, and when NOT to open at all. Prefer this skill even if the user doesn't say "MCP" — any time opening files in IntelliJ is on the table, this is the skill.
---

# Opening Files in IntelliJ via MCP

## Why this skill exists

The IntelliJ MCP server exposes `mcp__idea__open_file_in_editor` — one call opens one file in IDEA. It sounds trivial. It isn't, because the naive shape ("I'll just open every file I mentioned") wastes turns, steals the user's focus, and surfaces stale state. This skill is the efficient pattern: open the *right* files, in *one turn*, without stomping on tabs the user is already using.

There's also a parallel mechanism you should not forget: **`file:line` links in Claude Code output are already clickable**. If the user's editor is IntelliJ, clicking that link opens the file in IDEA — for free, user-initiated, no tool call needed. Reach for the MCP tool only when the user explicitly wants Claude to drive the IDE, or when pre-emptive opening is obviously the right move (you just edited three files the user is about to review).

## Tool quick reference

| Tool | Purpose |
|---|---|
| `mcp__idea__open_file_in_editor(filePath, projectPath?)` | Open one file. `filePath` may be absolute OR project-root-relative. `projectPath` disambiguates when several projects are loaded. |
| `mcp__idea__get_all_open_file_paths(projectPath?)` | List currently open tabs. Cheap; use to dedupe before a batch open. |
| `mcp__idea__get_file_text_by_path` / `mcp__idea__read_file` | Read contents — not for opening. Use `Read` unless you specifically need IDE-side indexing context. |

Calling `open_file_in_editor` on an already-open file just re-activates the tab — not harmful, but it's a wasted roundtrip and yanks IDE focus. Dedupe when you can.

## When to open (and when not to)

```
User says "open X in IntelliJ" / "show me in IDEA" / "jump there"
        → open. Explicit request.

Claude just finished editing or creating files the user will review
        → open them (proactive, typically ≤5).

Claude just produced a call hierarchy / symbol lookup / exploration result
        → emit `file:line` links. Do NOT auto-open.
          Offer to open the top 2–3 on request.

User is reading Claude's explanation and hasn't asked for IDE
        → don't open. Stealing focus mid-explanation is rude.

User is mid-test-run, debugging, or has flow-critical focus
        → don't open.

File doesn't actually exist (generated path, hallucinated, outside project)
        → don't call. Verify first.
```

The core principle: **`file:line` links are the default surface for "here's where the code lives"; MCP open is for "put this on the user's screen now".**

## Efficiency rules

### 1. Batch in ONE turn with parallel tool calls

The tool opens one file per call. That does not mean one file per turn. Send N `open_file_in_editor` calls inside a single assistant message's tool-use block — they run in parallel. This is the single biggest efficiency lever.

**Bad** (N turns, N roundtrips):
```
turn 1: open_file_in_editor("a.java")
turn 2: open_file_in_editor("b.java")
turn 3: open_file_in_editor("c.java")
```

**Good** (1 turn):
```
<tool_use>open_file_in_editor("a.java")</tool_use>
<tool_use>open_file_in_editor("b.java")</tool_use>
<tool_use>open_file_in_editor("c.java")</tool_use>
```

### 2. Dedupe against already-open tabs (when batch ≥ 3)

For small batches (1–2 files) the dedupe call isn't worth the roundtrip. For ≥3 files, query tabs first, then skip:

```
1. mcp__idea__get_all_open_file_paths
2. Diff against the files you want to open
3. Batch-open only the missing ones
```

Skipping an already-open file avoids stealing focus from the tab the user was just reading.

### 3. Use absolute paths unless you're confident of the project root

The tool accepts both. Absolute is always unambiguous. Project-relative is shorter but fails if:
- multiple projects are loaded (IDEA opens in the wrong one)
- the file is in an included module whose root differs from the project root
- you guessed the root wrong

Default to absolute. Use project-relative only when you've just been reading from that project and the root is confirmed.

### 4. Cap proactive batches; offer for more

Proactively opening >5 files clutters the IDE and makes the user find the one they actually cared about. For larger sets (e.g., a 12-hit call hierarchy), emit `file:line` links and ask:

> "12 call sites. Want me to open the top few, or all of them?"

Wait for the answer. Don't guess.

### 5. Fail soft, in parallel

Parallel calls mean one bad path doesn't block the rest. Report failures compactly and keep going:

```
Opened 4, failed 1:
✗ /abs/path/gen/Generated.java — not in project
```

Don't retry the same path. Don't apologize at length. State it, move on.

## Decision flow

```
Intent to put files on user's screen in IDEA
        │
        ▼
Was the ask explicit, or is this clearly pre-emptive? ── no ──► emit file:line, stop
        │ yes
        ▼
How many files?
   1–2 ──► batch-open in one turn. Skip dedupe.
   3–5 ──► get_all_open_file_paths → dedupe → batch-open in one turn.
   6+  ──► emit file:line links, ask before opening.
        │
        ▼
Paths verified to exist (Read/test -f/prior tool result)?  ── no ──► verify first
        │ yes
        ▼
Open in one turn. Use absolute paths unless project root confirmed.
After: one-line report ("Opened N files in IntelliJ: …"). No ceremony.
```

## Patterns

### Pattern: open after a multi-file edit

You just edited `auth.go`, `auth_test.go`, and `middleware.go`. The user will want to review. One turn:

```
<open_file_in_editor("/repo/internal/auth/auth.go")>
<open_file_in_editor("/repo/internal/auth/auth_test.go")>
<open_file_in_editor("/repo/internal/middleware/middleware.go")>
```

Then: "Opened the three edited files in IntelliJ."

### Pattern: explicit "open these" with dedupe

User: "open the mapper, the listener, and the publisher in IntelliJ."

```
1. get_all_open_file_paths
   → ["/repo/.../LitePrepaidTransactionMapper.java", ...]
2. Mapper already open; skip.
3. Open listener + publisher in parallel.
```

Report: "Opened 2 files (mapper was already open)."

### Pattern: call-hierarchy result — links, not opens

You produced 8 callers of `processOrder`. Do NOT auto-open 8 tabs. Emit:

```
- src/orders/service.py:42
- src/orders/legacy.py:178
…
Want me to open any of these in IntelliJ?
```

Let the user click `file:line` links (opens in their configured editor — IDEA if configured) or tell you which to MCP-open.

### Pattern: single focal file

User: "jump to the `onBillPayNotifyEvent` definition in IntelliJ."

One call, one line of confirmation. No dedupe check, no batching overhead. Don't overthink single-file opens.

## Pitfalls

- **Don't re-open a file just to "refresh" it.** IDEA watches the filesystem; after an edit the tab updates on its own. Opening again just steals focus.
- **Don't open generated / build-output files** unless asked. `target/`, `build/`, `dist/`, `.next/`, `node_modules/` — opening these clutters the IDE and they'll likely be regenerated out from under the user.
- **Don't assume MCP is connected.** If `mcp__idea__open_file_in_editor` isn't available, say so plainly — "IntelliJ MCP server not reachable; nothing opened" — and stop. Don't fall back to guessing-another-way.
- **Don't use this tool for reading.** If you need the content, use `Read` (or `mcp__idea__get_file_text_by_path` when you specifically want IDE-resolved text). Opening a file just to scrape it is backwards.
- **Don't open a file whose path you got from a hallucination.** If the only evidence the path exists is that you wrote it in this turn, verify first (`Read`, `Glob`, or a prior tool result). A failed open in IDEA is silent-ish — you'll report the failure but you'll already have stolen a turn.
- **Multiple projects loaded?** Pass `projectPath` explicitly. Otherwise IDEA may open in the wrong project's window and the file won't be found.
- **Windows vs. Unix path separators** — absolute paths should match the OS IDEA is running on. Mixing `/` and `\` on Windows has bitten people.

## Boundaries

- **Slash command `/open-in-intellij`** (in this same plugin) is a separate, user-invoked workflow that opens all files touched in the current session, with a confirmation list. Don't reimplement it here; if the user wants "open everything we touched", suggest `/open-in-intellij`.
- **`file:line` links in Claude Code output** are the default "here is the location" surface. They require nothing from this skill and are almost always the right call for exploration / search results.
- **Jumping to a specific line** — `open_file_in_editor` opens the file; it does not position the caret on a line number. Emit the `file:line` link alongside the open so the user can click-to-jump if they want precision.

## Examples

**Happy path — explicit multi-file open:**
```
User: open UserService, UserRepository, and UserController in IntelliJ.

[one turn, three parallel open_file_in_editor calls]

→ "Opened 3 files in IntelliJ."
```

**Dedupe saves focus:**
```
User: open the three auth files.
get_all_open_file_paths → AuthService.java already open.

[one turn, two parallel opens for the other two]

→ "Opened 2 (AuthService was already open)."
```

**Proactive after edit:**
```
[Claude just edited 2 files as part of a fix.]
→ "Fix applied. Opening both files in IntelliJ for review."
[one turn, two parallel opens]
```

**Correctly resisting the urge:**
```
User: who calls processOrder?
[12 hits from tags/grep]

→ Emit 12 `file:line` links. Do NOT open 12 tabs.
→ "12 call sites across 8 files. Want the top few opened in IntelliJ?"
```

**MCP not available:**
```
mcp__idea__open_file_in_editor is not in the tool list.

→ "IntelliJ MCP server isn't reachable in this session — can't open files from here.
   If IDEA is running with the MCP plugin, restart this session once it's connected."
```

## Output discipline

- One confirmation line after opening. "Opened N files in IntelliJ" + any failures. No list of paths the user just handed you.
- Never narrate the batching or dedupe mechanics to the user. They don't care how you called the tool; they care that their tabs are right.
- If you emitted `file:line` links instead of opening, make that choice visible in one short sentence so the user knows the ball is in their court.
