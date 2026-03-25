import AppKit

/// Shows a brief HUD-style notification when the active layout changes.
enum LayoutNotification {
    private static var panel: NSPanel?
    private static var hideTimer: Timer?

    static func show() {
        guard let layout = LayoutStore.shared.activeLayout else { return }
        guard let screen = NSScreen.main else { return }

        hideTimer?.invalidate()

        let width: CGFloat = 260
        let height: CGFloat = 60
        let x = screen.frame.midX - width / 2
        let y = screen.frame.midY - height / 2 + screen.frame.height * 0.25

        let p = panel ?? {
            let newPanel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            newPanel.level = .floating
            newPanel.backgroundColor = .clear
            newPanel.isOpaque = false
            newPanel.hasShadow = false
            newPanel.ignoresMouseEvents = true
            newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel = newPanel
            return newPanel
        }()

        let view = LayoutNotificationView(name: layout.name, zoneCount: layout.zones.count)
        p.contentView = view
        p.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        p.orderFrontRegardless()
        p.alphaValue = 1.0

        // Fade out after 1.2 seconds
        hideTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                p.animator().alphaValue = 0
            } completionHandler: {
                p.orderOut(nil)
            }
        }
    }
}

private class LayoutNotificationView: NSView {
    let name: String
    let zoneCount: Int

    init(name: String, zoneCount: Int) {
        self.name = name
        self.zoneCount = zoneCount
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        // Rounded dark background
        let bg = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.75).setFill()
        bg.fill()

        // Layout name
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let nameStr = NSAttributedString(string: name, attributes: nameAttrs)
        let nameSize = nameStr.size()

        // Zone count
        let countAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.white.withAlphaComponent(0.6),
        ]
        let countStr = NSAttributedString(string: "\(zoneCount) zones", attributes: countAttrs)
        let countSize = countStr.size()

        let totalHeight = nameSize.height + countSize.height + 2
        let nameY = bounds.midY - totalHeight / 2 + countSize.height + 2
        let countY = bounds.midY - totalHeight / 2

        nameStr.draw(at: NSPoint(x: bounds.midX - nameSize.width / 2, y: nameY))
        countStr.draw(at: NSPoint(x: bounds.midX - countSize.width / 2, y: countY))
    }
}
