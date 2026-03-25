import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var workspaces = WorkspaceManager.loadAll()
    @State private var newWorkspaceName = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            snappingTab
                .tabItem { Label("Snapping", systemImage: "rectangle.split.3x3") }
            workspacesTab
                .tabItem { Label("Workspaces", systemImage: "square.stack.3d.up") }
        }
        .frame(width: 420, height: 320)
        .padding()
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            Toggle("Animate window snapping", isOn: $settings.animateSnap)

            Section("Hotkeys") {
                Text("All hotkeys use ⌃⌥ (Ctrl+Option) as modifier")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    hotkeyRow("←→↑↓", "Snap to halves")
                    hotkeyRow("U/I/J/K", "Snap to quarters")
                    hotkeyRow("1-9", "Snap to zone")
                    hotkeyRow("Enter", "Maximize")
                    hotkeyRow("C", "Center")
                    hotkeyRow("N/P", "Next/prev monitor")
                    hotkeyRow("L", "Cycle layouts")
                    hotkeyRow("Shift+Drag", "Drag to zone")
                }
                .font(.system(.caption, design: .monospaced))
            }
        }
    }

    private func hotkeyRow(_ key: String, _ desc: String) -> some View {
        GridRow {
            Text(key)
                .frame(width: 100, alignment: .trailing)
                .foregroundStyle(.blue)
            Text(desc)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Snapping

    private var snappingTab: some View {
        Form {
            Section("Zone Gaps") {
                HStack {
                    Slider(value: $settings.zoneGap, in: 0...20, step: 1)
                    Text("\(Int(settings.zoneGap))px")
                        .frame(width: 40)
                        .monospacedDigit()
                }
            }

            Section("Edge Snapping") {
                Toggle("Snap when dragging to screen edge", isOn: $settings.edgeSnapEnabled)
                if settings.edgeSnapEnabled {
                    HStack {
                        Text("Trigger distance")
                        Slider(value: $settings.edgeSnapThreshold, in: 2...20, step: 1)
                        Text("\(Int(settings.edgeSnapThreshold))px")
                            .frame(width: 40)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Delay")
                        Slider(value: $settings.edgeSnapDelay, in: 0.1...1.0, step: 0.1)
                        Text(String(format: "%.1fs", settings.edgeSnapDelay))
                            .frame(width: 40)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    // MARK: - Workspaces

    private var workspacesTab: some View {
        Form {
            Section("Saved Workspaces") {
                if workspaces.isEmpty {
                    Text("No workspaces saved yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workspaces) { ws in
                        HStack {
                            Text(ws.name)
                            Spacer()
                            Text("\(ws.entries.count) windows")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Button("Restore") {
                                WorkspaceManager.restore(ws)
                            }
                            .buttonStyle(.bordered)
                            Button(role: .destructive) {
                                workspaces.removeAll { $0.id == ws.id }
                                WorkspaceManager.saveAll(workspaces)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("Capture") {
                HStack {
                    TextField("Workspace name", text: $newWorkspaceName)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Current") {
                        let name = newWorkspaceName.isEmpty ? "Workspace \(workspaces.count + 1)" : newWorkspaceName
                        let ws = WorkspaceManager.captureCurrentWorkspace(name: name)
                        workspaces.append(ws)
                        WorkspaceManager.saveAll(workspaces)
                        newWorkspaceName = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
