# Quota Bar v1.2.2

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Added an automatic menu bar display mode: full quota text on wide screens and a continuous left-scrolling marquee on smaller screens.
- Added explicit Full and Scroll display choices in Settings.
- The marquee animates only the already loaded quota text and never triggers a quota refresh or model request.
- Removed the unsupported Kimi Open Platform voucher/cash balance API, API-key controls, network request, and card content.
- Kimi Code quota and local work status remain available.
