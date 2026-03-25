import AppKit
import ApplicationServices

enum WindowManager {

    /// Stores previous window frames for "Restore" functionality. Key = window hash.
    private static var previousFrames: [Int: CGRect] = [:]

    // MARK: - Public

    static func snap(to position: SnapPosition) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }

        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame

        // Handle dynamic positions
        switch position {
        case .restore:
            restoreWindow(window, screen: screen)
            return
        case .makeSmaller:
            resizeWindow(window, screen: screen, factor: 0.9)
            return
        case .makeLarger:
            resizeWindow(window, screen: screen, factor: 1.1)
            return
        case .maximizeHeight:
            maximizeHeight(window, screen: screen)
            return
        default:
            break
        }

        // Save current frame for restore
        saveFrame(of: window)

        let targetNS = position.frame(in: visibleFrame)
        applyFrame(targetNS, to: window)
    }

    static func snap(to zone: Zone) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }

        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        saveFrame(of: window)
        let gap = AppSettings.shared.zoneGap
        let targetNS = zone.rect.frame(in: screen.visibleFrame, gap: gap)
        applyFrame(targetNS, to: window)
    }

    static func snapToActiveZone(index: Int) {
        guard AccessibilityChecker.isGranted else { return }
        guard let window = getFocusedWindow() else { return }

        let screen = screenForWindow(window) ?? NSScreen.main ?? NSScreen.screens[0]
        guard let layout = LayoutStore.shared.activeLayout(for: screen),
              index < layout.zones.count else { return }

        saveFrame(of: window)
        let gap = AppSettings.shared.zoneGap
        let targetNS = layout.zones[index].rect.frame(in: screen.visibleFrame, gap: gap)
        applyFrame(targetNS, to: window)
        WindowPersistence.record(window: window, zoneIndex: index, screen: screen, layoutID: layout.id)
    }

    // MARK: - Dynamic Positions

    private static func restoreWindow(_ window: AXUIElement, screen: NSScreen) {
        let key = windowHash(window)
        if let prev = previousFrames[key] {
            previousFrames.removeValue(forKey: key)
            applyFrame(prev, to: window)
        }
    }

    private static func resizeWindow(_ window: AXUIElement, screen: NSScreen, factor: Double) {
        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return }

        let primaryHeight = NSScreen.screens[0].frame.height
        let nsX = axPos.x
        let nsY = primaryHeight - axPos.y - axSize.height

        let newW = axSize.width * factor
        let newH = axSize.height * factor
        // Keep centered
        let newX = nsX - (newW - axSize.width) / 2
        let newY = nsY - (newH - axSize.height) / 2

        let targetNS = CGRect(x: newX, y: newY, width: newW, height: newH)
        applyFrame(targetNS, to: window)
    }

    private static func maximizeHeight(_ window: AXUIElement, screen: NSScreen) {
        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return }

        saveFrame(of: window)
        let vf = screen.visibleFrame

        // Keep X and width, maximize height to visible frame
        let targetNS = CGRect(
            x: axPos.x,
            y: vf.origin.y,
            width: axSize.width,
            height: vf.height
        )
        applyFrame(targetNS, to: window)
    }

    private static func saveFrame(of window: AXUIElement) {
        guard let axPos = getPosition(of: window),
              let axSize = getSize(of: window) else { return }
        let primaryHeight = NSScreen.screens[0].frame.height
        let nsFrame = CGRect(
            x: axPos.x,
            y: primaryHeight - axPos.y - axSize.height,
            width: axSize.width,
            height: axSize.height
        )
        previousFrames[windowHash(window)] = nsFrame
    }

    private static func windowHash(_ window: AXUIElement) -> Int {
        var pid: pid_t = 0
        AXUIElementGetPid(window, &pid)
        // Combine PID with window title for uniqueness
        var title: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &title)
        let titleStr = (title as? String) ?? ""
        var hasher = Hasher()
        hasher.combine(pid)
        hasher.combine(titleStr)
        return hasher.finalize()
    }

    // MARK: - Move Between Monitors

    static func moveToNextScreen() { moveToScreen(offset: 1) }
    static func moveToPreviousScreen() { moveToScreen(offset: -1) }

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

        let primaryHeight = screens[0].frame.height
        let srcVF = currentScreen.visibleFrame
        let dstVF = targetScreen.visibleFrame

        let nsX = axPos.x
        let nsY = primaryHeight - axPos.y - axSize.height

        let relX = (nsX - srcVF.origin.x) / srcVF.width
        let relY = (nsY - srcVF.origin.y) / srcVF.height
        let relW = axSize.width / srcVF.width
        let relH = axSize.height / srcVF.height

        let targetNS = CGRect(
            x: dstVF.origin.x + relX * dstVF.width,
            y: dstVF.origin.y + relY * dstVF.height,
            width: relW * dstVF.width,
            height: relH * dstVF.height
        )
        applyFrame(targetNS, to: window)
    }


    // MARK: - Apply

    static func applyFrame(_ targetNS: CGRect, to window: AXUIElement, animated: Bool = true) {
        if animated && AppSettings.shared.animateSnap {
            // WindowAnimator handles main-thread dispatch internally
            WindowAnimator.animate(window: window, to: targetNS)
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
