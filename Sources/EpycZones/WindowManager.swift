import AppKit
import ApplicationServices

enum WindowManager {

    // MARK: - Public

    static func snap(to position: SnapPosition) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }

        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let targetNS = position.frame(in: visibleFrame)

        applyFrame(targetNS, to: window)
    }

    static func snap(to zone: Zone) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }

        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let gap = AppSettings.shared.zoneGap
        let targetNS = zone.rect.frame(in: visibleFrame, gap: gap)

        applyFrame(targetNS, to: window)
    }

    /// Snap to the Nth zone (0-indexed) of the active layout for the focused window's screen.
    static func snapToActiveZone(index: Int) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }

        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        guard let layout = LayoutStore.shared.activeLayout(for: screen),
              index < layout.zones.count else { return }

        let gap = AppSettings.shared.zoneGap
        let targetNS = layout.zones[index].rect.frame(in: screen.visibleFrame, gap: gap)
        applyFrame(targetNS, to: window)
        WindowPersistence.record(window: window, zoneIndex: index, screen: screen, layoutID: layout.id)
    }

    // MARK: - Move Between Monitors

    static func moveToNextScreen() {
        moveToScreen(offset: 1)
    }

    static func moveToPreviousScreen() {
        moveToScreen(offset: -1)
    }

    private static func moveToScreen(offset: Int) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }
        let screens = NSScreen.screens
        guard screens.count > 1 else { return }

        let currentScreen = screenForWindow(window) ?? NSScreen.main ?? screens[0]
        guard let currentIndex = screens.firstIndex(where: { $0 == currentScreen }) else { return }

        let nextIndex = (currentIndex + offset + screens.count) % screens.count
        let targetScreen = screens[nextIndex]

        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return }

        // Convert current window rect to relative position within source screen's visibleFrame
        let primaryHeight = screens[0].frame.height
        let srcVF = currentScreen.visibleFrame
        let dstVF = targetScreen.visibleFrame

        // AX to NS coords for the window origin
        let nsX = axPos.x
        let nsY = primaryHeight - axPos.y - axSize.height

        // Relative position within source visible frame
        let relX = (nsX - srcVF.origin.x) / srcVF.width
        let relY = (nsY - srcVF.origin.y) / srcVF.height
        let relW = axSize.width / srcVF.width
        let relH = axSize.height / srcVF.height

        // Apply relative position to target visible frame
        let targetNS = CGRect(
            x: dstVF.origin.x + relX * dstVF.width,
            y: dstVF.origin.y + relY * dstVF.height,
            width: relW * dstVF.width,
            height: relH * dstVF.height
        )

        applyFrame(targetNS, to: window)
    }

    // MARK: - Apply

    private static func applyFrame(_ targetNS: CGRect, to window: AXUIElement, animated: Bool = true) {
        if animated {
            DispatchQueue.global(qos: .userInteractive).async {
                WindowAnimator.animate(window: window, to: targetNS)
            }
        } else {
            let primaryHeight = NSScreen.screens[0].frame.height
            setPosition(of: window, to: CGPoint(x: targetNS.origin.x, y: primaryHeight - targetNS.origin.y - targetNS.height))
            setSize(of: window, to: targetNS.size)
        }
    }

    // MARK: - AX Helpers

    private static func getFocusedWindow() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        ) == .success else { return nil }

        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(
            focusedApp as! AXUIElement,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindow
        ) == .success else { return nil }

        return (focusedWindow as! AXUIElement)
    }

    private static func setPosition(of window: AXUIElement, to point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }

    private static func setSize(of window: AXUIElement, to size: CGSize) {
        var s = size
        guard let value = AXValueCreate(.cgSize, &s) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }

    static func getPosition(of window: AXUIElement) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success else {
            return nil
        }
        var point = CGPoint.zero
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
        return point
    }

    static func getSize(of window: AXUIElement) -> CGSize? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success else {
            return nil
        }
        var size = CGSize.zero
        AXValueGetValue(value as! AXValue, .cgSize, &size)
        return size
    }

    static func screenForWindow(_ window: AXUIElement) -> NSScreen? {
        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return nil }

        let centerAX = CGPoint(x: axPos.x + axSize.width / 2, y: axPos.y + axSize.height / 2)
        let primaryHeight = NSScreen.screens[0].frame.height
        let centerNS = NSPoint(x: centerAX.x, y: primaryHeight - centerAX.y)

        for screen in NSScreen.screens {
            if screen.frame.contains(centerNS) {
                return screen
            }
        }
        return nil
    }
}
