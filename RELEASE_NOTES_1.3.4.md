Quota Bar 1.3.4

## 新增 / New

• DeepSeek Harness 桌面端凭证自动识别：直接从 DeepSeek Harness 桌面端及 CLI（`~/.dsh/.credentials.yaml`）或环境变量 `DEEPSEEK_API_KEY` 自动发现并读取授权凭据，无需手动输入 API Key 即可同步账户余额。
• DeepSeek 本地客户端与任务会话监控：新增 DeepSeek 本地收集器，自动检测 `/Applications/DeepSeek Harness.app` 运行状态以及本地会话活跃度（工作、空闲、离线）。
• 模型管理面板凭证来源展示：在设置面板中明确标注 DeepSeek 凭据的检测来源（例如「DeepSeek Harness 已授权」）。

DeepSeek Harness auto-discovery: automatically reads credentials from DeepSeek Harness desktop & CLI (`~/.dsh/.credentials.yaml`) and `DEEPSEEK_API_KEY` environment variables without requiring manual API key configuration.
DeepSeek local collector: detects DeepSeek Harness desktop installation and tracks real-time task and session activity states.
Credential origin display: clearly indicates the source of active credentials in Model Management.

## 修复 / Fixes

• 修复服务处于暂停状态且无历史记录时显示为「等待同步账户余额」的文案误导问题。
• 优化钥匙串访问交互，避免后台/无交互环境下弹窗挂起。

Fixed paused providers displaying misleading waiting state when initial cache is empty.
Modernized keychain authentication queries to prevent hanging in non-interactive environments.
