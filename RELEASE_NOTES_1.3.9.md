Quota Bar 1.3.9

## 新增与修复 / Highlights & Fixes

- **真实官方品牌矢量 Logo**：全面升级所有支持的模型服务商 Logo 为官方真实权威矢量图标：
  - **OpenAI (Codex)**：采用官方正版祖母绿（`#10A37F`）螺旋风车花瓣结徽标；
  - **Anthropic (Claude)**：采用官方正版赤陶陶土色（`#D97757`）日光星火（Spark）徽标；
  - **Moonshot (Kimi)**：采用官方正版科技蓝（`#1B64F2`）极简几何 `K` 标志；
  - **DeepSeek**：采用官方正版海豚跃浪蓝（`#4D6BFE`）灵动蓝鲸徽标；
  - **xAI (Grok)**：采用官方正版纯白环带徽标；
  - **Google (Gemini)**：采用官方四色微光渐变（`#3186FF` 蓝绿黄红多重流光）四角星火徽标。
- **设置浮窗防透底与半透明遮罩**：修复设置弹窗开启时底层主卡片文字、百分比与进度圆环隐约透出的问题；为设置浮窗采用 100% 实心深黑底色，并在背后叠加高质感暗色遮罩，彻底杜绝文字穿透。
- **设置项「额度窗口」与「顶部栏显示」解耦重构**：将原本挤压在同一卡片内的两个分段选择器独立拆分为两项设置，给予充足布局宽度（`额度窗口` 220px、`顶部栏显示` 130px），彻底修复“5 小时”等标签左侧被挤压截断的排版问题。

- **Official vector brand logos**: fully upgraded all provider icons to their authentic, official vector branding:
  - **OpenAI (Codex)**: authentic emerald green (`#10A37F`) six-petaled rosette knot;
  - **Anthropic (Claude)**: authentic terracotta (`#D97757`) sunburst spark;
  - **Moonshot (Kimi)**: authentic tech blue (`#1B64F2`) geometric `K` symbol;
  - **DeepSeek**: authentic oceanic blue (`#4D6BFE`) leaping whale emblem;
  - **xAI (Grok)**: authentic crisp white ring icon;
  - **Google (Gemini)**: authentic multi-stop gradient sparkle star.
- **Settings overlay opacity & backdrop fix**: resolved background bleed-through where underlying card text and progress rings showed through the settings panel; made the overlay 100% opaque and added a clean dimming backdrop.
- **Refined Quota Window & Menu Bar Display rows**: decoupled quota window and menu bar display into two distinct, spacious setting rows with generous widths, eliminating text clipping on segmented options (such as "5 小时").

## 验证 / Validation

- 36 项自动化测试全量通过。
- 实测 6 款模型官方矢量 Logo 在 12pt、14pt、23pt 及 Retina 屏幕下均清晰纯正。
- 设置弹窗底层文字无任何穿透，分段选择器文字完整舒展。

已安装的用户可通过菜单栏右键“检查更新”升级，也可下载 DMG 安装；ZIP 用于应用内自动更新。安装包沿用现有的 ad-hoc 签名方式，未经过 Apple 公证。

Existing users can update through “Check for updates” in the menu bar's right-click menu or install the DMG. The ZIP supports the built-in updater. Packages use the existing ad-hoc signing setup and are not notarized by Apple.
