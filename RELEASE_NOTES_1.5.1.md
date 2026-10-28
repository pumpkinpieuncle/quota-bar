Quota Bar 1.5.1 — 模型桌宠 / Desktop pets

## 1.5.1 修复

- 额度气泡改为左键点击显示，再次点击或点击别处收起；鼠标经过不再弹窗，拖动也不会触发。

- 修复 GitHub 构建安装包的桌宠资源查找路径，确保下载后在其他 Mac 上能正确加载全部角色与动作。
- 发布前新增打包应用资源自检，不依赖构建机目录，也不读取账号或钥匙串。
- 本版本替代 v1.5.0；请下载 v1.5.1。

## 新增

- Codex、Claude、Kimi、DeepSeek、Grok、Antigravity 各有独立桌宠。在模型卡片、单行模式或模型管理中点击爪印即可打开，多只可同时显示。
- DeepSeek 接入已安装 DSH 鲸鱼娘的 14 组原版动画；其余五只各有 32 帧、8 组动作，包括眨眼、挥手、思考、阅读、伸懒腰、吃东西、跳舞和打盹。
- 空闲时自动轮换小动作，点击挥手，右键选择动作。工作、思考和等待审批状态会切换对应动作；其余角色采用四个关键姿势，DeepSeek 原版动画帧数更多。
- 左键点击时，桌宠用对话气泡展示现有额度、余额、重置时间、更新时间及工作状态。与主面板共用数据和额度窗口设置，不增加模型调用。
- 拖动可移动位置，重启后恢复；桌宠开关独立于模型卡片和主浮窗。气泡自动避开屏幕边缘，不抢键盘焦点，支持系统“减少动态效果”。

## 验证与发布

- 37 项不依赖真实账号的测试通过，包括动画资源、额度数据、独立窗口、位置恢复和气泡边界检查。
- 已在本机安装验证：六只桌宠显示正常，逐帧动画变化及真实额度气泡均已确认。
- 发布工作流跳过需要本机已登录账号的 `live` 测试，避免 GitHub runner 缺少账号凭据时阻断发布。

## English

- Quota bubbles now open on left click instead of hover. Click again or elsewhere to dismiss; dragging does not open them.
- Fixed resource lookup in packaged SwiftPM builds and added a packaged-app resource smoke check.

- Independent desktop pets for all six providers, available from paw buttons in cards, compact rows, and provider management.
- DeepSeek includes 14 original DSH animations. Each other character has 32 frames across eight actions, with automatic leisure actions, click-to-wave, and a right-click action menu.
- Click-to-toggle speech bubbles reuse actual quota, balance, reset, and activity data from the main panel without making model calls.
- Persistent positions and visibility, screen-edge-aware bubbles, nonactivating windows, and Reduce Motion support.
- 37 offline tests passed, plus installed-app animation and quota-bubble checks. Release CI excludes account-dependent live checks.

## 安装 / Installation

下载 DMG 后拖入 Applications，或使用应用内“检查更新”；ZIP 供自动更新使用。安装包沿用 ad-hoc 签名，未经过 Apple 公证。替换应用后，macOS 可能重新请求访问 DeepSeek 钥匙串，请在系统窗口中自行处理。

Install the DMG or use the built-in updater (ZIP). Packages retain ad-hoc signing and are not Apple-notarized. macOS may ask to authorize access to the existing DeepSeek Keychain item after replacing the app.

角色素材来源、生成记录与第三方署名见 [桌宠文档](https://github.com/pumpkinpieuncle/quota-bar/blob/v1.5.1/docs/desktop-pets.md)。
