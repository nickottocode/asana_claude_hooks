---
description: Remove the current working directory's link to its Asana task. Deletes the config entry and state file.
allowed-tools: Bash, AskUserQuestion
---

# /asana-unlink

The user wants to stop the asana-update hook from tracking the current cwd.

## Procedure

1. **Identify the match.** Run:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/helpers/status.sh "$PWD"
   ```
   to show the user which entry is about to be removed.

2. **Confirm.** Ask the user a yes/no question via AskUserQuestion: "Remove the link from `<key>` to `<url>`? This deletes the config entry and the per-project state file." Provide options: "Yes, unlink" / "No, cancel".

3. **Execute.** If the user confirmed, run:
   ```bash
   ${CLAUDE_PLUGIN_ROOT}/helpers/unlink.sh "$PWD" yes
   ```
   Otherwise do nothing and tell the user the unlink was cancelled.

4. Print the helper's stdout to the user verbatim.
