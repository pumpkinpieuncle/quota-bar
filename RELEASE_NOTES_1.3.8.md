Quota Bar 1.3.8

## 新增 / New

- **设置界面原生 Segmented Tab 切换栏**：彻底移除原设置弹窗右上角隐蔽晦涩的 `list.bullet` 图标，改用顶部居中 Apple 原生磨砂胶囊 Tab 切换栏（`常规设置` 与 `模型管理`），点击即无缝切换，配备平滑弹簧滑块动效（`matchedGeometryEffect`）与交互反馈；右上角统一保留精简的 `[ ✕ ]` 关闭按钮。
- **模型管理一键直达联动**：在主界面点击卡片操作按钮（如 DeepSeek 卡片的“管理 DeepSeek”）时，直接唤起设置浮窗并自动选中“模型管理”分页，直观明了。
- **模型管理响应式自适应布局**：模型管理在大窗口下自适应左右双栏排版（左侧模型排序/显隐/暂停列表，右侧 DeepSeek 授权卡片），在较窄窗口下自动转换为流式单列纵向排版，保证任何尺寸下均清爽易读。
- **情境化底部状态与指引栏**：根据当前选中的 Tab 动态提供贴合的指引说明（常规设置下提示本地隐私与 ⌥⌘Q 快捷键，模型管理下提示卡片拖拽排序、隐藏、暂停刷新与钥匙串安全存储机制）。

- **Native Segmented Tab switcher in Settings**: replaced the obscure `list.bullet` icon in the settings overlay with an Apple-native frosted capsule tab bar (`General` and `Models`), featuring smooth spring sliding transitions (`matchedGeometryEffect`), hover feedback, and a unified clean close button.
- **Direct model management navigation**: clicking card action buttons (such as "Manage DeepSeek") now opens Settings and navigates directly to the "Models" tab.
- **Adaptive layout for model management**: automatically renders a two-column view in wider panels (model list on left, DeepSeek credential card on right) and gracefully falls back to a single scrollable column in narrower layouts.
- **Context-aware footer tips**: dynamically adapts footer guidance to the active tab (local privacy & ⌥⌘Q shortcut in General; reordering, hiding, pausing, and Keychain security notes in Models).

## 验证 / Validation

- 36 项自动化测试全量通过。
- 经过实际窗口缩放、Tab 快速来回切换及卡片联动验证，动效流畅丝滑。

已安装的用户可通过菜单栏右键“检查更新”升级，也可下载 DMG 安装；ZIP 用于应用内自动更新。安装包沿用现有的 ad-hoc 签名方式，未经过 Apple 公证。

Existing users can update through “Check for updates” in the menu bar's right-click menu or install the DMG. The ZIP supports the built-in updater. Packages use the existing ad-hoc signing setup and are not notarized by Apple.
