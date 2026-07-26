import Foundation
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
