# Quota Bar v1.2.0

- Codex quota now comes from the signed-in account's read-only rate-limit endpoint, so the same account shows current quota on multiple Macs without making a model call.
- Claude Desktop quota is read from its local plan-usage history; sending a message in Claude Desktop is no longer required for Quota Bar integration.
- Added the new Quota Bar app icon and a polished drag-to-Applications DMG.
- Added Developer ID hardened-runtime signing, Apple notarization, ticket stapling, and Gatekeeper verification to the release pipeline.
- Kept task/activity detection local to each Mac for privacy. Quota is account-level; work state is device-level.
