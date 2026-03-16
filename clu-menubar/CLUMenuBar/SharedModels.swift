import SwiftUI

// MARK: - API Models (shared between app + widget)

struct UsageSample: Codable, Identifiable {
    let ts: Int
    let fiveH: Double
    let sevenD: Double
    let tok: Int

    var id: Int { ts }
    var date: Date { Date(timeIntervalSince1970: TimeInterval(ts)) }

    enum CodingKeys: String, CodingKey {
        case ts
        case fiveH = "5h"
        case sevenD = "7d"
        case tok
    }
}

struct ModelInfo: Codable {
    let utilization: Double?
    let resets_at: String?
}

struct ExtraUsage: Codable {
    let enabled: Bool?
    let limit: Double?
    let used: Double?
    let utilization: Double?
}

struct APIResponse: Codable {
    let pct_5h: Double?
    let pct_7d: Double?
    let reset_5h_iso: String?
    let reset_7d_iso: String?
    let reset_5h_secs: Int?
    let reset_7d_secs: Int?
    let tokens_5h: Int?
    let pace_pct: Double?
    let elapsed_ratio: Double?
    let plan: String?
    let is_promo: Bool?
    let promo_label: String?
    let models: [String: ModelInfo]?
    let extra_usage: ExtraUsage?
    let history: [UsageSample]?
    let last_fetch: Int?
    let error: String?
}

// MARK: - Colors

extension Color {
    static let cluViolet = Color(red: 0.65, green: 0.55, blue: 0.98)
    static let cluCyan = Color(red: 0.25, green: 0.78, blue: 0.92)
    static let cluGreen = Color(red: 0.20, green: 0.78, blue: 0.55)
    static let cluOrange = Color(red: 0.96, green: 0.55, blue: 0.22)
    static let cluRed = Color(red: 0.94, green: 0.36, blue: 0.36)
    static let cluAmber = Color(red: 0.96, green: 0.72, blue: 0.15)

    static func forPct(_ pct: Double) -> Color {
        if pct >= 90 { return .cluRed }
        if pct >= 70 { return .cluOrange }
        if pct >= 40 { return .cluAmber }
        return .cluGreen
    }
}

// MARK: - Format Helpers

func formatReset(seconds: Int?) -> String {
    guard let secs = seconds, secs > 0 else { return "—" }
    let d = secs / 86400
    let h = (secs % 86400) / 3600
    let m = (secs % 3600) / 60
    if d > 0 { return "\(d)d \(h)h" }
    if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
    return "\(m)m"
}

func formatTimeAgo(_ date: Date?) -> String {
    guard let date = date else { return "never" }
    let secs = Int(Date().timeIntervalSince(date))
    if secs < 5 { return "just now" }
    if secs < 60 { return "\(secs)s ago" }
    if secs < 3600 { return "\(secs / 60)m ago" }
    return "\(secs / 3600)h ago"
}

func parseISO(_ iso: String?) -> Date? {
    guard let iso = iso else { return nil }
    let fmt = ISO8601DateFormatter()
    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = fmt.date(from: iso) { return d }
    fmt.formatOptions = [.withInternetDateTime]
    return fmt.date(from: iso)
}

// MARK: - Shared Fetch

func fetchCLUData(from baseURL: String = "http://localhost:8765") async -> APIResponse? {
    guard let url = URL(string: "\(baseURL)/api") else { return nil }
    guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
    return try? JSONDecoder().decode(APIResponse.self, from: data)
}
