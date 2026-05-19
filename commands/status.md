---
description: Show which Asana task (if any) is linked to the current working directory, and current cooldown state.
allowed-tools: Bash
---

# /asana-status

The user wants to know which Asana task is linked to the current cwd, how the resolution matched, and the cooldown status.

## Procedure

1. Run:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/helpers/status.sh "$PWD"
   ```
2. Print the helper's stdout to the user verbatim, inside a fenced code block.

No further action — this command is read-only.
