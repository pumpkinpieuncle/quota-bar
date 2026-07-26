import AppKit
import Combine
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var panel: FloatingPanel?
    private var hostingView: NSHostingView<ContentView>?
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var toggleMenuItem: NSMenuItem?
    private var refreshMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var quotaWindowMenuItem: NSMenuItem?
    private var fiveHourMenuItem: NSMenuItem?
    private var weeklyMenuItem: NSMenuItem?
    private var quotaMenuItems: [ProviderID: NSMenuItem] = [:]
    private var snapshotObservation: AnyCancellable?
    private var quotaWindowObservation: AnyCancellable?
    private var panelLayoutObservation: AnyCancellable?
    private var providerOrderObservation: AnyCancellable?
    private var hiddenProvidersObservation: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makePanel()
        makeStatusItem()
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func makePanel() {
        let size = NSSize(
            width: model.preferences.panelLayout.panelWidth(
                visibleProviderCount: model.preferences.visibleProviderOrder.count
            ),
            height: model.preferences.panelLayout.panelHeight
        )
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Quota Bar"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        let hostingView = NSHostingView(
            rootView: ContentView(model: model, onHideToMenuBar: { [weak self] in
                self?.collapsePanel()
            })
        )
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 24
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView
        self.hostingView = hostingView

        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            let origin = NSPoint(
                x: visible.maxX - size.width - 24,
                y: visible.maxY - size.height - 24
            )
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }
        panel.orderFrontRegardless()
        self.panel = panel

        panelLayoutObservation = model.preferences.$panelLayout
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                self?.resizePanel(for: mode)
            }
    }

    private func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "gauge.with.dots.needle.67percent",
                accessibilityDescription: "Quota Bar"
            )
            button.imagePosition = .imageLeading
            button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.delegate = self
        let toggle = NSMenuItem(
            title: "",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        for provider in ProviderID.allCases {
            let quota = NSMenuItem(title: provider.title, action: nil, keyEquivalent: "")
            quota.isEnabled = false
            menu.addItem(quota)
            quotaMenuItems[provider] = quota
        }
        menu.addItem(.separator())

        let windowMenu = NSMenu()
        let fiveHour = NSMenuItem(
            title: "",
            action: #selector(showFiveHourQuota),
            keyEquivalent: ""
        )
        fiveHour.target = self
        windowMenu.addItem(fiveHour)
        let weekly = NSMenuItem(
            title: "",
            action: #selector(showWeeklyQuota),
            keyEquivalent: ""
        )
        weekly.target = self
        windowMenu.addItem(weekly)
        let windowParent = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        windowParent.submenu = windowMenu
        menu.addItem(windowParent)
        quotaWindowMenuItem = windowParent
        fiveHourMenuItem = fiveHour
        weeklyMenuItem = weekly

        let refresh = NSMenuItem(
            title: "",
            action: #selector(refreshNow),
            keyEquivalent: "r"
        )
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quit.target = self
        menu.addItem(quit)
        statusMenu = menu
        toggleMenuItem = toggle
        refreshMenuItem = refresh
        quitMenuItem = quit
        updateMenuTitles()
        statusItem = item
        updateStatusItem(snapshots: model.snapshots)
        snapshotObservation = model.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] snapshots in
                self?.updateStatusItem(snapshots: snapshots)
            }
        quotaWindowObservation = model.preferences.$quotaWindow
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusItem(snapshots: self.model.snapshots)
                self.updateMenuTitles()
            }
        providerOrderObservation = model.preferences.$providerOrder
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusItem(snapshots: self.model.snapshots)
                self.updateMenuTitles()
            }
        hiddenProvidersObservation = model.preferences.$hiddenProviders
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusItem(snapshots: self.model.snapshots)
                self.updateMenuTitles()
                self.resizePanel(for: self.model.preferences.panelLayout)
            }
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuTitles()
    }

    private func updateMenuTitles() {
        let language = model.language
        toggleMenuItem?.title = panel?.isVisible == true
            ? language.text("收起到菜单栏", "Collapse to menu bar")
            : language.text("显示浮窗", "Show panel")
        refreshMenuItem?.title = language.text("立即刷新", "Refresh now")
        quitMenuItem?.title = language.text("退出 Quota Bar", "Quit Quota Bar")
        fiveHourMenuItem?.title = language.text("显示 5 小时额度", "Show 5-hour quota")
        weeklyMenuItem?.title = language.text("显示周额度", "Show weekly quota")
        fiveHourMenuItem?.state = model.preferences.quotaWindow == .fiveHour ? .on : .off
        weeklyMenuItem?.state = model.preferences.quotaWindow == .weekly ? .on : .off
        quotaWindowMenuItem?.title = language.text(
            "顶部栏额度",
            "Menu bar quota"
        )
        updateQuotaMenuItems(snapshots: model.snapshots)
    }

    private func updateStatusItem(snapshots: [ProviderSnapshot]) {
        let summary = MenuBarSummary.text(
            snapshots: snapshots,
            preference: model.preferences.quotaWindow,
            providers: model.preferences.visibleProviderOrder
        )
        statusItem?.button?.title = summary
        statusItem?.button?.toolTip = MenuBarSummary.accessibilityText(
            snapshots: snapshots,
            language: model.language,
            preference: model.preferences.quotaWindow,
            providers: model.preferences.visibleProviderOrder
        )
        updateQuotaMenuItems(snapshots: snapshots)
    }

    private func updateQuotaMenuItems(snapshots: [ProviderSnapshot]) {
        if let statusMenu {
            for provider in model.preferences.providerOrder {
                guard let item = quotaMenuItems[provider] else { continue }
                statusMenu.removeItem(item)
            }
            for (offset, provider) in model.preferences.providerOrder.enumerated() {
                guard let item = quotaMenuItems[provider] else { continue }
                statusMenu.insertItem(item, at: min(2 + offset, statusMenu.items.count))
            }
        }

        for provider in model.preferences.providerOrder {
            guard let item = quotaMenuItems[provider] else { continue }
            let snapshot = snapshots.first { $0.id == provider }
            let quota = snapshot.flatMap {
                MenuBarSummary.value(
                    snapshot: $0,
                    preference: model.preferences.quotaWindow
                )
            } ?? "—"
            let state = snapshot?.activity.label(language: model.language)
                ?? ActivityState.offline.label(language: model.language)
            item.title = "\(provider.title)  \(quota)  ·  \(state)"
            item.isHidden = model.preferences.hiddenProviders.contains(provider)
        }
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            collapsePanel()
        } else {
            panel.orderFrontRegardless()
            updateMenuTitles()
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            updateMenuTitles()
            statusMenu?.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.minY - 4),
                in: sender
            )
        } else {
            togglePanel()
        }
    }

    private func collapsePanel() {
        panel?.orderOut(nil)
        updateMenuTitles()
    }

    private func resizePanel(for mode: PanelLayoutMode) {
        guard let panel else { return }
        let oldFrame = panel.frame
        let newSize = NSSize(
            width: mode.panelWidth(
                visibleProviderCount: model.preferences.visibleProviderOrder.count
            ),
            height: mode.panelHeight
        )
        let origin = NSPoint(
            x: oldFrame.maxX - newSize.width,
            y: oldFrame.maxY - newSize.height
        )
        hostingView?.layer?.cornerRadius = mode == .compact ? 20 : 24
        panel.setFrame(
            NSRect(origin: origin, size: newSize),
            display: true,
            animate: true
        )
        panel.invalidateShadow()
        updateMenuTitles()
    }

    @objc private func showFiveHourQuota() {
        model.preferences.quotaWindow = .fiveHour
    }

    @objc private func showWeeklyQuota() {
        model.preferences.quotaWindow = .weekly
    }

    @objc private func refreshNow() {
        Task { await model.refresh(forceRemote: true) }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

enum MenuBarSummary {
    static func text(
        snapshots: [ProviderSnapshot],
        preference: QuotaWindowPreference,
        providers: [ProviderID]
    ) -> String {
        let values = providers.map { provider in
            let quota = snapshots
                .first { $0.id == provider }
                .flatMap { value(snapshot: $0, preference: preference) }
                ?? "—"
            return "\(abbreviation(provider)) \(quota)"
        }
        return values.joined(separator: "  ")
    }

    static func accessibilityText(
        snapshots: [ProviderSnapshot],
        language: AppLanguage,
        preference: QuotaWindowPreference,
        providers: [ProviderID]
    ) -> String {
        let values = providers.map { provider in
            let quota = snapshots
                .first { $0.id == provider }
                .flatMap { value(snapshot: $0, preference: preference) }
                ?? language.text("未知", "unknown")
            return "\(provider.title) \(quota)"
        }
        return "Quota Bar · "
            + preference.label(language: language)
            + " · "
            + values.joined(separator: ", ")
    }

    private static func abbreviation(_ provider: ProviderID) -> String {
        provider.title
    }

    static func value(
        snapshot: ProviderSnapshot,
        preference: QuotaWindowPreference
    ) -> String? {
        if let balance = snapshot.balances.first {
            return balance.compactText
        }
        return QuotaWindowSelector.limit(
            in: snapshot.limits,
            preference: preference
        ).map { "\(Int($0.clampedRemaining.rounded()))%" }
    }
}

@main
struct QuotaBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
