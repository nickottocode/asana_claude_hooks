# TOML config helpers. Source, don't execute.
# All functions take the config file path as $1.
# Uses python3 (3.11+) tomllib for parsing; writes by regenerating the file.

_py_load() {
  # Emit a small Python preamble that loads the config dict into `cfg`.
  cat <<'PY'
import sys, tomllib
try:
    with open(sys.argv[1], 'rb') as f:
        cfg = tomllib.load(f)
except FileNotFoundError:
    cfg = {}
PY
}

config_list_paths() {
  local config="$1"
  [ -f "$config" ] || return 0
  python3 -c "$(_py_load)
for k, v in cfg.items():
    if isinstance(v, dict):
        print(k)
" "$config"
}

config_get_url() {
  local config="$1" key="$2"
  [ -f "$config" ] || return 0
  python3 - "$config" "$key" <<'PY'
import sys, tomllib
config_path, key = sys.argv[1], sys.argv[2]
try:
    with open(config_path, 'rb') as f:
        cfg = tomllib.load(f)
except FileNotFoundError:
    cfg = {}
print(cfg.get(key, {}).get('asana_task_url', ''))
PY
}

config_get_cooldown() {
  local config="$1" key="$2"
  if [ ! -f "$config" ]; then echo 120; return 0; fi
  python3 - "$config" "$key" <<'PY'
import sys, tomllib
config_path, key = sys.argv[1], sys.argv[2]
try:
    with open(config_path, 'rb') as f:
        cfg = tomllib.load(f)
except FileNotFoundError:
    cfg = {}
entry = cfg.get(key, {})
print(entry.get('cooldown_minutes', cfg.get('cooldown_minutes', 120)))
PY
}

config_get_auto_post() {
  local config="$1" key="$2"
  if [ ! -f "$config" ]; then echo true; return 0; fi
  python3 - "$config" "$key" <<'PY'
import sys, tomllib
config_path, key = sys.argv[1], sys.argv[2]
try:
    with open(config_path, 'rb') as f:
        cfg = tomllib.load(f)
except FileNotFoundError:
    cfg = {}
entry = cfg.get(key, {})
val = entry.get('auto_post', cfg.get('auto_post', True))
print('true' if val else 'false')
PY
}

config_has_entry() {
  local config="$1" key="$2"
  [ -f "$config" ] || return 1
  python3 - "$config" "$key" <<'PY'
import sys, tomllib
config_path, key = sys.argv[1], sys.argv[2]
try:
    with open(config_path, 'rb') as f:
        cfg = tomllib.load(f)
except FileNotFoundError:
    cfg = {}
sys.exit(0 if isinstance(cfg.get(key), dict) else 1)
PY
}

config_add_entry() {
  local config="$1" key="$2" url="$3"
  mkdir -p "$(dirname "$config")"
  touch "$config"
  python3 - "$config" "$key" "$url" <<'PY'
import sys, tomllib
config_path, key, url = sys.argv[1], sys.argv[2], sys.argv[3]
with open(config_path, 'rb') as f:
    cfg = tomllib.load(f)
cfg[key] = {**cfg.get(key, {}), "asana_task_url": url}
# Rewrite preserving order: globals first (keys with non-dict values), then sections.
globals_kv = [(k, v) for k, v in cfg.items() if not isinstance(v, dict)]
sections = [(k, v) for k, v in cfg.items() if isinstance(v, dict)]
out_lines = []
for k, v in globals_kv:
    if isinstance(v, bool):
        out_lines.append(f"{k} = {'true' if v else 'false'}")
    elif isinstance(v, (int, float)):
        out_lines.append(f"{k} = {v}")
    else:
        out_lines.append(f'{k} = "{v}"')
if globals_kv:
    out_lines.append("")
for k, v in sections:
    escaped_k = k.replace('\\', '\\\\').replace('"', '\\"')
    out_lines.append(f'["{escaped_k}"]')
    for kk, vv in v.items():
        if isinstance(vv, bool):
            out_lines.append(f"{kk} = {'true' if vv else 'false'}")
        elif isinstance(vv, (int, float)):
            out_lines.append(f"{kk} = {vv}")
        else:
            out_lines.append(f'{kk} = "{vv}"')
    out_lines.append("")
with open(config_path, 'w') as f:
    f.write("\n".join(out_lines).rstrip() + "\n")
PY
}

config_remove_entry() {
  local config="$1" key="$2"
  [ -f "$config" ] || return 0
  python3 - "$config" "$key" <<'PY'
import sys, tomllib
config_path, key = sys.argv[1], sys.argv[2]
with open(config_path, 'rb') as f:
    cfg = tomllib.load(f)
cfg.pop(key, None)
globals_kv = [(k, v) for k, v in cfg.items() if not isinstance(v, dict)]
sections = [(k, v) for k, v in cfg.items() if isinstance(v, dict)]
out_lines = []
for k, v in globals_kv:
    if isinstance(v, bool):
        out_lines.append(f"{k} = {'true' if v else 'false'}")
    elif isinstance(v, (int, float)):
        out_lines.append(f"{k} = {v}")
    else:
        out_lines.append(f'{k} = "{v}"')
if globals_kv:
    out_lines.append("")
for k, v in sections:
    escaped_k = k.replace('\\', '\\\\').replace('"', '\\"')
    out_lines.append(f'["{escaped_k}"]')
    for kk, vv in v.items():
        if isinstance(vv, bool):
            out_lines.append(f"{kk} = {'true' if vv else 'false'}")
        elif isinstance(vv, (int, float)):
            out_lines.append(f"{kk} = {vv}")
        else:
            out_lines.append(f'{kk} = "{vv}"')
    out_lines.append("")
with open(config_path, 'w') as f:
    f.write("\n".join(out_lines).rstrip() + "\n")
PY
}
