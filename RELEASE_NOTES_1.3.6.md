Quota Bar 1.3.6

## 新增 / New

- **Kimi 会员月度额度支持**：全面支持展示 Kimi 会员月度权益总额度（`subscriptionBalance`），自动对接 Kimi 会员中心 Connect-RPC 接口与本地凭据（Kimi Desktop / 浏览器），自动维持长期有效的访问会话。
- **Kimi 三层配额窗口与方案标注**：Kimi 卡片由双窗口扩展支持三层配额窗口展示（5 小时、7 天与月额度），并在卡片底部标明会员等级方案（如 `Allegretto`）。
- **菜单栏与顶部栏月额度切换**：菜单栏「顶部栏额度」新增「显示月额度」切换项，支持自由设置以月度额度为主展示窗口。
- **Kimi 闲置状态自动刷新**：优化刷新策略，Kimi 处于闲置状态时依然自动按策略进行后台配额同步。

- **Kimi monthly quota & membership integration**: supports full display of Kimi membership monthly quotas (`subscriptionBalance`) by integrating the Kimi Connect-RPC gateway and discovering local credentials from Kimi Desktop / Chromium browsers.
- **Kimi 3-tier quota windows**: expands Kimi quota windows to display 5-hour, 7-day, and monthly quotas simultaneously, with user membership tier (e.g. `Allegretto`) displayed.
- **Menu bar monthly quota switch**: added "Show monthly quota" option in menu bar quota preferences.
- **Idle state refresh**: ensures Kimi quota automatically syncs in the background even when the CLI process is idle.

## 验证 / Validation

- 34 项单元与集成测试全部通过。
- 实测成功获取真实 Kimi 5小时、7天、月额度及 `Allegretto` 会员信息。

已安装的用户可通过菜单栏右键“检查更新”升级，也可下载 DMG 安装；ZIP 用于应用内自动更新。安装包沿用现有的 ad-hoc 签名方式，未经过 Apple 公证。

Existing users can update through “Check for updates” in the menu bar's right-click menu or install the DMG. The ZIP supports the built-in updater. Packages use the existing ad-hoc signing setup and are not notarized by Apple.
