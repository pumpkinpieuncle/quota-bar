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
    let image: NSImage
    let columns: Int
    let rows: Int
    let frames: [Int]
    let frameDurations: [TimeInterval]
    let displayHeight: CGFloat
    var frameCount: Int { frames.count }
    var duration: TimeInterval { frameDurations.reduce(0, +) }

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
        if provider == .deepseek {
            let name = "deepseek-\(animation.rawValue)"
            guard let image = image(named: name) else { return nil }
            // Metadata comes from the imported video itself, including clips
            // shorter than ten seconds and their transparent frame geometry.
            guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Pets"),
                  let data = try? Data(contentsOf: url),
                  let info = try? JSONDecoder().decode(AtlasInfo.self, from: data) else { return nil }
            return Self(image: image, columns: info.columns, rows: info.rows,
                        frames: Array(0..<info.frameCount),
                        frameDurations: Array(repeating: 1 / info.fps, count: info.frameCount),
                        displayHeight: 180)
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
                    frames: offsets.map { start + $0 }, frameDurations: holds, displayHeight: 150)
    }

    private struct AtlasInfo: Decodable {
        let columns: Int
        let rows: Int
        let frameCount: Int
        let fps: Double
    }

    private static func image(named name: String) -> NSImage? {
        guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Pets") else { return nil }
        return NSImage(contentsOf: url)
    }
}
