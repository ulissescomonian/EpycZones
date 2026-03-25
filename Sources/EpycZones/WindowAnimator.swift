import AppKit
import ApplicationServices

/// Animates window snapping with smooth interpolation.
enum WindowAnimator {
    private static let steps = 8
    private static let totalDuration: TimeInterval = 0.15

    /// Smoothly animate a window from its current position/size to a target frame.
    /// `targetNS` is in NSScreen coordinates (bottom-left origin).
    static func animate(window: AXUIElement, to targetNS: CGRect) {
        let primaryHeight = NSScreen.screens[0].frame.height

        // Get current window frame in AX coords
        guard let currentPos = WindowManager.getPosition(of: window),
              let currentSize = WindowManager.getSize(of: window) else {
            // Fallback: instant snap
            applyAX(window: window, targetNS: targetNS, primaryHeight: primaryHeight)
            return
        }

        // Target in AX coords
        let targetAX = CGPoint(x: targetNS.origin.x, y: primaryHeight - targetNS.origin.y - targetNS.height)
        let targetSize = targetNS.size

        let stepInterval = totalDuration / Double(steps)

        for i in 1...steps {
            let t = easeOutCubic(Double(i) / Double(steps))

            let x = currentPos.x + (targetAX.x - currentPos.x) * t
            let y = currentPos.y + (targetAX.y - currentPos.y) * t
            let w = currentSize.width + (targetSize.width - currentSize.width) * t
            let h = currentSize.height + (targetSize.height - currentSize.height) * t

            var pos = CGPoint(x: x, y: y)
            if let val = AXValueCreate(.cgPoint, &pos) {
                AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, val)
            }
            var size = CGSize(width: w, height: h)
            if let val = AXValueCreate(.cgSize, &size) {
                AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, val)
            }

            if i < steps {
                Thread.sleep(forTimeInterval: stepInterval)
            }
        }
    }

    private static func applyAX(window: AXUIElement, targetNS: CGRect, primaryHeight: CGFloat) {
        var pos = CGPoint(x: targetNS.origin.x, y: primaryHeight - targetNS.origin.y - targetNS.height)
        if let val = AXValueCreate(.cgPoint, &pos) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, val)
        }
        var size = CGSize(width: targetNS.width, height: targetNS.height)
        if let val = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, val)
        }
    }

    /// Ease-out cubic: fast start, smooth deceleration.
    private static func easeOutCubic(_ t: Double) -> Double {
        1 - pow(1 - t, 3)
    }
}
