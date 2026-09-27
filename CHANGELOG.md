# Changelog / 更新日志

# Quota Bar 1.3.3

## 新增 / New

- **Antigravity 真实配额实时支持**：直接对接 Antigravity 本地语言服务（Language Server），精准获取并展示 Gemini 模型（Flash/Pro）以及 3P 模型（Claude Opus/Sonnet、GPT-OSS）的 5 小时滑动窗口与 7 天周额度，提供精确到分秒的重置倒计时与本地持久化缓存。
- **Provider 显示升级**：将原 Gemini 模型统一呈现为「Antigravity」，卡片与菜单栏完整支持双窗口配额与第三方模型额度展示。

**Antigravity real-time quota support**: directly interfaces with the local Antigravity Language Server to display real-time 5-hour and 7-day rolling quota windows for both Gemini models and 3P models (Claude & GPT) with exact reset countdowns and persistent local caching.

## 修复 / Fixes

- **Codex 额度读取修复**：适配最新版 ChatGPT.app 与独立 Codex CLI 的二进制安装路径，新增可用性执行校验与超时保护，并支持账户余额与信用额度解析。

**Codex quota fix**: resolved executable path discovery for modern ChatGPT.app and standalone Codex CLI bundles, added execution validation, and restored balance parsing.

安装方式：已安装 1.3.2 的用户可在菜单栏或设置面板中点击「更新到 v1.3.3」一键自动升级，或下载 DMG 手动替换。

---

# Quota Bar 1.3.2

## 新增 / New

- **内置自动更新**：启动约 8 秒后自动检查 GitHub 最新 Release；设置面板新增
  「软件更新」一行，顶部栏右键菜单新增「检查更新」。发现新版本后一键下载、
  自动替换 App 并重启，无需再手动下载 DMG。
- 更新基于 GitHub Releases 的 zip 产物做整包替换，不依赖 Sparkle 等第三方框架；
  版本比较容忍 `v` 前缀与预发布后缀（含单元测试）。
- 开机自启的登录项注册在更新替换后依然有效（同一 Bundle ID）。

**Built-in updater**: the app quietly checks GitHub Releases after launch. A new
"Software update" row in Settings and a "Check for updates" item in the status
menu offer one-click updates — download, swap the bundle, relaunch. No third
party framework involved.

## 修复 / Fixes

- 副行额度重置时间文字左对齐（1.3.1 的样式修正）。

安装方式：打开 DMG，将 `Quota Bar.app` 拖入 Applications。首次打开若被 macOS
拦截，请在"系统设置 → 隐私与安全性"中允许打开。本版本为 ad-hoc 签名。
从 1.3.2 起，后续新版本可直接在 App 内一键更新。

---

# Quota Bar 1.3.1

## 新增 / New

- **开机自启**：设置里新增「开机自启」开关，基于系统登录项（`SMAppService`），
  注册状态由 macOS 持久化，App 重装也不丢。需要以 `.app` 形式运行才会生效。

**Launch at login**: a new toggle in Settings registers the app with the
system's login items (`SMAppService`); the registration survives reinstalls.

## 改进 / Improvements

- **5 小时额度窗口现在显示具体重置钟点**，格式如「3 小时 20 分后重置 · 16:35」，
  倒计时和绝对时间都能看到。副行（例如周额度模式下方的 5 小时）同样显示，
  且文字左对齐。
- **DeepSeek 卡片底部新增「前往 API 平台」按钮**，点击直接在浏览器打开
  platform.deepseek.com 创建或管理 API Key。
- Kimi 适配其 5 小时计时的调整，重置时间解析保持兼容。

**Quota windows under 24 hours now show the absolute reset time** (e.g.
"Resets in 3h 20m · 4:35 PM") — including on secondary rows such as the 5-hour
line in weekly mode, left-aligned. The DeepSeek card gained an always-visible
button that opens platform.deepseek.com.

## 修复 / Fixes

- 修复设置面板「开机自启」开关在网格中丢失引用导致不可达的问题。

安装方式：打开 DMG，将 `Quota Bar.app` 拖入 Applications。首次打开若被 macOS
拦截，请在"系统设置 → 隐私与安全性"中允许打开。本版本为 ad-hoc 签名。

---

# Quota Bar 1.3.0

## 浮窗 / Panel

- 浮窗现在可以拖到屏幕最上边和最左边，靠近边缘会自动贴齐；不再被菜单栏挡住。
- 浮窗可以直接拖拽边缘调整宽高，位置和尺寸会分别记住；设置里有“恢复默认大小与位置”。
- 修好了单行模式上下留白不均的问题（标题栏安全区把内容整体顶了下去）。
- 标准视图改成自适应网格，模型多的时候会自动换行，不再挤成一行。

The panel can now be dragged flush to the top and left edges of the display and
snaps to them, can be resized by dragging any edge (position and size are
remembered separately), and the one-line bar is finally centred vertically —
the titlebar safe area had been pushing its content down. The standard view uses
an adaptive grid so extra services wrap instead of squeezing into one row.

## 模型 / Providers

- 新增 **Grok** 与 **Gemini**。Gemini 读取本地 CLI 日志，按免费层每日 1000 次请求
  折算余量；Grok 显示本机工作状态与所用模型（xAI 未公开额度接口）。
- 升级到本版本时新服务默认隐藏，在“模型管理”里打开即可。
- 全部服务换成真正的品牌标识（矢量绘制，不是 SF Symbol）：OpenAI 花结、Anthropic
  星芒、Kimi 月牙、DeepSeek 鲸鱼、xAI 的 X、Gemini 四角星。

Adds **Grok** and **Gemini**, and replaces the SF Symbol placeholders with real
vector brand marks for every service. New providers stay hidden on upgrade until
you turn them on in Model management.

## 修复 / Fixes

- **卡片现在按所选额度窗口显示。** 之前大数字取的是服务返回的第一个窗口，Kimi 先返回
  周额度，于是卡片顶部显示 7 天、底部显示 5 小时，和顶部栏对不上。现在所有窗口按时长
  排序，大数字始终是你在“摘要显示”里选的那个。
- 顶部栏对只有单一窗口的服务（如 Gemini 的每日额度）不再显示 “—”。
- 版本号统一从 Info.plist 读取，不再散落在三个网络客户端里。

**Provider cards now follow the selected quota window.** They used to show
whichever window the service happened to return first — Kimi returns the weekly
one first, so cards showed 7 days on top and 5 hours underneath while the menu
bar showed something else.

## 新增 / New

- **低额度提醒**：可设 5/10/20/30%，低于阈值时卡片、单行和菜单栏图标一起变色。
- **HUD 外接屏**：把额度推送到备用手机或 ESP32。开关在设置里，代码全部在
  [`HUD/`](HUD/) 目录，含内嵌网页、只读 HTTP 接口和 ESP32 + SSD1306 固件。
  只读、只在局域网、带令牌校验，不会产生任何额外的模型调用。

**HUD display**: serve the same numbers to a spare phone or an ESP32. Read-only,
LAN-only, token-protected, and no extra model calls. Everything lives in
[`HUD/`](HUD/).

---

# Quota Bar v1.2.6

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the scrolling menu bar text appearing black after the Core Animation marquee update.
- The marquee now uses high-contrast white text to match adjacent macOS menu bar items.
- Added a subtle dark shadow so the quota text stays readable over colored and brighter menu bar backgrounds.
- Scrolling remains a local animation and never triggers quota refreshes or model requests.

---

# Quota Bar v1.2.5

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the marquee disappearing after the first providers because `NSTextField` clipped the repeated offscreen text.
- Replaced the marquee renderer with a full Core Animation text layer.
- The complete summary is rendered twice and moves by exactly one copy, creating a seamless first-to-last infinite loop.
- The status item and gauge icon remain fixed; only the text inside the fixed-width viewport moves.
- The animation uses already loaded text and never triggers a quota refresh or model request.

---

# Quota Bar v1.2.4

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the scrolling menu bar summary so the status item and gauge icon stay fixed while only the text moves.
- Ensured the complete Codex, Claude, Kimi, and DeepSeek summary is rendered as one unbroken line.
- Increased the marquee speed so every visible provider passes through within at most 12 seconds per cycle.
- The animation uses only already loaded text and never triggers quota refreshes or model requests.
- Made DMG packaging resilient when Finder briefly keeps the temporary image busy.

---

# Quota Bar v1.2.3

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the scrolling menu bar summary so the status item and gauge icon stay fixed while only the text moves.
- Ensured the complete Codex, Claude, Kimi, and DeepSeek summary is rendered as one unbroken line.
- Increased the marquee speed so every visible provider passes through within at most 12 seconds per cycle.
- The animation still uses only already loaded text and never triggers quota refreshes or model requests.

---

# Quota Bar v1.2.2

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Added an automatic menu bar display mode: full quota text on wide screens and a continuous left-scrolling marquee on smaller screens.
- Added explicit Full and Scroll display choices in Settings.
- The marquee animates only the already loaded quota text and never triggers a quota refresh or model request.
- Removed the unsupported Kimi Open Platform voucher/cash balance API, API-key controls, network request, and card content.
- Kimi Code quota and local work status remain available.

---

# Quota Bar v1.2.1

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Fixed the DMG Finder layout when hidden files are visible.
- Removed the generated `.fseventsd` directory before finalizing the image.
- Moved required hidden support items outside the visible icon area.
- Kept the real Quota Bar app and Applications shortcut aligned with the installer background.
- Changed all installer-background copy to white for clear contrast.
- On smaller screens, the menu bar rotates through one full model name and quota at a time.
- Added the global `⌥⌘Q` shortcut so the floating panel remains reachable when macOS hides the menu bar item.

---

# Quota Bar v1.2.0

> **Installation notice:** This community build is ad-hoc signed and has not been notarized by Apple. Download it only from this repository and verify `SHA256SUMS.txt`.
>
> On first launch, try opening Quota Bar once, then open **System Settings → Privacy & Security**, scroll down to **Security**, click **Open Anyway**, and confirm **Open**. macOS may ask for your login password. See [Apple's instructions](https://support.apple.com/102445).

- Codex quota now comes from the signed-in account's read-only rate-limit endpoint, so the same account shows current quota on multiple Macs without making a model call.
- Claude Desktop quota is read from its local plan-usage history; sending a message in Claude Desktop is no longer required for Quota Bar integration.
- Added the new Quota Bar app icon and a polished drag-to-Applications DMG.
- Added a live menu-bar quota summary with 5-hour/weekly switching, left-click panel restore, right-click actions, a rounded one-line panel, and familiar red/yellow/green macOS window controls.
- Added DeepSeek account balance through the official read-only `/user/balance` endpoint, with its API key stored in macOS Keychain.
- Added persistent provider ordering and per-provider show/hide controls across cards, one-line mode, and the menu bar.
- Simplified the floating panel header, improved contrast on light backgrounds, and made a menu-bar left click toggle the panel.
- Menu-bar summaries now use full provider names; panel layout is controlled directly from the panel instead of Settings.
- Added optional Kimi Open Platform voucher/cash balance display through its read-only balance endpoint.
- Fixed scheduled refreshes cancelling themselves, which prevented DeepSeek from updating until a manual refresh.
- Added per-provider refresh pause, longer presets, a 24-hour custom maximum, flush-top panel positioning, and a wider four-provider layout.
- Added Developer ID hardened-runtime signing, Apple notarization, ticket stapling, and Gatekeeper verification to the release pipeline.
- Kept task/activity detection local to each Mac for privacy. Quota is account-level; work state is device-level.

---

# Quota Bar 1.1.1

- 刷新设置新增可编辑的自定义间隔，范围为 10–3600 秒。
- Claude status-line 采集器会自动更新到当前 App 的实际路径，解决移动或重新安装 App 后缓存不再更新的问题。
- 移除 Claude status line 自身的固定 30 秒刷新，改为事件触发，降低空闲资源消耗。
- Claude 卡片增加失效命令链接和未返回额度字段的明确诊断。
- Claude 重置时间兼容秒、毫秒时间戳与 ISO 8601 格式。
- 新会话尚未返回额度字段时保留最近一次官方额度快照，不再把卡片清空。
- 保持零模型调用：额度和状态展示不会发送测试提示词。

安装方式：打开 DMG，将 `Quota Bar.app` 拖入 Applications。首次打开若被 macOS 拦截，请在“系统设置 → 隐私与安全性”中允许打开。

---

