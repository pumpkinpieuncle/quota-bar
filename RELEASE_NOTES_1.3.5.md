Quota Bar 1.3.5

## 修复 / Fixes

- 修复启动后弹出空白“Quota Bar 设置”窗口的问题：移除空的 SwiftUI 设置场景，改由 AppKit 直接启动已有浮窗。
- 设置仍通过浮窗上的齿轮按钮打开；保留退出、撤销、重做、剪切、复制、粘贴和全选快捷键。

- Fixed the blank “Quota Bar Settings” window appearing on launch by starting the existing panel directly through AppKit instead of an empty SwiftUI Settings scene.
- Settings remain available from the panel's gear button, with standard quit and editing shortcuts preserved.

## 验证 / Validation

- 30 项测试通过。
- 已验证启动、设置与模型管理界面、隐藏浮窗、再次打开应用恢复，以及 ⌥⌘Q 快捷键恢复。

- All 30 tests passed.
- Verified startup, Settings and Model Management, hiding and reopening the panel, and restoration with ⌥⌘Q.

已安装的用户可通过菜单栏右键“检查更新”升级，也可下载 DMG 安装；ZIP 用于应用内自动更新。安装包沿用现有的 ad-hoc 签名方式，未经过 Apple 公证。

Existing users can update through “Check for updates” in the menu bar's right-click menu or install the DMG. The ZIP supports the built-in updater. Packages use the existing ad-hoc signing setup and are not notarized by Apple.
