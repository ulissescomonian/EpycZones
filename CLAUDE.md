# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
make bundle   # release build + .app bundle with code signing
make run      # bundle + open
make debug    # debug build only (faster, no bundle)
make clean    # remove .build/ and .app
```

Code signing uses a self-signed cert "EpycZones Dev" from `/tmp/epyczones-dev.keychain` (empty password). If the keychain is missing, create one or change to ad-hoc signing (`--sign -`).

## Architecture

EpycZones is a **menu bar app** (LSUIElement=true) that manages window positions via the macOS Accessibility API. It has two independent interaction paths:

### Shift+Drag Path (no accessibility needed for detection)
`DragDetector` → `ZoneOverlayController` → `WindowManager.applyFrame()`

- **DragDetector**: NSEvent global+local monitors detect mouse drag + Shift modifier. Captures the focused window (`AXUIElement`) at drag start before overlay appears.
- **ZoneOverlayController**: Creates one transparent `NSPanel` (level `.screenSaver`, `ignoresMouseEvents=true`) per screen. Each panel hosts a `ZoneOverlayNSView` that draws zones.
- Zone hit-testing converts cursor position to relative [0–1] coords and finds primary zone + adjacent zones near boundaries (~20px threshold). Supports 1–4 zone spanning.
- On mouse up, snaps the captured window to the bounding rect of all highlighted zones.

### Hotkey Path (requires accessibility)
`HotKeyManager` → `WindowManager.snap()` / `snapToActiveZone()`

- Carbon `RegisterEventHotKey()` with C function pointer callback. The callback retrieves `HotKeyManager.shared` via `Unmanaged<HotKeyManager>.fromOpaque(userData)`.
- Bindings are customizable via `AppSettings.customHotKeys`. `HotKeyManager.reloadHotKeys()` unregisters all and re-registers with current bindings.

### Coordinate Systems (critical)
Three coordinate systems used throughout:

| System | Origin | Used by |
|--------|--------|---------|
| **NSScreen** | Bottom-left of primary screen | Screen geometry, animation targets |
| **AX (Accessibility)** | Top-left of primary screen | Window position/size via AXUIElement |
| **Relative (0–1)** | Top-left conceptual | Zone/layout storage, screen-independent |

Conversion: `axY = primaryScreenHeight - nsY - windowHeight`

`RelativeRect.frame(in: screenVisibleFrame, gap:)` converts relative → NSScreen coords with Y flip.

### Per-Screen Layouts
`LayoutStore` has both `activeLayoutID` (global fallback) and `screenLayouts: [String: UUID]` (keyed by `NSScreen.localizedName`). `activeLayout(for: NSScreen)` checks per-screen first, then falls back.

### Persistence
All JSON files in `~/Library/Application Support/EpycZones/`:
- `layouts.json` — layouts + per-screen assignments
- `window-zones.json` — window→zone records (max 200, for restore on launch)
- `workspaces.json` — saved workspace snapshots

Settings in UserDefaults (standard domain).

## Key Patterns

- **Activation policy toggle**: App is `.accessory` normally but switches to `.regular` when LayoutEditorView appears (so the window shows in Cmd+Tab), reverts on disappear.
- **Drag window capture**: `draggedWindow` is captured at drag start via AX API. If captured after overlay panels appear, the focused app may have changed.
- **Edge snap timer**: Configurable delay (0.1–1.0s) before overlay appears when dragging near screen edges without Shift.
- **Window animation**: 8 steps over 0.15s on `DispatchQueue.global(qos: .userInteractive)` with easeOutCubic. Falls back to instant snap if current frame unreadable.
- **Dark mode detection**: `NSApp.effectiveAppearance` is unreliable for accessory apps. Uses `UserDefaults["AppleInterfaceStyle"] == "Dark"` instead.
