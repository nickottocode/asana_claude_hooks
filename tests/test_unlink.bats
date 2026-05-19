#!/usr/bin/env bats

load helpers/fixture
setup() {
  setup_common
  CONFIG="$XDG_CONFIG_HOME/asana-skill/config.toml"
  STATE_DIR="$XDG_CONFIG_HOME/asana-skill/state"
  PROJ="$SCRATCH/proj"
  mkdir -p "$PROJ"
  # Pre-seed an entry + state file via the link helper
  "$PLUGIN_DIR/helpers/link.sh" "$PROJ" "https://app.asana.com/0/12345/67890" >/dev/null
}
teardown() { teardown_common; }

@test "unlink.sh removes the config entry" {
  run "$PLUGIN_DIR/helpers/unlink.sh" "$PROJ" "yes"
  [ "$status" -eq 0 ]
  . "$PLUGIN_DIR/lib/config.sh"
  result="$(config_get_url "$CONFIG" "$PROJ")"
  [ -z "$result" ]
}

@test "unlink.sh removes the state file" {
  "$PLUGIN_DIR/helpers/unlink.sh" "$PROJ" "yes" >/dev/null
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  path="$(state_path_for "$STATE_DIR" "$PROJ")"
  [ ! -f "$path" ]
}

@test "unlink.sh refuses without confirmation token" {
  run "$PLUGIN_DIR/helpers/unlink.sh" "$PROJ"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "confirm"
  # Entry still present
  . "$PLUGIN_DIR/lib/config.sh"
  result="$(config_get_url "$CONFIG" "$PROJ")"
  [ "$result" = "https://app.asana.com/0/12345/67890" ]
}

@test "unlink.sh fails gracefully when nothing matches" {
  run "$PLUGIN_DIR/helpers/unlink.sh" "/tmp" "yes"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "no registered"
}
