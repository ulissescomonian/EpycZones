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
        // Visual layout preview
        if let layout = store.activeLayout, !layout.zones.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(layout.name)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                LayoutPreviewView(layout: layout)
                    .frame(width: 180, height: 100)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }

        // Active layout zones
        if let layout = store.activeLayout, !layout.zones.isEmpty {
            Section("Zones") {
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
            HStack(spacing: 8) {
                // Visual preview
                SnapPreviewIcon(rect: position.previewRect)
                    .frame(width: 20, height: 14)
                Text(position.displayName)
                Spacer()
            }
        }
    }
}

// MARK: - Layout Preview (mini zone map in menu bar)

struct LayoutPreviewView: View {
    let layout: Layout

    private let zoneColors: [Color] = [
        .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint, .cyan, .red,
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.05))
                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)

                ForEach(Array(layout.zones.enumerated()), id: \.element.id) { index, zone in
                    let r = zone.rect
                    let color = zoneColors[index % zoneColors.count]

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(color.opacity(0.6), lineWidth: 1)
                        )
                        .overlay(
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(color)
                        )
                        .frame(
                            width: r.width * geo.size.width - 2,
                            height: r.height * geo.size.height - 2
                        )
                        .position(
                            x: (r.x + r.width / 2) * geo.size.width,
                            y: (r.y + r.height / 2) * geo.size.height
                        )
                }
            }
        }
    }
}
