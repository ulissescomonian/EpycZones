# EpycZones

**FancyZones for macOS** — A powerful window manager with custom zone layouts, drag-to-snap, and multi-monitor support.

EpycZones brings the best features of Windows PowerToys FancyZones to macOS, letting you define custom screen zones and snap windows into them with keyboard shortcuts or by dragging with Shift held.

### Layout Editor
![Layout Editor](screenshots/editor.png)

### Customizable Hotkeys
![Hotkeys Settings](screenshots/hotkeys.png)

### Menu Bar
![Menu Bar](screenshots/menubar.png)

## Features

### Window Snapping
- **30+ snap positions** — Halves, quarters, thirds, two-thirds, fourths, sixths, and more
- **Shift + Drag** — Hold Shift while dragging a window to see zone overlay, release to snap
- **Zone spanning** — Drag near the boundary of two zones to snap across both at once
- **Edge snapping** — Optionally trigger zones by dragging to screen edges (configurable delay)
- **Smooth animations** — Windows glide into position with ease-out cubic animation
- **Restore** — Return a window to its previous position before snapping
- **Resize** — Make windows incrementally smaller or larger

### Layout Editor
- **Visual zone editor** — Drag to move zones, drag corners or edges to resize
- **8 resize handles** — 4 corners + 4 edge midpoints for precise control
- **Snap-to-grid toggle** — 24×24 grid for alignment, or free-form for pixel-perfect editing
- **6 built-in templates** — 2 Columns, 3 Columns, 2 Rows, Grid 2×2, Priority Right, Focus Center
- **Unlimited custom layouts** — Create as many layouts as you need
- **Per-monitor layouts** — Assign different layouts to each connected display

### Multi-Monitor
- **Per-screen layout assignment** — Each monitor can have its own layout
- **Move windows between monitors** — `⌃⌥N` / `⌃⌥P` to send windows to next/previous screen
- **Proportional positioning** — Windows maintain their relative position when moving between screens

### Workspaces
- **Save window arrangements** — Capture the current position of all windows as a named workspace
- **Restore workspaces** — Instantly restore a saved arrangement with one click
- **Window persistence** — Remembers which app was in which zone and restores on app launch

### Customization
- **Customizable hotkeys** — Rebind any shortcut in Settings > Hotkeys
- **Visual shortcut previews** — Each shortcut shows a mini icon of the target position
- **Overlay themes** — Auto (follow system), Dark, or Light overlay appearance
- **Configurable zone gaps** — 0–20px spacing between zones
- **Edge snap with delay** — Adjustable trigger distance and delay to prevent accidental activation
- **Cycle layouts** — `⌃⌥L` to quickly switch between layouts on the current screen
- **Launch at Login** — Start EpycZones automatically with macOS

## Keyboard Shortcuts

All shortcuts use **⌃⌥** (Ctrl+Option) as the default modifier. Every shortcut is rebindable in Settings > Hotkeys.

### Halves
| Shortcut | Action |
|---|---|
| `⌃⌥ ←` | Left Half |
| `⌃⌥ →` | Right Half |
| `⌃⌥ ↑` | Top Half |
| `⌃⌥ ↓` | Bottom Half |

### Quarters
| Shortcut | Action |
|---|---|
| `⌃⌥ U` | Top Left |
| `⌃⌥ I` | Top Right |
| `⌃⌥ J` | Bottom Left |
| `⌃⌥ K` | Bottom Right |

### Thirds & Two-Thirds
| Shortcut | Action |
|---|---|
| `⌃⌥ D` | First Third |
| `⌃⌥ F` | Center Third |
| `⌃⌥ G` | Last Third |
| `⌃⌥ E` | First Two Thirds |
| `⌃⌥ R` | Center Two Thirds |
| `⌃⌥ T` | Last Two Thirds |

### Special
| Shortcut | Action |
|---|---|
| `⌃⌥ Enter` | Maximize |
| `⌃⌥ H` | Maximize Height |
| `⌃⌥ C` | Center (60% × 80%) |
| `⌃⌥ -` | Make Smaller |
| `⌃⌥ =` | Make Larger |
| `⌃⌥ ⌫` | Restore previous position |

### Navigation
| Shortcut | Action |
|---|---|
| `⌃⌥ N` | Move window to next monitor |
| `⌃⌥ P` | Move window to previous monitor |
| `⌃⌥ L` | Cycle to next layout |
| `⌃⌥ 1-9` | Snap to zone 1–9 of active layout |
| `Shift + Drag` | Drag window to zone overlay |

## Requirements

- **macOS 14.0** (Sonoma) or later
- **Accessibility permission** — Required to move and resize windows from other apps

## Build & Run

```bash
# Clone the repository
git clone https://github.com/ulissescomonian/EpycZones.git
cd EpycZones

# Build and create .app bundle
make bundle

# Run
make run
```

### Build Requirements

- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

### Development

```bash
# Debug build (faster compilation)
make debug

# Clean build artifacts
make clean
```

## Project Structure

```
EpycZones/
├── Package.swift                           # Swift Package Manager config
├── Makefile                                # Build & bundle automation
├── Resources/
│   ├── Info.plist                          # App bundle configuration
│   └── AppIcon.icns                       # App icon
└── Sources/EpycZones/
    ├── EpycZonesApp.swift                  # App entry point + menu bar
    ├── AppDelegate.swift                   # App lifecycle + setup
    ├── AppSettings.swift                   # User preferences
    │
    ├── Zone.swift                          # Zone model + RelativeRect
    ├── Layout.swift                        # Layout model + templates
    ├── LayoutStore.swift                   # Layout persistence + per-screen assignments
    ├── SnapPosition.swift                  # 30+ built-in snap positions
    ├── HotKeyBinding.swift                 # Hotkey model + action definitions
    │
    ├── WindowManager.swift                 # AXUIElement window control
    ├── WindowAnimator.swift                # Smooth snap animations
    ├── WindowPersistence.swift             # Remember window-zone assignments
    ├── WorkspaceManager.swift              # Save/restore complete workspaces
    │
    ├── DragDetector.swift                  # Shift+drag detection (NSEvent monitors)
    ├── ZoneOverlayController.swift         # Transparent overlay panels
    ├── LayoutNotification.swift            # HUD notification
    │
    ├── HotKeyManager.swift                 # Carbon global hotkeys
    ├── AccessibilityChecker.swift          # Accessibility permission handling
    │
    ├── LayoutEditorView.swift              # Visual layout editor (SwiftUI)
    ├── ZoneCanvasView.swift                # Interactive zone canvas
    └── SettingsView.swift                  # Settings UI (4 tabs)
```

## How It Works

EpycZones runs as a **menu bar app** (no Dock icon). It uses:

- **Accessibility API** (`AXUIElement`) to move and resize windows from other apps
- **NSEvent global/local monitors** to detect Shift+drag without intercepting system events
- **Carbon `RegisterEventHotKey`** for global keyboard shortcuts (fully customizable)
- **SwiftUI** for the layout editor, settings, and menu bar preview
- **AppKit** (`NSPanel`) for transparent zone overlays with dark/light theme support

## Acknowledgments

- Inspired by [FancyZones](https://learn.microsoft.com/en-us/windows/powertoys/fancyzones) from Microsoft PowerToys

## License

MIT License — see [LICENSE](LICENSE) for details.
