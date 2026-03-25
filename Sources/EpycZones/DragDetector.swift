import Cocoa
import ApplicationServices

/// Detects window dragging + Shift key to show zone overlays.
///
/// Uses NSEvent global + local monitors.
/// Global monitors track events to other apps; local monitors track events to our app
/// (needed when overlay panels are showing and our app receives focus).
final class DragDetector {
    private let overlay = ZoneOverlayController()

    private var globalMouseDownMonitor: Any?
    private var globalMouseDragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localMouseDragMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var localFlagsMonitor: Any?

    private var isMouseDown = false
    private var isDragging = false
    private var isOverlayVisible = false
    private var dragStartPos: NSPoint = .zero

    /// The window being dragged — captured before overlay appears so we don't lose the reference.
    private var draggedWindow: AXUIElement?

    /// Timer for edge snap delay.
    private var edgeSnapTimer: Timer?
    private var isWaitingForEdgeSnap = false

    private let dragThreshold: CGFloat = 5.0

    // MARK: - Lifecycle

    func start() {
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.onMouseDown()
        }
        globalMouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            self?.onMouseDragged()
        }
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.onMouseUp()
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.onFlagsChanged(flags: event.modifierFlags)
        }

        localMouseDragMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.onMouseDragged()
            return event
        }
        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.onMouseUp()
            return event
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.onFlagsChanged(flags: event.modifierFlags)
            return event
        }
    }

    func stop() {
        for m in [globalMouseDownMonitor, globalMouseDragMonitor, globalMouseUpMonitor,
                   globalFlagsMonitor, localMouseDragMonitor, localMouseUpMonitor, localFlagsMonitor] {
            if let m = m { NSEvent.removeMonitor(m) }
        }
    }

    // MARK: - Event Handlers

    private func onMouseDown() {
        isMouseDown = true
        isDragging = false
        draggedWindow = nil
        dragStartPos = NSEvent.mouseLocation
    }

    private func onMouseDragged() {
        let currentPos = NSEvent.mouseLocation

        if isMouseDown && !isDragging {
            let distance = hypot(currentPos.x - dragStartPos.x, currentPos.y - dragStartPos.y)
            if distance > dragThreshold {
                isDragging = true
                draggedWindow = getFocusedWindow()
            }
        }

        guard isDragging else { return }

        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        let nearEdge = AppSettings.shared.edgeSnapEnabled && isNearScreenEdge(currentPos)

        if shiftHeld && !isOverlayVisible {
            // Shift: show immediately
            cancelEdgeSnapTimer()
            showOverlay()
        } else if nearEdge && !isOverlayVisible && !shiftHeld {
            // Edge: show after delay
            if !isWaitingForEdgeSnap {
                startEdgeSnapTimer()
            }
        } else if !shiftHeld && !nearEdge && isOverlayVisible {
            cancelEdgeSnapTimer()
            hideOverlay(snap: false)
        } else if !nearEdge && isWaitingForEdgeSnap {
            cancelEdgeSnapTimer()
        }

        if isOverlayVisible {
            updateHighlight(at: currentPos)
        }
    }

    private func onMouseUp() {
        if isOverlayVisible {
            hideOverlay(snap: true)
        }
        isMouseDown = false
        isDragging = false
        draggedWindow = nil
    }

    private func onFlagsChanged(flags: NSEvent.ModifierFlags) {
        let shiftHeld = flags.contains(.shift)

        if shiftHeld && isDragging && !isOverlayVisible {
            showOverlay()
            updateHighlight(at: NSEvent.mouseLocation)
        } else if !shiftHeld && isOverlayVisible {
            hideOverlay(snap: false)
        }
    }

    // MARK: - Overlay

    private func showOverlay() {
        guard !isOverlayVisible else { return }
        // Check that at least one screen has a layout with zones
        let store = LayoutStore.shared
        guard NSScreen.screens.contains(where: { screen in
            let l = store.activeLayout(for: screen)
            return l != nil && !l!.zones.isEmpty
        }) else { return }
        isOverlayVisible = true
        overlay.show { screen in store.activeLayout(for: screen) }
    }

    private func updateHighlight(at nsPoint: NSPoint) {
        overlay.updateHighlight(zoneIndex: zoneIndex(at: nsPoint))
    }

    private func hideOverlay(snap: Bool) {
        let zoneIdx = overlay.highlightedZoneIndex
        isOverlayVisible = false
        overlay.hide()

        if snap, let index = zoneIdx, let window = draggedWindow {
            let mousePos = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mousePos) }),
                  let layout = LayoutStore.shared.activeLayout(for: screen),
                  index < layout.zones.count else { return }
            snapWindow(window, to: layout.zones[index], on: screen)
            WindowPersistence.record(window: window, zoneIndex: index, screen: screen, layoutID: layout.id)
        }
    }

    // MARK: - Window Snapping

    private func snapWindow(_ window: AXUIElement, to zone: Zone, on screen: NSScreen) {
        let targetNS = zone.rect.frame(in: screen.visibleFrame, gap: AppSettings.shared.zoneGap)
        DispatchQueue.global(qos: .userInteractive).async {
            WindowAnimator.animate(window: window, to: targetNS)
        }
    }

    // MARK: - AX Helpers

    private func getFocusedWindow() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }
        var focusedWindow: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedApp as! AXUIElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success else {
            return nil
        }
        return (focusedWindow as! AXUIElement)
    }

    // MARK: - Edge Snap Timer

    private func startEdgeSnapTimer() {
        isWaitingForEdgeSnap = true
        edgeSnapTimer = Timer.scheduledTimer(withTimeInterval: AppSettings.shared.edgeSnapDelay, repeats: false) { [weak self] _ in
            guard let self = self, self.isWaitingForEdgeSnap, self.isDragging else { return }
            self.isWaitingForEdgeSnap = false
            self.showOverlay()
            self.updateHighlight(at: NSEvent.mouseLocation)
        }
    }

    private func cancelEdgeSnapTimer() {
        edgeSnapTimer?.invalidate()
        edgeSnapTimer = nil
        isWaitingForEdgeSnap = false
    }

    // MARK: - Edge Detection

    private func isNearScreenEdge(_ point: NSPoint) -> Bool {
        let threshold = AppSettings.shared.edgeSnapThreshold
        for screen in NSScreen.screens {
            let f = screen.frame
            if point.x <= f.minX + threshold || point.x >= f.maxX - threshold ||
               point.y <= f.minY + threshold || point.y >= f.maxY - threshold {
                if f.insetBy(dx: -threshold, dy: -threshold).contains(point) {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Zone Hit-Testing

    private func zoneIndex(at nsPoint: NSPoint) -> Int? {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(nsPoint) }),
              let layout = LayoutStore.shared.activeLayout(for: screen) else { return nil }

        let vf = screen.visibleFrame
        let relX = (nsPoint.x - vf.origin.x) / vf.width
        let relY = 1.0 - (nsPoint.y - vf.origin.y) / vf.height

        for (index, zone) in layout.zones.enumerated() {
            let r = zone.rect
            if relX >= r.x && relX < r.x + r.width && relY >= r.y && relY < r.y + r.height {
                return index
            }
        }
        return nil
    }
}
