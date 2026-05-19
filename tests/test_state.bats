#!/usr/bin/env bats

load helpers/fixture
setup() {
  setup_common
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  STATE_DIR="$XDG_CONFIG_HOME/asana-skill/state"
}
teardown() { teardown_common; }

@test "state_slug_for produces a 16-char hex slug" {
  result="$(state_slug_for "/home/alice/proj-a")"
  [ "${#result}" -eq 16 ]
}

@test "state_slug_for is deterministic for the same input" {
  a="$(state_slug_for "/home/alice/proj-a")"
  b="$(state_slug_for "/home/alice/proj-a")"
  [ "$a" = "$b" ]
}

@test "state_slug_for differs for different inputs" {
  a="$(state_slug_for "/home/alice/proj-a")"
  b="$(state_slug_for "/home/alice/proj-b")"
  [ "$a" != "$b" ]
}

@test "state_path_for builds the absolute state file path" {
  result="$(state_path_for "$STATE_DIR" "/home/alice/proj-a")"
  slug="$(state_slug_for "/home/alice/proj-a")"
  [ "$result" = "$STATE_DIR/$slug.json" ]
}

@test "state_write creates the file with all required fields" {
  state_write "$STATE_DIR" "/home/alice/proj-a" "67890" "2026-05-19T14:32:11Z" "story"
  path="$(state_path_for "$STATE_DIR" "/home/alice/proj-a")"
  [ -f "$path" ]
  jq -e '.registered_path == "/home/alice/proj-a"' "$path" >/dev/null
  jq -e '.task_gid == "67890"' "$path" >/dev/null
  jq -e '.last_update_at == "2026-05-19T14:32:11Z"' "$path" >/dev/null
  jq -e '.last_update_kind == "story"' "$path" >/dev/null
}

@test "state_read_last_update_at returns the stored timestamp" {
  state_write "$STATE_DIR" "/home/alice/proj-a" "67890" "2026-05-19T14:32:11Z" "story"
  result="$(state_read_last_update_at "$STATE_DIR" "/home/alice/proj-a")"
  [ "$result" = "2026-05-19T14:32:11Z" ]
}

@test "state_read_last_update_at returns empty for a missing file" {
  result="$(state_read_last_update_at "$STATE_DIR" "/never-registered")"
  [ -z "$result" ]
}

@test "state_read_task_gid returns the stored gid" {
  state_write "$STATE_DIR" "/home/alice/proj-a" "67890" "2026-05-19T14:32:11Z" "story"
  result="$(state_read_task_gid "$STATE_DIR" "/home/alice/proj-a")"
  [ "$result" = "67890" ]
}

@test "state_delete removes the file" {
  state_write "$STATE_DIR" "/home/alice/proj-a" "67890" "2026-05-19T14:32:11Z" "story"
  state_delete "$STATE_DIR" "/home/alice/proj-a"
  path="$(state_path_for "$STATE_DIR" "/home/alice/proj-a")"
  [ ! -f "$path" ]
}
