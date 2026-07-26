# Quota Bar v1.2.3

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the scrolling menu bar summary so the status item and gauge icon stay fixed while only the text moves.
- Ensured the complete Codex, Claude, Kimi, and DeepSeek summary is rendered as one unbroken line.
- Increased the marquee speed so every visible provider passes through within at most 12 seconds per cycle.
- The animation still uses only already loaded text and never triggers quota refreshes or model requests.
