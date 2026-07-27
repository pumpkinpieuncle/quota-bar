# Quota Bar HUD

把额度和工作状态送到一块外接屏上：一部闲置手机、一台旧 iPad，或者一块 ESP32 + OLED。

Send quotas and work state to a second screen: a spare phone, an old iPad, or an
ESP32 with a small OLED.

```
HUD/
├── macOS/      # QuotaBarHUD —— 应用内的只读 HTTP 服务（SwiftPM target）
│   ├── HUDPayload.swift     数据结构 + JSON / 纯文本两种输出
│   ├── HUDServer.swift      基于 Network.framework 的极简 HTTP 服务
│   ├── HUDWebPage.swift     内嵌网页
│   └── Resources/hud.html   手机上打开的 HUD 页面
└── esp32/
    └── quota_hud/quota_hud.ino   ESP32 + SSD1306 固件
```

## 设计原则 / Design rules

- **只读**：HUD 只有 `GET`，任何设备都无法改动 Mac 上的设置或触发刷新。
- **不出局域网**：服务只监听本机端口，数据不经过任何第三方服务器。
- **零额外模型调用**：HUD 复用浮窗已经拿到的快照，不会再去请求任何模型接口。
- **令牌保护**：每次访问都要带上 Quota Bar 生成的令牌，随时可以换新。

## 1. 在 Mac 上打开 HUD

1. 打开 Quota Bar 浮窗 → 齿轮图标 → **HUD 外接屏 / HUD display**；
2. 打开开关。默认端口 `7425`，勾选“允许局域网访问”后同一 Wi-Fi 的设备才能连上；
3. 面板会显示形如下面的网址，点“复制网址”：

```
http://192.168.1.20:7425/?token=k7m2q9xr4b3d
```

> 首次开启时 macOS 可能会询问是否允许 Quota Bar 接受传入连接，选择“允许”。
> 如果端口被占用，面板会直接显示失败原因，换一个端口即可。

## 2. 备用手机 / 平板

在手机浏览器里打开上面的网址即可，页面会：

- 每 5 秒拉取一次数据（`?every=10` 可改成 10 秒）；
- 自适应竖屏、横屏和小屏，卡片会自动换行；
- 低于阈值的额度整张卡片变红；
- 提供“Keep awake”按钮（Wake Lock），让屏幕常亮；
- 断线时保留最后一次数据，并把右上角的小圆点从绿变黄再变红。

想常驻的话：iOS Safari →「分享」→「添加到主屏幕」，即可全屏运行，没有地址栏。

令牌只需要输入一次，之后存在浏览器本地；换了令牌就在页面里重新填一次。

## 3. ESP32 + OLED

固件在 [`esp32/quota_hud/quota_hud.ino`](esp32/quota_hud/quota_hud.ino)。

**需要的东西**

| 项目 | 说明 |
| --- | --- |
| 开发板 | 任意 ESP32（ESP32-WROOM / ESP32-C3 均可） |
| 屏幕 | SSD1306 128×64 I²C OLED |
| 库 | Adafruit SSD1306、Adafruit GFX Library |

**接线**

```
OLED VCC -> 3V3      OLED SDA -> GPIO21
OLED GND -> GND      OLED SCL -> GPIO22
```

**烧录步骤**

1. Arduino IDE → 开发板管理器安装 `esp32`，选择 “ESP32 Dev Module”；
2. 库管理器安装 `Adafruit SSD1306` 和 `Adafruit GFX Library`；
3. 打开 `quota_hud.ino`，修改文件顶部的四行配置：

```cpp
static const char *WIFI_SSID = "your-wifi";
static const char *WIFI_PASSWORD = "your-password";
static const char *QUOTA_HOST = "192.168.1.20";   // Mac 的局域网 IP
static const char *QUOTA_TOKEN = "paste-token-here";
```

4. 上传。屏幕会先显示 “Joining Wi-Fi…”，连上之后每 15 秒刷新一次；
5. 超过 3 个服务时会自动翻页；额度低于 `LOW_QUOTA_PERCENT` 的行会闪烁。

如果屏幕一直黑着：多数模块的 I²C 地址是 `0x3C`，少数是 `0x3D`，改
`OLED_ADDRESS` 即可。

## 4. 接口 / API

所有接口都只接受 `GET`，令牌可以放在 `?token=` 或 `X-Quota-Token` 头里。

| 路径 | 用途 |
| --- | --- |
| `/` | HUD 网页，本身不需要令牌 |
| `/api/status` | 完整 JSON（加 `?pretty=1` 便于调试） |
| `/api/hud.txt` | 单行文本，给单片机用 |
| `/healthz` | 存活检查，返回 `ok` |

`/api/status` 示例：

```json
{
  "app": "Quota Bar",
  "version": "1.3.0",
  "host": "studio.local",
  "generatedAt": "2026-07-27T01:38:01Z",
  "language": "zh-Hans",
  "quotaWindow": "fiveHour",
  "lowQuotaThreshold": 10,
  "providers": [
    {
      "id": "codex",
      "title": "Codex",
      "accent": "#5FD4AB",
      "state": "working",
      "stateLabel": "当牛马中",
      "isActive": true,
      "headline": "62%",
      "percent": 62,
      "detail": "Plus · 最近会话 quota-bar",
      "limits": [
        { "label": "5 小时", "remainingPercent": 62, "resetText": "2 小时后重置" }
      ]
    }
  ]
}
```

`/api/hud.txt` 示例，字段为 `名称|百分比|状态|显示值|重置时间`，
没有百分比（例如 DeepSeek 余额）时该字段留空：

```
# ts=1785034681 window=fiveHour low=10 count=2
Codex|62|working|62%|2 小时后重置
DeepSeek||connected|¥110|
```

## 5. 自己写显示端

只要能发 HTTP `GET`，就能做 HUD。几个建议：

- 单片机优先用 `/api/hud.txt`，省掉 JSON 解析和内存；
- 轮询别快过 5 秒，Quota Bar 本身的刷新最快也是 30 秒一次；
- `percent` 为 `null` 时说明这一项是余额而不是百分比，直接显示 `headline`；
- `state` 的取值：`waitingApproval` `working` `thinking` `idle` `offline`
  `needsAttention` `connected`，`stateLabel` 是已经翻译好的文案。
