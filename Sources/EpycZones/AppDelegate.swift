import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private let dragDetector = DragDetector()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Load window persistence data
        WindowPersistence.load()

        // Drag detection works without accessibility (uses NSEvent monitors)
        dragDetector.start()

        // Hotkeys + window snapping require accessibility
        if AccessibilityChecker.isGranted {
            onAccessibilityReady()
        } else {
            AccessibilityChecker.requestAccess()
            pollAccessibility()
        }
    }

    private func onAccessibilityReady() {
        HotKeyManager.shared.registerDefaults()
        HotKeyManager.shared.registerZoneHotKeys()

        // Restore windows to their last recorded zones (delayed to let apps finish launching)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            WindowPersistence.restoreAll()
        }
    }

    private func pollAccessibility() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            if AccessibilityChecker.isGranted {
                timer.invalidate()
                self?.onAccessibilityReady()
            }
        }
    }
}
