import SwiftUI

@main
struct EpycZonesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var store = LayoutStore.shared

    var body: some Scene {
        MenuBarExtra("EpycZones", systemImage: "rectangle.split.2x2") {
            MenuBarView()
                .environment(store)
        }

        Window("Layout Editor", id: "layout-editor") {
            LayoutEditorView()
                .environment(store)
        }
        .defaultSize(width: 860, height: 560)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .defaultSize(width: 420, height: 320)
    }
}

struct MenuBarView: View {
    @Environment(LayoutStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        // Active layout zones
        if let layout = store.activeLayout, !layout.zones.isEmpty {
            Section("Zones — \(layout.name)") {
                ForEach(Array(layout.zones.prefix(9).enumerated()), id: \.element.id) { index, zone in
                    Button {
                        WindowManager.snap(to: zone)
                    } label: {
                        HStack {
                            Text(zone.name.isEmpty ? "Zone \(index + 1)" : zone.name)
                            Spacer()
                            Text("⌃⌥\(index + 1)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }

            Divider()
        }

        // Layout selection
        if store.layouts.count > 1 {
            Section("Layouts") {
                ForEach(store.layouts) { layout in
                    Button {
                        store.setActive(id: layout.id)
                    } label: {
                        HStack {
                            if layout.id == store.activeLayoutID {
                                Image(systemName: "checkmark")
                            }
                            Text(layout.name)
                        }
                    }
                }
            }

            Divider()
        }

        // Fixed snap positions
        Section("Halves") {
            snapButton(.leftHalf)
            snapButton(.rightHalf)
            snapButton(.topHalf)
            snapButton(.bottomHalf)
        }

        Section("Quarters") {
            snapButton(.topLeftQuarter)
            snapButton(.topRightQuarter)
            snapButton(.bottomLeftQuarter)
            snapButton(.bottomRightQuarter)
        }

        Section {
            snapButton(.maximize)
            snapButton(.center)
        }

        Divider()

        Button("Edit Layouts...") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "layout-editor")
        }

        Button("Settings...") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "settings")
        }

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func snapButton(_ position: SnapPosition) -> some View {
        Button {
            WindowManager.snap(to: position)
        } label: {
            HStack {
                Text(position.displayName)
                Spacer()
                Text(position.shortcutHint)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}
