#!/usr/bin/env python3
"""Compatibility entrypoint for the reviewed Claude continuous-motion sample."""
from pathlib import Path
import subprocess
import sys

if len(sys.argv) != 2:
    raise SystemExit("Usage: python3 scripts/build-claude-motion.py /path/to/claude-wave-source.mp4")
subprocess.run([
    sys.executable, str(Path(__file__).with_name("build-pet-motion.py")),
    "claude", "--source", sys.argv[1],
], check=True)
