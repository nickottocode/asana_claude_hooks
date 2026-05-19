#!/usr/bin/env bats

load helpers/fixture
setup() {
  setup_common
  CONFIG="$XDG_CONFIG_HOME/asana-skill/config.toml"
  STATE_DIR="$XDG_CONFIG_HOME/asana-skill/state"
  PROJ="$SCRATCH/proj"
  mkdir -p "$PROJ"
}
teardown() { teardown_common; }

@test "link.sh creates a new entry and seeds the state file" {
  run "$PLUGIN_DIR/helpers/link.sh" "$PROJ" "https://app.asana.com/0/12345/67890"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "Linked $PROJ"
  echo "$output" | grep -q "gid 67890"
  # Config entry exists
  . "$PLUGIN_DIR/lib/config.sh"
  result="$(config_get_url "$CONFIG" "$PROJ")"
  [ "$result" = "https://app.asana.com/0/12345/67890" ]
  # State file exists
  . "$PLUGIN_DIR/lib/compat.sh"
  . "$PLUGIN_DIR/lib/state.sh"
  path="$(state_path_for "$STATE_DIR" "$PROJ")"
  [ -f "$path" ]
}

@test "link.sh refuses to overwrite without force argument" {
  "$PLUGIN_DIR/helpers/link.sh" "$PROJ" "https://app.asana.com/0/1/2" >/dev/null
  run "$PLUGIN_DIR/helpers/link.sh" "$PROJ" "https://app.asana.com/0/9/9"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "already"
  # URL was NOT overwritten
  . "$PLUGIN_DIR/lib/config.sh"
  result="$(config_get_url "$CONFIG" "$PROJ")"
  [ "$result" = "https://app.asana.com/0/1/2" ]
}

@test "link.sh overwrites when force is given" {
  "$PLUGIN_DIR/helpers/link.sh" "$PROJ" "https://app.asana.com/0/1/2" >/dev/null
  run "$PLUGIN_DIR/helpers/link.sh" "$PROJ" "https://app.asana.com/0/9/9" "force"
  [ "$status" -eq 0 ]
  . "$PLUGIN_DIR/lib/config.sh"
  result="$(config_get_url "$CONFIG" "$PROJ")"
  [ "$result" = "https://app.asana.com/0/9/9" ]
}

@test "link.sh rejects a URL it can't extract a gid from" {
  run "$PLUGIN_DIR/helpers/link.sh" "$PROJ" "https://example.com/not-asana"
  [ "$status" -ne 0 ]
  echo "$output" | grep -qi "could not extract"
}
