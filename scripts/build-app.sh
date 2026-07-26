#!/bin/zsh

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/dist/Quota Bar.app"
contents_dir="$app_dir/Contents"

cd "$project_dir"
swift build -c release

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$contents_dir/Helpers" "$contents_dir/Resources"
cp ".build/release/QuotaBar" "$contents_dir/MacOS/QuotaBar"
cp ".build/release/QuotaBarCapture" "$contents_dir/Helpers/QuotaBarCapture"
cp "Resources/Info.plist" "$contents_dir/Info.plist"

codesign --force --deep --sign - "$app_dir"
echo "$app_dir"
