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
