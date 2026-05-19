---
description: Register the current working directory with an Asana task URL so the asana-update hook tracks it.
allowed-tools: Bash, mcp__asana__asana_get_task
---

# /asana-link

The user wants to link the current working directory to an Asana task so the asana-update hook can post progress automatically.

Arguments: `$ARGUMENTS` — expected shape: `<asana-task-url> [force]`

## Procedure

1. **Parse arguments.** Split `$ARGUMENTS` on whitespace. The first token is the URL. If a second token equals the literal string `force`, capture it; otherwise ignore extras.

2. **Validate the URL with Asana.** Extract the task gid from the URL (the last numeric path segment, ignoring any trailing slash or query string) and call `mcp__asana__asana_get_task` with that gid to confirm the task exists and is accessible. If the call fails, abort and tell the user the URL appears invalid or inaccessible.

3. **Call the backend.** Run:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/helpers/link.sh "$PWD" "<url>" [force]
   ```

4. **Report.** Print the helper's stdout to the user verbatim. If the helper exits non-zero, print its stderr and explain the next step (e.g., "pass `force` as a second argument to overwrite").

## Notes
- No Asana write happens at link time — only `asana_get_task` (read-only validation). The first Asana write occurs when the cooldown elapses and meaningful work has been done.
- If the URL is malformed (no extractable task gid), the helper will reject it; surface that error verbatim.
