"""Synthesise Vietnamese lines with a running VieNeu-TTS Gradio server (called by tool/gen_voice.dart).

Job file (JSON): {"url": "http://127.0.0.1:7860/", "voice": "Trúc Ly", "temperature": 0.7,
                  "workers": 4, "items": [{"text": "...", "out": "build/voice-parts/x.wav"}]}

Each item is written as the server's WAV, atomically (`<out>.tmp` then rename).
stdout: `OK <i>` per finished item. stderr: `FAIL <i> <message>` per failed item.
Exit codes: 0 all done, 1 some items failed, 3 the server cannot be reached.

Usage: uv run --quiet --with gradio_client python -I tool/tts/vieneu_batch.py job.json
"""
import json
import os
import shutil
import sys
import threading
from concurrent.futures import ThreadPoolExecutor

UNAVAILABLE = 3


def say(line: str, err: bool = False) -> None:
    """Progress output; a closed pipe must never turn a written WAV into a failure."""
    try:
        print(line, file=sys.stderr if err else sys.stdout, flush=True)
    except OSError:
        pass


def main(job_path: str) -> int:
    from gradio_client import Client

    with open(job_path, encoding="utf-8") as f:
        job = json.load(f)
    url = job.get("url") or "http://127.0.0.1:7860/"
    voice = job.get("voice", "Trúc Ly")
    temperature = float(job.get("temperature", 0.7))
    items = job["items"]
    local = threading.local()
    lock = threading.Lock()

    def client() -> "Client":
        c = getattr(local, "client", None)
        if c is None:
            c = local.client = Client(url, verbose=False)
        return c

    try:
        client()  # fail fast (one clear message) when the server is down
    except Exception as e:  # noqa: BLE001 - any connection problem means "unavailable"
        say(f"Không kết nối được VieNeu-TTS tại {url}: {e}", err=True)
        return UNAVAILABLE

    def run(i: int) -> bool:
        item = items[i]
        try:
            wav, status, _ = client().predict(
                item["text"], voice, None, "", "Standard (Một lần)", False, 1, temperature, 256, True,
                api_name="/wrapper",
            )
            path = wav.get("path") if isinstance(wav, dict) else wav
            if not path or not os.path.exists(path) or os.path.getsize(path) == 0:
                raise RuntimeError(f"không có audio ({status})")
            out = item["out"]
            os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
            shutil.copyfile(path, out + ".tmp")
            os.replace(out + ".tmp", out)
        except Exception as e:  # noqa: BLE001 - reported per item, the batch goes on
            msg = " ".join(str(e).split())[:300]
            with lock:
                say(f"FAIL {i} {msg}", err=True)
            return False
        with lock:
            say(f"OK {i}")
        return True

    with ThreadPoolExecutor(max_workers=int(job.get("workers", 4))) as pool:
        results = list(pool.map(run, range(len(items))))
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
