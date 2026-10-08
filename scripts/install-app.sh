#!/bin/zsh

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh" >/dev/null

source_app="$project_dir/dist/Quota Bar.app"
target_app="/Applications/Quota Bar.app"

rm -rf "$target_app"
cp -R "$source_app" "$target_app"
rm -rf "$source_app"
open "$target_app"
echo "$target_app"
