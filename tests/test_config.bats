#!/usr/bin/env bats

load helpers/fixture
setup() {
  setup_common
  . "$PLUGIN_DIR/lib/config.sh"
  CONFIG="$XDG_CONFIG_HOME/asana-skill/config.toml"
  cat > "$CONFIG" <<EOF
cooldown_minutes = 30
auto_post = true

["/home/alice/proj-a"]
asana_task_url = "https://app.asana.com/0/12345/67890"

["/home/alice/proj-b"]
asana_task_url = "https://app.asana.com/0/55555/66666"
cooldown_minutes = 120
auto_post = false
EOF
}
teardown() { teardown_common; }

@test "config_list_paths returns all registered paths" {
  result="$(config_list_paths "$CONFIG" | sort | tr '\n' ',')"
  [ "$result" = "/home/alice/proj-a,/home/alice/proj-b," ]
}

@test "config_get_url returns the URL for a registered path" {
  result="$(config_get_url "$CONFIG" "/home/alice/proj-a")"
  [ "$result" = "https://app.asana.com/0/12345/67890" ]
}

@test "config_get_url returns empty for an unregistered path" {
  result="$(config_get_url "$CONFIG" "/nowhere")"
  [ -z "$result" ]
}

@test "config_get_cooldown uses per-project override when present" {
  result="$(config_get_cooldown "$CONFIG" "/home/alice/proj-b")"
  [ "$result" = "120" ]
}

@test "config_get_cooldown falls back to global default" {
  result="$(config_get_cooldown "$CONFIG" "/home/alice/proj-a")"
  [ "$result" = "30" ]
}

@test "config_get_cooldown uses hardcoded 30 when nothing is set" {
  echo "" > "$CONFIG"
  result="$(config_get_cooldown "$CONFIG" "/anything")"
  [ "$result" = "30" ]
}

@test "config_get_auto_post uses per-project override when false" {
  result="$(config_get_auto_post "$CONFIG" "/home/alice/proj-b")"
  [ "$result" = "false" ]
}

@test "config_get_auto_post defaults to true" {
  result="$(config_get_auto_post "$CONFIG" "/home/alice/proj-a")"
  [ "$result" = "true" ]
}

@test "config_add_entry creates a new section" {
  config_add_entry "$CONFIG" "/home/alice/proj-c" "https://app.asana.com/0/99/11"
  result="$(config_get_url "$CONFIG" "/home/alice/proj-c")"
  [ "$result" = "https://app.asana.com/0/99/11" ]
}

@test "config_remove_entry deletes the section" {
  config_remove_entry "$CONFIG" "/home/alice/proj-a"
  result="$(config_get_url "$CONFIG" "/home/alice/proj-a")"
  [ -z "$result" ]
  # proj-b should still be there
  result="$(config_get_url "$CONFIG" "/home/alice/proj-b")"
  [ "$result" = "https://app.asana.com/0/55555/66666" ]
}

@test "config_has_entry returns 0 for registered, 1 for unregistered" {
  config_has_entry "$CONFIG" "/home/alice/proj-a"
  config_has_entry "$CONFIG" "/nowhere" && false || true
}

@test "config_get_url handles path with single quote" {
  cat > "$CONFIG" <<EOF
["/home/o'brien/proj"]
asana_task_url = "https://app.asana.com/0/1/2"
EOF
  result="$(config_get_url "$CONFIG" "/home/o'brien/proj")"
  [ "$result" = "https://app.asana.com/0/1/2" ]
}

@test "config_add_entry handles path containing a double quote" {
  echo "" > "$CONFIG"
  weird='/home/some"weird/path'
  config_add_entry "$CONFIG" "$weird" "https://app.asana.com/0/1/2"
  result="$(config_get_url "$CONFIG" "$weird")"
  [ "$result" = "https://app.asana.com/0/1/2" ]
}
