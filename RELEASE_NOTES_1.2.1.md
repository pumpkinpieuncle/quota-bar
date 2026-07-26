# Quota Bar v1.2.1

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the DMG Finder layout when hidden files are visible.
- Removed the generated `.fseventsd` directory before finalizing the image.
- Moved required hidden support items outside the visible icon area.
- Kept the real Quota Bar app and Applications shortcut aligned with the installer background.
- Changed all installer-background copy to white for clear contrast.
- On smaller screens, the menu bar rotates through one full model name and quota at a time.
- Added the global `⌥⌘Q` shortcut so the floating panel remains reachable when macOS hides the menu bar item.
