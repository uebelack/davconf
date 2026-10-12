#!/usr/bin/env bash
# Scaffold a new Slidev talk repo (en + de) with the standard setup.
# See ../SKILL.md for usage.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS="$SKILL_DIR/assets"

DIR="" SLUG="" TITLE_EN="" SUBTITLE_EN="" TITLE_DE="" SUBTITLE_DE="" REPO=""
GH_USER="uebelack"
DO_INSTALL=1 DO_GIT=1

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)          DIR="$2"; shift 2 ;;
    --slug)         SLUG="$2"; shift 2 ;;
    --title-en)     TITLE_EN="$2"; shift 2 ;;
    --subtitle-en)  SUBTITLE_EN="$2"; shift 2 ;;
    --title-de)     TITLE_DE="$2"; shift 2 ;;
    --subtitle-de)  SUBTITLE_DE="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --gh-user)      GH_USER="$2"; shift 2 ;;
    --no-install)   DO_INSTALL=0; shift ;;
    --no-git)       DO_GIT=0; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$SLUG" ]        || die "--slug is required"
[ -n "$TITLE_EN" ]    || die "--title-en is required"
[ -n "$TITLE_DE" ]    || die "--title-de is required"
[ -n "$SUBTITLE_EN" ] || die "--subtitle-en is required"
[ -n "$SUBTITLE_DE" ] || die "--subtitle-de is required"

DIR="${DIR:-$SLUG}"
REPO="${REPO:-https://github.com/$GH_USER/$SLUG}"

[ -e "$DIR" ] && [ -n "$(ls -A "$DIR" 2>/dev/null)" ] && die "$DIR exists and is not empty"

# Substitute {{PLACEHOLDER}} tokens. Values arrive via the environment so that
# slashes, ampersands and quotes in titles cannot break the substitution.
render() { # render <template> <output>
  TPL="$1" python3 -c '
import os, sys
tpl = open(os.environ["TPL"], encoding="utf-8").read()
for key in ("TITLE", "SUBTITLE", "SLUG", "LANG", "REPO_URL", "AI_FOOTNOTE"):
    tpl = tpl.replace("{{%s}}" % key, os.environ.get(key, ""))
sys.stdout.write(tpl)
' > "$2"
}

for LANG in en de; do
  OUT="$DIR/slides/$LANG"
  mkdir -p "$OUT/setup" "$OUT/images"

  cp "$ASSETS/common/setup/mermaid.ts" "$OUT/setup/mermaid.ts"
  cp "$ASSETS/common/vercel.json"      "$OUT/vercel.json"
  cp "$ASSETS/common/gitignore"        "$OUT/.gitignore"
  cp "$ASSETS/common/images/nag.svg"   "$OUT/images/nag.svg"
  cp "$ASSETS/common/images/qr.svg"    "$OUT/images/qr.svg"

  if [ "$LANG" = "en" ]; then
    export TITLE="$TITLE_EN" SUBTITLE="$SUBTITLE_EN"
    export AI_FOOTNOTE="🤖 contains content created with AI"
    ABSTRACT_OUT="$DIR/ABSTRACT.md"
  else
    export TITLE="$TITLE_DE" SUBTITLE="$SUBTITLE_DE"
    export AI_FOOTNOTE="🤖 enthält Inhalte, die mit KI erstellt wurden"
    ABSTRACT_OUT="$DIR/ABSTRACT_de.md"
  fi
  export SLUG LANG REPO_URL="$REPO"

  render "$ASSETS/common/package.json" "$OUT/package.json"
  render "$ASSETS/common/styles.css"   "$OUT/styles.css"
  render "$ASSETS/$LANG/slides.md"     "$OUT/slides.md"
  render "$ASSETS/$LANG/$(basename "$ABSTRACT_OUT")" "$ABSTRACT_OUT"

  # Repo QR for the closing slide. Same generator the reference talk used.
  if npx --yes qrcode -o "$OUT/images/qr_repo.svg" -t svg "$REPO" >/dev/null 2>&1; then
    :
  else
    echo "warn: could not generate $OUT/images/qr_repo.svg (npx qrcode failed)" >&2
  fi

  if [ "$DO_INSTALL" = 1 ]; then
    echo "npm install in $OUT ..."
    (cd "$OUT" && npm install --silent) || echo "warn: npm install failed in $OUT" >&2
  fi
done

if [ "$DO_GIT" = 1 ] && [ ! -d "$DIR/.git" ]; then
  git -C "$DIR" init -q
fi

echo "✅ talk scaffolded in $DIR"
echo "   repo url: $REPO"
echo "   dev:      cd $DIR/slides/en && npm run dev"
