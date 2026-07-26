#!/bin/zsh

set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
info_plist="$project_dir/Resources/Info.plist"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info_plist")"
release_dir="$project_dir/dist/release/v$version"
stage_dir="$(mktemp -d "${TMPDIR:-/tmp}/quotabar-release.XXXXXX")"
mount_dir="$(mktemp -d "${TMPDIR:-/tmp}/quotabar-mount.XXXXXX")"
rw_dmg="$stage_dir/Quota-Bar-$version-rw.dmg"
notary_zip="$stage_dir/Quota-Bar-$version-notary.zip"
mounted_device=""

cleanup() {
    if [[ -n "$mounted_device" ]]; then
        /usr/bin/hdiutil detach "$mounted_device" -quiet || true
    elif mount | grep -Fq " on $mount_dir "; then
        /usr/bin/hdiutil detach "$mount_dir" -quiet || true
    fi
    rm -rf "$stage_dir" "$mount_dir"
}
trap cleanup EXIT

notary_credentials_available() {
    [[ -n "${QUOTABAR_NOTARY_PROFILE:-}" ]] || {
        [[ -n "${APPLE_ID:-}" ]] &&
            [[ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]] &&
            [[ -n "${APPLE_TEAM_ID:-}" ]]
    }
}

notarize() {
    local artifact="$1"
    if [[ -n "${QUOTABAR_NOTARY_PROFILE:-}" ]]; then
        xcrun notarytool submit "$artifact" \
            --keychain-profile "$QUOTABAR_NOTARY_PROFILE" \
            --wait
    else
        xcrun notarytool submit "$artifact" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_APP_SPECIFIC_PASSWORD" \
            --team-id "$APPLE_TEAM_ID" \
            --wait
    fi
}

"$project_dir/scripts/build-app.sh"
mkdir -p "$release_dir"

app_name="Quota Bar.app"
app_path="$project_dir/dist/$app_name"
zip_path="$release_dir/Quota-Bar-$version.zip"
dmg_path="$release_dir/Quota-Bar-$version.dmg"
volname="Quota Bar $version"

sign_identity="${QUOTABAR_SIGN_IDENTITY:-}"
if [[ -z "$sign_identity" ]]; then
    sign_identity="$(security find-identity -v -p codesigning \
        | sed -n 's/.*\"\\(Developer ID Application:.*\\)\"/\\1/p' \
        | head -1)"
fi

rm -f "$zip_path" "$dmg_path" "$release_dir/SHA256SUMS.txt"

if [[ -n "$sign_identity" ]] && notary_credentials_available; then
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent \
        "$app_path" "$notary_zip"
    notarize "$notary_zip"
    xcrun stapler staple "$app_path"
    xcrun stapler validate "$app_path"
    spctl --assess --type execute --verbose=2 "$app_path"
elif [[ -n "$sign_identity" ]]; then
    echo "Warning: Developer ID signing is available, but notarization credentials are missing." >&2
else
    echo "Warning: this local package is ad-hoc signed and will be blocked by Gatekeeper on other Macs." >&2
fi

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"

mkdir -p "$stage_dir/payload/.background"
cp -R "$app_path" "$stage_dir/payload/$app_name"
cp "$project_dir/Resources/DMGBackground.png" \
    "$stage_dir/payload/.background/DMGBackground.png"
ln -s /Applications "$stage_dir/payload/Applications"

/usr/bin/hdiutil create \
    -volname "$volname" \
    -srcfolder "$stage_dir/payload" \
    -ov \
    -format UDRW \
    "$rw_dmg" >/dev/null

attach_output="$(/usr/bin/hdiutil attach "$rw_dmg" \
    -readwrite \
    -noverify \
    -noautoopen \
    -mountpoint "$mount_dir")"
mounted_device="$(print -r -- "$attach_output" | awk '$1 ~ /^\/dev\// {print $1; exit}')"

chflags hidden "$mount_dir/.background" || true
/usr/bin/SetFile -a V "$mount_dir/.background" || true
if [[ -d "$mount_dir/.fseventsd" ]]; then
    chflags hidden "$mount_dir/.fseventsd" || true
    /usr/bin/SetFile -a V "$mount_dir/.fseventsd" || true
fi
/usr/bin/osascript <<APPLESCRIPT || \
    echo "Warning: Finder layout could not be applied; drag-to-Applications remains available." >&2
tell application "Finder"
    set dmgFolder to (POSIX file "$mount_dir" as alias)
    set backgroundFile to (POSIX file "$mount_dir/.background/DMGBackground.png" as alias)
    open dmgFolder
    set dmgWindow to container window of dmgFolder
    set current view of dmgWindow to icon view
    set toolbar visible of dmgWindow to false
    set statusbar visible of dmgWindow to false
    set pathbar visible of dmgWindow to false
    set bounds of dmgWindow to {120, 120, 1040, 520}
    set theViewOptions to icon view options of dmgWindow
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 112
    set text size of theViewOptions to 13
    set background picture of theViewOptions to backgroundFile
    set position of item "$app_name" of dmgFolder to {230, 205}
    set position of item "Applications" of dmgFolder to {690, 205}
    try
        set position of item ".background" of dmgFolder to {1600, 1600}
    end try
    try
        set position of item ".fseventsd" of dmgFolder to {1700, 1600}
    end try
    try
        set position of item ".Trashes" of dmgFolder to {1800, 1600}
    end try
    update dmgFolder without registering applications
    delay 2
    close dmgWindow
end tell
APPLESCRIPT

sync
rm -rf "$mount_dir/.fseventsd" "$mount_dir/.Trashes"
if ! /usr/bin/hdiutil detach "$mounted_device" -quiet; then
    echo "DMG is still busy; retrying detach..." >&2
    sleep 2
    if ! /usr/bin/hdiutil detach "$mounted_device" -quiet; then
        echo "DMG is still busy; force-detaching temporary image..." >&2
        /usr/bin/hdiutil detach "$mounted_device" -force -quiet
    fi
fi
mounted_device=""
/usr/bin/hdiutil convert "$rw_dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov \
    -o "$dmg_path" >/dev/null

if [[ -n "$sign_identity" ]]; then
    codesign --force --timestamp --sign "$sign_identity" "$dmg_path"
    if notary_credentials_available; then
        notarize "$dmg_path"
        xcrun stapler staple "$dmg_path"
        xcrun stapler validate "$dmg_path"
        spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
    fi
fi

(
    cd "$release_dir"
    /usr/bin/shasum -a 256 \
        "Quota-Bar-$version.dmg" \
        "Quota-Bar-$version.zip" > SHA256SUMS.txt
)

echo "$release_dir"
