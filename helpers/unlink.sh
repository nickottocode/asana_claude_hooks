#!/usr/bin/env bash
# /asana-unlink backend.
# Usage: unlink.sh <cwd-path> [yes]
#
# Resolves the matching registered project for <cwd-path>, then removes
# both the config entry and the state file. Requires the literal token
# "yes" as the second argument to actually delete; without it, refuses.
# The slash command markdown is responsible for getting interactive
# confirmation from the user before passing "yes".

set -euo pipefail

CWD="${1:-}"
CONFIRM="${2:-}"

[ -n "$CWD" ] || { echo "unlink.sh: missing cwd argument" >&2; exit 2; }

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG="$CONFIG_HOME/asana-skill/config.toml"
STATE_DIR="$CONFIG_HOME/asana-skill/state"

. "$PLUGIN_DIR/lib/compat.sh"
. "$PLUGIN_DIR/lib/config.sh"
. "$PLUGIN_DIR/lib/state.sh"

[ -f "$CONFIG" ] || { echo "unlink.sh: no config file at $CONFIG" >&2; exit 1; }

key="$("$PLUGIN_DIR/hooks/resolve.sh" "$CWD" "$CONFIG" 2>/dev/null || true)"
if [ -z "$key" ]; then
  echo "unlink.sh: no registered project matched cwd $CWD" >&2
  exit 1
fi

if [ "$CONFIRM" != "yes" ]; then
  echo "unlink.sh: would unlink $key — pass 'yes' as second arg to confirm" >&2
  exit 1
fi

url="$(config_get_url "$CONFIG" "$key")"
config_remove_entry "$CONFIG" "$key"
state_delete "$STATE_DIR" "$key"
echo "Unlinked $key (was → $url)"
