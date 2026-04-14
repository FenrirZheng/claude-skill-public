Collect all files that were read, edited, or created during this session, then list them in the UI for the user before opening in Zed.

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
5. Based on the reply, open the chosen files with a single command: `zed file1 file2 file3 ...`.

Rules:
- Do NOT run `zed` until the user confirms in step 4.
- If the user says "all" / "yes" / "全部", open everything from the list.
