import AppKit
import Foundation

enum PetAnimation: String, CaseIterable, Sendable {
    case idle, greeting, thinking, working, waiting, attention, sleeping
    case stretching, snack, dancing, puzzle, magic, looking, jumping

    static func base(for activity: ActivityState) -> Self {
        switch activity {
        case .working: .working
        case .thinking: .thinking
        case .waitingApproval: .waiting
        case .needsAttention: .attention
        // A disconnected model should still be a living companion. Offline is
        // described in the speech bubble, rather than freezing its character.
        case .offline, .idle, .connected: .idle
        }
    }

    static func leisure(for provider: ProviderID) -> [Self] {
        let shared: [Self] = [.greeting, .stretching, .snack, .dancing, .sleeping, .thinking]
        return provider == .deepseek ? shared + [.puzzle, .magic, .looking, .jumping] : shared
    }

    func label(language: AppLanguage) -> String {
        switch self {
        case .idle: language.text("眨眨眼", "Idle")
        case .greeting: language.text("打个招呼", "Wave hello")
        case .thinking: language.text("想一想", "Think")
        case .working: language.text("认真工作", "Work")
        case .waiting: language.text("等你回应", "Wait")
        case .attention: language.text("有点烦恼", "Ponder")
        case .sleeping: language.text("打个盹", "Nap")
        case .stretching: language.text("伸个懒腰", "Stretch")
        case .snack: language.text("吃点东西", "Have a snack")
        case .dancing: language.text("跳个小舞", "Dance")
        case .puzzle: language.text("玩魔方", "Solve a cube")
        case .magic: language.text("变个魔术", "Make magic")
        case .looking: language.text("东张西望", "Look around")
        case .jumping: language.text("开心跳跃", "Happy jump")
        }
    }

    var sheet: String {
        switch self {
        case .stretching, .snack, .dancing, .sleeping: "extra"
        default: "core"
        }
    }

    var row: Int {
        switch self {
        case .idle, .stretching: 0
        case .greeting, .waiting, .snack, .jumping: 1
        case .thinking, .attention, .dancing, .looking, .magic: 2
        case .working, .sleeping, .puzzle: 3
        }
    }
}

@MainActor
struct PetArtwork {
    // SwiftPM's command-line build accessor searches beside the executable
    // bundle, while app resources are installed under Contents/Resources.
    // Resolve that location explicitly so release builds do not depend on a
    // resource directory that exists only on the build machine.
    private static let resourceBundle: Bundle? = {
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("QuotaBar_QuotaBar.bundle") else { return nil }
            return Bundle(url: url)
        }
        return Bundle.module
    }()

    let image: NSImage
    let columns: Int
    let rows: Int
    let frames: [Int]
    let frameDurations: [TimeInterval]
    // Measurements of the neutral pose, shared by every action from that
    // source. Transparent canvas padding must not decide character size.
    let referenceHeight: CGFloat
    let bottomInset: CGFloat
    let horizontalOffset: CGFloat
    let isContinuousVideo: Bool
    static let subjectDisplayHeight: CGFloat = 150
    var frameCount: Int { frames.count }
    var duration: TimeInterval { frameDurations.reduce(0, +) }

    static func hasContinuousAnimation(provider: ProviderID, animation: PetAnimation) -> Bool {
        let name = continuousResourceName(provider: provider, animation: animation)
        return resourceBundle?.url(forResource: name, withExtension: "json", subdirectory: "Pets") != nil
            && resourceBundle?.url(forResource: name, withExtension: "png", subdirectory: "Pets") != nil
    }

    private static func continuousResourceName(provider: ProviderID, animation: PetAnimation) -> String {
        let direct = "\(provider.rawValue)-\(animation.rawValue)"
        if provider == .deepseek || resourceBundle?.url(forResource: direct, withExtension: "json", subdirectory: "Pets") != nil {
            return direct
        }
        // These states share poses in the original sheets. Prefer the same
        // continuous counterpart when a dedicated state clip is unavailable.
        switch animation {
        case .waiting: return "\(provider.rawValue)-greeting"
        case .attention: return "\(provider.rawValue)-thinking"
        default: return direct
        }
    }

    func frameIndex(at elapsed: TimeInterval) -> Int {
        guard !frames.isEmpty, duration > 0 else { return 0 }
        var time = max(0, elapsed).truncatingRemainder(dividingBy: duration)
        for (index, hold) in frameDurations.enumerated() {
            if time < hold { return frames[index] }
            time -= hold
        }
        return frames[0]
    }

    static func load(provider: ProviderID, activity: ActivityState) -> Self? {
        load(provider: provider, animation: .base(for: activity))
    }

    static func load(provider: ProviderID, animation: PetAnimation) -> Self? {
        let name = continuousResourceName(provider: provider, animation: animation)
        if let url = resourceBundle?.url(forResource: name, withExtension: "json", subdirectory: "Pets") {
            guard let image = image(named: name) else { return nil }
            // Metadata comes from the imported video itself, including clips
            // shorter than ten seconds and their transparent frame geometry.
            guard let data = try? Data(contentsOf: url),
                  let info = try? JSONDecoder().decode(AtlasInfo.self, from: data),
                  info.columns > 0, info.rows > 0, info.frameCount > 0,
                  info.frameCount <= info.columns * info.rows,
                  info.fps > 0, info.fps <= 60,
                  info.referenceHeight > 0, info.referenceHeight.isFinite,
                  info.bottomInset.isFinite,
                  (info.horizontalOffset ?? 0).isFinite else { return nil }
            return Self(image: image, columns: info.columns, rows: info.rows,
                        frames: Array(0..<info.frameCount),
                        frameDurations: Array(repeating: 1 / info.fps, count: info.frameCount),
                        referenceHeight: info.referenceHeight,
                        bottomInset: info.bottomInset,
                        horizontalOffset: info.horizontalOffset ?? 0,
                        isContinuousVideo: true)
        }
        guard let image = image(named: "\(provider.rawValue)-\(animation.sheet)") else { return nil }
        let start = animation.row * 4
        let offsets: [Int]
        let holds: [TimeInterval]
        switch animation {
        case .idle:
            offsets = [0, 1, 2, 3]
            holds = [1.3, 0.12, 0.14, 0.5]
        case .greeting, .waiting:
            offsets = [0, 1, 2, 1, 2, 3]
            holds = [0.18, 0.22, 0.22, 0.22, 0.22, 0.3]
        case .sleeping:
            offsets = [0, 1, 2, 3, 2, 3]
            holds = [0.5, 0.6, 1, 0.7, 1, 0.7]
        case .stretching:
            offsets = [0, 1, 2, 3]
            holds = [0.3, 0.7, 0.6, 0.3]
        default:
            offsets = [0, 1, 2, 3]
            holds = [0.35, 0.3, 0.35, 0.3]
        }
        return Self(image: image, columns: 4, rows: 4,
                    frames: offsets.map { start + $0 }, frameDurations: holds,
                    referenceHeight: legacyReferenceHeight(for: provider),
                    bottomInset: 6, horizontalOffset: 0, isContinuousVideo: false)
    }

    private static func legacyReferenceHeight(for provider: ProviderID) -> CGFloat {
        // Measured from the neutral core frame's alpha > 50% bounds. Both
        // legacy sheets use the same scale and a shared 250px foot baseline.
        switch provider {
        case .codex: 232
        case .claude: 230
        case .kimi: 208
        case .grok: 219
        case .gemini: 229
        case .deepseek: 133
        }
    }

    private struct AtlasInfo: Decodable {
        let columns: Int
        let rows: Int
        let frameCount: Int
        let fps: Double
        let referenceHeight: CGFloat
        let bottomInset: CGFloat
        let horizontalOffset: CGFloat?
    }

    private static func image(named name: String) -> NSImage? {
        guard let url = resourceBundle?.url(forResource: name, withExtension: "png", subdirectory: "Pets") else { return nil }
        return NSImage(contentsOf: url)
    }
}
