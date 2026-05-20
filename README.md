# asana

A Claude Code plugin that automatically posts progress to a linked Asana task as you work, with zero day-to-day Asana interaction beyond initial setup.

## How it works

- A `Stop` hook fires after every model turn. It checks: "has enough time elapsed since the last Asana update?"
- If yes, it injects a system reminder asking Claude to invoke the `asana:update` skill on the next turn.
- The skill summarizes recent work from conversation context and posts a story (comment) to the linked Asana task via the Asana MCP server. Optionally refreshes the task description if the project's high-level scope changed.
- All state is per-user, centralized at `~/.config/asana-skill/`. Nothing is committed into your project repos.

## Prerequisites

- `bash` (≥ 3.2; macOS default `/bin/bash` is fine)
- `python3` ≥ 3.11 (uses stdlib `tomllib`)
- `jq`
- `git` (needed only if you use git worktrees)
- Asana MCP server installed and authed in Claude Code
- **macOS only:** `brew install coreutils` (provides `gdate` for GNU-style date parsing)

For development/tests:
- `bats-core` (`brew install bats-core` or clone https://github.com/bats-core/bats-core and run `./install.sh ~/.local`)

## Install

### Option A: local development install (no marketplace)

Clone the repo anywhere and load it directly with `--plugin-dir`:

```bash
git clone https://github.com/nickottocode/asana_claude_hooks ~/src/asana_claude_hooks
claude --plugin-dir ~/src/asana_claude_hooks
```

This loads the plugin for that Claude Code session only. Re-pass the flag (or alias it) for future sessions.

### Option B: install via this repo's marketplace

This repo ships a `.claude-plugin/marketplace.json` that points at itself, so you can install it like any other marketplace plugin:

```
/plugin marketplace add nickottocode/asana_claude_hooks
/plugin install asana@asana-plugin
```

After install, run `/plugin` (or restart Claude Code) to verify the `asana` plugin is enabled.

## Usage

In any working directory where you want Asana tracking:

```
/asana:link https://app.asana.com/0/12345/67890
```

Then just work normally. The first Asana post happens after your configured cooldown (default 120 min) once you have meaningful work to summarize.

Inspect or troubleshoot:

```
/asana:status        # what's linked here? what's the cooldown state?
/asana:unlink        # remove the link
```

The model-invoked skill `asana:update` is fired automatically by the Stop hook; you don't usually call it by hand, but you can ask Claude to "update Asana now" to force it.

## Configuration

Edit `~/.config/asana-skill/config.toml`. Per-project overrides are optional:

```toml
# Global defaults
cooldown_minutes = 120
auto_post = true

["/home/me/work/widget-project"]
asana_task_url = "https://app.asana.com/0/12345/67890"
# Optional overrides:
# cooldown_minutes = 60
# auto_post = false
```

- `cooldown_minutes`: minimum minutes between Asana updates for that project. Default 120.
- `auto_post`: if false, the skill drafts the comment and waits for your approval instead of posting directly. Default true.

## Tests

```bash
bats tests/
```

## Smoke test (end-to-end)

After installing:

1. Create a throwaway task in Asana for testing.
2. In a scratch directory: `/asana:link <url-of-throwaway-task>`. Confirm the terminal output shows the linked path and gid.
3. Run `/asana:status`. Confirm match info is shown and "Next eligible: in N minutes."
4. Edit `~/.config/asana-skill/config.toml` and set `cooldown_minutes = 1` for the test project.
5. Have a short conversation that does some work (create a file, write a note, etc.).
6. Wait 60 seconds, then send another turn. The Stop hook should fire and Claude should invoke the skill, posting to Asana.
7. Refresh the Asana task — you should see a new comment.
8. Run `/asana:status` again — `Last update` should be recent and `Next eligible: in 1 minutes`.
9. Cleanup: `/asana:unlink`.

## Troubleshooting

- **Hook doesn't fire**: run `/asana:status` to confirm the cwd resolves to a registered project. If it doesn't, you may be in a worktree of a directory you didn't register — register the main repo root instead of the worktree.
- **"parse_date: no GNU date available" on macOS**: install coreutils — `brew install coreutils`.
- **Skill posts but state doesn't update**: that means the MCP call failed silently. Run with verbose logging or check Claude Code's hook diagnostics.
