Quota Bar 1.4.1

## 新增与优化 / New Features & Improvements

- **Grok / X Premium 真实配额与重置时间接入**：
  - 接入 Grok 官方配额服务端点（`cli-chat-proxy.grok.com/v1/billing?format=credits`），全面支持 X Premium / SuperGrok 订阅用户的真实周额度实时显示；
  - 自动复用 Grok CLI 本地登录凭证（`~/.grok/auth.json`），支持 OAuth2 Token 静默无感自动续期；
  - 支持精确到分秒的 7 天滑动窗口重置倒计时（例如 `10月21日 13:52 重置`），同步适配周额度选择器与低额度预警；
  - 增强本地模型自动探测能力，优先识别当前会话最新模型（如 `grok-4.7`）；
  - 配备完整的本地多级容灾（离线日志 `unified.jsonl` 快照回退 + 磁盘持久化缓存）。
- **零推理调用原则保障**：仅读取账户配额与账单数据，不发起模型推理调用，不消耗任何额外的 Token 或配额。

- **Live Grok & X Premium Quota & Reset Timers**:
  - Integrated official Grok billing endpoint (`cli-chat-proxy.grok.com/v1/billing?format=credits`), bringing real-time weekly quota support for X Premium / SuperGrok subscribers.
  - Automatically reuses Grok CLI credentials (`~/.grok/auth.json`) with silent OAuth2 token refresh support.
  - Accurate 7-day rolling window reset countdowns, fully integrated with the weekly quota preference and low-quota warnings.
  - Automatic active model discovery (e.g. `grok-4.7`) from local session summaries and model catalogs.
  - Multi-tier offline fallback via local unified logs and disk caching.
- **Zero Model Calls Maintained**: Quota is gathered purely via account billing endpoints with no inference calls or extra token consumption.

## 验证 / Validation

- 37 项自动化测试全量通过（新增 live Grok 配额拉取与解析测试）。
- 实测成功获取 X Premium / SuperGrok 真实配额与精确重置时间。

已安装的用户可通过菜单栏右键“检查更新”升级，也可下载 DMG 安装；ZIP 用于应用内自动更新。安装包沿用现有的 ad-hoc 签名方式，未经过 Apple 公证。

Existing users can update through “Check for updates” in the menu bar's right-click menu or install the DMG. The ZIP supports the built-in updater. Packages use the existing ad-hoc signing setup and are not notarized by Apple.
