import Foundation
import AppKit
import Testing
@testable import QuotaBar

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
    #expect(preferences.hiddenProviders == [.deepseek])
    preferences.setProvider(.deepseek, hidden: false)
    #expect(preferences.visibleProviderOrder.contains(.deepseek))

    preferences.moveProvider(.deepseek, offset: -1)
    #expect(preferences.providerOrder == [.codex, .claude, .deepseek, .kimi])

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
