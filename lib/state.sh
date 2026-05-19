# State file helpers. Source, don't execute.
# Requires lib/compat.sh to be sourced first (for sha256_hex).
# All functions take the state directory as $1.

state_slug_for() {
  local key="$1"
  printf '%s' "$key" | sha256_hex | cut -c1-16
}

state_path_for() {
  local state_dir="$1" key="$2"
  local slug
  slug="$(state_slug_for "$key")"
  printf '%s/%s.json\n' "$state_dir" "$slug"
}

state_write() {
  local state_dir="$1" key="$2" task_gid="$3" iso_timestamp="$4" kind="$5"
  local path
  path="$(state_path_for "$state_dir" "$key")"
  mkdir -p "$state_dir"
  jq -n \
    --arg registered_path "$key" \
    --arg task_gid "$task_gid" \
    --arg last_update_at "$iso_timestamp" \
    --arg last_update_kind "$kind" \
    '{registered_path: $registered_path, task_gid: $task_gid, last_update_at: $last_update_at, last_update_kind: $last_update_kind}' \
    > "$path"
}

state_read_last_update_at() {
  local state_dir="$1" key="$2"
  local path
  path="$(state_path_for "$state_dir" "$key")"
  [ -f "$path" ] || return 0
  jq -r '.last_update_at // empty' "$path"
}

state_read_task_gid() {
  local state_dir="$1" key="$2"
  local path
  path="$(state_path_for "$state_dir" "$key")"
  [ -f "$path" ] || return 0
  jq -r '.task_gid // empty' "$path"
}

state_delete() {
  local state_dir="$1" key="$2"
  local path
  path="$(state_path_for "$state_dir" "$key")"
  rm -f "$path"
}
