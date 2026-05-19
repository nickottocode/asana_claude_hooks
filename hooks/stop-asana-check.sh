#!/usr/bin/env bash
# Claude Code Stop hook for the asana plugin.
# Decides whether enough time has elapsed since the last Asana update
# to fire the asana:update skill on the next turn.
#
# On a fire decision: prints a Claude-Code-compatible hook output JSON to stdout.
# Otherwise: exits 0 silently.

set -euo pipefail

# Read Claude's stdin event JSON but ignore it; we don't depend on its content.
cat >/dev/null 2>&1 || true

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG="$CONFIG_HOME/asana-skill/config.toml"
STATE_DIR="$CONFIG_HOME/asana-skill/state"

[ -f "$CONFIG" ] || exit 0   # not installed; silent no-op

. "$PLUGIN_DIR/lib/compat.sh"
. "$PLUGIN_DIR/lib/config.sh"
. "$PLUGIN_DIR/lib/state.sh"
. "$PLUGIN_DIR/lib/url.sh"

# Resolve current cwd to a registered key
key="$("$PLUGIN_DIR/hooks/resolve.sh" "$PWD" "$CONFIG" 2>/dev/null || true)"
[ -z "$key" ] && exit 0

cooldown_min="$(config_get_cooldown "$CONFIG" "$key" 2>/dev/null)" || cooldown_min=30
configured_url="$(config_get_url "$CONFIG" "$key" 2>/dev/null)" || configured_url=""
configured_gid="$(extract_task_gid "$configured_url" 2>/dev/null || true)"

state_file="$(state_path_for "$STATE_DIR" "$key")"
if [ -f "$state_file" ]; then
  state_gid="$(state_read_task_gid "$STATE_DIR" "$key" 2>/dev/null || true)"
  # If the configured URL now points at a different task gid than the one
  # we last updated, the URL was repointed. Force-fire regardless of cooldown.
  if [ -n "$configured_gid" ] && [ -n "$state_gid" ] && [ "$configured_gid" != "$state_gid" ]; then
    : # fall through to fire
  else
    last_iso="$(state_read_last_update_at "$STATE_DIR" "$key" 2>/dev/null || true)"
    if [ -n "$last_iso" ]; then
      if last_epoch="$(parse_date "$last_iso" 2>/dev/null)"; then
        now_epoch="$(date +%s)"
        elapsed_min=$(( (now_epoch - last_epoch) / 60 ))
        if [ "$elapsed_min" -lt "$cooldown_min" ]; then
          exit 0
        fi
      else
        # parse_date failed (e.g., no gdate on macOS). Silent no-op to match spec intent.
        exit 0
      fi
    fi
  fi
fi

# Fire: emit hookSpecificOutput.additionalContext telling Claude to invoke the skill.
jq -n --arg key "$key" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: ("[asana-update] " + ($key | tostring) + " is due for an Asana update. Invoke the asana:update skill now to summarize recent work and post a story to the linked task.")
  }
}'
