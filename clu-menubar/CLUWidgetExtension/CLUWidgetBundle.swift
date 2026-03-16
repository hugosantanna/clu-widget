import WidgetKit
import SwiftUI
import Charts

// MARK: - Timeline Provider

struct CLUEntry: TimelineEntry {
    let date: Date
    let data: WidgetData?
}

struct WidgetData: Codable {
    let pct_5h: Double?
    let pct_7d: Double?
    let reset_5h_secs: Int?
    let reset_7d_secs: Int?
    let pace_pct: Double?
    let plan: String?
    let is_promo: Bool?
    let promo_label: String?
    let history: [WSample]?
    let error: String?
}

struct WSample: Codable, Identifiable {
    let ts: Int
    let fiveH: Double
    let sevenD: Double

    var id: Int { ts }
    var date: Date { Date(timeIntervalSince1970: TimeInterval(ts)) }

    enum CodingKeys: String, CodingKey {
        case ts
        case fiveH = "5h"
        case sevenD = "7d"
    }
}

struct CLUProvider: TimelineProvider {
    func placeholder(in context: Context) -> CLUEntry {
        CLUEntry(date: .now, data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CLUEntry) -> Void) {
        fetchData { data in completion(CLUEntry(date: .now, data: data)) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CLUEntry>) -> Void) {
        fetchData { data in
            let entry = CLUEntry(date: .now, data: data)
            let next = Calendar.current.date(byAdding: .minute, value: 5, to: .now)!
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private func fetchData(completion: @escaping (WidgetData?) -> Void) {
        guard let url = URL(string: "http://localhost:8765/api") else {
            completion(nil); return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { completion(nil); return }
            completion(try? JSONDecoder().decode(WidgetData.self, from: data))
        }.resume()
    }
}

// MARK: - Colors

extension Color {
    static func wForPct(_ pct: Double) -> Color {
        if pct >= 90 { return Color(red: 0.94, green: 0.36, blue: 0.36) }
        if pct >= 70 { return Color(red: 0.96, green: 0.55, blue: 0.22) }
        if pct >= 40 { return Color(red: 0.96, green: 0.72, blue: 0.15) }
        return Color(red: 0.20, green: 0.78, blue: 0.55)
    }
    static let wCyan = Color(red: 0.25, green: 0.78, blue: 0.92)
    static let wOrange = Color(red: 0.96, green: 0.55, blue: 0.22)
    static let wViolet = Color(red: 0.65, green: 0.55, blue: 0.98)
    static let wGreen = Color(red: 0.20, green: 0.78, blue: 0.55)
}

func wFormatReset(_ secs: Int?) -> String {
    guard let s = secs, s > 0 else { return "—" }
    let h = (s % 86400) / 3600, m = (s % 3600) / 60
    let d = s / 86400
    if d > 0 { return "\(d)d \(h)h" }
    if h > 0 { return "\(h)h \(String(format: "%02d", m))m" }
    return "\(m)m"
}

// MARK: - Small Widget

struct SmallView: View {
    let entry: CLUEntry

    var body: some View {
        if let d = entry.data {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 4) {
                    Text("CLU")
                        .font(.system(size: 13, weight: .bold))
                    if d.is_promo == true {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.yellow)
                    }
                    Spacer()
                    if let plan = d.plan, !plan.isEmpty {
                        Text(plan.capitalized)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.wViolet)
                    }
                }

                // 5h bar
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("5h")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(d.pct_5h ?? 0))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.wForPct(d.pct_5h ?? 0))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(.quaternary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.wForPct(d.pct_5h ?? 0))
                                .frame(width: max(0, geo.size.width * (d.pct_5h ?? 0) / 100))
                        }
                    }
                    .frame(height: 7)
                }

                // 7d bar
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("7d")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(d.pct_7d ?? 0))%")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.wForPct(d.pct_7d ?? 0))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(.quaternary)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.wForPct(d.pct_7d ?? 0))
                                .frame(width: max(0, geo.size.width * (d.pct_7d ?? 0) / 100))
                        }
                    }
                    .frame(height: 7)
                }

                Spacer(minLength: 0)

                // Footer
                HStack(spacing: 4) {
                    if let pace = d.pace_pct {
                        let pc = pace <= 100 ? Color.wGreen : Color.wOrange
                        Image(systemName: pace <= 100 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(pc)
                        Text("\(Int(pace))%")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(pc)
                    }
                    Spacer()
                    Text(wFormatReset(d.reset_5h_secs))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(2)
        } else {
            VStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.secondary)
                Text("clu --serve")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Medium Widget

struct MediumView: View {
    let entry: CLUEntry

    var body: some View {
        if let d = entry.data {
            HStack(spacing: 10) {
                // Left side: bars
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Text("CLU")
                            .font(.system(size: 14, weight: .bold))
                        if d.is_promo == true {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 8))
                                Text(d.promo_label?.uppercased() ?? "2X")
                                    .font(.system(size: 8, weight: .heavy))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.8).gradient)
                            .clipShape(Capsule())
                        }
                        Spacer()
                        if let plan = d.plan, !plan.isEmpty {
                            Text(plan.capitalized)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Color.wViolet)
                        }
                    }

                    // 5h
                    HStack {
                        Text("5h").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(.quaternary)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.wForPct(d.pct_5h ?? 0))
                                    .frame(width: max(0, geo.size.width * (d.pct_5h ?? 0) / 100))
                            }
                        }
                        .frame(height: 7)
                        Text("\(Int(d.pct_5h ?? 0))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.wForPct(d.pct_5h ?? 0))
                            .frame(width: 36, alignment: .trailing)
                    }

                    // 7d
                    HStack {
                        Text("7d").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(.quaternary)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.wForPct(d.pct_7d ?? 0))
                                    .frame(width: max(0, geo.size.width * (d.pct_7d ?? 0) / 100))
                            }
                        }
                        .frame(height: 7)
                        Text("\(Int(d.pct_7d ?? 0))%")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.wForPct(d.pct_7d ?? 0))
                            .frame(width: 36, alignment: .trailing)
                    }

                    Spacer(minLength: 0)

                    HStack(spacing: 6) {
                        if let pace = d.pace_pct {
                            let pc = pace <= 100 ? Color.wGreen : Color.wOrange
                            Image(systemName: pace <= 100 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(pc)
                            Text("Pace \(Int(pace))%")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(pc)
                        }
                        Spacer()
                        Text(wFormatReset(d.reset_5h_secs))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                // Right side: chart
                if let history = d.history, history.count >= 2 {
                    Chart {
                        ForEach(history) { s in
                            AreaMark(x: .value("T", s.date), y: .value("U", s.fiveH))
                                .foregroundStyle(
                                    LinearGradient(colors: [Color.wCyan.opacity(0.3), Color.wCyan.opacity(0.02)],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .interpolationMethod(.catmullRom)
                        }
                        ForEach(history) { s in
                            LineMark(x: .value("T", s.date), y: .value("U", s.fiveH))
                                .foregroundStyle(Color.wCyan)
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYScale(domain: 0...100)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(2)
        } else {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(.secondary)
                Text("Run clu --serve")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Widget Definitions

struct CLUSmallWidget: Widget {
    let kind = "CLUSmall"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CLUProvider()) { entry in
            SmallView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CLU")
        .description("Claude usage at a glance")
        .supportedFamilies([.systemSmall])
    }
}

struct CLUMediumWidget: Widget {
    let kind = "CLUMedium"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CLUProvider()) { entry in
            MediumView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("CLU Dashboard")
        .description("Claude usage with chart")
        .supportedFamilies([.systemMedium])
    }
}

@main
struct CLUWidgetBundle: WidgetBundle {
    var body: some Widget {
        CLUSmallWidget()
        CLUMediumWidget()
    }
}
