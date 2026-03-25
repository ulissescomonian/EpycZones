import AppKit
import Foundation
import Observation

@Observable
final class LayoutStore {
    static let shared = LayoutStore()

    var layouts: [Layout] = []
    var activeLayoutID: UUID?

    /// Per-screen layout assignments. Key = NSScreen.localizedName.
    var screenLayouts: [String: UUID] = [:]

    /// Default active layout (fallback when no per-screen assignment exists).
    var activeLayout: Layout? {
        layouts.first { $0.id == activeLayoutID }
    }

    /// Active layout for a specific screen. Falls back to the default active layout.
    func activeLayout(for screen: NSScreen) -> Layout? {
        if let id = screenLayouts[screen.localizedName],
           let layout = layouts.first(where: { $0.id == id }) {
            return layout
        }
        return activeLayout
    }

    private init() {
        load()
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EpycZones", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("layouts.json")
    }

    func save() {
        let model = StorageModel(layouts: layouts, activeLayoutID: activeLayoutID, screenLayouts: screenLayouts)
        guard let data = try? JSONEncoder().encode(model) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let model = try? JSONDecoder().decode(StorageModel.self, from: data) else { return }
        layouts = model.layouts
        activeLayoutID = model.activeLayoutID
        screenLayouts = model.screenLayouts ?? [:]
    }

    // MARK: - CRUD

    func addLayout(_ layout: Layout) {
        layouts.append(layout)
        if activeLayoutID == nil {
            activeLayoutID = layout.id
        }
        save()
    }

    func deleteLayout(id: UUID) {
        layouts.removeAll { $0.id == id }
        if activeLayoutID == id {
            activeLayoutID = layouts.first?.id
        }
        screenLayouts = screenLayouts.filter { entry in layouts.contains(where: { $0.id == entry.value }) }
        save()
    }

    func setActive(id: UUID) {
        activeLayoutID = id
        save()
    }

    func setActive(id: UUID, forScreen screenName: String) {
        screenLayouts[screenName] = id
        save()
    }

    func removeScreenAssignment(for screenName: String) {
        screenLayouts.removeValue(forKey: screenName)
        save()
    }

    /// Cycle to the next layout for the screen under the mouse cursor.
    /// If the screen has a per-screen assignment, cycles that. Otherwise cycles the default.
    func cycleLayout() {
        guard layouts.count > 1 else { return }

        let mouseScreen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
        let screenName = mouseScreen?.localizedName

        // Determine current layout for this screen
        let currentID: UUID?
        if let name = screenName, let id = screenLayouts[name] {
            currentID = id
        } else {
            currentID = activeLayoutID
        }

        // Find next layout
        let nextID: UUID
        if let currentID = currentID,
           let idx = layouts.firstIndex(where: { $0.id == currentID }) {
            nextID = layouts[(idx + 1) % layouts.count].id
        } else {
            nextID = layouts.first!.id
        }

        // Apply to the correct target
        if let name = screenName, screenLayouts[name] != nil {
            screenLayouts[name] = nextID
        }
        activeLayoutID = nextID
        save()
    }

    // MARK: - Storage Model

    private struct StorageModel: Codable {
        var layouts: [Layout]
        var activeLayoutID: UUID?
        var screenLayouts: [String: UUID]?
    }
}
