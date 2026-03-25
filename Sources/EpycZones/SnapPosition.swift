import Foundation

enum SnapPosition: String, CaseIterable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case maximize
    case center

    var displayName: String {
        switch self {
        case .leftHalf:           return "Left Half"
        case .rightHalf:          return "Right Half"
        case .topHalf:            return "Top Half"
        case .bottomHalf:         return "Bottom Half"
        case .topLeftQuarter:     return "Top Left"
        case .topRightQuarter:    return "Top Right"
        case .bottomLeftQuarter:  return "Bottom Left"
        case .bottomRightQuarter: return "Bottom Right"
        case .maximize:           return "Maximize"
        case .center:             return "Center"
        }
    }

    var shortcutHint: String {
        switch self {
        case .leftHalf:           return "⌃⌥←"
        case .rightHalf:          return "⌃⌥→"
        case .topHalf:            return "⌃⌥↑"
        case .bottomHalf:         return "⌃⌥↓"
        case .topLeftQuarter:     return "⌃⌥U"
        case .topRightQuarter:    return "⌃⌥I"
        case .bottomLeftQuarter:  return "⌃⌥J"
        case .bottomRightQuarter: return "⌃⌥K"
        case .maximize:           return "⌃⌥⏎"
        case .center:             return "⌃⌥C"
        }
    }

    /// Calculate the target frame within a given screen area (NSScreen coordinates, bottom-left origin)
    func frame(in rect: CGRect) -> CGRect {
        let x = rect.origin.x
        let y = rect.origin.y
        let w = rect.width
        let h = rect.height
        let hw = w / 2
        let hh = h / 2

        switch self {
        case .leftHalf:
            return CGRect(x: x, y: y, width: hw, height: h)
        case .rightHalf:
            return CGRect(x: x + hw, y: y, width: hw, height: h)
        case .topHalf:
            return CGRect(x: x, y: y + hh, width: w, height: hh)
        case .bottomHalf:
            return CGRect(x: x, y: y, width: w, height: hh)
        case .topLeftQuarter:
            return CGRect(x: x, y: y + hh, width: hw, height: hh)
        case .topRightQuarter:
            return CGRect(x: x + hw, y: y + hh, width: hw, height: hh)
        case .bottomLeftQuarter:
            return CGRect(x: x, y: y, width: hw, height: hh)
        case .bottomRightQuarter:
            return CGRect(x: x + hw, y: y, width: hw, height: hh)
        case .maximize:
            return rect
        case .center:
            let cw = w * 0.6
            let ch = h * 0.8
            return CGRect(x: x + (w - cw) / 2, y: y + (h - ch) / 2, width: cw, height: ch)
        }
    }
}
