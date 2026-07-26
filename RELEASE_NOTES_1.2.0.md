# Quota Bar v1.2.0

- Codex quota now comes from the signed-in account's read-only rate-limit endpoint, so the same account shows current quota on multiple Macs without making a model call.
- Claude Desktop quota is read from its local plan-usage history; sending a message in Claude Desktop is no longer required for Quota Bar integration.
- Added the new Quota Bar app icon and a polished drag-to-Applications DMG.
- Added a live menu-bar quota summary with 5-hour/weekly switching, left-click panel restore, right-click actions, a rounded one-line panel, and familiar red/yellow/green macOS window controls.
- Added DeepSeek account balance through the official read-only `/user/balance` endpoint, with its API key stored in macOS Keychain.
- Added persistent provider ordering and per-provider show/hide controls across cards, one-line mode, and the menu bar.
- Simplified the floating panel header, improved contrast on light backgrounds, and made a menu-bar left click toggle the panel.
- Menu-bar summaries now use full provider names; panel layout is controlled directly from the panel instead of Settings.
- Added Developer ID hardened-runtime signing, Apple notarization, ticket stapling, and Gatekeeper verification to the release pipeline.
- Kept task/activity detection local to each Mac for privacy. Quota is account-level; work state is device-level.
