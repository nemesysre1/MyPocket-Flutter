import hmac
import os

import requests
from dotenv import load_dotenv
from flask import Flask, jsonify, request
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

load_dotenv()

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_KEY = os.environ["GROQ_API_KEY"]  # hanya ada di server
GROQ_MODEL = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")
APP_TOKEN = os.environ.get("APP_TOKEN", "")

SYSTEM_PROMPT = (
    "Kamu asisten keuangan pribadi berbahasa Indonesia. Jawab ringkas, praktis, "
    "dan tanpa menghakimi. Jangan memberi saran investasi spesifik. "
    "Gunakan data pengguna berikut bila relevan: "
)

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 32 * 1024  # tolak request di atas 32 KB
limiter = Limiter(get_remote_address, app=app, default_limits=["120 per hour"])


@app.get("/health")
def health():
    return jsonify(status="ok")


@app.post("/chat")
@limiter.limit("20 per minute")
def chat():
    token = request.headers.get("X-App-Token", "")
    if APP_TOKEN and not hmac.compare_digest(token, APP_TOKEN):
        return jsonify(error="unauthorized"), 401

    data = request.get_json(silent=True) or {}
    msgs = [
        {"role": m["role"], "content": str(m["content"])[:2000]}
        for m in (data.get("messages") or [])[-12:]
        if isinstance(m, dict) and m.get("role") in ("user", "assistant") and m.get("content")
    ]
    if not msgs:
        return jsonify(error="pesan kosong"), 400
    context = str(data.get("context", ""))[:3000]

    try:
        r = requests.post(
            GROQ_URL,
            headers={"Authorization": f"Bearer {GROQ_KEY}"},
            json={
                "model": GROQ_MODEL,
                "temperature": 0.4,
                "max_tokens": 700,
                "messages": [{"role": "system", "content": SYSTEM_PROMPT + context}, *msgs],
            },
            timeout=30,
        )
        r.raise_for_status()
        return jsonify(reply=r.json()["choices"][0]["message"]["content"])
    except (requests.RequestException, KeyError, IndexError, ValueError):
        return jsonify(error="layanan AI tidak tersedia"), 502


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
