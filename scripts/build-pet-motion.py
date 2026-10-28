#!/usr/bin/env python3
"""Build transparent pet atlases from reviewed, hash-pinned video imports."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import tempfile

from PIL import Image


def main():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provider")
    parser.add_argument("--config", type=Path, default=root / "docs/pet-motion-imports.json")
    parser.add_argument("--source", type=Path, help="Override the local source location; SHA256 must still match.")
    parser.add_argument("--output-dir", type=Path, help="Write review atlases outside the packaged resource directory.")
    args = parser.parse_args()
    imports = json.loads(args.config.read_text())
    if args.provider not in imports:
        parser.error("No reviewed import configuration for this provider")
    config = imports[args.provider]
    provider = config.get("provider", args.provider)
    source = args.source or root / config["rawVideo"]
    digest = hashlib.sha256(source.read_bytes()).hexdigest()
    if digest != config["sourceSHA256"]:
        parser.error("Source SHA256 differs from the reviewed clip")
    fps = config["fps"]
    blend = config["seamBlendFrames"]
    x, y, width, height = config["crop"]
    cell_height = config.get("cellHeight", 252)
    cell_width = round(width / height * cell_height)
    if fps <= 0 or blend <= 0 or width <= 0 or height <= 0:
        parser.error("Invalid timing or crop")
    destination = args.output_dir or root / "Sources/QuotaBar/Resources/Pets"
    destination.mkdir(parents=True, exist_ok=True)
    key = config.get("keyColor", "0x00FF00")
    similarity = config.get("keySimilarity", 0.18)
    softness = config.get("keySoftness", 0.04)
    spill = config.get("despill")
    spill_filter = f"despill={spill}:mix=0.3," if spill else ""
    base_filters = (
        f"crop={width}:{height}:{x}:{y},chromakey={key}:{similarity}:{softness},"
        f"format=rgba,{spill_filter}scale={cell_width}:{cell_height}:flags=lanczos,fps={fps}"
    )

    def geometry(frame):
        bounds = frame.getchannel("A").point(lambda alpha: 255 if alpha > 128 else 0).getbbox()
        if bounds is None:
            raise ValueError("Empty neutral calibration frame")
        return {"referenceHeight": bounds[3] - bounds[1],
                "bottomInset": cell_height - bounds[3],
                "horizontalOffset": config.get("horizontalOffset", 0)}

    with tempfile.TemporaryDirectory(prefix="pet-motion-") as temporary:
        prepared = []
        calibration = None
        # Additional action sources need their own neutral-frame measurement;
        # measuring a raised hand or bent sleeping pose would change body size.
        if "calibrationFrame" in config:
            neutral = Path(temporary) / "neutral.png"
            calibration_frame = config["calibrationFrame"]
            if not isinstance(calibration_frame, int) or calibration_frame < 0:
                parser.error("calibrationFrame must be a nonnegative source frame index")
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                "-vf", f"{base_filters},trim=start_frame={calibration_frame}:end_frame={calibration_frame + 1}",
                "-frames:v", "1", "-update", "1", str(neutral),
            ], check=True)
            with Image.open(neutral) as frame:
                calibration = geometry(frame)
        for action, (start, end) in config["clips"].items():
            length = end - start
            count = length - blend
            if count <= blend:
                parser.error(f"{action} is too short for the loop blend")
            columns = 8 if count <= 64 else 16
            rows = math.ceil(count / columns)
            output = Path(temporary) / f"{provider}-{action}.png"
            filters = (
                f"[0:v]{base_filters},trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS,split=2[a][b];"
                f"[a]trim=start_frame={blend},setpts=PTS-STARTPTS[body];"
                f"[b]trim=end_frame={blend},setpts=PTS-STARTPTS[head];"
                f"[body][head]xfade=transition=fade:duration={blend / fps}:offset={(length - 2 * blend) / fps},"
                f"trim=end_frame={count},format=rgba,tile={columns}x{rows}:color=black@0[out]"
            )
            subprocess.run([
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                "-filter_complex", filters, "-map", "[out]", "-frames:v", "1", "-update", "1",
                "-compression_level", "9", "-pred", "mixed", str(output),
            ], check=True)
            with Image.open(output) as atlas:
                for index in range(count):
                    tile = atlas.crop((index % columns * cell_width, index // columns * cell_height,
                                       (index % columns + 1) * cell_width, (index // columns + 1) * cell_height))
                    bounds = tile.getchannel("A").point(lambda alpha: 255 if alpha > 128 else 0).getbbox()
                    if bounds is None:
                        raise ValueError(f"{action}: empty frame {index}; inspect the source and cut points")
                    if calibration is None and action == "idle" and index == 0:
                        calibration = geometry(tile)
            metadata = {
                "columns": columns, "rows": rows, "frameCount": count, "fps": fps,
                "source": config["source"], "sourceURL": config["sourceURL"],
                "sourceSHA256": digest, "sourceClipFrames": [start, end],
                "seamBlendFrames": blend, "crop": config["crop"], "cellSize": [cell_width, cell_height],
                "keyColor": key,
                "calibrationSourceFrame": config.get("calibrationFrame", config["clips"].get("idle", [0])[0] + blend),
                "processing": "Fixed crop and scale, chromakey, optional despill, neutral-pose seam blend. No synthesized in-between frames.",
            }
            prepared.append((output, metadata))
        if calibration is None:
            parser.error("An idle clip or explicit calibrationFrame is required for neutral-pose geometry")
        # All clips must succeed before replacing any existing packaged assets.
        for output, metadata in prepared:
            metadata.update(calibration)
            target = destination / output.name
            target.write_bytes(output.read_bytes())
            target.with_suffix(".json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
            print(f"{target.stem}: {metadata['frameCount']} frames at {fps} fps; neutral height {calibration['referenceHeight']}px")


if __name__ == "__main__":
    main()
