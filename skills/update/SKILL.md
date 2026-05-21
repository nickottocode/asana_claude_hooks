---
name: update
description: Use when the Stop hook injects an "[asana-update]" system reminder, or when the user explicitly asks to update Asana. Summarizes recent work and posts to the linked Asana task.
---

# asana:update

The Stop hook fires this skill when enough time has elapsed since the last Asana update. Its job is to summarize what has happened in the conversation since the last update and post it as a story (comment) on the linked Asana task. Optionally, if the high-level project scope or approach has materially changed, it also rewrites the task description.

## Announce at start

"Invoking the asana:update skill to summarize recent work and post to Asana."

## Procedure

### 1. Resolve the registered project for this cwd

Run:

```bash
${CLAUDE_PLUGIN_ROOT}/hooks/resolve.sh "$PWD" "${XDG_CONFIG_HOME:-$HOME/.config}/asana-skill/config.toml"
```

This prints the registered key on stdout. If the command exits non-zero or prints nothing, **abort silently** — there's nothing to update.

### 2. Read configured URL + current state

The configured URL in `config.toml` is the source of truth for the task gid. State's `task_gid` is only used to detect "URL was repointed since the last update."

```bash
. ${CLAUDE_PLUGIN_ROOT}/lib/compat.sh
. ${CLAUDE_PLUGIN_ROOT}/lib/config.sh
. ${CLAUDE_PLUGIN_ROOT}/lib/state.sh
. ${CLAUDE_PLUGIN_ROOT}/lib/url.sh
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/asana-skill/config.toml"
STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/asana-skill/state"
URL="$(config_get_url "$CONFIG" "$KEY")"
GID="$(extract_task_gid "$URL")"
LAST="$(state_read_last_update_at "$STATE_DIR" "$KEY")"
PRIOR_GID="$(state_read_task_gid "$STATE_DIR" "$KEY")"
```

If `$PRIOR_GID` differs from `$GID`, the user has repointed the link to a different Asana task since the last update. Treat this as a "fresh task" — your conversation summary should establish initial context for the *new* task, not assume continuity with the prior one.

### 3. Draft the progress story

Review the conversation since `$LAST` (or since session start if `$LAST` is empty). Identify concrete progress:

- Files created or modified
- Decisions reached (architecture, scope, approach)
- Tests added, bugs fixed
- Blockers, open questions, things to revisit

Write the story using the skeleton below. The goal is a scannable status update, not a narrative. Omit any section that's genuinely empty — don't pad.

```
**Progress:**
- <concrete artifact, change, or decision>
- <concrete artifact, change, or decision>

**Next:**
- <what's queued or in-flight>

**Blockers:**
- <anything stuck, open question, or decision needed>
```

Rules:

- Describe artifacts and decisions, not the journey. Bullets should read like changelog entries.
- Each bullet ≤ ~20 words. Aim for ≤ 4 bullets per section.
- Plain English, no marketing language, no "I" narration ("I looked at…", "I decided to…").
- **No code blocks** — Asana renders them poorly. Reference files by relative path inline.
- If literally nothing substantive happened (idle chitchat, no edits, no decisions), post a single line: `No substantive work since last update.` Do not invent progress to fill the skeleton.

#### Example

**Avoid** (stream of consciousness):

> Started by looking at the failing tests and tried a few things. Noticed the retry logic wasn't being hit so went back to client.py and added some logging. Eventually figured out the timeout was wrong, so changed it. Then ran the tests again and they passed. Also thought about whether to refactor the whole client but decided not to for now. Might revisit later.

**Prefer** (skeleton):

> **Progress:**
> - Fixed retry path in `client.py` — timeout was set to 0 so retries never fired.
> - Tests in `tests/test_client.py` now pass locally.
>
> **Next:**
> - Sweep other call sites for the same timeout bug.
>
> **Blockers:**
> - None — flagging the broader client refactor as deferred, not blocking.

### 4. Decide whether to update the description

Has the high-level **project scope** or **approach** materially changed since the last update? Examples that count:

- Scope expanded or contracted (added/removed a major feature area)
- Architecture pivot (different framework, different topology, different storage)
- Goal shifted (was building X, now building Y)

Examples that **do not** count (and should NOT trigger a description rewrite):

- Implementation details progressed
- Bugs were fixed
- New tests added
- Refactoring within the existing approach

If the description should change, draft a new one using the template below.

#### Description template (only on scope change)

```
## Overview
<one paragraph: what this task accomplishes>

## Approach
<bullet points: current implementation strategy>

## Status
<one sentence: where things stand right now>

---
*Maintained by Claude Code · last refreshed YYYY-MM-DD*
```

### 5. Check auto-post setting

Read `auto_post` for the matched project:

```bash
. ${CLAUDE_PLUGIN_ROOT}/lib/config.sh
AUTO="$(config_get_auto_post "$CONFIG" "$KEY")"
```

### 6. Post (or draft) the update

**If `auto_post = true`:**

- Post the story by calling `mcp__asana__asana_create_task_story` with `task_id = $GID` and `text = <your drafted story>`.
- If the description should change, also call `mcp__asana__asana_update_task` with `task_id = $GID` and `notes = <your new description>`.

**If `auto_post = false`:**

- Print the drafted story (and description, if applicable) to the user, clearly labeled.
- Ask: "Should I post this to Asana? (yes/edit/skip)"
- If yes: proceed with the MCP calls above.
- If edit: invite the user to provide corrections, then re-confirm.
- If skip: do nothing further (and do NOT update state — the cooldown will re-elapse).

### 7. Update state on success

If the MCP calls succeeded, write the new state file:

```bash
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || gdate -u +%Y-%m-%dT%H:%M:%SZ)"
KIND="story"  # or "story+description" if you also updated notes
state_write "$STATE_DIR" "$KEY" "$GID" "$NOW" "$KIND"
```

**Important:** do NOT update state on failure. Leaving the old timestamp ensures the cooldown re-elapses naturally and the next Stop event retries.

### 8. Tell the user (one short line)

After successful posting, print one line to the user, e.g.:
`Posted progress story to Asana task 67890.`

If you also updated the description, say:
`Posted progress story and refreshed description on Asana task 67890.`

## Failure handling

| Failure | Behavior |
|---|---|
| Asana MCP not available / not authed | Print one-line warning. Do NOT update state. |
| `asana_create_task_story` returns an error | Print the error. Do NOT update state. |
| URL points to a deleted task | Same as above. User can /asana-unlink and /asana-link with a fresh URL. |

In all failure cases: do NOT update the state file. The cooldown will naturally retry next turn after the cooldown elapses.
