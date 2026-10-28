#!/usr/bin/env python3
"""Transcode the installed DSH character clips into native transparent atlases."""
import hashlib
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys

from PIL import Image

source = Path(sys.argv[1])
destination = Path(__file__).resolve().parent.parent / "Sources/QuotaBar/Resources/Pets"
destination.mkdir(parents=True, exist_ok=True)
clips = {
    "idle": "待机呼吸休闲", "thinking": "工作状态-思考冒泡",
    "working": "工作状态-忙碌点按", "waiting": "工作状态-原地踱步张望",
    "attention": "工作状态-垂头叹气冒汗", "sleeping": "原地小憩沉眠",
    "greeting": "点击回应-元气挥手", "stretching": "超大伸懒腰",
    "snack": "吃白饭", "dancing": "轻快摇摆舞", "puzzle": "原地专心玩魔方",
    "magic": "凭空生花", "looking": "东张西望", "jumping": "点击回应-开心跃动",
}
for action, clip in clips.items():
    video = source / "assets/webm" / (clip + ".webm")
    probe = subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(video)
    ])
    count = max(1, round(float(json.loads(probe)["format"]["duration"]) * 10))
    rows = math.ceil(count / 10)
    # The flower effect extends beyond the usual 384px character viewport.
    crop_width, crop_x = (448, 112) if action == "magic" else (384, 128)
    width = crop_width // 2
    output = destination / f"deepseek-{action}.png"
    subprocess.run([
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-c:v", "libvpx-vp9", "-i", str(video),
        "-vf", f"fps=10,crop={crop_width}:360:{crop_x}:0,scale={width}:180:flags=lanczos,format=rgba,tile=10x{rows}:color=black@0",
        "-frames:v", "1", "-update", "1", str(output),
    ], check=True)
    atlas = Image.open(output).convert("RGBA")
    occupied = [i for i in range(10 * rows) if atlas.getchannel("A").crop(
        ((i % 10) * width, (i // 10) * 180, (i % 10 + 1) * width, (i // 10 + 1) * 180)
    ).getbbox()]
    count = max(occupied) + 1
    metadata = {
        "columns": 10, "rows": rows, "frameCount": count, "fps": 10,
        "referenceHeight": 133, "bottomInset": 15,
        "horizontalOffset": -8 if action == "magic" else 0,
        "source": f"PC2005-cloud/dsh-pet 0.3.8/assets/webm/{clip}.webm",
        "sourceSHA256": hashlib.sha256(video.read_bytes()).hexdigest(),
    }
    output.with_suffix(".json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    print(f"{action}: {count} frames")
shutil.copy2(source / "LICENSE", destination / "DSH-PET-LICENSE.txt")
