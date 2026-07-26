import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = AppModel()
    private var panel: FloatingPanel?
    private var statusItem: NSStatusItem?
    private var toggleMenuItem: NSMenuItem?
    private var refreshMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?

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
        let size = NSSize(width: 600, height: 286)
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
        panel.contentView = NSHostingView(rootView: ContentView(model: model))

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
    }

    private func makeStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "gauge.with.dots.needle.67percent",
                accessibilityDescription: "Quota Bar"
            )
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
        item.menu = menu
        toggleMenuItem = toggle
        refreshMenuItem = refresh
        quitMenuItem = quit
        updateMenuTitles()
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuTitles()
    }

    private func updateMenuTitles() {
        let language = model.language
        toggleMenuItem?.title = language.text("显示 / 隐藏浮窗", "Show / hide panel")
        refreshMenuItem?.title = language.text("立即刷新", "Refresh now")
        quitMenuItem?.title = language.text("退出 Quota Bar", "Quit Quota Bar")
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    @objc private func refreshNow() {
        Task { await model.refresh(forceRemote: true) }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
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
