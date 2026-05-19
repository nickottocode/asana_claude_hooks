#!/usr/bin/env bats

load helpers/fixture
setup() { setup_common; . "$PLUGIN_DIR/lib/compat.sh"; }
teardown() { teardown_common; }

@test "sha256_hex hashes a known string to its known digest" {
  result="$(printf '%s' "hello" | sha256_hex)"
  [ "$result" = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" ]
}

@test "sha256_hex produces 64 hex characters for any input" {
  result="$(printf '%s' "any input string" | sha256_hex)"
  [ "${#result}" -eq 64 ]
}

@test "parse_date converts an ISO 8601 UTC timestamp to epoch seconds" {
  # 2026-05-19T14:32:11Z = 1779201131
  result="$(parse_date "2026-05-19T14:32:11Z")"
  [ "$result" = "1779201131" ]
}

@test "parse_date fails non-zero on malformed input" {
  run parse_date "not a date"
  [ "$status" -ne 0 ]
}
