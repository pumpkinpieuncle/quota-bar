Quota Bar 1.3.7

## 新增 / New

- **Codex 重置卡全部列出与到期时间展示**：Codex 卡片全面支持逐张列出当前账户所有的可用重置卡，并清晰标注每张重置卡的具体到期时间；鼠标悬停可查看秒级精确到期时间与卡券说明（`Full reset`）。
- **重置卡每日只读同步策略**：严格遵循按天只读同步与本地持久化缓存（`codex_reset_cards_cache`），日常高频刷新绝不重复发起额外查询，零写操作、零核销风险。
- **Tibo 重置监控与预测对接（零模型额度消耗）**：集成 aihot.news/codex-reset 实时重置监控，展示最新重置与发卡动态及历史间隔中位数；基于纯网页轻量解析，不调用任何 AI 模型接口，消耗 0 Token / 0 模型额度，支持一键在浏览器中打开完整日历。

- **Codex multiple reset passes & expiration dates**: lists each individual reset pass in the Codex card with its specific expiration date and time; hovering shows full card details (`Full reset`).
- **Daily read-only caching for reset passes**: strict daily sync and local caching prevents redundant queries during high-frequency refreshes, with zero write calls or consumption risks.
- **Tibo reset monitor & prediction (zero token cost)**: integrates real-time status and historical reset stats from aihot.news/codex-reset; runs purely via lightweight web scraping without consuming any AI model quota, with one-click browser access.

## 验证 / Validation

- 36 项单元与集成测试全部通过。
- 实测成功获取真实 Codex 2 张可用重置卡及每张到期时间（10月30日、11月7日）。
- 实测成功抓取 aihot.news Tibo 重置监控数据并展示预测徽标。

已安装的用户可通过菜单栏右键“检查更新”升级，也可下载 DMG 安装；ZIP 用于应用内自动更新。安装包沿用现有的 ad-hoc 签名方式，未经过 Apple 公证。

Existing users can update through “Check for updates” in the menu bar's right-click menu or install the DMG. The ZIP supports the built-in updater. Packages use the existing ad-hoc signing setup and are not notarized by Apple.
