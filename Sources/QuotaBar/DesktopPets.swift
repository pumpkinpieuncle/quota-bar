import AppKit
import Combine
import SwiftUI

struct PetToggleButton: View {
    let provider: ProviderID
    @ObservedObject var preferences: AppPreferences
    var compact = false

    private var isEnabled: Bool { preferences.desktopPets.contains(provider) }
    private var label: String {
        preferences.language.text(
            "\(isEnabled ? "收起" : "打开") \(provider.title) 桌宠",
            "\(isEnabled ? "Hide" : "Show") \(provider.title) pet"
        )
    }

    var body: some View {
        Button {
            preferences.toggleDesktopPet(provider)
        } label: {
            Image(systemName: isEnabled ? "pawprint.fill" : "pawprint")
                .font(.system(size: compact ? 10 : 12, weight: .semibold))
                .foregroundStyle(isEnabled ? provider.accent : .white.opacity(0.5))
                .frame(width: compact ? 21 : 25, height: compact ? 23 : 25)
                .background(
                    isEnabled ? provider.accent.opacity(0.16) : Color.white.opacity(0.045),
                    in: RoundedRectangle(cornerRadius: 7)
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityValue(preferences.language.text(isEnabled ? "已打开" : "已关闭", isEnabled ? "On" : "Off"))
    }
}

/// One window per provider. Pet visibility is deliberately independent of card
/// visibility: hiding the quota panel must not dismiss its companions.
@MainActor
final class DesktopPetController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var panels: [ProviderID: NSPanel] = [:]
    private var speechPanels: [ProviderID: NSPanel] = [:]
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var observations = Set<AnyCancellable>()
    private var isRestoringPosition = false
    static let windowSize = CGSize(width: 260, height: 242)
    static let spriteSize = CGSize(width: 260, height: 200)

    init(model: AppModel) {
        self.model = model
        super.init()
        synchronize(model.preferences.desktopPets)
        model.preferences.$desktopPets
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.synchronize($0) }
            .store(in: &observations)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.restoreVisiblePositions() }
            .store(in: &observations)
        model.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshSpeechPanels() }
            .store(in: &observations)
        model.preferences.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshSpeechPanels() }
            .store(in: &observations)
    }

    private func synchronize(_ enabled: Set<ProviderID>) {
        for provider in Array(panels.keys) where !enabled.contains(provider) {
            setSpeechVisible(false, for: provider)
            panels.removeValue(forKey: provider)?.close()
        }
        for provider in ProviderID.allCases where enabled.contains(provider) && panels[provider] == nil {
            show(provider)
        }
    }

    private func show(_ provider: ProviderID) {
        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "\(provider.title) · Quota Bar"
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.delegate = self

        let view = NSHostingView(rootView: DesktopPetView(
            provider: provider, model: model,
            onClick: { [weak self] in self?.toggleSpeech(for: provider) },
            onRename: { [weak self] in self?.renamePet(provider) }
        ))
        view.safeAreaRegions = []
        view.sizingOptions = []
        panel.contentView = view
        panels[provider] = panel

        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let index = ProviderID.allCases.firstIndex(of: provider) ?? 0
        let columns = max(1, Int(screen.width / Self.windowSize.width))
        let initial = CGPoint(
            x: screen.maxX - Self.windowSize.width * CGFloat(index % columns + 1),
            y: screen.minY + 12 + CGFloat(index / columns) * Self.windowSize.height
        )
        let origin = model.preferences.savedPetOrigin(for: provider) ?? initial
        panel.setFrameOrigin(Self.visibleOrigin(origin, size: Self.windowSize, screens: NSScreen.screens.map(\.visibleFrame)))
        panel.orderFrontRegardless()
    }

    /// Keep the entire companion reachable after a monitor is disconnected.
    static func visibleOrigin(_ origin: CGPoint, size: CGSize, screens: [CGRect]) -> CGPoint {
        guard let first = screens.first else { return origin }
        let center = CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2)
        let screen = screens.first(where: { $0.contains(center) }) ?? first
        return CGPoint(
            x: min(max(origin.x, screen.minX), max(screen.minX, screen.maxX - size.width)),
            y: min(max(origin.y, screen.minY), max(screen.minY, screen.maxY - size.height))
        )
    }

    private func restoreVisiblePositions() {
        isRestoringPosition = true
        for panel in panels.values {
            panel.setFrameOrigin(Self.visibleOrigin(
                panel.frame.origin, size: panel.frame.size, screens: NSScreen.screens.map(\.visibleFrame)
            ))
        }
        isRestoringPosition = false
        for (provider, panel) in panels {
            model.preferences.setPetOrigin(panel.frame.origin, for: provider)
        }
        refreshSpeechPanels()
    }

    func windowDidMove(_ notification: Notification) {
        guard !isRestoringPosition, let panel = notification.object as? NSPanel,
              let provider = panels.first(where: { $0.value === panel })?.key else { return }
        model.preferences.setPetOrigin(panel.frame.origin, for: provider)
        positionSpeechPanel(for: provider)
    }

    func toggleSpeech(for provider: ProviderID) {
        let shouldShow = speechPanels[provider] == nil
        for openProvider in Array(speechPanels.keys) {
            setSpeechVisible(false, for: openProvider)
        }
        if shouldShow { setSpeechVisible(true, for: provider) }
    }

    private func renamePet(_ provider: ProviderID) {
        let preferences = model.preferences
        let language = preferences.language
        setSpeechVisible(false, for: provider)
        let alert = NSAlert()
        alert.messageText = language.text("给桌宠改名", "Rename pet")
        alert.informativeText = language.text("最多 32 个字符，留空恢复默认名字。", "Up to 32 characters. Leave blank to use the default name.")
        alert.addButton(withTitle: language.text("保存", "Save"))
        alert.addButton(withTitle: language.text("取消", "Cancel"))
        alert.addButton(withTitle: language.text("恢复默认", "Reset name"))
        let field = NSTextField(frame: CGRect(x: 0, y: 0, width: 280, height: 26))
        field.stringValue = preferences.petName(for: provider)
        field.placeholderString = provider.title
        field.setAccessibilityLabel(language.text("桌宠名字", "Pet name"))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        // Pet windows never take keyboard focus; only this explicit edit opens
        // a normal keyboard-capable dialog, then returns focus to the prior app.
        let previousApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            preferences.setPetName(field.stringValue, for: provider)
        } else if response == .alertThirdButtonReturn {
            preferences.setPetName("", for: provider)
        }
        if previousApp?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp?.activate(options: [])
        }
    }

    func dismissSpeechIfOutside(at point: CGPoint) {
        guard !speechPanels.keys.contains(where: { panels[$0]?.frame.contains(point) == true }) else { return }
        for provider in Array(speechPanels.keys) { setSpeechVisible(false, for: provider) }
    }

    private func monitorOutsideClicks() {
        guard localClickMonitor == nil else { return }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated { self?.dismissSpeechIfOutside(at: NSEvent.mouseLocation) }
            return event
        }
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismissSpeechIfOutside(at: NSEvent.mouseLocation) }
        }
    }

    func setSpeechVisible(_ visible: Bool, for provider: ProviderID) {
        guard visible, panels[provider] != nil else {
            speechPanels.removeValue(forKey: provider)?.close()
            if speechPanels.isEmpty {
                if let monitor = localClickMonitor { NSEvent.removeMonitor(monitor) }
                if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
                localClickMonitor = nil
                globalClickMonitor = nil
            }
            return
        }
        if speechPanels[provider] == nil {
            let bubble = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            bubble.title = "\(provider.title) · Quota details"
            bubble.isReleasedWhenClosed = false
            bubble.isOpaque = false
            bubble.backgroundColor = .clear
            bubble.hasShadow = true
            bubble.level = .floating
            bubble.hidesOnDeactivate = false
            bubble.ignoresMouseEvents = true
            bubble.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            bubble.appearance = NSAppearance(named: .darkAqua)
            let host = NSHostingView(rootView: PetSpeechBubble(provider: provider, model: model))
            host.sizingOptions = [.intrinsicContentSize]
            host.safeAreaRegions = []
            host.frame.size = CGSize(width: 288, height: 400)
            bubble.contentView = host
            speechPanels[provider] = bubble
        }
        positionSpeechPanel(for: provider)
        speechPanels[provider]?.orderFrontRegardless()
        monitorOutsideClicks()
    }

    private func refreshSpeechPanels() {
        for provider in speechPanels.keys { positionSpeechPanel(for: provider) }
    }

    private func positionSpeechPanel(for provider: ProviderID) {
        guard let pet = panels[provider], let bubble = speechPanels[provider],
              let host = bubble.contentView as? NSHostingView<PetSpeechBubble> else { return }
        host.rootView = PetSpeechBubble(provider: provider, model: model)
        host.layoutSubtreeIfNeeded()
        let size = CGSize(width: 288, height: min(460, max(150, host.fittingSize.height)))
        let screen = pet.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? pet.frame
        let pointsDown = pet.frame.maxY - 10 + size.height <= screen.maxY
        let proposed = CGPoint(x: pet.frame.midX - size.width / 2,
                               y: pointsDown ? pet.frame.maxY - 10 : pet.frame.minY - size.height + 20)
        let origin = Self.visibleOrigin(proposed, size: size, screens: [screen])
        let tail = min(max(pet.frame.midX - origin.x, 20), size.width - 20) - size.width / 2
        host.rootView = PetSpeechBubble(provider: provider, model: model, pointsDown: pointsDown, tailOffset: tail)
        bubble.setFrame(CGRect(origin: origin, size: size), display: true)
    }
}

private struct DesktopPetView: View {
    let provider: ProviderID
    @ObservedObject var model: AppModel
    @ObservedObject private var preferences: AppPreferences
    let onClick: () -> Void
    let onRename: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var artwork: PetArtwork?
    @State private var animationStarted = Date()
    @State private var interactionSerial = 0
    @State private var requestedAnimation: PetAnimation?

    init(provider: ProviderID, model: AppModel, onClick: @escaping () -> Void, onRename: @escaping () -> Void) {
        self.provider = provider
        self.model = model
        self.onClick = onClick
        self.onRename = onRename
        _preferences = ObservedObject(wrappedValue: model.preferences)
    }

    private var snapshot: ProviderSnapshot {
        model.snapshots.first { $0.id == provider } ?? .placeholder(provider)
    }
    private var activity: ActivityState { snapshot.activity }
    private var isWaiting: Bool { activity == .waitingApproval || activity == .needsAttention }
    private var playbackID: String { "\(activity.rawValue)-\(interactionSerial)-\(reduceMotion)" }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { timeline in
                    if let artwork {
                        let elapsed = max(0, timeline.date.timeIntervalSince(animationStarted))
                        PetSpriteView(artwork: artwork, frame: artwork.frameIndex(at: reduceMotion ? 0 : elapsed))
                            .frame(width: DesktopPetController.spriteSize.width, height: DesktopPetController.spriteSize.height)
                    }
                }
                .frame(width: DesktopPetController.spriteSize.width, height: DesktopPetController.spriteSize.height)

                PetDragSurface {
                    request(.greeting)
                    onClick()
                }
                    .frame(width: 210, height: DesktopPetController.spriteSize.height)
                    .accessibilityLabel(preferences.language.text("点击查看额度，拖动移动桌宠", "Click for quota, drag to move"))

                HStack {
                    if isWaiting {
                        Image(systemName: "exclamationmark.bubble.fill").foregroundStyle(.orange)
                    }
                    Spacer()
                    Button {
                        preferences.desktopPets.remove(provider)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(.black.opacity(0.65), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(hovering ? 1 : 0)
                    .allowsHitTesting(hovering)
                    .accessibilityLabel(preferences.language.text("收起桌宠", "Hide pet"))
                }
                .frame(width: 180)
                .padding(.top, 5)
            }

            Button(action: onRename) {
                HStack(spacing: 5) {
                    Circle().fill(isWaiting ? Color.orange : provider.accent).frame(width: 5, height: 5)
                    Text(preferences.petName(for: provider))
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: "pencil").font(.system(size: 8))
                }
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.7), in: Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: 210)
            .help(preferences.language.text("点击改名 · \(provider.title)", "Click to rename · \(provider.title)"))
            .accessibilityLabel(preferences.language.text("修改 \(preferences.petName(for: provider)) 的名字", "Rename \(preferences.petName(for: provider))"))
            Spacer(minLength: 0)
        }
        .frame(width: DesktopPetController.windowSize.width, height: DesktopPetController.windowSize.height)
        .onHover { hovering = $0 }
        .contextMenu {
            Button(preferences.language.text("修改名字…", "Rename…"), action: onRename)
            Divider()
            ForEach([PetAnimation.idle, .working] + PetAnimation.leisure(for: provider), id: \.rawValue) { animation in
                Button(animation.label(language: preferences.language)) { request(animation) }
            }
            Divider()
            Button(preferences.language.text("收起 \(preferences.petName(for: provider)) 桌宠", "Hide \(preferences.petName(for: provider)) pet")) {
                preferences.desktopPets.remove(provider)
            }
        }
        .task(id: playbackID) {
            do { try await runPlayback() } catch { /* A new state or closing the pet cancels playback. */ }
        }
    }

    private func request(_ animation: PetAnimation) {
        requestedAnimation = animation
        interactionSerial += 1
    }

    @MainActor
    private func play(_ animation: PetAnimation) -> TimeInterval {
        guard let next = PetArtwork.load(provider: provider, animation: animation) else { return 1 }
        artwork = next
        animationStarted = Date()
        return next.duration
    }

    @MainActor
    private func runPlayback() async throws {
        if let requested = requestedAnimation {
            requestedAnimation = nil
            let duration = play(requested)
            if !reduceMotion {
                try await Task.sleep(for: .seconds(artwork?.isContinuousVideo == true ? duration : max(3, duration * 2)))
            }
        }
        let base = PetAnimation.base(for: activity)
        _ = play(base)
        guard base == .idle, !reduceMotion else { return }
        let allActions = PetAnimation.leisure(for: provider)
        // During incremental video imports, do not automatically alternate
        // smooth clips with the older key-pose sheets. Manual actions remain.
        let continuousActions = allActions.filter {
            PetArtwork.hasContinuousAnimation(provider: provider, animation: $0)
        }
        let actions = continuousActions.isEmpty ? allActions : continuousActions
        let providerIndex = ProviderID.allCases.firstIndex(of: provider) ?? 0
        var index = providerIndex % actions.count
        while !Task.isCancelled {
            let idleDuration = artwork?.duration ?? 1
            let desiredRest = 6 + Double(providerIndex) * 0.7
            let rest = artwork?.isContinuousVideo == true
                ? ceil(desiredRest / idleDuration) * idleDuration : desiredRest
            try await Task.sleep(for: .seconds(rest))
            try Task.checkCancellation()
            let duration = play(actions[index])
            try await Task.sleep(for: .seconds(artwork?.isContinuousVideo == true ? duration : max(3.5, duration * 2)))
            try Task.checkCancellation()
            _ = play(.idle)
            index = (index + 1) % actions.count
        }
    }
}

private struct PetSpriteView: NSViewRepresentable {
    let artwork: PetArtwork
    let frame: Int

    func makeNSView(context: Context) -> SpriteCanvas {
        let view = SpriteCanvas()
        view.identifier = NSUserInterfaceItemIdentifier("desktopPetSprite")
        return view
    }
    func updateNSView(_ view: SpriteCanvas, context: Context) {
        view.artwork = artwork
        view.frameIndex = frame
        view.needsDisplay = true
    }

    final class SpriteCanvas: NSView {
        var artwork: PetArtwork?
        var frameIndex = 0
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.clear.setFill()
            dirtyRect.fill(using: .copy)
            guard let artwork else { return }
            let tileWidth = artwork.image.size.width / CGFloat(artwork.columns)
            let tileHeight = artwork.image.size.height / CGFloat(artwork.rows)
            let column = frameIndex % artwork.columns
            let row = frameIndex / artwork.columns
            let source = CGRect(
                x: CGFloat(column) * tileWidth,
                y: CGFloat(artwork.rows - 1 - row) * tileHeight,
                width: tileWidth, height: tileHeight
            )
            let scale = PetArtwork.subjectDisplayHeight / artwork.referenceHeight
            let size = CGSize(width: tileWidth * scale, height: tileHeight * scale)
            let destination = CGRect(
                x: (bounds.width - size.width) / 2 - artwork.horizontalOffset * scale,
                y: 10 - artwork.bottomInset * scale,
                width: size.width, height: size.height
            )
            artwork.image.draw(in: destination, from: source, operation: .sourceOver, fraction: 1)
        }
    }
}

private struct PetDragSurface: NSViewRepresentable {
    let onClick: () -> Void
    func makeNSView(context: Context) -> DragView {
        let view = DragView()
        view.onClick = onClick
        return view
    }
    func updateNSView(_ view: DragView, context: Context) { view.onClick = onClick }

    final class DragView: NSView {
        var onClick: () -> Void = {}
        private var initialEvent: NSEvent?
        private var didDrag = false

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) {
            initialEvent = event
            didDrag = false
        }
        override func mouseDragged(with event: NSEvent) {
            guard !didDrag, let initialEvent else { return }
            let dx = event.locationInWindow.x - initialEvent.locationInWindow.x
            let dy = event.locationInWindow.y - initialEvent.locationInWindow.y
            guard hypot(dx, dy) > 3 else { return }
            didDrag = true
            window?.performDrag(with: initialEvent)
        }
        override func mouseUp(with event: NSEvent) {
            if !didDrag { onClick() }
            initialEvent = nil
        }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
    }
}
