---
name: update-javascript-package
description: Maintenance run for one of the user's small open-source JavaScript/TypeScript apps or libraries — migrate tooling to pnpm + oxlint + oxfmt + Vitest if needed, move to the current Node LTS, update all dependencies, bring test coverage to 100%, make sure GitHub Actions CI, CodeQL and the tag-triggered npm release workflow are in place and green, generate the changelog, and bump the version for a new release. Use when the user wants to update dependencies, do maintenance, "freshen up", modernize or prepare a new release of a JS/TS package.
---

# Update a JavaScript package

A maintenance pass over a small open-source JS/TS package. The target state:

- **pnpm** (pinned via `packageManager`, lockfile `pnpm-lock.yaml`)
- **oxlint** for linting, **oxfmt** for formatting
- **Vitest** with coverage at **100 %** (statements, branches, functions, lines)
- **Node**: developed on the current LTS, minimum supported = the LTS before it
- **GitHub Actions**: CI on every push / PR, **CodeQL** code scanning, and a
  **release workflow** that stages an npm publish with provenance when a `v*`
  tag is pushed (the user approves it with 2FA)
- **CHANGELOG.md** generated from the gitmoji commits with git-cliff

The reference setup is `github.com/uebelack/tossitin` (`~/projects/tossitin`).
Templates live next to this file in `assets/` (`ci.yml`, `release.yml`,
`cliff.toml`) — copy them and adapt (Node versions, build step, branch name).

Work through the phases in order. Run the full check (`pnpm run format:check &&
pnpm run lint:check && pnpm test`) after every phase that changes code, and make
one commit per phase so each step can be reviewed or reverted on its own. Chain
the commit with `&&` after the check so a failing check never gets committed.

The user's standing decisions — apply them without asking, just mention them in
the plan summary:

- raise the minimum Node version to the previous LTS (phase 4), even if that
  makes the release a major
- enable CodeQL default setup (phase 7)
- no Dependabot (phase 7)
- back-fill a tag for the last published version when tags are missing (phase 8)

## 0. Recon

1. Make sure the working tree is clean (`git status`). If not, stop and ask.
2. Read `package.json`, the lockfile name, CI workflows in `.github/workflows/`,
   lint/format/test configs, `README.md`, `CHANGELOG.md`, and the release
   history: `git tag --sort=-v:refname | head`, `gh release list -L 5`,
   `npm view <name> versions --json` (is it published at all?).
3. Note what is already on target and what needs migrating. Give the user a
   short summary of the plan before changing anything.

## 1. Package manager → pnpm

Skip if already on pnpm. Otherwise:

1. Remove the old lockfile (`package-lock.json`, `yarn.lock`) and Yarn leftovers
   (`.yarnrc.yml`, `.yarn/`, `.pnp.*`, Yarn entries in `.gitignore`).
2. Set `"packageManager": "pnpm@<latest>"` (look up with `npm view pnpm version`).
3. `pnpm install` to create `pnpm-lock.yaml`.
4. Replace `npm run` / `yarn` / `npx` in scripts, README and CI
   (`npx foo` → `pnpm exec foo` / `pnpm dlx foo`).
5. Recent pnpm enforces a minimum release age for new versions. If a freshly
   published package is blocked, add it to `minimumReleaseAgeExclude` in
   `pnpm-workspace.yaml` rather than turning the feature off.

## 2. Lint & format → oxlint + oxfmt

Skip parts already on target. Otherwise:

1. Remove ESLint and Prettier: packages (`eslint*`, `@typescript-eslint/*`,
   `prettier*`, `eslint-config-*`, `eslint-plugin-*`), config files
   (`.eslintrc*`, `eslint.config.*`, `.prettierrc*`, `.prettierignore`,
   `.eslintignore`) and `eslint-disable` comments that no longer mean anything.
2. `pnpm add -D oxlint oxfmt` and add `.oxlintrc.json` / `.oxfmtrc.json` modelled
   on tossitin (enable the `typescript`, `unicorn`, `oxc`, `vitest` plugins as
   relevant; carry over meaningful rules from the old ESLint config).
3. Scripts:
   ```json
   "lint:check": "oxlint",
   "lint:fix": "oxlint --fix",
   "format:check": "oxfmt --check .",
   "format:write": "oxfmt ."
   ```
4. Run `pnpm run format:write` and `pnpm run lint:fix`, then fix the remaining
   lint errors by hand. Commit the pure reformat separately from real fixes.

## 3. Tests → Vitest

Skip if already on Vitest. Otherwise migrate from Jest / Mocha / etc.:

1. Remove the old runner and its config (`jest.config.*`, `babel.config.*` if
   only used for Jest, `@types/jest`, `ts-jest`, `babel-jest`, …).
2. `pnpm add -D vitest @vitest/coverage-istanbul` (or `coverage-v8`; match
   what the repo already uses if anything).
3. Add `vitest.config.(m)js|ts` like tossitin: `globals: true`, coverage
   enabled, `reporter: ["text", "lcov"]`, include only source files,
   thresholds at 100 for all four metrics.
4. Replace `jest.*` with `vi.*` (`jest.fn` → `vi.fn`, `jest.mock` → `vi.mock`,
   `jest.spyOn` → `vi.spyOn`, timers, `requireActual` → `vi.importActual`, …).
   Mind that `vi.mock` factories are hoisted and module mocks of ESM need
   `default` exports handled explicitly.
5. Script: `"test": "vitest run"`.

## 4. Node versions

Policy: develop and release on the **current LTS**, support down to the
**previous LTS**.

1. Find both from the release index — the two highest majors whose `lts` is not
   `false`:
   ```sh
   curl -s https://nodejs.org/dist/index.json | python3 -c "import json,sys
   seen=[]
   for r in json.load(sys.stdin):
     m=r['version'].split('.')[0]
     if r['lts'] and m not in seen: seen.append(m)
   print(seen[:2])"
   ```
2. Set:
   - `engines.node` → `">=<previous LTS>.0.0"`
   - `.nvmrc` → `<current LTS>` (create it if missing)
   - CI matrix → `[<previous LTS>, <current LTS>]`; release workflow → current LTS
   - `@types/node` → `^<previous LTS>` — types match the minimum, so code can't
     accidentally use APIs that the oldest supported Node lacks
3. Raising the minimum Node version is a **breaking change** → major version
   bump in phase 10. Commit it with 💥 (e.g. `💥 chore: require Node.js 24`) so
   the changelog lists it under "Breaking changes".
4. Use language/runtime features the new minimum allows only where it simplifies
   code (e.g. drop polyfills or packages now covered by Node built-ins:
   `node-fetch`, `rimraf`, `mkdirp`, `dotenv` → `--env-file`, `glob` → `fs.glob`).

## 5. Update dependencies

1. `pnpm outdated` to list everything.
2. Update in batches, not all at once:
   - patch/minor: `pnpm update` → run checks → commit
   - each **major** separately: `pnpm update <pkg> --latest`, read its
     changelog / migration guide (`gh release view <tag> -R <owner>/<repo>`),
     adapt code, run checks, commit
   - pre-1.0 packages (e.g. `oxfmt`) are not covered by `^0.x` — update them
     explicitly with `@latest`
   - if the tests mock the updated library (common for `execa`, prompt
     libraries, HTTP clients), they prove nothing about the new version: write a
     small throwaway script in the scratchpad that runs the real API the way the
     code uses it (interactive prompts via `script -q /dev/null node x.mjs`)
3. Also update the `packageManager` pnpm version and any versions pinned
   exactly (e.g. `"zod": "4.4.3"`) — keep the pin style if it was deliberate
   (check `git log -S`). An exact pin that duplicates a version dependencies
   already bring in (`pnpm why <pkg>` shows two versions) is not deliberate →
   switch it to `^`.
4. `pnpm audit` — fix advisories (update, or overrides for transitive ones) and
   mention anything left unresolved. An auto-installed **peer** dependency (e.g.
   `vite` under `vitest`) stays at its locked version even with an override —
   add it as an explicit devDependency instead.
5. Look for unused or missing dependencies (`pnpm dlx knip`); remove unused ones
   after confirming they really are unused (bin-only tools, config-referenced
   plugins and peer deps show up as false positives).
6. If something cannot be updated (breaking change too large, upstream bug),
   leave it, and report why.

## 6. Coverage → 100 %

1. `pnpm test` and read the coverage table for uncovered lines/branches.
2. Write tests that exercise real behaviour — error paths, edge cases, CLI
   argument handling. Mock only process/network/filesystem boundaries.
3. Do not reach 100 % with `/* istanbul ignore */` / `/* v8 ignore */` unless
   the code genuinely cannot run in tests (e.g. `if (import.meta.main)` entry
   guards); say which ignores you added and why.
4. If a test reveals an actual bug, fix it in its own commit and tell the user.
5. Make sure the thresholds in the Vitest config are 100 so CI enforces it.

## 7. GitHub Actions: CI, CodeQL, Dependabot

**CI** — make `.github/workflows/ci.yml` match `assets/ci.yml`:

- `push` and `pull_request` on the default branch
- `actions/checkout`, `pnpm/action-setup` (reads `packageManager`, no
  `version:` input needed), `actions/setup-node` with `cache: pnpm`
- `pnpm install --frozen-lockfile`, then `format:check`, `lint:check`, `test`
  (plus `build` / `typecheck` if the package has them)
- Node matrix from phase 4; Coveralls upload once (current LTS) if the README
  has a coverage badge, otherwise drop that step

Bump every action to its latest major — the template may be outdated:
`gh api repos/<owner>/<action>/releases/latest --jq .tag_name`.
Remove workflows for tools no longer used (Yarn, ESLint, Jest caches, …).

**CodeQL** — use GitHub's default setup (no workflow file to maintain). Check
and enable it:

```sh
gh api repos/<owner>/<repo>/code-scanning/default-setup --jq .state
gh api -X PATCH repos/<owner>/<repo>/code-scanning/default-setup -f state=configured
```

If the repo already has a `codeql.yml` workflow, keep it and just bump its
action versions instead.

**Dependabot** — not wanted; the user updates manually with this skill. Don't
add it (leave an existing config alone).

## 8. Release automation & changelog

1. Copy `assets/cliff.toml` to the repo root. It groups gitmoji commits
   (✨ features, 🐛 fixes, 🔒 security, ⬆️ dependencies, …), strips the
   `type:` part after the emoji, and skips 🔖 release and merge commits.
2. Copy `assets/release.yml` to `.github/workflows/release.yml`. On a `v*` tag
   it checks the tag equals `package.json` `version`, runs all checks, **stages**
   the npm publish with provenance via **trusted publishing** (OIDC, no
   `NPM_TOKEN`; `npm stage publish` needs npm 12, so the workflow installs it),
   and creates the GitHub release with git-cliff notes. The version goes live on
   npm only after the user approves it with 2FA. Adapt: add `pnpm run build`
   before publishing if the package has a build step; drop the npm step for
   apps that aren't published to npm.
3. If there are **no git tags** yet, git-cliff would put the whole history under
   the next version. Tag the last published version first: find the commit with
   `git log -S'"version": "<x.y.z>"' --oneline -- package.json`, confirm it
   against the publish time (`npm view <name> time --json`), then
   `git tag v<x.y.z> <sha>` (pushed together with the release in phase 11).
4. If there is no `CHANGELOG.md`, it gets created in phase 10. If one exists in
   another format, ask whether to regenerate it or keep the old entries below a
   marker.
5. Trusted publishing needs a one-time setup **by the user** on npmjs.com —
   tell them: package → Settings → Trusted publishing → GitHub Actions, with
   owner, repo, workflow filename `release.yml` and permission
   "npm stage publish". A new trusted publisher must be validated by a publish
   within ~48 h. Then recommend "Require
   two-factor authentication and disallow tokens" in the same settings page,
   and deleting any old `NPM_TOKEN` repo secret. A package that has never been
   published must be published once by hand first.

## 9. Package hygiene

Quick checks, fix what's off:

- `files` / `exports` / `main` / `types` / `bin`: run `pnpm pack --dry-run` and
  check nothing is missing and no tests, coverage, configs or local files
  (`.claude/`, `.idea/`) get published. Without a `files` field everything not
  git-ignored ships — add a whitelist, e.g. `["index.mjs", "src/**/*.mjs",
  "!src/**/*.test.mjs"]`, and check both `pnpm pack --dry-run` and
  `npm pack --dry-run` (the release publishes with npm). Make sure no runtime
  code reads a file that is now excluded.
- After `npm pkg set`, run `pnpm run format:write` — oxfmt sorts
  `package.json` keys (and formats TOML/Markdown), so the check fails otherwise.
  For libraries also run `pnpm dlx publint` (and `pnpm dlx @arethetypeswrong/cli --pack`
  if types are shipped).
- `repository`, `homepage`, `bugs`, `license`, `keywords` present and correct —
  `repository.url` must match the GitHub repo exactly or provenance fails.
- `LICENSE` exists and its year is current.
- README: install/usage still correct, commands use pnpm, required Node version
  matches `engines`, badges point to the right workflows, no references to
  removed tools.
- `.gitignore` covers `node_modules`, `coverage`, build output.

## 10. Version bump & changelog

1. Decide the bump from what changed since the last release
   (`git log <last-tag>..HEAD --oneline`):
   - **patch** — only dependency/tooling updates and bug fixes
   - **minor** — new features
   - **major** — breaking API changes, raised `engines.node`, dropped exports
   Propose the bump with the reasoning and let the user confirm.
2. `pnpm version <type> --no-git-tag-version`.
3. `pnpm dlx git-cliff --tag v<version> -o CHANGELOG.md`, then
   `pnpm run format:write` (oxfmt formats Markdown too). Read the new section —
   reword nothing in history, but tell the user if commit messages make it
   unreadable.
4. Commit both as `🔖 chore: release v<version>`.

## 11. Push & release

- Commit messages follow the repo's gitmoji style, e.g.
  `🔧 chore: migrate from Yarn to pnpm`, `⬆️ chore: update dependencies`,
  `✅ test: raise coverage to 100%`, `👷 ci: add release workflow`,
  `🔖 chore: release v2.2.0`.
- **Ask before** pushing, tagging, or anything that publishes — these are
  public and hard to undo.
- Never rewrite commits that are already on the remote: check
  `git fetch && git status -sb` before any amend / rebase / filter-branch. If
  something needs fixing after a push, add a new commit and regenerate the
  changelog into it (`git commit --amend` that new commit only).
- Push the branch first and watch CI (`gh run watch`); fix failures until green.
- Only then release: `git tag v<version> && git push origin v<version>`
  (plus any back-filled tag from phase 8). Watch the release workflow with
  `gh run watch`, take the stage id from the "Stage npm publish" log
  (`gh run view <id> --log | grep "staged with id"`), and tell the user to
  approve: on npmjs.com, or `npm stage approve <stage-id>` (npm 12 needs Node
  `^24.15 || >=26`). Afterwards verify `npm view <name> version` and
  `gh release view v<version>`.
- If trusted publishing isn't configured yet, the publish step fails — tell the
  user what to set up (phase 8.5) and re-run the job with `gh run rerun <id> --failed`.

## Report

Finish with a short summary: what was migrated, Node versions (old → new
minimum), which dependencies moved by a major version, anything that could not
be updated and why, coverage before → after, CI / CodeQL / release workflow
status, the new version, and what still needs the user (npm trusted publisher
setup, pushing, approving the staged npm release).
