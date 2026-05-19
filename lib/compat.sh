# Cross-platform shell helpers. Source, don't execute.
# Provides:
#   sha256_hex   - reads stdin, writes 64-char hex digest to stdout
#   parse_date   - takes ISO 8601 timestamp, writes epoch seconds to stdout

if command -v sha256sum >/dev/null 2>&1; then
  sha256_hex() { sha256sum | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_hex() { shasum -a 256 | awk '{print $1}'; }
else
  sha256_hex() { echo "asana-skill: no sha256 tool found" >&2; return 1; }
fi

if date -d "1970-01-01T00:00:00Z" +%s >/dev/null 2>&1; then
  parse_date() { date -d "$1" +%s; }
elif command -v gdate >/dev/null 2>&1; then
  parse_date() { gdate -d "$1" +%s; }
else
  parse_date() {
    echo "asana-skill: no GNU date available (install coreutils via brew on macOS)" >&2
    return 1
  }
fi
