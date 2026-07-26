#!/bin/zsh

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
info_plist="$project_dir/Resources/Info.plist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
release_dir="$project_dir/dist/release/v$version"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/quotabar-release.XXXXXX")"

cleanup() {
    rm -rf "$stage_dir"
}
trap cleanup EXIT

"$project_dir/scripts/build-app.sh"
mkdir -p "$release_dir"

app_name="Quota Bar.app"
zip_path="$release_dir/Quota-Bar-$version.zip"
dmg_path="$release_dir/Quota-Bar-$version.dmg"

rm -f "$zip_path" "$dmg_path" "$release_dir/SHA256SUMS.txt"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent \
    "$project_dir/dist/$app_name" "$zip_path"

cp -R "$project_dir/dist/$app_name" "$stage_dir/$app_name"
ln -s /Applications "$stage_dir/Applications"
/usr/bin/hdiutil create \
    -volname "Quota Bar" \
    -srcfolder "$stage_dir" \
    -ov \
    -format UDZO \
    "$dmg_path"

(
    cd "$release_dir"
    /usr/bin/shasum -a 256 \
        "Quota-Bar-$version.dmg" \
        "Quota-Bar-$version.zip" > SHA256SUMS.txt
)

echo "$release_dir"
