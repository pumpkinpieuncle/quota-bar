# Quota Bar v1.2.6

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the scrolling menu bar text appearing black after the Core Animation marquee update.
- The marquee now uses high-contrast white text to match adjacent macOS menu bar items.
- Added a subtle dark shadow so the quota text stays readable over colored and brighter menu bar backgrounds.
- Scrolling remains a local animation and never triggers quota refreshes or model requests.
