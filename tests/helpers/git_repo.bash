# Helper for tests that need a git repo + external worktree.

make_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email "test@test.test"
  git -C "$dir" config user.name "test"
  echo "hi" > "$dir/README"
  git -C "$dir" add . && git -C "$dir" commit -q -m "init"
}

make_external_worktree() {
  # Args: main repo dir, external worktree dir, branch name
  local main="$1" external="$2" branch="$3"
  git -C "$main" worktree add -q -b "$branch" "$external"
}
