---
name: init-talk
description: Scaffold a new conference talk repository with bilingual (en + de) Slidev slide decks — same setup, layout and options as the "still-coding" talk. Use when the user wants to start, init or set up a new talk, presentation or slide deck.
---

# Init a new talk

Creates a talk repo with two Slidev decks — `slides/en` and `slides/de` — sharing
one setup: the Synthwave '85 theme, mermaid and shiki re-themed to match, the
Orbitron / Fira Code font pair, a title slide with DRAFT badge on a neon-horizon
background, a "who am I" slide, an agenda stub, and a closing thank-you slide
with a QR code to the repo. Modelled on `github.com/uebelack/still-coding` and
`who-is-jev`.

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
`--no-install` (skip `pnpm install`), `--no-git` (skip `git init`).

The script refuses to write into a non-empty directory.

## What you get

```
<dir>/
├── ABSTRACT.md             # skeleton, TODOs to fill in
├── ABSTRACT_de.md
└── slides/{en,de}/
    ├── slides.md           # cover, who-am-I, agenda stub, thank-you slide
    ├── styles.css          # the whole theme; only the AI footnote differs by language
    ├── package.json        # slidev 52, name "<slug>-<lang>"
    ├── pnpm-workspace.yaml # the markdown-it pin — see "Package manager"
    ├── vite.config.ts      # CSS minification off — see "Package manager"
    ├── vercel.json         # build to dist/, SPA rewrite
    ├── setup/mermaid.ts    # base theme re-coloured to the palette
    ├── setup/shiki.ts      # code blocks on shiki's synthwave-84
    ├── .gitignore
    └── images/
        ├── nag.svg         # employer logo (ships white; .logo-nag only lights it)
        ├── qr.svg          # QR to uebelacker.dev
        ├── qr_repo.svg     # QR to the repo, generated for this talk
        └── bg-{horizon,arcade,monolith}.jpg   # slide backgrounds
```

## Package manager — pnpm, and two pins that are not optional

Both decks are **pnpm** projects. Do not run `npm install` in them: npm's flat
`node_modules` hides two real problems that pnpm's strict linking exposes, and
mixing the two leaves a stale `package-lock.json` that resolves a different tree
than the one known to work.

- **`pnpm-workspace.yaml` pins `markdown-it` to `^14`.** `@comark/markdown-it`,
  a `@slidev/cli` dependency, imports `markdown-it/lib/token.mjs`, which
  markdown-it 15 removed from its `exports`. The other consumers in the tree
  have loose peer ranges, so without the pin pnpm resolves 15 for everyone and
  `slidev` dies on startup with `ERR_PACKAGE_PATH_NOT_EXPORTED`. The file has to
  be `pnpm-workspace.yaml` even though the deck is not a workspace — pnpm 11 no
  longer reads the `pnpm` field in `package.json`.
- **`vite` is a declared devDependency** because `vite.config.ts` imports it.
  Under npm that resolved by accident through hoisting; under pnpm an undeclared
  import fails with `Cannot find package 'vite'`.

If `slidev` ever fails to start on a markdown-it or vite resolution error, the
fix is a clean re-resolve. A plain `pnpm install` will not re-resolve an existing
tree — it reports "Already up to date" and leaves the broken version linked:

```bash
rm -rf node_modules pnpm-lock.yaml && pnpm install
ls -d node_modules/.pnpm/markdown-it@*      # expect only 14.x
```

Revisit both pins when bumping slidev: once `@comark/markdown-it` supports
markdown-it 15, the override can go.

## After scaffolding

- Fill in `ABSTRACT.md` / `ABSTRACT_de.md` — the German one duzes and uses Swiss
  spelling (`ss`, never `ß`).
- Keep the two decks in lockstep: every slide added to one gets a translated
  twin in the other, same layout and same order. The one thing that must stay
  different is the AI footnote at the bottom of `styles.css` — English in
  `slides/en`, German in `slides/de`. Copying one `styles.css` wholesale over the
  other is the usual way that gets lost.
- If the German title wraps badly on the cover, drop
  `.slidev-layout.cover h1`'s `font-size` in `slides/de/styles.css` and add
  `white-space: nowrap`.
- Remove `<div class="draft-badge">DRAFT</div>` from both title slides once the
  talk is final.

## The theme

Synthwave '85 — the palette from `davconf/nvim/config/colors/synthwave-85.lua`,
mirrored in `uebelacker.ch`'s `theme.css`. The rules that keep it coherent:

- **Indigo is the ground; magenta and cyan are lighting, never fill.** They
  appear as glows, hairlines, grid lines and borders. The `--glow-*` /
  `--text-glow-*` tokens at the top of `styles.css` exist so a new element can
  be lit without inventing another shadow stack.
- **Orbitron for anything that is a label** (headings, mastheads, card heads,
  list markers), **Fira Code for anything that is a sentence.** Handwriting —
  the Caveat the earlier decks used — is gone; it fights this register.
- Every `h1` carries a neon rule underneath; cover and `fact` / `statement`
  headings suppress it and take a glow or the animated chrome fill instead.
- Motion is one slow gradient drift on the cover, disabled under
  `prefers-reduced-motion`. A sign that flickers reads as broken, not as neon.

Fonts load via the `@import` at the top of `styles.css`, so the deck frontmatter
sets `fonts.provider: none`. Leave both halves alone unless you change both.

## Writing further slides

`styles.css` already carries the helper classes the reference talks use — reuse
them instead of inventing new markup:

- `.agenda-list` — roomier ordered list for the agenda slide
- `.compare` / `.compare-col` / `.compare-head` / `.compare-essence` /
  `.compare-footer` — three-column term comparison; the columns are lit gold /
  magenta / cyan by position, with the middle one raised, so order carries
  meaning. `.compare-essence` renders as a shell prompt.
- `.big-quote` — oversized pull quote with a decorative opening quote mark
- `.newspaper*` — a CRT news bulletin (the class names are left over from the
  newsprint version it replaced)
- `.center`, `.emoji-list` — flex centering; bullet list led by emoji
- `.logo-nag` — lights the white logo instead of inverting it
- `.qr-frame` — white ground inside a lit frame, so a QR still scans
- `.bg-horizon` / `.bg-arcade` / `.bg-monolith` — full-bleed backgrounds, set
  per slide with `class: bg-horizon` in the slide frontmatter. Add a
  talk-specific one next to those rules: scrim first in `background-image`,
  photo second.

Slidev layouts in use: default, `cover`, `fact`, `statement`, `full`, and
`two-cols-header` (with `::left::` / `::right::`).

Code blocks need no styling — `setup/shiki.ts` puts them on shiki's
`synthwave-84` theme.

Mermaid diagrams go in fenced mermaid blocks with a `{scale: N}` option.
Styling them from `styles.css` does not work — the SVG lives in a shadow root,
so all diagram styling belongs in `setup/mermaid.ts`; read the comments there
before touching it.

Illustrations are generated with the `generate-image` skill. Read
`references/art-direction.md` first — it carries the palette and the prompt
clauses that make an image land on these slides — and keep each prompt next to
its image as a sidecar `.md` in `art/`.
