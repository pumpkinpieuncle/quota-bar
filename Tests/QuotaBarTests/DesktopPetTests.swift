import AppKit
import Foundation
import SwiftUI
import Testing
@testable import QuotaBar

@Test func petSpeechUsesExistingQuotaAndBalances() {
    var snapshot = ProviderSnapshot.placeholder(.codex)
    snapshot.activity = .waitingApproval
    snapshot.limits = [
        LimitWindow(id: "short", label: "5h", remainingPercent: 72, resetAt: nil, windowMinutes: 300),
        LimitWindow(id: "week", label: "Weekly", remainingPercent: 41, resetAt: Date(timeIntervalSince1970: 1800000000), windowMinutes: 10080),
        LimitWindow(id: "month", label: "Monthly", remainingPercent: 90, resetAt: nil, windowMinutes: 43200),
        LimitWindow(id: "extra", label: "Other", remainingPercent: 13, resetAt: nil)
    ]
    let content = PetSpeechContent(snapshot: snapshot, preference: .weekly, language: .chinese)
    #expect(content.limits.first == snapshot.limits[1])
    #expect(content.limits.count == 3)
    #expect(content.extraLimitCount == 1)
    #expect(content.greeting.contains("确认"))
    snapshot.limits = []
    snapshot.balances = [AccountBalance(currency: "CNY", total: 12.5, granted: 0, toppedUp: 12.5)]
    let balance = PetSpeechContent(snapshot: snapshot, preference: .fiveHour, language: .english)
    #expect(balance.limits.isEmpty)
    #expect(balance.balances == snapshot.balances)
    let missing = PetSpeechContent(snapshot: .placeholder(.kimi), preference: .weekly, language: .chinese)
    #expect(missing.limits.isEmpty && missing.balances.isEmpty)
}

@MainActor
@Test func desktopPetWindowsOpenAndCloseIndependently() async throws {
    _ = NSApplication.shared
    let suite = "QuotaBarPetWindows.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AppPreferences(defaults: defaults)
    let model = AppModel(preferences: preferences)
    let controller = DesktopPetController(model: model)
    let originalKeyWindow = NSApp.keyWindow
    preferences.desktopPets = [.deepseek, .claude]
    try await Task.sleep(for: .milliseconds(250))

    func petWindows() -> [NSWindow] {
        NSApp.windows.filter { $0.title.hasSuffix(" · Quota Bar") && $0.isVisible }
    }
    #expect(Set(petWindows().map(\.title)) == ["DeepSeek · Quota Bar", "Claude · Quota Bar"])
    #expect(NSApp.keyWindow === originalKeyWindow)
    let deepSeekWindow = try #require(petWindows().first { $0.title == "DeepSeek · Quota Bar" })
    let claudeWindow = try #require(petWindows().first { $0.title == "Claude · Quota Bar" })
    let claudeOrigin = claudeWindow.frame.origin
    let movedOrigin = CGPoint(x: deepSeekWindow.frame.minX + 20, y: deepSeekWindow.frame.minY + 20)
    deepSeekWindow.setFrameOrigin(movedOrigin)
    #expect(preferences.savedPetOrigin(for: .deepseek) == movedOrigin)
    #expect(claudeWindow.frame.origin == claudeOrigin)

    var snapshot = ProviderSnapshot.placeholder(.claude)
    snapshot.activity = .working
    snapshot.limits = [
        LimitWindow(id: "five", label: "5 小时", remainingPercent: 72, resetAt: Date().addingTimeInterval(3600), windowMinutes: 300),
        LimitWindow(id: "week", label: "周额度", remainingPercent: 41, resetAt: Date().addingTimeInterval(86400), windowMinutes: 10080)
    ]
    snapshot.detail = "本地工作状态与额度已同步"
    snapshot.lastUpdated = Date()
    model.snapshots = [snapshot]
    controller.setSpeechVisible(true, for: .claude)
    try await Task.sleep(for: .milliseconds(150))
    let bubble = try #require(NSApp.windows.first { $0.title == "Claude · Quota details" && $0.isVisible })
    #expect(NSApp.keyWindow === originalKeyWindow)
    #expect(bubble.ignoresMouseEvents)
    #expect(bubble.frame.height > 200)
    if let screen = claudeWindow.screen {
        #expect(screen.visibleFrame.contains(bubble.frame))
        claudeWindow.setFrameOrigin(CGPoint(x: screen.visibleFrame.minX, y: screen.visibleFrame.maxY - claudeWindow.frame.height))
        #expect(screen.visibleFrame.contains(bubble.frame))
        #expect(bubble.frame.maxY <= claudeWindow.frame.minY + 20)
        claudeWindow.setFrameOrigin(claudeOrigin)
    }

    if let directory = ProcessInfo.processInfo.environment["QUOTABAR_PET_PREVIEW_DIR"] {
        let destination = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for window in petWindows() + [bubble] {
            if let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try bitmap.representation(using: .png, properties: [:])?.write(to: destination.appendingPathComponent("\(window.title).png"))
            }
        }
        preferences.hiddenProviders = []
        preferences.desktopPets = Set(ProviderID.allCases)
        let panel = NSPanel(contentRect: CGRect(x: 60, y: 250, width: 1100, height: 360), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.appearance = NSAppearance(named: .darkAqua)
        let host = NSHostingView(rootView: ContentView(model: model))
        host.sizingOptions = []
        panel.contentView = host
        panel.orderFrontRegardless()
        try await Task.sleep(for: .milliseconds(250))
        if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: destination.appendingPathComponent("quota-bar-pet-buttons.png"))
        }
        preferences.panelLayout = .compact
        panel.setContentSize(CGSize(width: 1100, height: 68))
        try await Task.sleep(for: .milliseconds(150))
        if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
            host.cacheDisplay(in: host.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])?.write(to: destination.appendingPathComponent("quota-bar-compact-pet-buttons.png"))
        }
        panel.close()
        preferences.desktopPets = [.deepseek, .claude]
        try await Task.sleep(for: .milliseconds(100))
    }

    preferences.toggleDesktopPet(.deepseek)
    try await Task.sleep(for: .milliseconds(100))
    #expect(petWindows().map(\.title) == ["Claude · Quota Bar"])
    preferences.toggleDesktopPet(.claude)
    try await Task.sleep(for: .milliseconds(100))
    #expect(petWindows().isEmpty)
    #expect(!bubble.isVisible)
    withExtendedLifetime(controller) {}
}

@MainActor
@Test func desktopPetVisibilityIsIndependentAndPersists() throws {
    let suite = "QuotaBarPetTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AppPreferences(defaults: defaults)
    #expect(preferences.desktopPets.isEmpty)

    preferences.toggleDesktopPet(.deepseek)
    preferences.toggleDesktopPet(.claude)
    // Hidden providers can still have pets, and changing card visibility does
    // not tear down either of the independent companions.
    preferences.setProvider(.claude, hidden: true)
    #expect(preferences.desktopPets == [.deepseek, .claude])
    preferences.toggleDesktopPet(.deepseek)
    #expect(preferences.desktopPets == [.claude])
    preferences.setPetOrigin(CGPoint(x: 120, y: 80), for: .claude)
    preferences.setPetOrigin(CGPoint(x: -900, y: 200), for: .deepseek)

    let relaunched = AppPreferences(defaults: defaults)
    #expect(relaunched.desktopPets == [.claude])
    #expect(relaunched.savedPetOrigin(for: .claude) == CGPoint(x: 120, y: 80))
    #expect(relaunched.savedPetOrigin(for: .deepseek) == CGPoint(x: -900, y: 200))
}

@MainActor
@Test func desktopPetsStayReachableWhenDisplaysChange() {
    let primary = CGRect(x: 0, y: 40, width: 1440, height: 860)
    let secondary = CGRect(x: -1440, y: 40, width: 1440, height: 860)
    let size = DesktopPetController.windowSize
    let original = CGPoint(x: -1000, y: 200)
    #expect(DesktopPetController.visibleOrigin(original, size: size, screens: [primary, secondary]) == original)
    let recovered = DesktopPetController.visibleOrigin(original, size: size, screens: [primary])
    #expect(primary.contains(CGRect(origin: recovered, size: size)))
    let bottomRight = DesktopPetController.visibleOrigin(CGPoint(x: 1400, y: -20), size: size, screens: [primary])
    #expect(primary.contains(CGRect(origin: bottomRight, size: size)))
}

@MainActor
@Test func desktopPetResourcesIncludeEveryProviderAndDeepSeekState() throws {
    for provider in ProviderID.allCases {
        let artwork = try #require(PetArtwork.load(provider: provider, activity: .idle), "Missing artwork for \(provider)")
        #expect(artwork.image.size.width > 0)
        for animation in Set([PetAnimation.idle, .working, .waiting, .attention] + PetAnimation.leisure(for: provider)) {
            let action = try #require(PetArtwork.load(provider: provider, animation: animation), "Missing \(provider) / \(animation)")
            #expect(action.frameCount > 1)
            #expect(Set(action.frames).count > 1)
            #expect(action.frames.allSatisfy { $0 >= 0 && $0 < action.columns * action.rows })
            #expect(action.frameDurations.count == action.frames.count)
            #expect(action.frameIndex(at: 0) == action.frames[0])
            #expect(action.frameIndex(at: action.frameDurations[0] + 0.001) == action.frames[1])
        }
    }
    for activity: ActivityState in [.idle, .thinking, .working, .waitingApproval, .needsAttention, .offline] {
        let artwork = try #require(PetArtwork.load(provider: .deepseek, activity: activity))
        #expect(artwork.frameCount > 1)
        #expect(artwork.frameCount <= artwork.columns * artwork.rows)
        #expect(artwork.image.size.width / Double(artwork.columns) == 192)
        #expect(artwork.image.size.height / Double(artwork.rows) == 180)
    }
}
