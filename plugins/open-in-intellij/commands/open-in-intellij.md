Collect all files that were read, edited, or created during this session, then list them in the UI for the user before opening in IntelliJ IDEA via the IntelliJ MCP server.

Prerequisite:
- The IntelliJ MCP server must be configured and connected (tool `mcp__idea__open_file_in_editor` must be available). If it is not, tell the user and stop.

Steps:
1. Gather the session's touched files (read / edited / created).
2. Filter:
   - Only include files that actually exist (verify with `test -f`).
   - Exclude files under `node_modules`, `.git`, `target`, `dist`, `build`, and similar generated directories.
3. Output the list in the UI using the `path:1` format so each entry is clickable in Claude Code, grouped by action. Example:
   ```
   Edited:
   - src/foo.ts:1
   - src/bar.ts:1

   Read:
   - README.md:1
   ```
4. Ask the user: open all, open a subset (they reply with numbers/paths), or cancel.
5. Based on the reply, open each chosen file by calling `mcp__idea__open_file_in_editor` once per file (the MCP tool opens one file at a time). Use absolute paths.

Rules:
- Do NOT call `mcp__idea__open_file_in_editor` until the user confirms in step 4.
- If the user says "all" / "yes" / "全部", open everything from the list.
- If a single `open_file_in_editor` call fails, report which file failed and continue with the rest.
