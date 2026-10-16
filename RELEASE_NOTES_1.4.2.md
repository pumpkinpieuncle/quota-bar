Quota Bar 1.4.2

## 新增与优化 / New Features & Improvements

- **Grok / Grok Bot / Grok Imagine 共享额度拆解明细与精准刷新**：
  - 完美支持 xAI 官方聚合周额度信用池与产品级使用明细拆解（`productUsage`）；
  - 卡片详情行直观呈现总用量与各产品占比：例如 `SuperGrok · 已用 18% (Chat 9% · Bot 7% · Imagine 2%)`，主额度与进度条精确计算共享后的真实剩余可用百分比（如 `82%`）；
  - 修复本地日志回退未校验时效导致在令牌自动刷新间隙回退至旧日志（导致额度偏低并停留于 9%）的问题，仅采纳 2 小时内的新鲜日志；
  - 完善 OAuth 令牌刷新后的过期时间计算与本地凭证持久化保存，确保持续稳定同步；
  - 数据源提示明确注明“Grok 官方配额服务（含 Grok 与 Grok Bot 共享额度）”。

- **Grok, Grok Bot & Grok Imagine Shared Quota Breakdown & Accurate Refresh**:
  - Full support for xAI's official shared weekly credit pool and product usage breakdowns (`productUsage`).
  - Added multi-product breakdown display on the card detail line (e.g. `SuperGrok · 已用 18% (Chat 9% · Bot 7% · Imagine 2%)`), accurately reflecting the shared remaining weekly quota (e.g. `82%`).
  - Fixed a fallback issue where stale local unified logs older than 2 hours could cause the quota to read outdated usage (such as 9%) before the fresh remote fetch finished.
  - Enhanced OAuth token refresh expiration persistence and local quota cache serialization.
  - Updated source tooltip to indicate shared quota across Grok and Grok Bot.

## 验证 / Validation

- 37 项自动化测试全量通过（包含真实 Grok 共享配额与子产品拆解拉取验证）。
- 实测成功展示 GrokChat、GrokBot、GrokImagine 共享用量明细与真实剩余百分比。

已安装的用户可通过菜单栏右键“检查更新”升级，也可下载 DMG 安装；ZIP 用于应用内自动更新。安装包沿用现有的 ad-hoc 签名方式，未经过 Apple 公证。

Existing users can update through “Check for updates” in the menu bar's right-click menu or install the DMG. The ZIP supports the built-in updater. Packages use the existing ad-hoc signing setup and are not notarized by Apple.
