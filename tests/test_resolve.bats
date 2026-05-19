#!/usr/bin/env bats

load helpers/fixture
setup() {
  setup_common
  CONFIG="$XDG_CONFIG_HOME/asana-skill/config.toml"
  # Create a registered project root inside SCRATCH so we can cd into it.
  PROJ_A="$SCRATCH/proj-a"
  PROJ_B="$SCRATCH/proj-b"
  mkdir -p "$PROJ_A/subdir/deep" "$PROJ_B"
  cat > "$CONFIG" <<EOF
cooldown_minutes = 30

["$PROJ_A"]
asana_task_url = "https://app.asana.com/0/1/2"

["$PROJ_B"]
asana_task_url = "https://app.asana.com/0/3/4"
EOF
}
teardown() { teardown_common; }

@test "exact match returns the registered key" {
  result="$("$PLUGIN_DIR/hooks/resolve.sh" "$PROJ_A" "$CONFIG")"
  [ "$result" = "$PROJ_A" ]
}

@test "ancestor walk one level up matches" {
  result="$("$PLUGIN_DIR/hooks/resolve.sh" "$PROJ_A/subdir" "$CONFIG")"
  [ "$result" = "$PROJ_A" ]
}

@test "ancestor walk two levels up matches" {
  result="$("$PLUGIN_DIR/hooks/resolve.sh" "$PROJ_A/subdir/deep" "$CONFIG")"
  [ "$result" = "$PROJ_A" ]
}

@test "unregistered cwd returns empty and non-zero exit" {
  run "$PLUGIN_DIR/hooks/resolve.sh" "/tmp" "$CONFIG"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "missing config file returns non-zero" {
  run "$PLUGIN_DIR/hooks/resolve.sh" "$PROJ_A" "$XDG_CONFIG_HOME/does-not-exist.toml"
  [ "$status" -ne 0 ]
}

@test "deepest registration wins when both parent and child are registered" {
  PROJ_NESTED="$PROJ_A/subdir"
  cat >> "$CONFIG" <<EOF

["$PROJ_NESTED"]
asana_task_url = "https://app.asana.com/0/9/9"
EOF
  result="$("$PLUGIN_DIR/hooks/resolve.sh" "$PROJ_A/subdir/deep" "$CONFIG")"
  [ "$result" = "$PROJ_NESTED" ]
}

load helpers/git_repo

@test "git fallback: external worktree of a registered repo resolves to the repo" {
  make_git_repo "$PROJ_A"
  # config already has PROJ_A registered
  EXT="$SCRATCH/external/proj-a-feat"
  make_external_worktree "$PROJ_A" "$EXT" "feat"
  result="$("$PLUGIN_DIR/hooks/resolve.sh" "$EXT" "$CONFIG")"
  [ "$result" = "$PROJ_A" ]
}

@test "git fallback: external worktree of an UNregistered repo still returns no match" {
  UNREG_REPO="$SCRATCH/unregistered-repo"
  make_git_repo "$UNREG_REPO"
  EXT="$SCRATCH/external/unreg-feat"
  make_external_worktree "$UNREG_REPO" "$EXT" "feat2"
  run "$PLUGIN_DIR/hooks/resolve.sh" "$EXT" "$CONFIG"
  [ "$status" -ne 0 ]
}

@test "git fallback: worktree of nested repo walks up to multi-repo parent registration" {
  # Register $SCRATCH/multi (parent of multiple repos)
  MULTI="$SCRATCH/multi"
  mkdir -p "$MULTI"
  cat >> "$CONFIG" <<EOF

["$MULTI"]
asana_task_url = "https://app.asana.com/0/77/77"
EOF
  make_git_repo "$MULTI/sub-repo"
  EXT="$SCRATCH/external/sub-repo-feat"
  make_external_worktree "$MULTI/sub-repo" "$EXT" "feat3"
  result="$("$PLUGIN_DIR/hooks/resolve.sh" "$EXT" "$CONFIG")"
  [ "$result" = "$MULTI" ]
}
