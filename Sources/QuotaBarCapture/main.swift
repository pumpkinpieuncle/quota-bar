import Darwin
import Foundation

let fm = FileManager.default
let outputDirectory = ProcessInfo.processInfo.environment["QUOTABAR_CACHE_DIR"]
    .map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? fm.homeDirectoryForCurrentUser.appending(path: ".quotabar", directoryHint: .isDirectory)
try? fm.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let input = FileHandle.standardInput.readDataToEndOfFile()
guard let object = try? JSONSerialization.jsonObject(with: input) as? [String: Any] else {
    if !CommandLine.arguments.contains("--hook") {
        print("Quota Bar · waiting for Claude")
    }
    exit(0)
}

func writePrivateJSON(_ object: [String: Any], to url: URL) {
    guard let encoded = try? JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    ) else {
        return
    }
    try? encoded.write(to: url, options: .atomic)
    chmod(url.path, S_IRUSR | S_IWUSR)
}

if CommandLine.arguments.contains("--hook") {
    let event = object["hook_event_name"] as? String ?? ""
    let notificationType = object["notification_type"] as? String ?? ""
    let state: String

    switch (event, notificationType) {
    case ("PermissionRequest", _), ("Notification", "permission_prompt"):
        state = "waitingApproval"
    case ("Stop", _), ("SessionEnd", _), ("Notification", "idle_prompt"):
        state = "idle"
    case ("StopFailure", _):
        state = "needsAttention"
    case ("PreToolUse", _), ("PostToolUse", _), ("UserPromptSubmit", _),
         ("SessionStart", _), ("SubagentStart", _):
        state = "working"
    default:
        state = "working"
    }

    var activity: [String: Any] = [
        "captured_at": Date().timeIntervalSince1970,
        "state": state,
        "hook_event_name": event
    ]
    for key in ["session_id", "cwd", "tool_name", "notification_type"] {
        if let value = object[key] {
            activity[key] = value
        }
    }
    writePrivateJSON(
        activity,
        to: outputDirectory.appending(path: "claude-activity.json")
    )
    exit(0)
}

let statusURL = outputDirectory.appending(path: "claude-status.json")
var filtered: [String: Any] = [
    "captured_at": Date().timeIntervalSince1970
]
for key in ["cwd", "session_id", "version", "model", "context_window"] {
    if let value = object[key] {
        filtered[key] = value
    }
}
if
    let rateLimits = object["rate_limits"] as? [String: Any],
    !rateLimits.isEmpty
{
    filtered["rate_limits"] = rateLimits
    filtered["rate_limits_captured_at"] = Date().timeIntervalSince1970
} else if
    let existingData = try? Data(contentsOf: statusURL),
    let existing = try? JSONSerialization.jsonObject(with: existingData) as? [String: Any],
    let rateLimits = existing["rate_limits"] as? [String: Any]
{
    // A fresh Claude session omits rate_limits until its first response.
    // Preserve the last official snapshot instead of blanking the card.
    filtered["rate_limits"] = rateLimits
    filtered["rate_limits_captured_at"] = existing["rate_limits_captured_at"]
        ?? existing["captured_at"]
        ?? Date().timeIntervalSince1970
}
writePrivateJSON(filtered, to: statusURL)

let modelObject = object["model"] as? [String: Any]
let model = (modelObject?["display_name"] as? String)
    ?? (modelObject?["id"] as? String)
    ?? "Claude"
let rateLimits = object["rate_limits"] as? [String: Any]
var pieces = ["◈ \(model)"]

func usedPercentage(_ key: String, in rateLimits: [String: Any]?) -> Double? {
    guard
        let window = rateLimits?[key] as? [String: Any],
        let value = window["used_percentage"]
    else {
        return nil
    }
    if let number = value as? NSNumber { return number.doubleValue }
    if let string = value as? String { return Double(string) }
    return nil
}

if let used = usedPercentage("five_hour", in: rateLimits) {
    pieces.append("5h \(Int((100 - used).rounded()))% available")
}
if let used = usedPercentage("seven_day", in: rateLimits) {
    pieces.append("7d \(Int((100 - used).rounded()))% available")
}
if pieces.count == 1 {
    pieces.append("quota appears after the first response")
}
print(pieces.joined(separator: "  ·  "))
