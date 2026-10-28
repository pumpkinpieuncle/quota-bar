#!/bin/zsh
set -euo pipefail

# Import only the character artwork; no DSH code or runtime is bundled.
# Usage: ./scripts/import-deepseek-pet.sh /path/to/node_modules/dsh-pet
pet_package="${1:?Pass the installed dsh-pet package directory}"
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$project_dir/scripts/build-deepseek-atlases.py" "$pet_package"
