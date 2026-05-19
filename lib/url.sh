# Asana URL helpers. Source, don't execute.

extract_task_gid() {
  # Extract the task gid (numeric ID) from an Asana URL.
  # Asana URLs vary in shape; the task gid is always the LAST numeric segment
  # of the path (the trailing slash is ignored).
  local url="$1"
  [ -n "$url" ] || return 1
  # Strip query string and fragment, strip trailing slash
  url="${url%%\?*}"
  url="${url%%\#*}"
  url="${url%/}"
  # Take last path segment; must be all digits
  local last="${url##*/}"
  case "$last" in
    ''|*[!0-9]*) return 1 ;;
    *) printf '%s\n' "$last" ;;
  esac
}
