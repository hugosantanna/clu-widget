import SwiftUI
import Charts

// MARK: - API Model

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

struct ProjectInfo: Codable, Identifiable {
    let name: String
    let tokens: Int?
    let sessions: Int?
    let messages: Int?
    let last_active: String?
    let models: [String: Int]?

    var id: String { name }
}

struct SessionInfo: Codable, Identifiable {
    let id: String
    let project: String
    let messages: Int?
    let tokens: Int?
    let model: String?
    let last_active: String?
}

struct Totals: Codable {
    let tokens: Int?
    let messages: Int?
    let projects: Int?
    let sessions: Int?
    let cache_hit_rate: Double?
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
    let projects: [ProjectInfo]?
    let sessions: [SessionInfo]?
    let totals: Totals?
    let daily_tokens: [String: Int]?
    let last_fetch: Int?
    let error: String?
}

// MARK: - Data Service

@Observable
class UsageService {
    var data: APIResponse?
    var isLoading = false
    var lastUpdate: Date?

    private var timer: Timer?
    private let baseURL: String

    init(baseURL: String = "http://localhost:8765") {
        self.baseURL = baseURL
    }

    func startPolling(interval: TimeInterval = 30) {
        fetch()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetch()
        }
    }

    func fetch() {
        guard let url = URL(string: "\(baseURL)/api") else { return }
        isLoading = true
        URLSession.shared.dataTask(with: url) { [weak self] responseData, _, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                guard let responseData = responseData, error == nil else { return }
                if let response = try? JSONDecoder().decode(APIResponse.self, from: responseData) {
                    self?.data = response
                    self?.lastUpdate = Date()
                }
            }
        }.resume()
    }

    func triggerRefresh() {
        guard let url = URL(string: "\(baseURL)/api/refresh") else { return }
        URLSession.shared.dataTask(with: url) { _, _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.fetch()
            }
        }.resume()
    }
}

// MARK: - Colors (adaptive for light/dark)

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
    if d > 0 { return "Resets in \(d)d \(h)h" }
    if h > 0 { return "Resets in \(h)h \(String(format: "%02d", m))m" }
    return "Resets in \(m)m"
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

// MARK: - Usage Bar

struct UsageBar: View {
    let label: String
    let pct: Double
    let resetSecs: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int(pct))%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.forPct(pct))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(.quaternary)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.forPct(pct))
                        .frame(width: max(0, geo.size.width * pct / 100))
                        .animation(.easeInOut(duration: 0.6), value: pct)
                }
            }
            .frame(height: 10)

            Text(formatReset(seconds: resetSecs))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

// MARK: - Window Chart

struct WindowChartView: View {
    let title: String
    let history: [UsageSample]
    let keyPath: KeyPath<UsageSample, Double>
    let resetISO: String?
    let windowSecs: Double
    let color: Color

    private var windowStart: Date {
        if let reset = parseISO(resetISO) {
            return reset.addingTimeInterval(-windowSecs)
        }
        return Date().addingTimeInterval(-windowSecs)
    }

    private var windowEnd: Date {
        windowStart.addingTimeInterval(windowSecs)
    }

    private var budgetPoints: [(date: Date, pct: Double)] {
        stride(from: 0.0, through: 1.0, by: 0.05).map { ratio in
            (windowStart.addingTimeInterval(ratio * windowSecs), ratio * 100)
        }
    }

    private var usagePoints: [(date: Date, pct: Double)] {
        // Only show samples from the current window — filter out previous cycles
        history
            .filter { $0.date >= windowStart && $0.date <= windowEnd }
            .map { ($0.date, $0[keyPath: keyPath]) }
    }

    /// Human-readable time format for x-axis depending on window size
    private var xAxisFormat: Date.FormatStyle {
        if windowSecs <= 86400 {
            return .dateTime.hour().minute()         // "2 PM" / "14:30"
        } else {
            return .dateTime.weekday(.abbreviated)   // "Mon", "Tue"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title row with percentage inline
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                if let last = usagePoints.last {
                    Text("\(Int(last.pct))%")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
                Spacer()
            }

            Chart {
                // Budget diagonal
                ForEach(Array(budgetPoints.enumerated()), id: \.offset) { _, pt in
                    LineMark(
                        x: .value("Time", pt.date),
                        y: .value("Budget", pt.pct),
                        series: .value("S", "budget")
                    )
                    .foregroundStyle(.secondary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .interpolationMethod(.linear)
                }

                // Gradient fill under actual
                ForEach(Array(usagePoints.enumerated()), id: \.offset) { _, pt in
                    AreaMark(
                        x: .value("Time", pt.date),
                        y: .value("U", pt.pct)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                // Actual usage line
                ForEach(Array(usagePoints.enumerated()), id: \.offset) { _, pt in
                    LineMark(
                        x: .value("Time", pt.date),
                        y: .value("Usage", pt.pct),
                        series: .value("S", "actual")
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)
                }
            }
            .chartXScale(domain: windowStart...windowEnd)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .trailing, values: [0, 25, 50, 75, 100]) { val in
                    AxisValueLabel {
                        Text("\(val.as(Int.self) ?? 0)%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.2))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: windowSecs <= 86400 ? 5 : 4)) { val in
                    AxisValueLabel(format: xAxisFormat)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.15))
                }
            }
            .chartLegend(.hidden)
            .frame(height: 110)

            // Legend
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 16, height: 3)
                    Text("actual").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    DashedLine()
                        .stroke(.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        .frame(width: 16, height: 2)
                    Text("even pace").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Popover Content

// MARK: - CLU Mascot

struct CluMascot: View {
    @State private var tick = 0
    @State private var isBlinking = false

    private let skin = Color(red: 0.78, green: 0.53, blue: 0.42)
    private let eyes = Color.cluViolet
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var eyeChar: String {
        isBlinking ? "\u{2038}" : ["\u{25CF}", "\u{25D5}", "\u{25C9}"][(tick / 4) % 3]
    }

    var body: some View {
        VStack(spacing: -1) {
            Text("*").font(.system(size: 6, weight: .bold)).foregroundStyle(eyes)
            Text("|").font(.system(size: 5, design: .monospaced)).foregroundStyle(eyes)
                .frame(height: 4)
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(skin)
                    .frame(width: 18, height: 12)
                HStack(spacing: 3) {
                    Text(eyeChar).font(.system(size: 6)).foregroundStyle(eyes)
                    Text(eyeChar).font(.system(size: 6)).foregroundStyle(eyes)
                }
            }
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 0.5).fill(skin).frame(width: 2, height: 5)
                RoundedRectangle(cornerRadius: 0.5).fill(skin).frame(width: 2, height: 5)
            }
        }
        .frame(width: 22, height: 28)
        .onReceive(timer) { _ in
            tick += 1
            isBlinking = (tick % 10) == 0
        }
    }
}

// MARK: - Popover Content

struct PopoverView: View {
    var service: UsageService
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header with mascot
                HStack(alignment: .center, spacing: 8) {
                    CluMascot()
                    Text("Claude Usage")
                        .font(.system(size: 17, weight: .bold))
                    Spacer()
                    if let plan = service.data?.plan, !plan.isEmpty {
                        Text(plan.capitalized)
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.cluViolet.opacity(0.15))
                            .foregroundStyle(Color.cluViolet)
                            .clipShape(Capsule())
                    }
                    if service.data?.is_promo == true, let label = service.data?.promo_label {
                        Text("\u{26A1} \(label)")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.15))
                            .foregroundStyle(.yellow)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if let data = service.data {
                    // Promo badge is already in the header — no need for a separate banner

                    // Usage bars
                    UsageBar(label: "5-Hour Window", pct: data.pct_5h ?? 0, resetSecs: data.reset_5h_secs)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)

                    UsageBar(label: "7-Day Window", pct: data.pct_7d ?? 0, resetSecs: data.reset_7d_secs)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)

                    // Pace
                    if let pace = data.pace_pct {
                        let paceColor = pace <= 100 ? Color.cluGreen : pace <= 150 ? Color.cluOrange : Color.cluRed
                        let paceIcon = pace <= 100 ? "checkmark.circle.fill" : pace <= 150 ? "exclamationmark.triangle.fill" : "flame.fill"
                        let paceLabel = pace <= 100 ? "under budget" : pace <= 150 ? "ahead of budget" : "burning fast"

                        HStack(spacing: 6) {
                            Image(systemName: paceIcon)
                                .font(.system(size: 12))
                                .foregroundStyle(paceColor)
                            Text("Pace \(Int(pace))%")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(paceColor)
                            Text(paceLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }

                    // Charts
                    if let history = data.history, history.count >= 2 {
                        VStack(spacing: 8) {
                            WindowChartView(
                                title: "5-Hour Window",
                                history: history,
                                keyPath: \.fiveH,
                                resetISO: data.reset_5h_iso,
                                windowSecs: 5 * 3600,
                                color: .cluCyan
                            )
                            WindowChartView(
                                title: "7-Day Window",
                                history: history,
                                keyPath: \.sevenD,
                                resetISO: data.reset_7d_iso,
                                windowSecs: 7 * 86400,
                                color: .cluOrange
                            )
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }

                    Divider()
                        .padding(.horizontal, 16)

                    // Footer
                    HStack {
                        Text("Updated \(formatTimeAgo(service.lastUpdate))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Button("Refresh") { service.triggerRefresh() }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11))
                        Button("Quit") { NSApplication.shared.terminate(nil) }
                            .buttonStyle(.borderless)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                } else {
                    // Loading state
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.regular)
                        Text("Connecting to clu --serve...")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("clu --serve")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                }
            }
        }
        .frame(width: 340, height: service.data != nil ? 620 : 200)
    }
}

// MARK: - Token Formatting

func fmtTokens(_ n: Int?) -> String {
    guard let n = n, n > 0 else { return "0" }
    if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
    if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
    return "\(n)"
}

func fmtModel(_ name: String) -> String {
    var s = name.replacingOccurrences(of: "claude-", with: "")
    if let dash = s.firstIndex(of: "-") {
        let model = s[s.startIndex..<dash].capitalized
        let ver = s[s.index(after: dash)...]
        s = "\(model) \(ver)"
    } else {
        s = s.capitalized
    }
    return s
}

func isoToAgo(_ iso: String?) -> String {
    guard let iso = iso, let d = parseISO(iso) else { return "—" }
    return formatTimeAgo(d)
}

// MARK: - Dashboard Window View

struct DashboardWindowView: View {
    var service: UsageService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let data = service.data {
                    // Top: usage bars side by side
                    HStack(spacing: 16) {
                        // Left column: bars + pace
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                CluMascot()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Claude Usage")
                                        .font(.system(size: 16, weight: .bold))
                                    HStack(spacing: 6) {
                                        if let plan = data.plan, !plan.isEmpty {
                                            Text(plan.capitalized)
                                                .font(.system(size: 10, weight: .semibold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.cluViolet.opacity(0.15))
                                                .foregroundStyle(Color.cluViolet)
                                                .clipShape(Capsule())
                                        }
                                        if data.is_promo == true, let label = data.promo_label {
                                            Text("\u{26A1} \(label)")
                                                .font(.system(size: 10, weight: .bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.yellow.opacity(0.15))
                                                .foregroundStyle(.yellow)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }

                            UsageBar(label: "5-Hour Window", pct: data.pct_5h ?? 0, resetSecs: data.reset_5h_secs)
                            UsageBar(label: "7-Day Window", pct: data.pct_7d ?? 0, resetSecs: data.reset_7d_secs)

                            if let pace = data.pace_pct {
                                let pc = pace <= 100 ? Color.cluGreen : pace <= 150 ? Color.cluOrange : Color.cluRed
                                let icon = pace <= 100 ? "checkmark.circle.fill" : pace <= 150 ? "exclamationmark.triangle.fill" : "flame.fill"
                                HStack(spacing: 6) {
                                    Image(systemName: icon).font(.system(size: 12)).foregroundStyle(pc)
                                    Text("Pace \(Int(pace))%")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(pc)
                                    Text(pace <= 100 ? "under budget" : pace <= 150 ? "ahead" : "burning fast")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        // Right column: stats
                        VStack(alignment: .leading, spacing: 8) {
                            if let totals = data.totals {
                                StatRow(label: "Total tokens", value: fmtTokens(totals.tokens))
                                StatRow(label: "Projects", value: "\(totals.projects ?? 0)")
                                StatRow(label: "Sessions", value: "\(totals.sessions ?? 0)")
                                StatRow(label: "Messages", value: "\(totals.messages ?? 0)")
                                if let cache = totals.cache_hit_rate, cache > 0 {
                                    HStack {
                                        Text("Cache hit")
                                            .font(.system(size: 11)).foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(Int(cache))%")
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundStyle(cache > 80 ? Color.cluGreen : cache > 50 ? Color.cluAmber : Color.cluRed)
                                    }
                                }
                            }
                            if let extra = data.extra_usage, extra.enabled == true {
                                Divider()
                                HStack {
                                    Text("Extra credits")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("$\(Int(extra.used ?? 0)) / $\(Int(extra.limit ?? 0))")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Charts
                    if let history = data.history, history.count >= 2 {
                        HStack(spacing: 12) {
                            WindowChartView(
                                title: "5-Hour Window",
                                history: history,
                                keyPath: \.fiveH,
                                resetISO: data.reset_5h_iso,
                                windowSecs: 5 * 3600,
                                color: .cluCyan
                            )
                            WindowChartView(
                                title: "7-Day Window",
                                history: history,
                                keyPath: \.sevenD,
                                resetISO: data.reset_7d_iso,
                                windowSecs: 7 * 86400,
                                color: .cluOrange
                            )
                        }
                    }

                    // Projects
                    if let projects = data.projects, !projects.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Active Projects")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(projects) { p in
                                HStack {
                                    Text(p.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Text(fmtTokens(p.tokens))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.cluAmber)
                                    Text("\(p.sessions ?? 0)s")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 24, alignment: .trailing)
                                    Text(isoToAgo(p.last_active))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Sessions
                    if let sessions = data.sessions, !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recent Sessions")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                            ForEach(sessions) { s in
                                HStack {
                                    Text(s.project)
                                        .font(.system(size: 12, weight: .medium))
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(s.messages ?? 0) msgs")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    Text(fmtTokens(s.tokens))
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.cluCyan)
                                        .frame(width: 50, alignment: .trailing)
                                    Text(fmtModel(s.model ?? ""))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 60, alignment: .trailing)
                                    Text(isoToAgo(s.last_active))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                        .frame(width: 50, alignment: .trailing)
                                }
                            }
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    }

                    // Footer
                    HStack {
                        Text("Updated \(formatTimeAgo(service.lastUpdate))")
                            .font(.system(size: 10)).foregroundStyle(.tertiary)
                        Spacer()
                        Button("Refresh") { service.triggerRefresh() }
                            .buttonStyle(.borderless).font(.system(size: 11))
                    }
                } else {
                    VStack(spacing: 10) {
                        ProgressView().controlSize(.regular)
                        Text("Connecting to clu --serve...")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 500, idealWidth: 560, minHeight: 500, idealHeight: 700)
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold, design: .rounded))
        }
    }
}

// MARK: - App

@main
struct CLUMenuBarApp: App {
    @State private var service = UsageService()
    @State private var started = false
    @Environment(\.openWindow) private var openWindow

    private func ensurePolling() {
        if !started {
            started = true
            service.startPolling(interval: 30)
        }
    }

    var body: some Scene {
        // Menu bar popover
        MenuBarExtra {
            VStack(spacing: 0) {
                PopoverView(service: service)
                Divider()
                Button {
                    openWindow(id: "clu-window")
                } label: {
                    HStack {
                        Image(systemName: "macwindow")
                        Text("Open in Window")
                        Spacer()
                        Text("\u{2318}D")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("d", modifiers: .command)
            }
            .onAppear { ensurePolling() }
        } label: {
            if let data = service.data {
                let pct = data.pct_5h ?? 0
                let icon = pct >= 90 ? "\u{1F534}" : pct >= 70 ? "\u{1F7E0}" : pct >= 40 ? "\u{1F7E1}" : "\u{1F7E2}"
                let promo = data.is_promo == true ? "\u{26A1}" : ""
                Text("\(promo)\(icon) \(Int(pct))%")
            } else {
                Text("clu \u{00B7}\u{00B7}\u{00B7}")
            }
        }
        .menuBarExtraStyle(.window)

        // Dashboard window — full view with projects, sessions, charts
        Window("CLU", id: "clu-window") {
            DashboardWindowView(service: service)
                .onAppear {
                    ensurePolling()
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onDisappear {
                    if NSApp.windows.filter({ $0.isVisible && $0.title == "CLU" }).isEmpty {
                        NSApp.setActivationPolicy(.accessory)
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .defaultPosition(.topTrailing)
        .defaultSize(width: 560, height: 700)
    }
}
