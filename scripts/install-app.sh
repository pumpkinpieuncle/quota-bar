#!/bin/zsh

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
"$project_dir/scripts/build-app.sh" >/dev/null

source_app="$project_dir/dist/Quota Bar.app"
target_app="/Applications/Quota Bar.app"

if [ -e "$target_app" ]; then
    backup_dir="$project_dir/dist/Quota Bar.previous.app"
    rm -rf "$backup_dir"
    mv "$target_app" "$backup_dir"
fi

cp -R "$source_app" "$target_app"
open "$target_app"
echo "$target_app"
