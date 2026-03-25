import Carbon
import SwiftUI

struct SettingsView: View {
    @State private var settings = AppSettings.shared
    @State private var workspaces = WorkspaceManager.loadAll()
    @State private var newWorkspaceName = ""
    @State private var recordingAction: HotKeyAction?

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            snappingTab
                .tabItem { Label("Snapping", systemImage: "rectangle.split.3x3") }
            hotkeysTab
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            workspacesTab
                .tabItem { Label("Workspaces", systemImage: "square.stack.3d.up") }
        }
        .frame(width: 480, height: 400)
        .padding()
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            Toggle("Animate window snapping", isOn: $settings.animateSnap)

            Section("Overlay Theme") {
                Picker("Theme", selection: $settings.overlayTheme) {
                    Text("Auto (follow system)").tag("auto")
                    Text("Dark").tag("dark")
                    Text("Light").tag("light")
                }
                .pickerStyle(.radioGroup)
            }
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

    // MARK: - Hotkeys

    private var hotkeysTab: some View {
        Form {
            Section("Keyboard Shortcuts") {
                Text("Click a shortcut and press new keys to rebind. Shift+Drag is always active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    ForEach(HotKeyAction.allCases) { action in
                        GridRow {
                            Text(action.displayName)
                                .frame(width: 120, alignment: .trailing)

                            hotkeyButton(for: action)
                                .frame(width: 100)
                        }
                    }
                }
            }

            Section {
                Button("Reset All to Defaults") {
                    settings.customHotKeys = [:]
                    HotKeyManager.shared.reloadHotKeys()
                }
            }
        }
    }

    private func hotkeyButton(for action: HotKeyAction) -> some View {
        let binding = resolvedBinding(for: action)
        let isRecording = recordingAction == action

        return Button {
            recordingAction = action
        } label: {
            Text(isRecording ? "Press keys..." : binding.displayString)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isRecording ? .orange : .primary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .onKeyPress(phases: .down) { press in
            guard recordingAction == action else { return .ignored }

            var carbonMods: UInt32 = 0
            if press.modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
            if press.modifiers.contains(.option) { carbonMods |= UInt32(optionKey) }
            if press.modifiers.contains(.shift) { carbonMods |= UInt32(shiftKey) }
            if press.modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }

            // Only save if at least one modifier is held
            guard carbonMods != 0 else { return .ignored }

            let keyCode = carbonKeyCode(from: press.key)
            guard keyCode != UInt32.max else { return .ignored }

            settings.customHotKeys[action.rawValue] = HotKeyBinding(keyCode: keyCode, modifiers: carbonMods)
            HotKeyManager.shared.reloadHotKeys()
            recordingAction = nil
            return .handled
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

// MARK: - Key Press → Carbon Key Code

/// Convert a SwiftUI KeyEquivalent character to a Carbon virtual key code.
private func carbonKeyCode(from key: KeyEquivalent) -> UInt32 {
    let ch = key.character
    let map: [Character: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    ]

    // Arrow keys and special keys
    switch ch {
    case "\u{F702}": return UInt32(kVK_LeftArrow)   // NSLeftArrowFunctionKey
    case "\u{F703}": return UInt32(kVK_RightArrow)
    case "\u{F700}": return UInt32(kVK_UpArrow)
    case "\u{F701}": return UInt32(kVK_DownArrow)
    case "\r", "\n": return UInt32(kVK_Return)
    case "\t":       return UInt32(kVK_Tab)
    case " ":        return UInt32(kVK_Space)
    default: break
    }

    if let code = map[Character(String(ch).lowercased())] {
        return UInt32(code)
    }
    return UInt32.max
}
