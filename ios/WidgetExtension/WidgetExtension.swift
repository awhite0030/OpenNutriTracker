import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), consumedCalories: 0, calorieGoal: 2000)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), consumedCalories: 500, calorieGoal: 2000)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.opennutritracker")
        let consumedCalories = userDefaults?.double(forKey: "consumedCalories") ?? 0
        let calorieGoal = userDefaults?.double(forKey: "calorieGoal") ?? 0

        let entry = SimpleEntry(date: Date(), consumedCalories: consumedCalories, calorieGoal: calorieGoal)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let consumedCalories: Double
    let calorieGoal: Double
}

struct WidgetExtensionEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today's Progress")
                .font(.caption)
                .foregroundColor(.secondary)

            if entry.calorieGoal > 0 {
                let progress = min(entry.consumedCalories / entry.calorieGoal, 1.0)

                HStack(alignment: .lastTextBaseline) {
                    Text("\(Int(entry.consumedCalories))")
                        .font(.system(size: 24, weight: .bold))
                    Text("/ \(Int(entry.calorieGoal)) kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 8)

                        Capsule()
                            .fill(Color.green)
                            .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                    }
                }
                .frame(height: 8)
            } else {
                Text("No data available")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

@main
struct CalorieWidget: Widget {
    let kind: String = "CalorieWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            WidgetExtensionEntryView(entry: entry)
        }
        .configurationDisplayName("Calorie Progress")
        .description("Track your daily calorie consumption.")
        .supportedFamilies([.systemSmall])
    }
}
