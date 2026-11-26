"""Synthesise English lines with Kokoro-82M (called by tool/gen_voice.dart).

Runs with the Python named by KOKORO_PYTHON (a venv with `kokoro`, `soundfile`, `numpy`);
the model comes from the Hugging Face cache (hexgrad/Kokoro-82M).

Job file (JSON): {"voice": "af_heart", "speed": 0.8, "items": [{"text": "...", "out": "x.wav"}]}

Each item is written as 24 kHz mono 16-bit WAV at a steady loudness, atomically (`<out>.tmp`).
stdout: `OK <i>` per finished item. stderr: `FAIL <i> <message>` per failed item.
Exit codes: 0 all done, 1 some items failed, 3 Kokoro cannot be loaded.

Usage: $KOKORO_PYTHON -I tool/tts/kokoro_batch.py job.json
"""
import json
import os
import re
import sys
import warnings

warnings.filterwarnings("ignore")
RATE = 24000
TARGET_DB = -20.0  # RMS of the raw line; gen_voice.dart levels every clip again after trimming
UNAVAILABLE = 3


def say(line: str, err: bool = False) -> None:
    """Progress output; a closed pipe must never turn a written WAV into a failure."""
    try:
        print(line, file=sys.stderr if err else sys.stdout, flush=True)
    except OSError:
        pass


def closed(text: str) -> str:
    """A bare word comes out clipped, as if cut mid-sentence; a full stop makes it a whole utterance."""
    return text if re.search(r"[.!?…]$", text.strip()) else text.strip() + "."


def level(audio):
    import numpy as np

    rms = float(np.sqrt(np.mean(audio**2))) or 1e-9
    audio = audio * 10 ** ((TARGET_DB - 20 * np.log10(rms)) / 20)
    peak = float(np.max(np.abs(audio)))
    return audio * (0.97 / peak) if peak > 0.97 else audio


def main(job_path: str) -> int:
    try:
        import numpy as np
        import soundfile as sf
        from kokoro import KPipeline
    except Exception as e:  # noqa: BLE001
        say(f"Không nạp được Kokoro ({sys.executable}): {e}", err=True)
        return UNAVAILABLE

    with open(job_path, encoding="utf-8") as f:
        job = json.load(f)
    voice = job.get("voice", "af_heart")
    speed = float(job.get("speed", 0.8))
    try:
        pipe = KPipeline(lang_code=voice[0], repo_id="hexgrad/Kokoro-82M")
    except Exception as e:  # noqa: BLE001
        say(f"Không nạp được mô hình Kokoro-82M: {e}", err=True)
        return UNAVAILABLE

    ok = True
    for i, item in enumerate(job["items"]):
        try:
            chunks = [r.audio.numpy() for r in pipe(closed(item["text"]), voice=voice, speed=speed, split_pattern=None)]
            if not chunks:
                raise RuntimeError("Kokoro không đọc được câu này")
            out = item["out"]
            os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
            sf.write(out + ".tmp", level(np.concatenate(chunks)), RATE, subtype="PCM_16", format="WAV")
            os.replace(out + ".tmp", out)
        except Exception as e:  # noqa: BLE001 - reported per item, the batch goes on
            ok = False
            say(f"FAIL {i} {' '.join(str(e).split())[:300]}", err=True)
            continue
        say(f"OK {i}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
