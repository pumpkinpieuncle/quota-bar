import AppKit
import Carbon
import Combine
import QuartzCore
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(
        _ frameRect: NSRect,
        to screen: NSScreen?
    ) -> NSRect {
        guard let bounds = screen?.visibleFrame else { return frameRect }
        var frame = frameRect
        frame.origin.x = min(
            max(frame.origin.x, bounds.minX),
            max(bounds.minX, bounds.maxX - frame.width)
        )
        frame.origin.y = min(
            max(frame.origin.y, bounds.minY),
            max(bounds.minY, bounds.maxY - frame.height)
        )
        return frame
    }
}

final class MenuBarMarqueeView: NSView {
    private let iconView = NSImageView()
    private let textClipView = NSView()
    private let textLayer = CATextLayer()
    private var currentText = ""
    private(set) var cycleDuration: CFTimeInterval = 0
    private(set) var singleCycleWidth: CGFloat = 0
    private(set) var textContentWidth: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        textClipView.wantsLayer = true
        textClipView.layer?.masksToBounds = true
        addSubview(textClipView)

        textLayer.alignmentMode = .left
        textLayer.truncationMode = .none
        textLayer.isWrapped = false
        textClipView.layer?.addSublayer(textLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func layout() {
        super.layout()
        iconView.frame = NSRect(
            x: 3,
            y: (bounds.height - 17) / 2,
            width: 17,
            height: 17
        )
        textClipView.frame = NSRect(
            x: 25,
            y: 0,
            width: max(0, bounds.width - 28),
            height: bounds.height
        )
        textLayer.frame.origin.y = (textClipView.bounds.height - textLayer.frame.height) / 2
    }

    func update(text: String, image: NSImage?, font: NSFont) {
        iconView.image = image
        guard currentText != text || textLayer.animation(forKey: "marquee") == nil else {
            return
        }
        currentText = text
        let cycle = text + "      "
        let repeatedText = cycle + cycle
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        textLayer.contentsScale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        textLayer.string = NSAttributedString(
            string: repeatedText,
            attributes: attributes
        )
        let cycleWidth = (cycle as NSString).size(
            withAttributes: attributes
        ).width
        let completeSize = (repeatedText as NSString).size(
            withAttributes: attributes
        )
        singleCycleWidth = ceil(cycleWidth)
        textContentWidth = ceil(completeSize.width)
        textLayer.frame = NSRect(
            x: 0,
            y: (textClipView.bounds.height - ceil(completeSize.height)) / 2,
            width: textContentWidth,
            height: ceil(completeSize.height)
        )
        layoutSubtreeIfNeeded()

        textLayer.removeAllAnimations()
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = 0
        animation.toValue = -singleCycleWidth
        animation.duration = min(12, max(6, Double(cycleWidth / 40)))
        cycleDuration = animation.duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.isRemovedOnCompletion = false
        textLayer.add(animation, forKey: "marquee")
    }

    func stop() {
        textLayer.removeAllAnimations()
        currentText = ""
    }

    var isAnimating: Bool {
        textLayer.animation(forKey: "marquee") != nil
    }

    var renderedText: String {
        (textLayer.string as? NSAttributedString)?.string ?? ""
    }
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
    private var menuBarDisplayObservation: AnyCancellable?
    private var marqueeView: MenuBarMarqueeView?
    private var screenParametersObserver: NSObjectProtocol?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?
    private var showPanelObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        makePanel()
        makeStatusItem()
        registerShowPanelHotKey()
        model.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let showPanelObserver {
            NotificationCenter.default.removeObserver(showPanelObserver)
        }
        if let screenParametersObserver {
            NotificationCenter.default.removeObserver(screenParametersObserver)
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let hotKeyHandlerRef {
            RemoveEventHandler(hotKeyHandlerRef)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showPanel()
        return true
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
                y: visible.maxY - size.height
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
        statusItem = item
        if let button = item.button {
            button.image = statusImage
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
            keyEquivalent: "q"
        )
        toggle.target = self
        toggle.keyEquivalentModifierMask = [.command, .option]
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
        updateStatusItem(snapshots: model.snapshots)
        screenParametersObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateStatusItem(snapshots: self.model.snapshots)
            }
        }
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
        menuBarDisplayObservation = model.preferences.$menuBarDisplayMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateStatusItem(snapshots: self.model.snapshots)
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
        let providers = model.preferences.visibleProviderOrder
        let fullSummary = MenuBarSummary.text(
            snapshots: snapshots,
            preference: model.preferences.quotaWindow,
            providers: providers
        )
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let fullWidth = (fullSummary as NSString).size(
            withAttributes: [.font: font]
        ).width
        let screenWidth = statusItem?.button?.window?.screen?.visibleFrame.width
            ?? NSScreen.main?.visibleFrame.width
            ?? 1_440
        let useScrolling = MenuBarSummary.shouldUseScrolling(
            mode: model.preferences.menuBarDisplayMode,
            screenWidth: screenWidth,
            fullSummaryWidth: fullWidth
        )
        if useScrolling, let statusItem, let button = statusItem.button {
            statusItem.length = 155
            button.image = nil
            button.title = ""
            let marquee = marqueeView ?? MenuBarMarqueeView(frame: button.bounds)
            if marqueeView == nil {
                marquee.autoresizingMask = [.width, .height]
                button.addSubview(marquee)
                marqueeView = marquee
            }
            marquee.isHidden = false
            marquee.frame = button.bounds
            marquee.update(
                text: fullSummary,
                image: statusImage,
                font: .monospacedSystemFont(ofSize: 11, weight: .semibold)
            )
        } else {
            marqueeView?.stop()
            marqueeView?.isHidden = true
            statusItem?.length = NSStatusItem.variableLength
            statusItem?.button?.image = statusImage
            statusItem?.button?.title = fullSummary
        }
        statusItem?.button?.toolTip = MenuBarSummary.accessibilityText(
            snapshots: snapshots,
            language: model.language,
            preference: model.preferences.quotaWindow,
            providers: providers
        )
        updateQuotaMenuItems(snapshots: snapshots)
    }

    private var statusImage: NSImage? {
        NSImage(
            systemSymbolName: "gauge.with.dots.needle.67percent",
            accessibilityDescription: "Quota Bar"
        )
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
            showPanel()
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

    @objc private func showPanel() {
        panel?.orderFrontRegardless()
        updateMenuTitles()
    }

    private func registerShowPanelHotKey() {
        showPanelObserver = NotificationCenter.default.addObserver(
            forName: .quotaBarShowPanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.showPanel()
            }
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { _, event, _ in
            guard let event else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr, hotKeyID.id == 1 else { return status }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .quotaBarShowPanel, object: nil)
            }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            &hotKeyHandlerRef
        )
        let hotKeyID = EventHotKeyID(
            signature: fourCharacterCode("QBAR"),
            id: 1
        )
        RegisterEventHotKey(
            UInt32(kVK_ANSI_Q),
            UInt32(cmdKey | optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    private func fourCharacterCode(_ value: String) -> OSType {
        value.utf8.reduce(0) { ($0 << 8) + OSType($1) }
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
    static func shouldUseScrolling(
        mode: MenuBarDisplayMode,
        screenWidth: CGFloat,
        fullSummaryWidth: CGFloat
    ) -> Bool {
        switch mode {
        case .automatic:
            fullSummaryWidth > max(160, screenWidth * 0.14)
        case .full:
            false
        case .scrolling:
            true
        }
    }

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
        if
            let balance = snapshot.balances.first,
            snapshot.id == .deepseek || snapshot.limits.isEmpty
        {
            return balance.compactText
        }
        if let limit = QuotaWindowSelector.limit(
            in: snapshot.limits,
            preference: preference
        ) {
            return "\(Int(limit.clampedRemaining.rounded()))%"
        }
        return snapshot.balances.first?.compactText
    }
}

private extension Notification.Name {
    static let quotaBarShowPanel = Notification.Name("QuotaBarShowPanel")
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
