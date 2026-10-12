---
name: init-talk
description: Scaffold a new conference talk repository with bilingual (en + de) Slidev slide decks — same setup, layout and options as the "still-coding" talk. Use when the user wants to start, init or set up a new talk, presentation or slide deck.
---

# Init a new talk

Creates a talk repo with two Slidev decks — `slides/en` and `slides/de` — sharing
one setup: handwritten-look mermaid diagrams, the Fira Code / Caveat / Roboto Slab
font set, the shared `styles.css`, a title slide with DRAFT badge, a "who am I"
slide, and a closing thank-you slide with a QR code to the repo. Modelled on
`github.com/uebelack/still-coding`.

## Collect first

Ask the user for anything not already given — do not invent a title:

- **slug** — repo / directory name, kebab-case (e.g. `still-coding`)
- **English title** and **English subtitle** (the `##` line under the title)
- **German title** and **German subtitle**
- **repo URL** — defaults to `https://github.com/uebelack/<slug>`; it is baked
  into the closing slide and its QR code, so confirm it if unsure.

Default the target directory to a sibling of the current project (`../<slug>`)
unless the user names a path.

## Run

```bash
~/.claude/skills/init-talk/scripts/init-talk.sh \
  --dir ../my-talk \
  --slug my-talk \
  --title-en "Still Coding or Already Prompting?" \
  --subtitle-en "Agentic Coding – The State of Things" \
  --title-de "Codest Du noch oder promptest Du schon?" \
  --subtitle-de "Agentic Coding – Stand der Dinge"
```

Options: `--repo <url>`, `--gh-user <user>` (default `uebelack`),
`--no-install` (skip `npm install`), `--no-git` (skip `git init`).

The script refuses to write into a non-empty directory.

## What you get

```
<dir>/
├── ABSTRACT.md            # skeleton, TODOs to fill in
├── ABSTRACT_de.md
└── slides/{en,de}/
    ├── slides.md          # title slide, who-am-I slide, thank-you slide
    ├── styles.css         # shared; only the AI footnote text differs by language
    ├── package.json       # slidev 52, name "<slug>-<lang>"
    ├── vercel.json        # build to dist/, SPA rewrite
    ├── setup/mermaid.ts   # base theme, handDrawn look, Caveat labels
    ├── .gitignore
    └── images/
        ├── nag.svg        # employer logo (rendered with filter: invert(1))
        ├── qr.svg         # QR to uebelacker.dev
        └── qr_repo.svg    # QR to the repo, generated for this talk
```

## After scaffolding

- Fill in `ABSTRACT.md` / `ABSTRACT_de.md` — the German one duzes and uses Swiss
  spelling (`ss`, never `ß`).
- Keep the two decks in lockstep: every slide added to one gets a translated
  twin in the other, same layout and same order.
- If the German title wraps on the cover slide, drop
  `.slidev-layout.cover h1` in `slides/de/styles.css` to ~2.15rem and add
  `white-space: nowrap` — that is what the reference talk does.
- Remove `<div class="draft-badge">DRAFT</div>` from both title slides once the
  talk is final.

## Writing further slides

`styles.css` already carries helper classes used by the reference talk — reuse
them instead of inventing new markup:

- `.agenda-list` — roomier ordered list for the agenda slide
- `.compare` / `.compare-col` / `.compare-head` / `.compare-essence` /
  `.compare-footer` — three-column term comparison
- `.big-quote` — oversized pull quote with a decorative opening quote mark
- `.newspaper*` — mock newspaper front page
- `.center` — flex centering
- `.emoji-list` — bullet list where each item leads with an emoji

Slidev layouts in use: default, `two-cols-header` (with `::left::` / `::right::`),
and `fact` for the closing slide.

Mermaid diagrams go in fenced ```mermaid blocks with a `{scale: N}` option.
Styling them from `styles.css` does not work — the SVG lives in a shadow root, so
all diagram styling belongs in `setup/mermaid.ts`; read the comments there before
touching it.

Hand-drawn illustrations for slides are generated with the `generate-image`
skill; the reference talk keeps the prompt next to each PNG as a sidecar `.md`.
