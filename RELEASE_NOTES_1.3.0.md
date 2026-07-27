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
