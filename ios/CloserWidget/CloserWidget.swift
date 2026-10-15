// Closer home-screen widget (iOS 17+, WidgetKit + App Intents).
//
// Each widget instance is configured with one group through "Edit Widget";
// instances are independent. Data is written by the Flutter app (home_widget)
// into the shared App Group "group.com.closerapp.closer":
//   closer.groups          JSON [{id, name, type}]            – group picker
//   closer.signedIn        "true" | "false"
//   closer.group.<id>      JSON {id, name, type, subtitle, updatedAt, imagePath}
// The widget never touches the network.

import AppIntents
import SwiftUI
import WidgetKit

private let appGroup = "group.com.closerapp.closer"

struct GroupIndexItem: Decodable {
    let id: String
    let name: String
    let type: String
}

struct GroupSnapshot: Decodable {
    let id: String
    let name: String
    let type: String
    let subtitle: String
    let imagePath: String?
}

enum SharedStore {
    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static func groups() -> [GroupIndexItem] {
        guard let raw = defaults?.string(forKey: "closer.groups"),
              let data = raw.data(using: .utf8),
              let items = try? JSONDecoder().decode([GroupIndexItem].self, from: data)
        else { return [] }
        return items
    }

    static func snapshot(_ id: String) -> GroupSnapshot? {
        guard let raw = defaults?.string(forKey: "closer.group.\(id)"),
              let data = raw.data(using: .utf8)
        else { return nil }
        return try? JSONDecoder().decode(GroupSnapshot.self, from: data)
    }

    static var signedIn: Bool { defaults?.string(forKey: "closer.signedIn") == "true" }
}

// MARK: - Configuration (per widget instance)

struct GroupEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Group")
    static var defaultQuery = GroupQuery()

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct GroupQuery: EntityQuery {
    func entities(for identifiers: [GroupEntity.ID]) async throws -> [GroupEntity] {
        SharedStore.groups().filter { identifiers.contains($0.id) }.map { GroupEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [GroupEntity] {
        SharedStore.groups().map { GroupEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectGroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Choose a group"
    static var description = IntentDescription("Each widget shows one of your Closer groups.")

    @Parameter(title: "Group")
    var group: GroupEntity?
}

// MARK: - Timeline

enum WidgetState {
    case signedOut
    case unconfigured
    case unavailable
    case group(GroupSnapshot, UIImage?)
}

struct CloserEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CloserEntry {
        CloserEntry(date: .now, state: .group(
            GroupSnapshot(id: "preview", name: "My Love", type: "couple", subtitle: "182 days", imagePath: nil),
            nil
        ))
    }

    func snapshot(for configuration: SelectGroupIntent, in context: Context) async -> CloserEntry {
        context.isPreview ? placeholder(in: context) : entry(for: configuration)
    }

    func timeline(for configuration: SelectGroupIntent, in context: Context) async -> Timeline<CloserEntry> {
        // No polling: the app asks WidgetKit to reload when something changes.
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectGroupIntent) -> CloserEntry {
        guard SharedStore.signedIn else { return CloserEntry(date: .now, state: .signedOut) }
        guard let id = configuration.group?.id else { return CloserEntry(date: .now, state: .unconfigured) }
        // Missing snapshot = access revoked or group deleted: show nothing private.
        guard let snap = SharedStore.snapshot(id) else { return CloserEntry(date: .now, state: .unavailable) }
        let image = snap.imagePath.flatMap { UIImage(contentsOfFile: $0) }
        return CloserEntry(date: .now, state: .group(snap, image))
    }
}

// MARK: - View

struct CloserWidgetView: View {
    let entry: CloserEntry

    private let coral = Color(red: 0.95, green: 0.42, blue: 0.50)

    var body: some View {
        switch entry.state {
        case .signedOut:
            message("Sign in to Closer to see your groups")
        case .unconfigured:
            message("Touch and hold, then Edit Widget to choose a group")
        case .unavailable:
            message("This group is no longer available")
        case let .group(snap, image):
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snap.name).font(.headline).foregroundStyle(.white).lineLimit(1)
                        Text(snap.subtitle).font(.caption).foregroundStyle(.white.opacity(0.9)).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if snap.type == "couple" {
                        Image(systemName: "heart.fill").foregroundStyle(coral).accessibilityHidden(true)
                    }
                }
                .padding(12)
            }
            .containerBackground(for: .widget) {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    sunset
                }
            }
            .widgetURL(URL(string: "com.closerapp.closer://group/\(snap.id)"))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(snap.name), \(snap.subtitle)")
        }
    }

    private var sunset: some View {
        LinearGradient(
            colors: [Color(red: 0.43, green: 0.36, blue: 0.60), Color(red: 0.91, green: 0.53, blue: 0.60), Color(red: 0.24, green: 0.23, blue: 0.40)],
            startPoint: .top, endPoint: .bottom
        )
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding()
            .containerBackground(for: .widget) { sunset }
    }
}

@main
struct CloserWidget: Widget {
    let kind = "CloserWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectGroupIntent.self, provider: Provider()) { entry in
            CloserWidgetView(entry: entry)
        }
        .configurationDisplayName("Closer")
        .description("The latest photo from one of your groups.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
