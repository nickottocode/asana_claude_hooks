#!/usr/bin/env bats

load helpers/fixture
setup() {
  setup_common
  CONFIG="$XDG_CONFIG_HOME/asana-skill/config.toml"
  STATE_DIR="$XDG_CONFIG_HOME/asana-skill/state"
  PROJ="$SCRATCH/proj"
  mkdir -p "$PROJ"
  cat > "$CONFIG" <<EOF
cooldown_minutes = 30

["$PROJ"]
asana_task_url = "https://app.asana.com/0/1/2"
EOF
}
teardown() { teardown_common; }

run_hook_in() {
  # Drive the hook with a stubbed Stop event JSON on stdin.
  (cd "$1" && printf '{}' | "$PLUGIN_DIR/hooks/stop-asana-check.sh")
}

run_hook_in_with_stdin() {
  # Drive the hook with a caller-supplied stdin payload.
  (cd "$1" && printf '%s' "$2" | "$PLUGIN_DIR/hooks/stop-asana-check.sh")
}

@test "hook is silent when cwd has no registered ancestor" {
  result="$(run_hook_in "/tmp")"
  [ -z "$result" ]
}

@test "hook is silent when config file is missing" {
  rm "$CONFIG"
  result="$(run_hook_in "$PROJ")"
  [ -z "$result" ]
}

@test "hook fires (emits decision:block with reason) when no state file exists" {
  result="$(run_hook_in "$PROJ")"
  echo "$result" | jq -e '.decision == "block"' >/dev/null
  echo "$result" | jq -e '.reason | test("asana:update")' >/dev/null
}

@test "hook is silent when cooldown has not elapsed" {
  # State gid must match the configured URL's gid (2 in PROJ's setup),
  # otherwise the gid-changed branch would force-fire regardless of cooldown.
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || gdate -u +%Y-%m-%dT%H:%M:%SZ)"
  state_write "$STATE_DIR" "$PROJ" "2" "$now_iso" "story"
  result="$(run_hook_in "$PROJ")"
  [ -z "$result" ]
}

@test "hook fires when cooldown has elapsed" {
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  state_write "$STATE_DIR" "$PROJ" "2" "2020-01-01T00:00:00Z" "story"
  result="$(run_hook_in "$PROJ")"
  echo "$result" | jq -e '.decision == "block"' >/dev/null
  echo "$result" | jq -e '.reason | test("asana:update")' >/dev/null
}

@test "hook respects per-project cooldown override" {
  # Override cooldown to 1 minute and put last_update_at 30 seconds ago: should still be silent.
  cat > "$CONFIG" <<EOF
cooldown_minutes = 30

["$PROJ"]
asana_task_url = "https://app.asana.com/0/1/2"
cooldown_minutes = 1
EOF
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  thirty_s_ago="$(date -u -d '30 seconds ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || gdate -u -d '30 seconds ago' +%Y-%m-%dT%H:%M:%SZ)"
  state_write "$STATE_DIR" "$PROJ" "2" "$thirty_s_ago" "story"
  result="$(run_hook_in "$PROJ")"
  [ -z "$result" ]
}

@test "hook handles corrupt state file gracefully (exits 0)" {
  mkdir -p "$STATE_DIR"
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  path="$(state_path_for "$STATE_DIR" "$PROJ")"
  echo "this is not valid json" > "$path"
  run run_hook_in "$PROJ"
  [ "$status" -eq 0 ]
}

@test "hook is silent when stop_hook_active is true (avoid block loop)" {
  # Even with cooldown elapsed (no state file), if a prior Stop hook in this
  # same turn already blocked, we must not block again.
  result="$(run_hook_in_with_stdin "$PROJ" '{"stop_hook_active": true}')"
  [ -z "$result" ]
}

@test "hook fires when config gid differs from state gid (URL was repointed)" {
  # State file says we last updated task gid 2 (from the configured URL),
  # but cooldown has NOT elapsed. If user changes the URL to point at a
  # different task gid, the hook should fire immediately.
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || gdate -u +%Y-%m-%dT%H:%M:%SZ)"
  state_write "$STATE_DIR" "$PROJ" "2" "$now_iso" "story"
  # Now repoint URL in config to a different task gid (999)
  cat > "$CONFIG" <<EOF
cooldown_minutes = 30

["$PROJ"]
asana_task_url = "https://app.asana.com/0/1/999"
EOF
  result="$(run_hook_in "$PROJ")"
  echo "$result" | jq -e '.decision == "block"' >/dev/null
  echo "$result" | jq -e '.reason | test("asana:update")' >/dev/null
}
