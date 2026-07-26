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
}
