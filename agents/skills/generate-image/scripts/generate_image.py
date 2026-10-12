#!/usr/bin/env python3
"""Generate images with Google Vertex AI — Gemini 3 Pro Image ("Nano Banana Pro").

Stdlib only. Auth comes from `gcloud auth print-access-token` (ADC login).
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime
from pathlib import Path

# Fallback project when neither --project, $GOOGLE_CLOUD_PROJECT, nor gcloud config resolve one.
DEFAULT_PROJECT = "culissa"
DEFAULT_MODEL = "gemini-3-pro-image"
DEFAULT_LOCATION = "global"  # Gemini 3 image models are served from the global endpoint only.

ASPECT_RATIOS = ["1:1", "2:3", "3:2", "3:4", "4:3", "9:16", "16:9", "21:9"]
IMAGE_SIZES = ["1K", "2K", "4K"]

# Threshold aliases -> the value the API expects.
SAFETY_LEVELS = {
    "off": "OFF",  # filters disabled entirely — the most permissive setting Vertex exposes
    "none": "BLOCK_NONE",  # filters run but never block
    "high": "BLOCK_ONLY_HIGH",
    "medium": "BLOCK_MEDIUM_AND_ABOVE",
    "low": "BLOCK_LOW_AND_ABOVE",
}

HARM_CATEGORIES = [
    "HARM_CATEGORY_HATE_SPEECH",
    "HARM_CATEGORY_DANGEROUS_CONTENT",
    "HARM_CATEGORY_HARASSMENT",
    "HARM_CATEGORY_SEXUALLY_EXPLICIT",
    "HARM_CATEGORY_CIVIC_INTEGRITY",
    "HARM_CATEGORY_IMAGE_HATE",
    "HARM_CATEGORY_IMAGE_DANGEROUS_CONTENT",
    "HARM_CATEGORY_IMAGE_HARASSMENT",
    "HARM_CATEGORY_IMAGE_SEXUALLY_EXPLICIT",
]

EXT_BY_MIME = {"image/png": "png", "image/jpeg": "jpg", "image/webp": "webp"}


def die(message: str) -> "None":
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def access_token() -> str:
    """ADC first (what the Vertex SDKs use), then the plain user credential."""
    errors = []
    for command in (
        ["gcloud", "auth", "application-default", "print-access-token"],
        ["gcloud", "auth", "print-access-token"],
    ):
        try:
            out = subprocess.run(command, capture_output=True, text=True, check=True)
        except FileNotFoundError:
            die("gcloud not found on PATH. Install the Google Cloud SDK.")
        except subprocess.CalledProcessError as exc:
            errors.append(exc.stderr.strip())
            continue
        token = out.stdout.strip()
        if token:
            return token
    die(
        "could not get an access token. Run:\n"
        "  gcloud auth application-default login\n"
        + "\n".join(errors)
    )


def resolve_project(flag: str | None) -> str:
    if flag:
        return flag
    env = os.environ.get("GOOGLE_CLOUD_PROJECT")
    if env:
        return env
    try:
        out = subprocess.run(
            ["gcloud", "config", "get-value", "project"],
            capture_output=True,
            text=True,
            check=False,
        )
        value = out.stdout.strip()
        if value and value != "(unset)":
            return value
    except FileNotFoundError:
        pass
    return DEFAULT_PROJECT


def slug(text: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:48]
    return s or "image"


def build_request(args, prompt: str, reference_images: list[dict]) -> dict:
    parts: list[dict] = [
        {"inlineData": {"data": ref["data"], "mimeType": ref["mimeType"]}}
        for ref in reference_images
    ]
    parts.append({"text": prompt})

    image_config: dict = {
        "aspectRatio": args.aspect,
        "imageSize": args.size,
        "personGeneration": args.person,
        "prominentPeople": args.prominent_people,
    }
    if args.mime:
        image_config["outputMimeType"] = args.mime
    if args.quality is not None:
        image_config["outputCompressionQuality"] = args.quality

    generation_config: dict = {
        # Nano Banana Pro reasons in text before it draws; both modalities are required.
        "responseModalities": ["TEXT", "IMAGE"],
        "imageConfig": image_config,
    }
    if args.temperature is not None:
        generation_config["temperature"] = args.temperature
    if args.seed is not None:
        generation_config["seed"] = args.seed

    body: dict = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": generation_config,
        "safetySettings": [
            {"category": category, "threshold": SAFETY_LEVELS[args.safety]}
            for category in HARM_CATEGORIES
        ],
    }
    if args.system:
        body["systemInstruction"] = {"parts": [{"text": args.system}]}
    return body


def call_vertex(body: dict, project: str, location: str, model: str, token: str) -> dict:
    host = (
        "https://aiplatform.googleapis.com"
        if location == "global"
        else f"https://{location}-aiplatform.googleapis.com"
    )
    url = (
        f"{host}/v1/projects/{project}/locations/{location}"
        f"/publishers/google/models/{model}:generateContent"
    )
    request = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json; charset=utf-8",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        die(f"Vertex AI returned HTTP {exc.code}\n{detail}")
    except urllib.error.URLError as exc:
        die(f"could not reach Vertex AI: {exc.reason}")


def extract(response: dict) -> tuple[list[dict], str, str | None]:
    candidate = (response.get("candidates") or [{}])[0]
    images: list[dict] = []
    texts: list[str] = []
    for part in (candidate.get("content") or {}).get("parts") or []:
        inline = part.get("inlineData")
        if inline and inline.get("data"):
            images.append(
                {
                    "data": base64.b64decode(inline["data"]),
                    "mimeType": inline.get("mimeType", "image/png"),
                }
            )
        elif part.get("text") and not part.get("thought"):
            texts.append(part["text"])
    return images, "\n".join(texts).strip(), candidate.get("finishReason")


def write_sidecar(
    image_path: Path,
    prompt: str,
    args,
    project: str,
    text: str,
    run: int,
) -> Path:
    """Store the prompt (and how it was rendered) as a .md file next to the image."""
    settings = [
        ("model", args.model),
        ("aspect", args.aspect),
        ("size", args.size),
        ("safety", args.safety),
        ("person", args.person),
        ("prominent_people", args.prominent_people),
        ("project", project),
        ("location", args.location),
        ("temperature", args.temperature),
        ("seed", args.seed),
        ("mime", args.mime),
        ("quality", args.quality),
        ("run", f"{run}/{args.count}" if args.count > 1 else None),
    ]

    lines = [
        "---",
        f"image: {image_path.name}",
        f"generated: {datetime.now().isoformat(timespec='seconds')}",
    ]
    lines += [f"{key}: {value}" for key, value in settings if value is not None]
    if args.image:
        lines.append("reference_images:")
        lines += [f"  - {path}" for path in args.image]
    lines += ["---", "", "## Prompt", "", prompt, ""]

    if args.system:
        lines += ["## System instruction", "", args.system, ""]
    if text:
        lines += ["## Model notes", "", text, ""]

    sidecar = image_path.with_suffix(".md")
    sidecar.write_text("\n".join(lines), encoding="utf-8")
    return sidecar


def parse_args(argv: list[str]):
    parser = argparse.ArgumentParser(
        prog="generate_image.py",
        description="Generate images with Vertex AI Gemini 3 Pro Image (Nano Banana Pro).",
    )
    parser.add_argument("prompt", nargs="*", help="the image prompt")
    parser.add_argument("-f", "--file", help="read the prompt from a file instead")
    parser.add_argument("-a", "--aspect", default="1:1", choices=ASPECT_RATIOS)
    parser.add_argument("-s", "--size", default="2K", choices=IMAGE_SIZES)
    parser.add_argument("-n", "--count", type=int, default=1, help="number of images")
    parser.add_argument("-o", "--out", default="generated-images", help="output directory")
    parser.add_argument("--name", help="filename prefix (default derived from the prompt)")
    parser.add_argument(
        "-i",
        "--image",
        action="append",
        default=[],
        help="reference image for editing/style/consistency (repeatable, up to 14)",
    )
    parser.add_argument("-m", "--model", default=os.environ.get("MODEL", DEFAULT_MODEL))
    parser.add_argument("--system", help="system instruction")
    parser.add_argument("-t", "--temperature", type=float)
    parser.add_argument("--seed", type=int)
    parser.add_argument("--safety", default="off", choices=list(SAFETY_LEVELS))
    parser.add_argument(
        "--person",
        default="ALLOW_ALL",
        choices=["ALLOW_ALL", "ALLOW_ADULT", "ALLOW_NONE"],
    )
    parser.add_argument(
        "--prominent-people",
        default="ALLOW_PROMINENT_PEOPLE",
        choices=["ALLOW_PROMINENT_PEOPLE", "ALLOW_NONE"],
    )
    parser.add_argument("--mime", help="image/png | image/jpeg | image/webp")
    parser.add_argument("--quality", type=int, help="JPEG compression quality 0..100")
    parser.add_argument("--project", help="GCP project (default $GOOGLE_CLOUD_PROJECT)")
    parser.add_argument(
        "--location",
        default=os.environ.get("GOOGLE_CLOUD_LOCATION", DEFAULT_LOCATION),
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)

    if args.file:
        prompt = Path(args.file).read_text(encoding="utf-8").strip()
    else:
        prompt = " ".join(args.prompt).strip()
    if not prompt:
        die("no prompt. Pass one as an argument or use --file.")

    reference_images = []
    for path in args.image:
        raw = Path(path).read_bytes()
        mime = mimetypes.guess_type(path)[0] or "image/png"
        reference_images.append(
            {"data": base64.b64encode(raw).decode(), "mimeType": mime}
        )

    project = resolve_project(args.project)
    token = access_token()
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    stamp = datetime.now().strftime("%Y-%m-%dT%H-%M-%S")
    prefix = args.name or (
        slug(Path(args.file).stem) if args.file else slug(prompt)
    )
    body = build_request(args, prompt, reference_images)
    saved = 0

    for run in range(1, args.count + 1):
        label = f" ({run}/{args.count})" if args.count > 1 else ""
        preview = prompt if len(prompt) <= 120 else prompt[:120] + "…"
        print(f"Generating{label}: {preview}", flush=True)

        response = call_vertex(body, project, args.location, args.model, token)
        images, text, finish_reason = extract(response)

        if not images:
            feedback = response.get("promptFeedback") or {}
            blocked = feedback.get("blockReason")
            reason = (
                f"prompt blocked: {blocked} {feedback.get('blockReasonMessage', '')}".strip()
                if blocked
                else f"finishReason: {finish_reason or 'unknown'}"
            )
            print(f"  no image returned ({reason})", file=sys.stderr)
            if text:
                print(f"  {text}", file=sys.stderr)
            continue

        for image in images:
            saved += 1
            ext = EXT_BY_MIME.get(image["mimeType"], "png")
            path = out_dir / f"{stamp}_{prefix}_{saved:02d}.{ext}"
            path.write_bytes(image["data"])
            print(f"  → {path} ({len(image['data']) / 1024:.0f} KB)")
            sidecar = write_sidecar(path, prompt, args, project, text, run)
            print(f"  → {sidecar}")

        if text:
            print("  " + text.replace("\n", "\n  "))

    if saved == 0:
        die("no images were generated.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
