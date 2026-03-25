# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
make bundle   # release build + .app bundle with code signing
make run      # bundle + open
make debug    # debug build only (faster, no bundle)
make dmg      # build + create DMG installer
make clean    # remove .build/ and .app
```

Code signing uses a self-signed cert "EpycZones Dev" from `/tmp/epyczones-dev.keychain` (empty password). If the keychain is missing, create one or change to ad-hoc signing (`--sign -`).

After each `make bundle`, the app must be re-added in **System Settings > Privacy & Security > Accessibility** if the signing identity changed.

## Architecture

EpycZones is a **menu bar app** (LSUIElement=true) that manages window positions via the macOS Accessibility API. It has two independent interaction paths:

### Shift+Drag Path (no accessibility needed for detection)
`DragDetector` → `ZoneOverlayController` → `WindowManager.applyFrame()`

- **DragDetector**: NSEvent global+local monitors detect mouse drag + Shift modifier. Captures the focused window (`AXUIElement`) at drag start before overlay appears.
- **ZoneOverlayController**: Creates one transparent `NSPanel` (level `.screenSaver`, `ignoresMouseEvents=true`) per screen. Each panel hosts a `ZoneOverlayNSView` that draws zones.
- Zone hit-testing converts cursor position to relative [0–1] coords and finds primary zone + adjacent zones near boundaries (~20px threshold). Supports 1–4 zone spanning.
- On mouse up, moves window to a **safe position** (top of screen) first, then snaps with `animated: false`. Animation is disabled for drag snaps to avoid clamping issues with intermediate positions.

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

## Critical: Window Frame Application (applyFrame)

**This is the most bug-prone area of the codebase.** Setting window position/size via AXUIElement has multiple pitfalls on macOS:

### SIZE → POSITION → SIZE (3 calls, not 2)
`WindowManager.applyFrame()` uses Rectangle's proven pattern:
1. `setSize()` — shrink window first so position change won't be clamped
2. `setPosition()` — move to target; safe because size is already small
3. `setSize()` — correct any size constraint from the old position

**Why not 2 calls?** macOS enforces that windows fit on the current display. If you set position first with a large old size, the window extends off-screen and macOS clamps the position. If you set size first then position, macOS may enforce size constraints from the old position. The third SIZE call fixes this.

### AXEnhancedUserInterface
Apps like Terminal and Xcode enable `AXEnhancedUserInterface` for VoiceOver, which blocks programmatic resize. `applyFrame()` disables it before resize and re-enables after. This is an undocumented private attribute.

### Drag snap: safe position first
After a drag, the window is at the cursor's drop position. For bottom zones (zones 3, 4 in a 2×2 grid), the drop position is low on screen. Calling SIZE at that position causes the window to extend past the screen bottom → macOS clamps → frame is corrupted. **Fix**: `DragDetector.onMouseUp()` moves the window to the top of the visible area before calling `applyFrame()`.

### Drag snap: no animation
Drag snaps use `animated: false`. Animation causes "gradual correction" artifacts because each interpolated step's intermediate size+position can trigger clamping. Hotkey snaps use animation (window is stationary, so intermediate steps are safe).

### WindowAnimator
Each animation frame also uses SIZE → POSITION → SIZE. All AX calls MUST be on main thread (macOS Tahoe crashes with "Must only be used from the main thread" otherwise).

## Key Patterns

- **Activation policy toggle**: App is `.accessory` normally but switches to `.regular` when LayoutEditorView appears (so the window shows in Cmd+Tab), reverts on disappear.
- **Electron app support**: `getFocusedWindow()` falls back to `NSWorkspace.shared.frontmostApplication` when the AX focused app PID differs from the window-owning PID (common with Electron apps like Termius where the launcher PID ≠ renderer PID).
- **Edge snap timer**: Configurable delay (0.1–1.0s) before overlay appears when dragging near screen edges without Shift.
- **Hotkey recording**: When recording a new shortcut in Settings, `HotKeyManager.unregisterAll()` is called first so Carbon hotkeys don't intercept the key press. After recording (or Esc to cancel), `reloadHotKeys()` re-registers everything.
- **Dynamic snap positions**: `makeSmaller`, `makeLarger`, `restore`, `maximizeHeight` need the current window frame. `WindowManager` handles these specially instead of using `SnapPosition.frame(in:)`.
- **Undo/Redo**: `WindowManager.undoStacks`/`redoStacks` store frames before each snap, keyed by PID+title hash. Max 20 entries per window.
- **Zone spanning**: DragDetector finds adjacent zones within ~20px of cursor from primary zone boundary, checking perpendicular axis overlap. At the center of 4 zones, all 4 highlight for fullscreen snap.
- **Move between Spaces**: NOT implemented. Private CGS APIs are unreliable on macOS Tahoe, and programmatic Space switching is blocked by macOS security.
- **Dark mode detection**: `NSApp.effectiveAppearance` is unreliable for accessory apps. Uses `UserDefaults["AppleInterfaceStyle"] == "Dark"` instead.
