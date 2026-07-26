# Quota Bar

一个轻量、原生的 macOS 菜单栏浮窗，用来查看 Codex、Claude Desktop / Code、Kimi Code 的剩余额度与当前工作状态。

A lightweight native macOS floating panel for Codex, Claude Code, and Kimi Code quotas and work status.

## 功能 / Features

- 同屏展示三个工具的额度窗口和重置时间。
- 状态包括：等你审批、当牛马中、思考中、摸鱼中、未运行、需处理。
- 智能刷新默认在工作中每 30 秒检查一次，全部空闲时降到每 5 分钟。
- 可选每 30 秒、1 分钟、5 分钟、自定义 10–3600 秒，或完全手动刷新。
- 中文与 English 即时切换。
- 菜单栏常驻、跨桌面置顶、无需打开浏览器。

## 零模型调用原则 / Zero model calls

Quota Bar **不会为了显示状态而消耗 Codex、Claude 或 Kimi 的模型额度**：

- Codex：通过官方 Codex app-server 的 `account/rateLimits/read` 读取当前登录账号的额度，并读取本地事件和任务进程判断工作状态。该接口不会生成模型回复。
- Claude Desktop：只读它维护的本地 `plan-usage-history.json`；Claude Code 使用官方 status line 与 **command hooks**。不会使用 prompt/agent hooks，也不会给 Claude 发送测试提示词。
- Kimi：读取本地会话事件；额度只通过 Kimi Code 官方 `/usages` HTTP 端点同步，它不是模型生成请求。智能模式在 Kimi 空闲时复用本地缓存。
- 不包含模型 SDK、遥测或第三方分析。

额度与工作状态采用不同边界：Codex 额度是账号级数据，同账号登录多台 Mac 时会各自从服务端刷新；“等你审批 / 当牛马中 / 摸鱼中”等状态只描述本机，不上传也不跨设备同步。

## 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon

v1.2.0 起的正式 Release 使用 Developer ID 签名、Apple 公证并装订票据，可直接通过 Gatekeeper 验证。源码本地构建在没有 Developer ID 证书时仍会退回 ad-hoc 签名，仅适合本机测试。

## 安装

从 [Releases](https://github.com/pumpkinpieuncle/quota-bar/releases) 下载 DMG，将 `Quota Bar.app` 拖入 Applications。

也可以从源码构建：

```bash
chmod +x scripts/*.sh
./scripts/build-app.sh
open "dist/Quota Bar.app"
```

安装到 `/Applications`：

```bash
./scripts/install-app.sh
```

旧的 `/Applications/Quota Bar.app` 会备份到 `dist/Quota Bar.previous.app`。

## Claude 额度与状态采集

Claude Desktop 安装后，Quota Bar 会自动读取它的本地套餐使用历史并显示 5 小时/7 天剩余额度。Claude Desktop 当前不会把精确重置时间写入本地历史，因此重置时间会在可由历史变化推断或 Claude Code status line 已提供时显示。

首次打开时，Claude 卡片会显示“启用零额度采集”。点击后，Quota Bar 会：

1. 备份现有的 `~/.claude/settings.json`；
2. 将应用内的 `QuotaBarCapture` 配置为 Claude 官方 status line；
3. 添加纯本地 command hooks，监听审批、工作、停止和空闲事件；
4. 只缓存模型名、rate limits、工作目录、会话 ID 和事件名，不保存提示词或回复正文。

重启 Claude Code，并完成一次正常请求后即可看到额度。采集不会主动发起 Claude 请求。

Claude 官方仅对 Claude.ai Pro/Max 订阅用户提供 `rate_limits` 字段，而且当前会话需要先完成一次正常 API 响应。Quota Bar 会显示 5 小时/7 天剩余额度与准确的重置时间；如果 status-line 命令路径因移动 App 而失效，再次点击“配置/修复零额度采集”即可更新路径。

如果已配置其他 status line，Quota Bar 不会覆盖它。可以在现有脚本中额外调用：

```bash
/Applications/Quota\ Bar.app/Contents/Helpers/QuotaBarCapture
```

注意：stdin 只能读取一次。已有脚本需要先把 stdin 保存到临时文件，再分别传给原逻辑和 `QuotaBarCapture`。

## 数据与隐私

- Claude/Kimi 的缓存位于 `~/.quotabar/`，权限为仅当前用户可读写。
- Kimi OAuth token 只在内存中发送到 Kimi 官方域名，不写入日志或 Quota Bar 缓存。
- Claude 配置首次修改前会备份为 `~/.claude/settings.json.quotabar-backup`。

## 发布构建

```bash
./scripts/package-release.sh
```

脚本会生成 DMG、ZIP 和 SHA-256 校验文件到 `dist/release/v<version>/`。

正式发布需要钥匙串中的 `Developer ID Application` 证书，以及以下任一公证凭据：

- 本机 `QUOTABAR_NOTARY_PROFILE`（由 `notarytool store-credentials` 创建）；或
- `APPLE_ID`、`APPLE_APP_SPECIFIC_PASSWORD`、`APPLE_TEAM_ID`。

GitHub Actions 使用同名 secrets，并额外需要 base64 编码的 `DEVELOPER_ID_APPLICATION_P12` 与 `DEVELOPER_ID_APPLICATION_PASSWORD`。

## License

[MIT](LICENSE)
