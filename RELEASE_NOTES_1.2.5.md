# Quota Bar v1.2.5

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the marquee disappearing after the first providers because `NSTextField` clipped the repeated offscreen text.
- Replaced the marquee renderer with a full Core Animation text layer.
- The complete summary is rendered twice and moves by exactly one copy, creating a seamless first-to-last infinite loop.
- The status item and gauge icon remain fixed; only the text inside the fixed-width viewport moves.
- The animation uses already loaded text and never triggers a quota refresh or model request.
