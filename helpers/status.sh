#!/usr/bin/env bash
# /asana-status backend.
# Usage: status.sh <cwd-path>
#
# Prints a diagnostic block describing the current resolution + cooldown state.

set -euo pipefail

CWD="${1:-$PWD}"

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG="$CONFIG_HOME/asana-skill/config.toml"
STATE_DIR="$CONFIG_HOME/asana-skill/state"

. "$PLUGIN_DIR/lib/compat.sh"
. "$PLUGIN_DIR/lib/config.sh"
. "$PLUGIN_DIR/lib/state.sh"
. "$PLUGIN_DIR/lib/url.sh"

echo "Working directory: $CWD"

if [ ! -f "$CONFIG" ]; then
  echo "Config file:       $CONFIG (does not exist)"
  echo "Run /asana-link <task-url> to register this directory."
  exit 0
fi

key="$("$PLUGIN_DIR/hooks/resolve.sh" "$CWD" "$CONFIG" 2>/dev/null || true)"
if [ -z "$key" ]; then
  echo "No registered project matched this cwd (tried ancestor walk; not in a git worktree of a registered repo)."
  echo "Run /asana-link <task-url> to register this directory."
  exit 0
fi

# Determine match rule for diagnostic display
if [ "$key" = "$CWD" ]; then
  rule="exact"
elif case "$CWD/" in "$key/"*) true ;; *) false ;; esac; then
  rule="ancestor walk"
else
  rule="git common-dir fallback"
fi

url="$(config_get_url "$CONFIG" "$key")"
gid="$(extract_task_gid "$url" 2>/dev/null || echo "?")"
cooldown="$(config_get_cooldown "$CONFIG" "$key")"
auto_post="$(config_get_auto_post "$CONFIG" "$key")"

echo "Matched project:   $key"
echo "Match rule:        $rule"
echo "Asana task:        $url"
echo "Task gid:          $gid"
echo "Cooldown:          $cooldown minutes"
echo "Auto-post:         $auto_post"

last_iso="$(state_read_last_update_at "$STATE_DIR" "$key")"
if [ -z "$last_iso" ]; then
  echo "Last update:       never"
  echo "Next eligible:     immediately (no state file)"
else
  echo "Last update:       $last_iso"
  if last_epoch="$(parse_date "$last_iso" 2>/dev/null)"; then
    now_epoch="$(date +%s)"
    elapsed_min=$(( (now_epoch - last_epoch) / 60 ))
    remaining=$(( cooldown - elapsed_min ))
    if [ "$remaining" -le 0 ]; then
      echo "Next eligible:     elapsed — next Stop will trigger"
    else
      echo "Next eligible:     in $remaining minutes"
    fi
  else
    echo "Next eligible:     unknown (could not parse timestamp)"
  fi
fi
