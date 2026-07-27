// Quota Bar HUD — ESP32 + SSD1306 (128x64 I2C OLED)
//
// Polls the Mac's HUD endpoint and shows one row per service. It reads the
// line-oriented `/api/hud.txt` feed, so no JSON library is needed and the whole
// sketch fits comfortably on an ESP32.
//
// Libraries (Arduino Library Manager):
//   - Adafruit SSD1306
//   - Adafruit GFX Library
//
// Wiring (any ESP32 dev board):
//   OLED VCC -> 3V3     OLED GND -> GND
//   OLED SDA -> GPIO21  OLED SCL -> GPIO22
//
// Board: "ESP32 Dev Module". See ../README.md for the full walkthrough.

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <Wire.h>

// ---------------------------------------------------------------- settings --

static const char *WIFI_SSID = "your-wifi";
static const char *WIFI_PASSWORD = "your-password";

// Shown in Quota Bar → Settings → HUD display.
static const char *QUOTA_HOST = "192.168.1.20";
static const uint16_t QUOTA_PORT = 7425;
static const char *QUOTA_TOKEN = "paste-token-here";

static const uint32_t POLL_INTERVAL_MS = 15000;  // how often to ask the Mac
static const uint32_t PAGE_INTERVAL_MS = 4000;   // page flip when >3 services
static const int LOW_QUOTA_PERCENT = 10;         // blink the row at or below

// --------------------------------------------------------------- hardware ---

static const uint8_t SCREEN_WIDTH = 128;
static const uint8_t SCREEN_HEIGHT = 64;
static const int8_t OLED_RESET = -1;
static const uint8_t OLED_ADDRESS = 0x3C;  // some modules use 0x3D

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// ------------------------------------------------------------------ state ---

static const uint8_t MAX_SERVICES = 8;
static const uint8_t ROWS_PER_PAGE = 3;

struct Service {
  char name[14];
  char headline[10];
  char state[16];
  char reset[22];
  int percent;  // -1 when the service reports a balance instead
};

static Service services[MAX_SERVICES];
static uint8_t serviceCount = 0;
static uint8_t page = 0;
static bool online = false;
static uint32_t lastPoll = 0;
static uint32_t lastPageFlip = 0;
static uint32_t lastSuccess = 0;

// ----------------------------------------------------------------- helpers --

static void copyField(char *destination, size_t size, const String &value) {
  strncpy(destination, value.c_str(), size - 1);
  destination[size - 1] = '\0';
}

static void showMessage(const char *title, const char *detail) {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 8);
  display.println(title);
  display.setCursor(0, 24);
  display.println(detail);
  display.display();
}

static void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) {
    return;
  }
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  showMessage("Quota Bar HUD", "Joining Wi-Fi...");
  for (int attempt = 0; attempt < 40 && WiFi.status() != WL_CONNECTED; attempt++) {
    delay(250);
  }
}

// Parses one `Name|percent|state|headline|reset` row.
static void parseRow(const String &line) {
  if (serviceCount >= MAX_SERVICES) {
    return;
  }
  Service &service = services[serviceCount];
  int start = 0;
  for (int field = 0; field < 5; field++) {
    int separator = line.indexOf('|', start);
    String value = (separator < 0) ? line.substring(start) : line.substring(start, separator);
    value.trim();
    switch (field) {
      case 0: copyField(service.name, sizeof(service.name), value); break;
      case 1: service.percent = value.length() ? value.toInt() : -1; break;
      case 2: copyField(service.state, sizeof(service.state), value); break;
      case 3: copyField(service.headline, sizeof(service.headline), value); break;
      case 4: copyField(service.reset, sizeof(service.reset), value); break;
    }
    if (separator < 0) {
      // Trailing fields the Mac did not send stay empty.
      for (int rest = field + 1; rest < 5; rest++) {
        if (rest == 1) service.percent = -1;
        if (rest == 2) service.state[0] = '\0';
        if (rest == 3) service.headline[0] = '\0';
        if (rest == 4) service.reset[0] = '\0';
      }
      break;
    }
    start = separator + 1;
  }
  serviceCount++;
}

static bool fetchStatus() {
  if (WiFi.status() != WL_CONNECTED) {
    return false;
  }
  HTTPClient http;
  String url = "http://" + String(QUOTA_HOST) + ":" + String(QUOTA_PORT) +
               "/api/hud.txt?token=" + String(QUOTA_TOKEN);
  http.setConnectTimeout(4000);
  http.setTimeout(5000);
  if (!http.begin(url)) {
    return false;
  }
  int status = http.GET();
  if (status != HTTP_CODE_OK) {
    http.end();
    return false;
  }

  String body = http.getString();
  http.end();

  serviceCount = 0;
  int start = 0;
  while (start < (int)body.length() && serviceCount < MAX_SERVICES) {
    int newline = body.indexOf('\n', start);
    String line = (newline < 0) ? body.substring(start) : body.substring(start, newline);
    line.trim();
    if (line.length() > 0 && line[0] != '#') {
      parseRow(line);
    }
    if (newline < 0) {
      break;
    }
    start = newline + 1;
  }
  return serviceCount > 0;
}

// ------------------------------------------------------------------ render --

static void drawHeader() {
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.print(F("QUOTA BAR"));

  uint8_t pageCount = (serviceCount + ROWS_PER_PAGE - 1) / ROWS_PER_PAGE;
  if (pageCount > 1) {
    display.setCursor(72, 0);
    display.print(page + 1);
    display.print(F("/"));
    display.print(pageCount);
  }

  // Connection dot: filled while fresh, hollow once the feed goes quiet.
  bool fresh = online && (millis() - lastSuccess < POLL_INTERVAL_MS * 3);
  if (fresh) {
    display.fillCircle(123, 3, 3, SSD1306_WHITE);
  } else {
    display.drawCircle(123, 3, 3, SSD1306_WHITE);
  }
  display.drawFastHLine(0, 10, SCREEN_WIDTH, SSD1306_WHITE);
}

static void drawService(const Service &service, int top) {
  bool low = service.percent >= 0 && service.percent <= LOW_QUOTA_PERCENT;
  bool blink = low && ((millis() / 600) % 2 == 0);

  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, top);
  display.print(service.name);

  const char *value = service.headline[0] ? service.headline : "-";
  int valueWidth = strlen(value) * 6;
  display.setCursor(SCREEN_WIDTH - valueWidth, top);
  display.print(value);

  int barTop = top + 10;
  display.drawRect(0, barTop, SCREEN_WIDTH, 5, SSD1306_WHITE);
  if (service.percent >= 0) {
    int width = (SCREEN_WIDTH - 2) * service.percent / 100;
    if (width > 0 && !blink) {
      display.fillRect(1, barTop + 1, width, 3, SSD1306_WHITE);
    }
  } else if (!blink) {
    // No percentage: dashed fill so the row still reads as "reporting".
    for (int x = 1; x < SCREEN_WIDTH - 1; x += 4) {
      display.drawFastVLine(x, barTop + 1, 3, SSD1306_WHITE);
    }
  }
}

static void render() {
  display.clearDisplay();
  drawHeader();

  if (serviceCount == 0) {
    display.setCursor(0, 24);
    display.println(WiFi.status() == WL_CONNECTED ? F("Waiting for Mac...")
                                                  : F("No Wi-Fi"));
    display.setCursor(0, 40);
    display.print(QUOTA_HOST);
    display.print(F(":"));
    display.print(QUOTA_PORT);
    display.display();
    return;
  }

  uint8_t first = page * ROWS_PER_PAGE;
  for (uint8_t offset = 0; offset < ROWS_PER_PAGE; offset++) {
    uint8_t index = first + offset;
    if (index >= serviceCount) {
      break;
    }
    drawService(services[index], 15 + offset * 17);
  }
  display.display();
}

// ------------------------------------------------------------------- main ---

void setup() {
  Serial.begin(115200);
  Wire.begin();
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
    Serial.println(F("SSD1306 not found — check wiring and the I2C address"));
    while (true) {
      delay(1000);
    }
  }
  display.clearDisplay();
  display.display();
  connectWiFi();
  online = fetchStatus();
  if (online) {
    lastSuccess = millis();
  }
  lastPoll = millis();
  render();
}

void loop() {
  uint32_t now = millis();

  if (now - lastPoll >= POLL_INTERVAL_MS) {
    lastPoll = now;
    connectWiFi();
    online = fetchStatus();
    if (online) {
      lastSuccess = now;
    }
    uint8_t pageCount = (serviceCount + ROWS_PER_PAGE - 1) / ROWS_PER_PAGE;
    if (pageCount > 0 && page >= pageCount) {
      page = 0;
    }
  }

  uint8_t pageCount = (serviceCount + ROWS_PER_PAGE - 1) / ROWS_PER_PAGE;
  if (pageCount > 1 && now - lastPageFlip >= PAGE_INTERVAL_MS) {
    lastPageFlip = now;
    page = (page + 1) % pageCount;
  }

  render();
  delay(120);  // keeps the low-quota blink smooth without busy-waiting
}
