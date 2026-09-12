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
