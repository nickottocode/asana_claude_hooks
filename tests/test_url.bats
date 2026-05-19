#!/usr/bin/env bats

load helpers/fixture
setup() { setup_common; . "$PLUGIN_DIR/lib/url.sh"; }
teardown() { teardown_common; }

@test "extracts task gid from canonical Asana URL" {
  result="$(extract_task_gid "https://app.asana.com/0/12345/67890")"
  [ "$result" = "67890" ]
}

@test "extracts task gid from Asana URL with trailing slash" {
  result="$(extract_task_gid "https://app.asana.com/0/12345/67890/")"
  [ "$result" = "67890" ]
}

@test "extracts task gid from /1/ format URL" {
  result="$(extract_task_gid "https://app.asana.com/1/12345/project/55555/task/67890")"
  [ "$result" = "67890" ]
}

@test "extracts task gid from /home/.../task/X format" {
  result="$(extract_task_gid "https://app.asana.com/0/inbox/12345/task/67890")"
  [ "$result" = "67890" ]
}

@test "fails non-zero on a URL with no task gid" {
  run extract_task_gid "https://example.com/not-asana"
  [ "$status" -ne 0 ]
}

@test "fails non-zero on empty input" {
  run extract_task_gid ""
  [ "$status" -ne 0 ]
}
