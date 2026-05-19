#!/usr/bin/env bash
# /asana-link backend.
# Usage: link.sh <cwd-path> <asana-url> [force]
#
# Writes a config entry mapping <cwd-path> to <asana-url>, seeds the state file
# so the cooldown starts fresh from now. Refuses to overwrite an existing entry
# unless the third arg is the literal string "force".
#
# Note: URL validation against Asana (asana_get_task) is the slash command's
# responsibility, not this script's.

set -euo pipefail

CWD="${1:-}"
URL="${2:-}"
FORCE="${3:-}"

[ -n "$CWD" ] || { echo "link.sh: missing cwd argument" >&2; exit 2; }
[ -n "$URL" ] || { echo "link.sh: missing url argument" >&2; exit 2; }

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG="$CONFIG_HOME/asana-skill/config.toml"
STATE_DIR="$CONFIG_HOME/asana-skill/state"

. "$PLUGIN_DIR/lib/compat.sh"
. "$PLUGIN_DIR/lib/config.sh"
. "$PLUGIN_DIR/lib/state.sh"
. "$PLUGIN_DIR/lib/url.sh"

TASK_GID="$(extract_task_gid "$URL" 2>/dev/null)" || {
  echo "link.sh: could not extract a task gid from URL: $URL" >&2
  exit 1
}

mkdir -p "$STATE_DIR"
touch "$CONFIG"

if config_has_entry "$CONFIG" "$CWD"; then
  if [ "$FORCE" != "force" ]; then
    existing="$(config_get_url "$CONFIG" "$CWD")"
    echo "link.sh: $CWD is already linked to $existing" >&2
    echo "link.sh: pass 'force' as the third argument to overwrite" >&2
    exit 1
  fi
fi

config_add_entry "$CONFIG" "$CWD" "$URL"

now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || gdate -u +%Y-%m-%dT%H:%M:%SZ)"
state_write "$STATE_DIR" "$CWD" "$TASK_GID" "$now_iso" "linked"

cooldown="$(config_get_cooldown "$CONFIG" "$CWD")"
echo "Linked $CWD → $URL (gid $TASK_GID). Cooldown $cooldown min."
