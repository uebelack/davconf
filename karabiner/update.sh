#!/usr/bin/env bash
#
# Teach caps lock to be AeroSpace's leader key, via Karabiner-Elements.
#
#   ./karabiner/update.sh          # install the rule where out of date
#   ./karabiner/update.sh --check  # report what would change, change nothing
#
# AeroSpace's modifiers are cmd, alt, ctrl and shift. A leader has to be one of
# those, or become one — and on a Swiss German layout none of them is spare:
# the option layer is where [ ] | { } # @ ~ are typed. So the leader is a key
# that is not a modifier at all, turned into one below the level AeroSpace can
# see. Karabiner sits at the event tap, which is why it can do that.
#
# Caps lock held is cmd+ctrl+alt — three modifiers AeroSpace understands, in a
# combination nothing else on the system claims. Not the full hyper of
# cmd+ctrl+alt+shift, deliberately: that would swallow shift, and shift is what
# tells `move` from `focus`. With three, caps+shift is still a second level.
#
# Caps lock rather than fn because fn is not in the same place twice. On the
# built-in keyboard it is bottom left; on the Logitech MX Keys S it is bottom
# right, the hand that is already on hjkl — and a Logitech fn is partly handled
# in firmware, so it does not reliably reach Karabiner at all. Caps lock is on
# every keyboard, in the same spot, left little finger, next to a.
#
# Unlike fn, caps lock has no second function worth keeping, so the rule can
# claim the whole key rather than enumerating the keys AeroSpace binds. Tapped
# on its own it sends escape, which is the more useful thing to have there.
#
# Create ~/.config/davconf/no-karabiner on a machine that does not want it.

set -euo pipefail

KARABINER_DIR="$HOME/.config/karabiner"
CONFIG="$KARABINER_DIR/karabiner.json"
ASSET="$KARABINER_DIR/assets/complex_modifications/davconf-leader.json"
# What this module used to install, back when the leader was fn. Removed on
# sight so the Karabiner UI does not go on listing a rule nothing installs.
LEGACY_ASSET="$KARABINER_DIR/assets/complex_modifications/davconf-fn-leader.json"
APP="Karabiner-Elements.app"
# Every rule this repo owns starts with this, which is how a re-run finds its
# own work to replace instead of stacking another copy beside it.
MARKER="davconf:"
GUIDANCE_LOG="$HOME/.local/share/karabiner/log/console_user_server.log"
OPT_OUT="$HOME/.config/davconf/no-karabiner"
BACKUP_SUFFIX="$(date +%Y%m%d%H%M%S).bak"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1"; }

# An installed rule and a working one are different things, and the gap between
# them is silent: Karabiner's agents need Input Monitoring and permission to run
# in the background, neither of which a script can grant, and without them the
# rule sits in karabiner.json doing nothing. Reporting "up to date" and stopping
# there would be reporting the file, not the behaviour — so every exit path
# comes through here first.
report_liveness() {
  local guidance

  if ! pgrep -qf "Karabiner-Core-Service" || ! pgrep -qf "Karabiner-Console-User-Server"; then
    warn "Karabiner is not running — the rule is installed and inert"
    cat <<EOM
    open -a Karabiner-Elements

    It asks for two things, and needs both:
      System Settings → General → Login Items & Extensions → Allow in the Background
      System Settings → Privacy & Security → Input Monitoring

    Until then caps lock is just caps lock, and AeroSpace hears nothing.
EOM
    return
  fi

  # Running is not the same as permitted: the agents come up and then sit there
  # refusing connections until the two approvals above are given. Karabiner
  # works that state out for itself and writes it to its log — anything other
  # than 'none' is it asking for something. Read that rather than guess at it
  # from the outside; if the log is not there to read, the process check above
  # is as far as this can honestly go.
  guidance="$(grep -o 'settings_window_guidance_setup changed: [a-z]* -> [a-z]*' \
              "$GUIDANCE_LOG" 2>/dev/null | tail -1 | awk '{print $NF}')"
  [ -z "$guidance" ] && return
  [ "$guidance" = none ] && return

  warn "Karabiner is running but still wants setup ($guidance) — the rule is inert until then"
  cat <<EOM
    open -a Karabiner-Elements   # its window says which approval is missing
EOM
}

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
  printf '    %-24s Karabiner not installed\n' "caps lock leader"
  warn "brew/Brewfile.common installs it — run ./brew/update.sh first"
  exit 0
fi

if ! command -v python3 >/dev/null; then
  printf '    %-24s python3 not found\n' "caps lock leader"
  warn "the rule is JSON surgery on karabiner.json — python3 does it, and is missing"
  exit 1
fi

# --- the rule ---------------------------------------------------------------
# Written to a temp file first so a failure here leaves what is installed alone
# rather than half-rewriting it.
#
# shift is `optional: any` rather than mandatory, which is what lets one
# manipulator cover both caps+h and caps+shift+h and still pass the shift
# through to AeroSpace — that is what tells `move` from `focus`.
#
# `lazy` holds the three modifiers back until a key actually follows, so
# holding caps and then thinking better of it emits nothing at all. 250ms
# rather than Karabiner's default second for the tap, so a held leader that
# ends in nothing does not turn into a stray escape a beat later.
rule="$(mktemp -d)/rule.json"

cat > "$rule" <<'JSON'
{
  "description": "davconf: caps lock is the AeroSpace leader (hold -> cmd+ctrl+alt, tap -> escape)",
  "manipulators": [
    {
      "type": "basic",
      "from": {
        "key_code": "caps_lock",
        "modifiers": {
          "optional": [
            "any"
          ]
        }
      },
      "to": [
        {
          "key_code": "left_command",
          "modifiers": [
            "left_control",
            "left_option"
          ],
          "lazy": true
        }
      ],
      "to_if_alone": [
        {
          "key_code": "escape"
        }
      ],
      "parameters": {
        "basic.to_if_alone_timeout_milliseconds": 250
      }
    }
  ]
}
JSON

# --- is it already installed? ------------------------------------------------
# Three things have to agree: the asset file, which is what the Karabiner UI
# lists; the rule inside the active profile, which is what actually runs; and
# the absence of the fn-era asset this module used to write. Only the second
# one changes behaviour — the first is there so the rule can be seen, and
# removed, the way every other Karabiner rule can.
current=no
if [ -f "$ASSET" ] && cmp -s "$rule" "$ASSET" && [ ! -e "$LEGACY_ASSET" ] && [ -f "$CONFIG" ]; then
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
  printf '    %-24s up to date\n' "caps lock leader"
  report_liveness
  exit 0
fi

if [ "$mode" = check ]; then
  printf '    %-24s would be installed\n' "caps lock leader"
  report_liveness
  exit 0
fi

# --- install ----------------------------------------------------------------
mkdir -p "$(dirname "$ASSET")"
cp "$rule" "$ASSET"
rm -f "$LEGACY_ASSET"

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
    # added themselves is never touched, and the old fn rule goes with it —
    # then add the current one.
    rules[:] = [r for r in rules if not str(r.get("description", "")).startswith(marker)]
    rules.append(rule)

with open(config_path, "w") as f:
    json.dump(config, f, indent=4)
    f.write("\n")
PY

printf '    %-24s installed\n' "caps lock leader"

# Karabiner watches this file and reloads on its own, so there is nothing to
# restart — only, possibly, something to permit.
report_liveness
