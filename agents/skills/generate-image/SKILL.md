---
name: generate-image
description: Generate or edit images with Google Vertex AI — Gemini 3 Pro Image ("Nano Banana Pro"). Use whenever the user asks to create, generate, draw, render, illustrate, or edit an image/picture/photo/illustration/logo/icon/slide graphic, or wants variations of an existing image. Handles text-to-image, image editing, style transfer, and character consistency via reference images.
---

# Generate images (Vertex AI / Nano Banana Pro)

Runs `gemini-3-pro-image` on Vertex AI through a dependency-free Python script.
Auth comes from the local `gcloud` login — no API key, no `npm install`.

## Run it

```bash
python3 ~/.claude/skills/generate-image/scripts/generate_image.py "<prompt>" [options]
```

Images are written to `generated-images/` (relative to the current working directory)
as `<timestamp>_<prefix>_<nn>.png`. Always tell the user the exact output path, and
show the image with the SendUserFile tool when the conversation supports it.

Every image gets a sidecar `<same-name>.md` written next to it, holding the prompt that
produced it plus the settings used (model, aspect, size, safety, seed, reference images,
system instruction, model notes). This happens automatically — never suppress it, and
never hand-write the sidecar yourself. It exists so an image can be reproduced or
iterated on later, so if the user edits an image, read its sidecar first to recover the
original prompt.

## Options

| Flag | Purpose |
| --- | --- |
| `-f, --file <path>` | read the prompt from a file (better for long prompts) |
| `-a, --aspect` | `1:1` (default) `2:3` `3:2` `3:4` `4:3` `9:16` `16:9` `21:9` |
| `-s, --size` | `1K` `2K` (default) `4K` |
| `-n, --count <n>` | number of images — separate requests, so each is a fresh variation |
| `-o, --out <dir>` | output directory (default `generated-images`) |
| `--name <prefix>` | filename prefix (default derived from the prompt) |
| `-i, --image <path>` | reference image, repeatable up to 14 — editing, style transfer, character consistency |
| `-m, --model <id>` | default `gemini-3-pro-image` |
| `--system <text>` | system instruction |
| `-t, --temperature` / `--seed` | sampling temperature / deterministic seed |
| `--safety` | `off` (default, filters disabled) `none` `high` `medium` `low` |
| `--person` | `ALLOW_ALL` (default) `ALLOW_ADULT` `ALLOW_NONE` |
| `--mime` / `--quality` | `image/png` \| `image/jpeg` \| `image/webp`, and JPEG quality 0..100 |
| `--project` / `--location` | GCP project and Vertex location (default `global`) |

## Examples

```bash
# straightforward text-to-image
python3 ~/.claude/skills/generate-image/scripts/generate_image.py \
  "a neon-lit ramen stall in the rain, cinematic" -a 16:9 -s 4K

# four variations of the same idea
python3 ~/.claude/skills/generate-image/scripts/generate_image.py \
  "portrait of an astronaut, 85mm, shallow depth of field" -a 3:4 -n 4

# edit an existing image / keep the character consistent
python3 ~/.claude/skills/generate-image/scripts/generate_image.py \
  "make it winter, keep the character identical" -i ./ref.png

# long prompt from a file, into a specific folder
python3 ~/.claude/skills/generate-image/scripts/generate_image.py \
  -f prompt.txt -o slides/assets --name hero -a 16:9
```

## Writing the prompt

Nano Banana Pro rewards long, descriptive prompts over keyword lists. Cover subject,
setting, action, lighting, camera/lens, style, and mood in prose. It also renders text
inside images reliably — put the exact wording in quotes when the user wants a caption,
label, or logotype. For edits, describe only the change and state what must stay the same.

## Setup / troubleshooting

- **Auth** — the script uses `gcloud auth application-default print-access-token`, falling back to the
  plain user credential. If both fail, ask the user to run `! gcloud auth application-default login`
  themselves (it needs a browser and can't be run non-interactively).
- **Project** — resolved from `--project`, then `$GOOGLE_CLOUD_PROJECT`, then `gcloud config get-value project`,
  then the `DEFAULT_PROJECT` constant in the script (currently `culissa`). The Vertex AI API must be
  enabled: `gcloud services enable aiplatform.googleapis.com --project <id>`.
- **Location** — Gemini 3 image models are served from the `global` endpoint only; don't set a region.
- **No image returned** — the script prints `blockReason`/`finishReason` instead of failing silently.
  Safety thresholds are already off by default; Vertex still enforces non-configurable server-side
  policy, so rephrase the prompt rather than tweaking flags.
- All generated images carry Google's SynthID watermark.

A TypeScript implementation of the same API call lives in `~/projects/ai-image-generator`
(`pnpm gen`) if a Node library version is ever needed.
