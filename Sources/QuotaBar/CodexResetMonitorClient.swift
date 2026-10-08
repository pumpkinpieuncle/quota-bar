import Foundation

actor CodexResetMonitorClient {
    static let shared = CodexResetMonitorClient()

    private var cachedPrediction: CodexResetPrediction?
    private var lastFetchDate: Date?

    init() {
        if let data = UserDefaults.standard.data(forKey: "codex_reset_prediction_cache"),
           let cached = try? JSONDecoder().decode(CodexResetPrediction.self, from: data) {
            self.cachedPrediction = cached
            self.lastFetchDate = cached.fetchedAt
        }
    }

    func fetchIfNeeded(force: Bool = false) async -> CodexResetPrediction? {
        // Cache for 15 minutes to stay current without spamming aihot.news
        if !force, let cachedPrediction, let lastFetchDate,
           Date().timeIntervalSince(lastFetchDate) < 900 {
            return cachedPrediction
        }

        guard let url = URL(string: "https://aihot.news/codex-reset") else {
            return cachedPrediction
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let html = String(data: data, encoding: .utf8) else {
                return cachedPrediction
            }

            if let prediction = Self.parseHTML(html, date: Date()) {
                self.cachedPrediction = prediction
                self.lastFetchDate = prediction.fetchedAt
                if let encoded = try? JSONEncoder().encode(prediction) {
                    UserDefaults.standard.set(encoded, forKey: "codex_reset_prediction_cache")
                }
                return prediction
            }
        } catch {
            // Keep using cached prediction on network failure
        }
        return cachedPrediction
    }

    nonisolated static func parseHTML(_ html: String, date: Date = Date()) -> CodexResetPrediction? {
        func stripHTML(_ str: String) -> String {
            str.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func extract(pattern: String) -> String {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
                  let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                  let r = Range(match.range(at: 1), in: html) else {
                return ""
            }
            return stripHTML(String(html[r]))
        }

        let status = extract(pattern: "<p[^>]*class=\"[^\"]*text-ok-ink[^\"]*\"[^>]*>(.*?)</p>")
        let headline = extract(pattern: "<h2[^>]*class=\"[^\"]*text-ink[^\"]*\"[^>]*>(.*?)</h2>")
        let median = extract(pattern: "<dt[^>]*>重置间隔中位数</dt>\\s*<dd[^>]*>(.*?)</dd>")
        let lastReset = extract(pattern: "<dt[^>]*>上次额度重置</dt>\\s*<dd[^>]*>(.*?)</dd>")

        guard !status.isEmpty || !headline.isEmpty || !median.isEmpty else {
            return nil
        }

        return CodexResetPrediction(
            status: status,
            headline: headline,
            medianInterval: median,
            lastReset: lastReset,
            fetchedAt: date
        )
    }
}
