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
cp "Resources/QuotaBar.icns" "$contents_dir/Resources/QuotaBar.icns"

sign_identity="${QUOTABAR_SIGN_IDENTITY:-}"
if [[ -z "$sign_identity" ]]; then
    sign_identity="$(security find-identity -v -p codesigning \
        | sed -n 's/.*\"\\(Developer ID Application:.*\\)\"/\\1/p' \
        | head -1)"
fi

if [[ -n "$sign_identity" ]]; then
    codesign --force --options runtime --timestamp \
        --identifier "local.quotabar.capture" \
        --sign "$sign_identity" "$contents_dir/Helpers/QuotaBarCapture"
    codesign --force --options runtime --timestamp \
        --sign "$sign_identity" "$app_dir"
    echo "Signed with $sign_identity"
else
    codesign --force --deep --sign - "$app_dir"
    echo "Warning: Developer ID Application certificate not found; using ad-hoc signing." >&2
fi
echo "$app_dir"
