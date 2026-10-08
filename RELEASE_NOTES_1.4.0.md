Quota Bar 1.4.0

## 优化与修复 / Improvements & Fixes

- **图标清晰度与暗色模式高对比重构**：针对深色界面全面提升模型服务商 Logo 的辨识度与视觉清晰度：
  - **Antigravity (Gemini)**：根治 macOS CoreSVG 在紧凑弧线指令下的解析崩溃（此前导致仅渲染出微小单点），改用高精度三次贝塞尔曲线及平滑 Google AI 三色光晕（`#4E88FF` 蓝 ➔ `#8357FF` 紫 ➔ `#FF5D8F` 粉），呈现完美四角星火；
  - **Kimi**：将原低对比度的深藏蓝（`#1B64F2`）升级为暗色模式高饱和电光科技蓝（`#458CFF`），重设视口尺寸消除边缘留白，标志性几何 `K` 字母与轨道星点清晰耀眼；
  - **Codex (OpenAI)**：将低明度的常规祖母绿升级为通透高亮翡翠薄荷绿（`#10D9A0`），六瓣旋转风车轮廓分明；
  - **DeepSeek**：修复 SVG 弧线参数间隙引起的解析警报，优化视口比例扩大蓝鲸图标可视面积，升级为高饱和海豚蓝（`#4D82FE`）；
  - **Claude**：采用高亮暖赤陶色（`#F27A59`），多角星火更加鲜明；
  - **Grok**：保持高清晰纯白（`#FFFFFF`）极简环带徽标。
- **Logo 容器与圆角边框高级感打磨**：
  - 卡片头部 Logo 尺寸由 14pt 放大至 16pt，容器微扩至 25x25pt；
  - 容器外框追加匹配品牌的半透明高质感精致描边（`.stroke(accent.opacity(0.28))`），彻底杜绝原先暗色方块与深色卡片混为一体的视觉沉陷感。
- **紧凑模式与设置面板图标同步放大**：紧凑菜单栏模式由 12pt 提升至 13.5pt，设置面板列表图标提升至 14.5pt~15pt。

- **High-Contrast Brand Icon Overhaul for Dark UI**:
  - **Antigravity (Gemini)**: Eliminated CoreSVG parser failure that resulted in an invisible 7-pixel dot; now renders a full, luminous 4-point sparkle star with Google's multi-stop AI spectrum gradient (`#4E88FF` ➔ `#8357FF` ➔ `#FF5D8F`).
  - **Kimi**: Upgraded the dark navy hue (`#1B64F2`) to high-luminance electric blue (`#458CFF`) and re-centered viewport geometry for maximum visual punch.
  - **Codex (OpenAI)**: Brightened rosette knot to vibrant emerald mint (`#10D9A0`), ensuring sharp petal definition against dark cards.
  - **DeepSeek**: Fixed compressed arc parameter bug in CoreSVG, enlarged whale silhouette and tuned to bright ocean blue (`#4D82FE`).
  - **Claude**: Enhanced terracotta starburst to luminous `#F27A59`.
  - **Tile squircle framing**: Enlarged card header logo from 14pt to 16pt in 25x25pt tiles and added a refined colored border stroke (`accent.opacity(0.28)`).

## 验证 / Validation

- 36 项自动化测试全量通过（包含并发安全校验）。
- 6 款品牌图标在深色卡片背景下色彩对比度与细节均达到高清晰度标准。
- macOS CoreSVG 零警告零报错，矢量解析渲染平滑。

已安装的用户可通过菜单栏右键“检查更新”升级，也可下载 DMG 安装；ZIP 用于应用内自动更新。安装包沿用现有的 ad-hoc 签名方式，未经过 Apple 公证。

Existing users can update through “Check for updates” in the menu bar's right-click menu or install the DMG. The ZIP supports the built-in updater. Packages use the existing ad-hoc signing setup and are not notarized by Apple.
