#!/usr/bin/env python3
"""Read synthwave-85.json, and either check the themes against it or emit it.

  palette.py --check            report any theme that disagrees with the JSON
  palette.py --emit css         CSS custom properties
  palette.py --emit swift       a Swift enum of Color values, for iOS
  palette.py --emit json        flattened name -> hex, one object
  palette.py --emit ghostty     the sixteen `palette = N=#hex` lines

The JSON is the canonical palette; every theme in this repo is a hand-written
copy of it in some other file format. Nothing generates those themes from it —
they each carry structure the palette knows nothing about — so --check exists
to catch the copies drifting rather than to prevent it.

Two targets are checked, and they are the two that spell raw hexes out:

  ghostty/config                       the sixteen ANSI colours and the six UI
                                       colours, which is where they are defined
  nvim/config/colors/synthwave-85.lua  its `local p = {}` table, every shade

vscode/, intellij/ and chrome/ are not checked. They are full of colours
derived from these — #f92aad33 is magenta at 20% over the background, and
nvim's blend() mixes the same wash down to an opaque value — and a checker
that does not understand the derivation would only be able to report every one
of them as a mismatch. The wallpaper prompts are checked, because their colour
discipline paragraph is a flat list of the hexes the model may use.
"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PALETTE = pathlib.Path(__file__).resolve().parent / "synthwave-85.json"

# nvim's table uses lua_case; the JSON uses camelCase. Only the names that
# actually differ need to be here.
NVIM_ALIASES = {
    "coral_br": "coralBright",
    "green_br": "greenBright",
    "gold_br": "goldBright",
    "blue_br": "blueBright",
    "magenta_br": "magentaBright",
    "magenta_ansi": "magentaAnsi",
}

# ghostty/config's key -> the JSON's `ui` key. cursor-text and the two
# selection colours are named differently on each side.
GHOSTTY_UI = {
    "background": "background",
    "foreground": "foreground",
    "cursor-color": "cursor",
    "cursor-text": "cursorText",
    "selection-background": "selectionBackground",
    "selection-foreground": "selectionForeground",
    "split-divider-color": "splitDivider",
}


def load():
    return json.loads(PALETTE.read_text())


def flatten(p):
    """Every named colour as one name -> hex dict, for lookups and --emit json."""
    out = {}
    for group in ("ui", "backgrounds", "text", "neon"):
        for key, value in p[group].items():
            if key == "note":
                continue
            out[key] = value
    for i, hex_ in enumerate(p["ansi"]["colors"]):
        out[f"ansi{i}"] = hex_
    return out


# --- checking ----------------------------------------------------------------

def check_ghostty(p, problems):
    text = (ROOT / "ghostty" / "config").read_text()

    for i, want in enumerate(p["ansi"]["colors"]):
        m = re.search(rf"^palette\s*=\s*{i}=#([0-9a-fA-F]{{6}})\s*$", text, re.M)
        if not m:
            problems.append(f"ghostty/config: no `palette = {i}=…` line")
        elif f"#{m.group(1).lower()}" != want:
            problems.append(
                f"ghostty/config: palette {i} is #{m.group(1).lower()}, "
                f"the palette says {want}"
            )

    for key, json_key in GHOSTTY_UI.items():
        want = p["ui"][json_key]
        m = re.search(rf"^{re.escape(key)}\s*=\s*#?([0-9a-fA-F]{{6}})\s*$", text, re.M)
        if not m:
            problems.append(f"ghostty/config: no `{key} = …` line")
        elif f"#{m.group(1).lower()}" != want:
            problems.append(
                f"ghostty/config: {key} is #{m.group(1).lower()}, "
                f"the palette says {want} (ui.{json_key})"
            )


def check_nvim(p, problems):
    path = ROOT / "nvim" / "config" / "colors" / "synthwave-85.lua"
    text = path.read_text()
    # Just the `local p = { … }` table: the file's later tables hold blended
    # values, which are derived and deliberately not in the JSON.
    m = re.search(r"local p = \{(.*?)\n\}", text, re.S)
    if not m:
        problems.append(f"{path.name}: could not find the `local p = {{}}` table")
        return

    flat = flatten(p)
    for name, hex_ in re.findall(r'(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"', m.group(1)):
        want_key = NVIM_ALIASES.get(name, name)
        want = flat.get(want_key)
        if want is None:
            problems.append(
                f"nvim colors: `{name}` = {hex_} is not in the palette — "
                f"add it to synthwave-85.json or drop it there"
            )
        elif hex_.lower() != want:
            problems.append(
                f"nvim colors: {name} is {hex_.lower()}, the palette says {want}"
            )


def check_wallpapers(p, problems):
    want = [h.lower() for h in p["wallpaper"]["colors"]]
    for md in sorted((ROOT / "wallpapers").glob("*/*.md")):
        for line in md.read_text().splitlines():
            if not line.startswith("COLOUR DISCIPLINE"):
                continue
            found = [h.lower() for h in re.findall(r"#[0-9a-fA-F]{6}", line)]
            extra = [h for h in found if h not in want]
            missing = [h for h in want if h not in found]
            where = md.relative_to(ROOT)
            if extra:
                problems.append(
                    f"{where}: colour discipline allows {', '.join(sorted(set(extra)))}, "
                    f"which the palette does not list"
                )
            if missing:
                problems.append(
                    f"{where}: colour discipline is missing {', '.join(missing)}"
                )
            break
        else:
            problems.append(f"{md.relative_to(ROOT)}: no COLOUR DISCIPLINE line")


def check(p):
    problems = []
    check_ghostty(p, problems)
    check_nvim(p, problems)
    check_wallpapers(p, problems)
    return problems


# --- emitting ----------------------------------------------------------------

def emit_css(p):
    lines = [":root {"]
    for name, hex_ in flatten(p).items():
        kebab = re.sub(r"(?<!^)(?=[A-Z])", "-", name).lower()
        lines.append(f"  --sw85-{kebab}: {hex_};")
    lines.append("}")
    return "\n".join(lines)


def emit_swift(p):
    lines = [
        "import SwiftUI",
        "",
        "/// Synthwave '85 — generated by palette/palette.py --emit swift.",
        "enum Synthwave85 {",
    ]
    for name, hex_ in flatten(p).items():
        r, g, b = (int(hex_[i:i + 2], 16) / 255 for i in (1, 3, 5))
        lines.append(
            f"    static let {name} = Color(red: {r:.3f}, "
            f"green: {g:.3f}, blue: {b:.3f})  // {hex_}"
        )
    lines.append("}")
    return "\n".join(lines)


def emit_json(p):
    return json.dumps(flatten(p), indent=2)


def emit_ghostty(p):
    return "\n".join(
        f"palette = {i}=#{h.lstrip('#')}" for i, h in enumerate(p["ansi"]["colors"])
    )


EMITTERS = {
    "css": emit_css,
    "swift": emit_swift,
    "json": emit_json,
    "ghostty": emit_ghostty,
}


def main(argv):
    p = load()

    if len(argv) == 2 and argv[0] == "--emit":
        emitter = EMITTERS.get(argv[1])
        if not emitter:
            print(f"unknown format: {argv[1]} (have: {', '.join(EMITTERS)})",
                  file=sys.stderr)
            return 2
        print(emitter(p))
        return 0

    if argv and argv != ["--check"]:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    problems = check(p)
    for problem in problems:
        print(f"    {problem}")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
