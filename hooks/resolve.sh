#!/usr/bin/env bash
# Resolve a starting path to a registered key in config.toml.
# Strategy:
#   1. Ancestor walk on the starting path.
#   2. If still no match AND the starting path is inside a git worktree
#      whose common-dir is OUTSIDE the starting path's ancestor chain
#      (i.e. an external/linked worktree), resolve to the main repo root
#      and walk ancestors from there.
#
# Usage: resolve.sh <start-path> <config-file>
# Output: prints the matched registered key on stdout, exits 0.
# If no match: prints nothing, exits 1.

set -euo pipefail

START="${1:-}"
CONFIG="${2:-}"
PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$PLUGIN_DIR/lib/config.sh"

[ -n "$START" ] || { echo "resolve.sh: missing start path" >&2; exit 1; }
[ -f "$CONFIG" ] || exit 1

if [ -d "$START" ]; then
  START="$(cd "$START" && pwd -P)"
fi

ancestor_walk() {
  # Echo the first registered ancestor of $1 (inclusive); fail if none.
  local cand="$1"
  while :; do
    if config_has_entry "$CONFIG" "$cand"; then
      printf '%s\n' "$cand"
      return 0
    fi
    local parent
    parent="$(dirname "$cand")"
    [ "$parent" = "$cand" ] && return 1
    cand="$parent"
  done
}

if match="$(ancestor_walk "$START")"; then
  printf '%s\n' "$match"
  exit 0
fi

# Git fallback: only if we're in a worktree whose common-dir sits outside START's ancestor chain.
if git_common="$(git -C "$START" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
  # Strip trailing /.git to get the main repo root.
  main_root="${git_common%/.git}"
  # Detect submodule: superproject working tree, if present, means we're in a submodule, not a worktree.
  if git -C "$START" rev-parse --show-superproject-working-tree 2>/dev/null | grep -q .; then
    exit 1
  fi
  # If main_root is already an ancestor of START, the ancestor walk already covered it; nothing new.
  case "$START/" in
    "$main_root/"*) exit 1 ;;
  esac
  if match="$(ancestor_walk "$main_root")"; then
    printf '%s\n' "$match"
    exit 0
  fi
fi

exit 1
