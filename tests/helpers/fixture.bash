# Sourced by .bats tests. Provides PLUGIN_DIR and a scratch tempdir.

setup_common() {
  PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export PLUGIN_DIR
  SCRATCH="$(mktemp -d "${TMPDIR:-/tmp}/asana-skill-test.XXXXXX")"
  export SCRATCH
  export XDG_CONFIG_HOME="$SCRATCH/.config"
  mkdir -p "$XDG_CONFIG_HOME/asana-skill/state"
}

teardown_common() {
  [ -n "${SCRATCH:-}" ] && rm -rf "$SCRATCH"
}
