import Foundation
import AppKit
import Testing
@testable import QuotaBar
@testable import QuotaBarHUD

@Test func windowLabels() {
    #expect(LocalCollectors.windowLabel(minutes: 300) == "5 小时")
    #expect(LocalCollectors.windowLabel(minutes: 10_080) == "7 天")
    #expect(LocalCollectors.windowLabel(minutes: 120) == "2 小时")
}

@Test func compactTokenCounts() {
    #expect(LocalCollectors.compactNumber(999) == "999")
    #expect(LocalCollectors.compactNumber(1_200) == "1.2K")
    #expect(LocalCollectors.compactNumber(2_500_000) == "2.5M")
}

@Test func activityLabelsAreBilingual() {
    #expect(ActivityState.waitingApproval.label(language: .chinese) == "等你审批")
    #expect(ActivityState.working.label(language: .chinese) == "当牛马中")
    #expect(ActivityState.idle.label(language: .chinese) == "摸鱼中")
    #expect(ActivityState.waitingApproval.label(language: .english) == "Awaiting approval")
    #expect(ActivityState.working.label(language: .english) == "Working")
    #expect(ActivityState.idle.label(language: .english) == "Idle")
}

@Test func smartRefreshSlowsDownWhenIdle() {
    #expect(RefreshMode.smart.interval(hasActiveProvider: true) == 30)
    #expect(RefreshMode.smart.interval(hasActiveProvider: false) == 300)
    #expect(RefreshMode.oneMinute.interval(hasActiveProvider: false) == 60)
    #expect(RefreshMode.manual.interval(hasActiveProvider: true) == nil)
    #expect(RefreshMode.custom.interval(
        hasActiveProvider: false,
        customSeconds: 95
    ) == 95)
    #expect(RefreshMode.custom.interval(
        hasActiveProvider: false,
        customSeconds: 1
    ) == 10)
    #expect(RefreshMode.oneHour.interval(hasActiveProvider: false) == 3_600)
    #expect(RefreshMode.sixHours.interval(hasActiveProvider: false) == 21_600)
    #expect(RefreshMode.custom.interval(
        hasActiveProvider: false,
        customSeconds: 100_000
    ) == 86_400)
}

@Test func readsClaudeDesktopPlanUsageHistory() throws {
    let payload = """
    {
      "version": 2,
      "samples": [
        {"t": 1785034681232, "org": "org-a", "u": {"fh": 48, "sd": 21}},
        {"t": 1785037081540, "org": "org-a", "u": {"fh": 93, "sd": 25}}
      ]
    }
    """
    let usage = try #require(
        LocalCollectors.claudeDesktopUsage(Data(payload.utf8))
    )
    #expect(usage.limits.count == 2)
    #expect(usage.limits[0].label == "5 小时")
    #expect(usage.limits[0].remainingPercent == 7)
    #expect(usage.limits[1].label == "7 天")
    #expect(usage.limits[1].remainingPercent == 75)
}

@Test func readsCodexAccountRateLimits() throws {
    let payload = """
    {
      "id": 2,
      "result": {
        "rateLimits": {
          "primary": {
            "usedPercent": 61,
            "windowDurationMins": 300,
            "resetsAt": 1785034681
          },
          "secondary": {
            "usedPercent": 18,
            "windowDurationMins": 10080,
            "resetsAt": 1785632632
          },
          "planType": "plus"
        },
        "rateLimitsByLimitId": {
          "codex": {
            "primary": {
              "usedPercent": 61,
              "windowDurationMins": 300,
              "resetsAt": 1785034681
            },
            "secondary": {
              "usedPercent": 18,
              "windowDurationMins": 10080,
              "resetsAt": 1785632632
            },
            "planType": "plus"
          }
        }
      }
    }
    """
    let usage = try CodexUsageClient.parseResponse(
        Data(payload.utf8),
        fetchedAt: Date(timeIntervalSince1970: 1785034682)
    )
    #expect(usage.plan == "Plus")
    #expect(usage.limits.count == 2)
    #expect(usage.limits[0].label == "5 小时")
    #expect(usage.limits[0].remainingPercent == 39)
    #expect(usage.limits[1].label == "7 天")
    #expect(usage.limits[1].remainingPercent == 82)
    #expect(usage.limits[1].resetAt == Date(timeIntervalSince1970: 1785632632))

    let english = try CodexUsageClient.parseResponse(
        Data(payload.utf8),
        language: .english
    )
    #expect(english.limits[0].label == "5 hours")
    #expect(english.limits[1].label == "7 days")
}

@Test func menuBarShowsAllProviderQuotas() {
    let providers: [ProviderID] = [.codex, .claude, .kimi]
    var snapshots = providers.enumerated().map { index, provider in
        ProviderSnapshot(
            id: provider,
            activity: .idle,
            limits: [
                LimitWindow(
                    id: "five-hour",
                    label: "5 小时",
                    remainingPercent: Double([31, 42, 53][index]),
                    resetAt: nil
                ),
                LimitWindow(
                    id: "weekly",
                    label: "7 天",
                    remainingPercent: Double([81, 7, 0][index]),
                    resetAt: nil
                )
            ],
            detail: "",
            source: "",
            lastUpdated: Date(),
            setupAvailable: false,
            isInstalled: true
        )
    }
    snapshots[2].balances = [
        AccountBalance(currency: "CNY", total: 15, granted: 15, toppedUp: 0)
    ]
    #expect(
        MenuBarSummary.text(
            snapshots: snapshots,
            preference: .weekly,
            providers: providers
        )
            == "Codex 81%  Claude 7%  Kimi 0%"
    )
    #expect(
        MenuBarSummary.text(
            snapshots: snapshots,
            preference: .fiveHour,
            providers: providers
        )
            == "Codex 31%  Claude 42%  Kimi 53%"
    )
}

@Test func menuBarDisplayModeControlsScrolling() {
    #expect(
        MenuBarSummary.shouldUseScrolling(
            mode: .automatic,
            screenWidth: 1_440,
            fullSummaryWidth: 240
        )
    )
    #expect(
        !MenuBarSummary.shouldUseScrolling(
            mode: .automatic,
            screenWidth: 2_560,
            fullSummaryWidth: 240
        )
    )
    #expect(
        !MenuBarSummary.shouldUseScrolling(
            mode: .full,
            screenWidth: 1_440,
            fullSummaryWidth: 400
        )
    )
    #expect(
        MenuBarSummary.shouldUseScrolling(
            mode: .scrolling,
            screenWidth: 2_560,
            fullSummaryWidth: 100
        )
    )
}

@MainActor
@Test func menuBarMarqueeUsesContinuousLayerAnimation() {
    let summary = "Codex 60%  Claude 71%  Kimi 0%  DeepSeek ¥5.47"
    let marquee = MenuBarMarqueeView(
        frame: NSRect(x: 0, y: 0, width: 155, height: 24)
    )
    marquee.update(
        text: summary,
        image: nil,
        font: .monospacedSystemFont(ofSize: 11, weight: .semibold)
    )
    #expect(marquee.isAnimating)
    #expect(marquee.renderedText.contains("Codex 60%"))
    #expect(marquee.renderedText.contains("Claude 71%"))
    #expect(marquee.renderedText.contains("Kimi 0%"))
    #expect(marquee.renderedText.contains("DeepSeek ¥5.47"))
    #expect(marquee.renderedText.components(separatedBy: summary).count - 1 == 2)
    #expect(marquee.textContentWidth >= marquee.singleCycleWidth * 2 - 1)
    #expect(marquee.renderedTextColor?.whiteComponent ?? 0 > 0.9)
    #expect(marquee.cycleDuration >= 6)
    #expect(marquee.cycleDuration <= 12)
    marquee.stop()
    #expect(!marquee.isAnimating)
}

@Test func readsDeepSeekBalance() throws {
    let payload = """
    {
      "is_available": true,
      "balance_infos": [
        {
          "currency": "CNY",
          "total_balance": "110.00",
          "granted_balance": "10.00",
          "topped_up_balance": "100.00"
        }
      ]
    }
    """
    let result = try DeepSeekBalanceClient.parseResponse(Data(payload.utf8))
    #expect(result.isAvailable)
    #expect(result.balances.count == 1)
    #expect(result.balances[0].currency == "CNY")
    #expect(result.balances[0].total == Decimal(string: "110.00"))
    #expect(result.balances[0].compactText == "¥110")
}

@Test func normalizesPastedDeepSeekAPIKeys() {
    #expect(
        DeepSeekCredentialStore.normalizedAPIKey("  Bearer sk-test-key\n")
            == "sk-test-key"
    )
    #expect(
        DeepSeekCredentialStore.normalizedAPIKey("\"sk-test-key\"")
            == "sk-test-key"
    )
    #expect(
        DeepSeekCredentialStore.normalizedAPIKey("sk-test key")
            == "sk-testkey"
    )
}

@MainActor
@Test func providerVisibilityAndOrderAreConfigurable() throws {
    let suite = "QuotaBarTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let preferences = AppPreferences(defaults: defaults)
    #expect(preferences.menuBarDisplayMode == .automatic)
    preferences.menuBarDisplayMode = .scrolling
    #expect(
        defaults.string(forKey: "menuBarDisplayMode")
            == MenuBarDisplayMode.scrolling.rawValue
    )
    #expect(preferences.hiddenProviders == ProviderID.optInByDefault)
    preferences.setProvider(.deepseek, hidden: false)
    #expect(preferences.visibleProviderOrder.contains(.deepseek))

    preferences.moveProvider(.deepseek, offset: -1)
    #expect(
        preferences.providerOrder
            == [.codex, .claude, .deepseek, .kimi, .grok, .gemini]
    )

    preferences.setProvider(.codex, hidden: true)
    preferences.setProvider(.claude, hidden: true)
    preferences.setProvider(.kimi, hidden: true)
    preferences.setProvider(.deepseek, hidden: true)
    #expect(preferences.visibleProviderOrder == [.deepseek])

    preferences.setProvider(.kimi, paused: true)
    #expect(preferences.pausedProviders == [.kimi])
    preferences.setProvider(.kimi, paused: false)
    #expect(preferences.pausedProviders.isEmpty)
}

@MainActor
@Test func newProvidersStayHiddenAfterAnUpgrade() throws {
    let suite = "QuotaBarTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    // An install from before Grok and Gemini existed: DeepSeek hidden, the
    // other three visible, and no record of which providers were known.
    defaults.set(["deepseek"], forKey: "hiddenProviders")

    let preferences = AppPreferences(defaults: defaults)
    #expect(preferences.hiddenProviders == [.deepseek, .grok, .gemini])
    #expect(preferences.visibleProviderOrder == [.codex, .claude, .kimi])

    // A second launch must not re-hide something the user turned on.
    preferences.setProvider(.gemini, hidden: false)
    let relaunched = AppPreferences(defaults: defaults)
    #expect(relaunched.visibleProviderOrder.contains(.gemini))
}

@MainActor
@Test func panelGeometryIsRememberedSeparatelyPerLayout() throws {
    let suite = "QuotaBarTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }

    let preferences = AppPreferences(defaults: defaults)
    #expect(preferences.savedPanelSize(for: .standard) == nil)
    #expect(!preferences.hasCustomPanelSize)

    preferences.setPanelTopLeft(CGPoint(x: 0, y: 900))
    #expect(preferences.savedPanelTopLeft() == CGPoint(x: 0, y: 900))
    // Moving the bar must not count as resizing it, so adding a service can
    // still widen a panel the user never resized.
    #expect(!preferences.hasCustomPanelSize)

    preferences.setPanelSize(CGSize(width: 640, height: 320), for: .standard)
    #expect(preferences.savedPanelSize(for: .standard) == CGSize(width: 640, height: 320))
    #expect(preferences.hasCustomPanelSize)
    // Out-of-range sizes are clamped back into what the layout supports.
    preferences.setPanelSize(CGSize(width: 40, height: 20), for: .compact)
    #expect(preferences.savedPanelSize(for: .compact) == PanelLayoutMode.compact.minSize)

    preferences.resetPanelGeometry()
    #expect(preferences.savedPanelTopLeft() == nil)
    #expect(!preferences.hasCustomPanelSize)
}

@Test func collapsingAndExpandingKeepsTheTopEdgeStill() {
    let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
    let standard = PanelLayoutMode.standard.defaultSize(visibleProviderCount: 6)
    let compact = PanelLayoutMode.compact.defaultSize(visibleProviderCount: 6)

    // Parked against the right edge, top at y = 1000.
    var frame = CGRect(
        x: screen.maxX - standard.width - 24,
        y: 1_000 - standard.height,
        width: standard.width,
        height: standard.height
    )
    let top = frame.maxY
    let right = frame.maxX

    // Toggle several times: neither the top nor the parked edge may drift.
    for step in 0..<6 {
        let size = step.isMultiple(of: 2) ? compact : standard
        frame = PanelGeometry.resized(frame, to: size, onScreen: screen)
        #expect(frame.maxY == top)
        #expect(frame.maxX == right)
        #expect(frame.size == size)
    }

    // A panel on the left half keeps its left edge instead.
    var left = CGRect(x: 0, y: 1_000 - standard.height, width: standard.width, height: standard.height)
    for step in 0..<4 {
        let size = step.isMultiple(of: 2) ? compact : standard
        left = PanelGeometry.resized(left, to: size, onScreen: screen)
        #expect(left.maxY == 1_000)
        #expect(left.minX == 0)
    }
}

@Test func cardsFollowTheSelectedQuotaWindowRegardlessOfProviderOrder() {
    // Kimi hands back the weekly summary first; Codex leads with 5 hours.
    let weeklyFirst = [
        LimitWindow(id: "w", label: "7 天", remainingPercent: 80, resetAt: nil),
        LimitWindow(id: "f", label: "5 小时", remainingPercent: 30, resetAt: nil)
    ]
    #expect(QuotaWindowSelector.ordered(weeklyFirst).map(\.id) == ["f", "w"])

    let fiveHour = QuotaWindowSelector.primary(in: weeklyFirst, preference: .fiveHour)
    #expect(fiveHour?.id == "f")
    #expect(QuotaWindowSelector.secondary(
        in: weeklyFirst,
        preference: .fiveHour
    ).map(\.id) == ["w"])

    let weekly = QuotaWindowSelector.primary(in: weeklyFirst, preference: .weekly)
    #expect(weekly?.id == "w")
    #expect(QuotaWindowSelector.secondary(
        in: weeklyFirst,
        preference: .weekly
    ).map(\.id) == ["f"])

    // A provider that only reports one window still fills the headline.
    let dailyOnly = [
        LimitWindow(
            id: "d",
            label: "1 天",
            remainingPercent: 64,
            resetAt: nil,
            windowMinutes: 1_440
        )
    ]
    #expect(QuotaWindowSelector.primary(in: dailyOnly, preference: .weekly)?.id == "d")
    #expect(QuotaWindowSelector.secondary(in: dailyOnly, preference: .weekly).isEmpty)
}

@Test func windowLengthIsReadFromLabelsWhenNotReported() {
    #expect(LimitWindow.minutes(fromLabel: "5 小时") == 300)
    #expect(LimitWindow.minutes(fromLabel: "5 hours") == 300)
    #expect(LimitWindow.minutes(fromLabel: "7 天") == 10_080)
    #expect(LimitWindow.minutes(fromLabel: "7 days") == 10_080)
    #expect(LimitWindow.minutes(fromLabel: "Weekly") == 10_080)
    #expect(LimitWindow.minutes(fromLabel: "90 分钟") == 90)
    #expect(LimitWindow.minutes(fromLabel: "额度") == .max)
    // An explicit duration always wins over the label.
    #expect(
        LimitWindow(
            id: "x",
            label: "额度",
            remainingPercent: 10,
            resetAt: nil,
            windowMinutes: 300
        ).effectiveMinutes == 300
    )
}

@Test func hudPayloadServesBothJSONAndMicrocontrollerText() throws {
    let payload = HUDPayload(
        version: "1.3.0",
        host: "studio",
        generatedAt: Date(timeIntervalSince1970: 1_785_034_681),
        language: "en",
        quotaWindow: "fiveHour",
        lowQuotaThreshold: 10,
        providers: [
            HUDProvider(
                id: "codex",
                title: "Codex",
                accent: "#5FD4AB",
                state: "working",
                stateLabel: "Working",
                isActive: true,
                headline: "62%",
                percent: 62,
                detail: "Plus · latest session",
                limits: [
                    HUDLimit(
                        label: "5 hours",
                        remainingPercent: 62,
                        resetAt: nil,
                        resetText: "Resets in 2h"
                    )
                ],
                updatedAt: nil
            ),
            HUDProvider(
                id: "deepseek",
                title: "DeepSeek",
                accent: "#59C2F5",
                state: "connected",
                stateLabel: "Connected",
                isActive: false,
                headline: "¥110",
                percent: nil,
                detail: "Account balance ¥110",
                limits: [],
                updatedAt: nil
            )
        ]
    )

    let json = try #require(
        try JSONSerialization.jsonObject(with: payload.jsonData()) as? [String: Any]
    )
    #expect(json["quotaWindow"] as? String == "fiveHour")
    #expect((json["providers"] as? [[String: Any]])?.count == 2)

    let lines = payload.plainText().split(separator: "\n").map(String.init)
    #expect(lines[0] == "# ts=1785034681 window=fiveHour low=10 count=2")
    #expect(lines[1] == "Codex|62|working|62%|Resets in 2h")
    // A balance has no percentage, so the field is left empty rather than faked.
    #expect(lines[2] == "DeepSeek||connected|¥110|")
}

@Test func hudServerParsesRequestTargets() {
    let plain = HUDServer.split(target: "/api/status")
    #expect(plain.path == "/api/status")
    #expect(plain.query.isEmpty)

    let withQuery = HUDServer.split(target: "/api/status?token=abc%20d&pretty=1")
    #expect(withQuery.path == "/api/status")
    #expect(withQuery.query["token"] == "abc d")
    #expect(withQuery.query["pretty"] == "1")
}

@MainActor
@Test func cardGridNeverLeavesAnEmptyColumn() {
    // The default panel width must lay the cards out with no dead space, so
    // the column count is capped at the number of services.
    for count in 1...6 {
        let width = PanelLayoutMode.standard.defaultWidth(visibleProviderCount: count)
        let available = width - 28  // the panel's horizontal padding
        #expect(
            ContentView.cardColumnCount(availableWidth: available, cardCount: count) == count
        )
    }

    // Narrowing the panel wraps the cards instead of shrinking them forever.
    #expect(ContentView.cardColumnCount(availableWidth: 1_226, cardCount: 6) == 6)
    #expect(ContentView.cardColumnCount(availableWidth: 700, cardCount: 6) == 4)
    #expect(ContentView.cardColumnCount(availableWidth: 340, cardCount: 6) == 2)
    #expect(ContentView.cardColumnCount(availableWidth: 300, cardCount: 6) == 1)
    #expect(ContentView.cardColumnCount(availableWidth: 0, cardCount: 6) == 1)
    #expect(ContentView.cardColumnCount(availableWidth: 1_226, cardCount: 0) == 1)
}
