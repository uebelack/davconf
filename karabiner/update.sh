#!/usr/bin/env bash
#
# Teach fn to be AeroSpace's leader key, via Karabiner-Elements.
#
#   ./karabiner/update.sh          # install the rule where out of date
#   ./karabiner/update.sh --check  # report what would change, change nothing
#
# AeroSpace's modifiers are cmd, alt, ctrl and shift. fn is not one of them and
# cannot become one: macOS handles it below the level any hotkey registration
# sees, so `fn-alt-h = ...` is not a binding AeroSpace fails to honour, it is a
# line it refuses to parse. Karabiner sits lower still, at the event tap, which
# is why it can do what the config cannot.
#
# So fn becomes cmd+ctrl+alt — three modifiers AeroSpace does understand, and a
# combination nothing else on the system claims. Pressing fn is pressing all
# three; fn+shift is the second level, which is what keeps `move` a shifted
# `focus` the way it was under plain alt.
#
# What it does NOT do is remap the fn key itself. That is the obvious way to
# write this rule and it quietly costs you the rest of the key: fn+arrows for
# home/end, fn+delete for forward delete, fn+F1 for a real F-key. Karabiner
# would be swallowing fn before macOS ever sees it. Instead the rule claims
# only fn plus the keys AeroSpace actually binds — letters, digits and a
# handful of punctuation — so every other fn combination reaches macOS
# untouched.
#
# Which keys those are is read out of aerospace/aerospace.toml rather than
# repeated here. The two files cannot drift: bind a new key over there, run
# this, and the rule grows to match.
#
# Create ~/.config/davconf/no-karabiner on a machine that does not want it.

set -euo pipefail

DAVCONF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AEROSPACE_TOML="$DAVCONF_DIR/aerospace/aerospace.toml"
KARABINER_DIR="$HOME/.config/karabiner"
CONFIG="$KARABINER_DIR/karabiner.json"
ASSET="$KARABINER_DIR/assets/complex_modifications/davconf-fn-leader.json"
APP="Karabiner-Elements.app"
# Every rule this repo owns starts with this, which is how a re-run finds its
# own work to replace instead of stacking another copy beside it.
MARKER="davconf:"
OPT_OUT="$HOME/.config/davconf/no-karabiner"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S).bak"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

mode=apply
for arg in "$@"; do
  case "$arg" in
    --check) mode=check ;;
    *)       echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

[ -e "$OPT_OUT" ] && exit 0

info "AeroSpace leader key"

app_dir=""
for base in "/Applications/$APP" "$HOME/Applications/$APP"; do
  [ -d "$base" ] || continue
  app_dir="$base"
  break
done

if [ -z "$app_dir" ]; then
  printf '    %-24s Karabiner not installed\n' "fn leader"
  warn "brew/Brewfile.common installs it — run ./brew/update.sh first"
  exit 0
fi

if ! command -v python3 >/dev/null; then
  printf '    %-24s python3 not found\n' "fn leader"
  warn "the rule is JSON surgery on karabiner.json — python3 does it, and is missing"
  exit 1
fi

# --- the rule ---------------------------------------------------------------
# Generated into a temp file first so a failure here leaves what is installed
# alone rather than half-rewriting it.
rule="$(mktemp -d)/rule.json"

python3 - "$AEROSPACE_TOML" "$rule" "$MARKER" <<'PY'
import json, re, sys

toml_path, out_path, marker = sys.argv[1], sys.argv[2], sys.argv[3]

# AeroSpace's key names are mostly Karabiner's too. These are the ones that are
# spelled differently, plus the two whose names collide with nothing.
RENAMED = {
    "minus": "hyphen",
    "equal": "equal_sign",
    "leftSquareBracket": "open_bracket",
    "rightSquareBracket": "close_bracket",
    "backtick": "grave_accent_and_tilde",
    "quote": "quote",
    "backslash": "backslash",
    "sectionSign": "non_us_backslash",
    "enter": "return_or_enter",
    "esc": "escape",
    "backspace": "delete_or_backspace",
    "forwardDelete": "delete_forward",
    "pageUp": "page_up",
    "pageDown": "page_down",
    "left": "left_arrow",
    "right": "right_arrow",
    "up": "up_arrow",
    "down": "down_arrow",
}

# Every binding written in the leader's three modifiers, shift or not: the
# shifted ones are the same physical key, so they collapse to the same rule.
keys = []
for match in re.finditer(r"^\s*ctrl-alt-cmd-(?:shift-)?(\S+?)\s*=", open(toml_path).read(), re.M):
    key = match.group(1)
    if key not in keys:
        keys.append(key)

if not keys:
    sys.exit("no ctrl-alt-cmd- bindings found in " + toml_path)

manipulators = [
    {
        "type": "basic",
        "from": {
            "key_code": RENAMED.get(key, key),
            # shift is optional, not mandatory, so one manipulator covers both
            # fn+h and fn+shift+h — and passes the shift through to AeroSpace,
            # which is what tells `move` from `focus`.
            "modifiers": {"mandatory": ["fn"], "optional": ["left_shift", "right_shift"]},
        },
        "to": [
            {
                "key_code": RENAMED.get(key, key),
                "modifiers": ["left_command", "left_control", "left_option"],
            }
        ],
    }
    for key in keys
]

rule = {
    "description": f"{marker} fn is the AeroSpace leader (fn+key -> cmd+ctrl+alt+key, {len(keys)} keys)",
    "manipulators": manipulators,
}

with open(out_path, "w") as f:
    json.dump(rule, f, indent=2)
    f.write("\n")
PY

key_count="$(python3 -c "
import json, sys
print(len(json.load(open('$rule'))['manipulators']))
")"

# --- is it already installed? ------------------------------------------------
# Two places have to agree: the asset file, which is what the Karabiner UI
# lists, and the rule inside the active profile, which is what actually runs.
# Only the second one changes behaviour — the first is there so the rule can be
# seen, and removed, the way every other Karabiner rule can.
current=no
if [ -f "$ASSET" ] && cmp -s "$rule" "$ASSET" && [ -f "$CONFIG" ]; then
  python3 - "$CONFIG" "$rule" "$MARKER" <<'PY' && current=yes
import json, sys

config_path, rule_path, marker = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(config_path) as f:
        config = json.load(f)
    with open(rule_path) as f:
        rule = json.load(f)
except (OSError, ValueError):
    sys.exit(1)

profiles = config.get("profiles") or []
if not profiles:
    sys.exit(1)

# Every profile, not just the selected one: switching profile should not
# silently switch the leader key off.
for profile in profiles:
    rules = profile.get("complex_modifications", {}).get("rules", [])
    if not any(r == rule for r in rules):
        sys.exit(1)
sys.exit(0)
PY
fi

if [ "$current" = yes ]; then
  printf '    %-24s up to date, %s keys\n' "fn leader" "$key_count"
  exit 0
fi

if [ "$mode" = check ]; then
  printf '    %-24s would be installed, %s keys\n' "fn leader" "$key_count"
  exit 0
fi

# --- install ----------------------------------------------------------------
mkdir -p "$(dirname "$ASSET")"
cp "$rule" "$ASSET"

if [ -f "$CONFIG" ]; then
  cp "$CONFIG" "$CONFIG.$BACKUP_SUFFIX"
fi

python3 - "$CONFIG" "$rule" "$MARKER" <<'PY'
import json, os, sys

config_path, rule_path, marker = sys.argv[1], sys.argv[2], sys.argv[3]

with open(rule_path) as f:
    rule = json.load(f)

if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
else:
    # Karabiner has never run here. It fills in every key it wants on first
    # launch, so the smallest valid file is enough to carry the rule until then.
    config = {"profiles": [{"name": "Default profile", "selected": True}]}

profiles = config.setdefault("profiles", [])
if not profiles:
    profiles.append({"name": "Default profile", "selected": True})

for profile in profiles:
    complex_mods = profile.setdefault("complex_modifications", {})
    rules = complex_mods.setdefault("rules", [])
    # Drop whatever this repo put here before — by marker, so a rule the user
    # added themselves is never touched — then add the current one.
    rules[:] = [r for r in rules if not str(r.get("description", "")).startswith(marker)]
    rules.append(rule)

with open(config_path, "w") as f:
    json.dump(config, f, indent=4)
    f.write("\n")
PY

printf '    %-24s installed, %s keys\n' "fn leader" "$key_count"

# Karabiner watches this file and reloads on its own, so there is nothing to
# restart — but it only sees the keyboard at all once macOS has been told to
# let it, and that is a dialog no script can click.
if ! pgrep -qf "$APP/Contents/MacOS" 2>/dev/null; then
  warn "Karabiner is not running yet — open it once:"
  cat <<EOM
    open -a Karabiner-Elements

    It will ask for a driver extension and Input Monitoring. Both are required:
    without them the rule is installed and inert.

    Not wanted on this machine?  touch $OPT_OUT
EOM
fi
