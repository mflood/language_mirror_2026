#!/usr/bin/env python3
"""Generate Miri character sheet via Nano Banana Pro (gemini-3-pro-image),
using the Mije hero art as a style reference."""
import base64, json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))

def load_key():
    env_path = os.path.expanduser(
        "~/workspace/six_wands_language_mirror/.env")
    if os.path.exists(env_path):
        for line in open(env_path, encoding="utf-8"):
            line = line.strip()
            if line.startswith("GEMINI_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    return os.environ["GEMINI_API_KEY"]

KEY = load_key()
MODEL = os.environ.get("MIRI_MODEL", "gemini-3-pro-image")
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent?key={KEY}"

prompt_name = sys.argv[1] if len(sys.argv) > 1 else "sheet"
prompt_file = os.path.join(HERE, f"prompt_{prompt_name}.txt")
with open(prompt_file, encoding="utf-8") as f:
    prompt = f.read()

def img_part(name):
    with open(os.path.join(HERE, name), "rb") as f:
        return {"inline_data": {"mime_type": "image/jpeg",
                "data": base64.b64encode(f.read()).decode()}}

ref_parts = [img_part(n) for n in
             os.environ.get("MIRI_REFS", "hero_ref.jpg").split(",")]

body = {
    "contents": [{
        "role": "user",
        "parts": ref_parts + [{"text": prompt}],
    }],
    "generationConfig": {
        "responseModalities": ["TEXT", "IMAGE"],
        "imageConfig": {"aspectRatio": "16:9", "imageSize": "2K"},
    },
}

req = urllib.request.Request(
    URL, data=json.dumps(body).encode(),
    headers={"Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=600) as r:
        resp = json.load(r)
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.read().decode()[:2000])
    sys.exit(1)

n = 0
for cand in resp.get("candidates", []):
    for part in cand.get("content", {}).get("parts", []):
        if "inlineData" in part:
            n += 1
            out = os.path.join(HERE, f"miri_{prompt_name}_{n}.png")
            with open(out, "wb") as f:
                f.write(base64.b64decode(part["inlineData"]["data"]))
            print("saved", out)
        elif "text" in part:
            print("[text]", part["text"][:500])
if n == 0:
    print(json.dumps(resp, indent=2)[:3000])
