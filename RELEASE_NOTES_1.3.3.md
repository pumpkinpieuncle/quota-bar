# Quota Bar 1.3.3

## 新增 / New

- **Antigravity 真实配额实时支持**：直接对接 Antigravity 本地语言服务（Language Server），精准获取并展示 Gemini 模型（Flash/Pro）以及 3P 模型（Claude Opus/Sonnet、GPT-OSS）的 5 小时滑动窗口与 7 天周额度，提供精确到分秒的重置倒计时与本地持久化缓存。
- **Provider 显示升级**：将原 Gemini 模型统一呈现为「Antigravity」，卡片与菜单栏完整支持双窗口配额与第三方模型额度展示。

**Antigravity real-time quota support**: directly interfaces with the local Antigravity Language Server to display real-time 5-hour and 7-day rolling quota windows for both Gemini models and 3P models (Claude & GPT) with exact reset countdowns and persistent local caching.

## 修复 / Fixes

- **Codex 额度读取修复**：适配最新版 ChatGPT.app 与独立 Codex CLI 的二进制安装路径，新增可用性执行校验与超时保护，并支持账户余额与信用额度解析。

**Codex quota fix**: resolved executable path discovery for modern ChatGPT.app and standalone Codex CLI bundles, added execution validation, and restored balance parsing.

安装方式：已安装 1.3.2 的用户可在菜单栏或设置面板中点击「更新到 v1.3.3」一键自动升级，或下载 DMG 手动替换。
