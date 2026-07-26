# Quota Bar

一个轻量、原生的 macOS 菜单栏浮窗，用来查看 Codex、Claude Code、Kimi Code 的剩余额度与当前工作状态。

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

- Codex：只读 `~/.codex/sessions` 已有的 rate-limit 快照、本地事件和任务进程。
- Claude：使用 Claude Code 官方 status line 与 **command hooks**。不会使用 prompt/agent hooks，也不会给 Claude 发送测试提示词。
- Kimi：读取本地会话事件；额度只通过 Kimi Code 官方 `/usages` HTTP 端点同步，它不是模型生成请求。智能模式在 Kimi 空闲时复用本地缓存。
- 不包含模型 SDK、遥测或第三方分析。

状态是本地事件推断：Claude 的审批/停止事件较精确；Codex 和 Kimi 在没有公开审批事件的场景中会采用最近会话事件与进程活跃度判断。

## 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon

Release 中的应用使用 ad-hoc 签名，未经过 Apple 公证。首次打开若被 macOS 拦截，请在“系统设置 → 隐私与安全性”中允许打开。

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

## License

[MIT](LICENSE)
