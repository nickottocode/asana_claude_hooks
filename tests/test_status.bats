#!/usr/bin/env bats

load helpers/fixture
setup() {
  setup_common
  CONFIG="$XDG_CONFIG_HOME/asana-skill/config.toml"
  STATE_DIR="$XDG_CONFIG_HOME/asana-skill/state"
  PROJ="$SCRATCH/proj"
  mkdir -p "$PROJ/subdir"
  cat > "$CONFIG" <<EOF
cooldown_minutes = 30

["$PROJ"]
asana_task_url = "https://app.asana.com/0/12345/67890"
EOF
}
teardown() { teardown_common; }

@test "status.sh on registered cwd reports match info" {
  result="$("$PLUGIN_DIR/helpers/status.sh" "$PROJ")"
  echo "$result" | grep -q "Working directory: $PROJ"
  echo "$result" | grep -q "Matched project:   $PROJ"
  echo "$result" | grep -q "Match rule:        exact"
  echo "$result" | grep -q "Asana task:        https://app.asana.com/0/12345/67890"
  echo "$result" | grep -q "Task gid:          67890"
  echo "$result" | grep -q "Cooldown:          30 minutes"
}

@test "status.sh on registered subdir reports ancestor walk" {
  result="$("$PLUGIN_DIR/helpers/status.sh" "$PROJ/subdir")"
  echo "$result" | grep -q "Match rule:        ancestor walk"
}

@test "status.sh on unregistered cwd reports no match" {
  result="$("$PLUGIN_DIR/helpers/status.sh" "/tmp")"
  echo "$result" | grep -q "No registered project matched"
}

@test "status.sh reports last update info when state file exists" {
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  state_write "$STATE_DIR" "$PROJ" "67890" "2020-01-01T00:00:00Z" "story"
  result="$("$PLUGIN_DIR/helpers/status.sh" "$PROJ")"
  echo "$result" | grep -q "Last update:       2020-01-01T00:00:00Z"
  echo "$result" | grep -q "Next eligible:     elapsed"
}

@test "status.sh reports remaining time when cooldown not yet elapsed" {
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || gdate -u +%Y-%m-%dT%H:%M:%SZ)"
  state_write "$STATE_DIR" "$PROJ" "67890" "$now_iso" "story"
  result="$("$PLUGIN_DIR/helpers/status.sh" "$PROJ")"
  echo "$result" | grep -q "Next eligible:     in "
}
