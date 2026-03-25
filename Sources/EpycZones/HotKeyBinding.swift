import Carbon
import Foundation

/// Persistable hotkey binding: a key code + modifier flags.
struct HotKeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // Carbon modifier flags

    /// Human-readable description, e.g. "⌃⌥←".
    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyCodeName(keyCode))
        return parts.joined()
    }

    static let defaultModifiers = UInt32(controlKey | optionKey)
}

/// All configurable hotkey actions.
enum HotKeyAction: String, CaseIterable, Identifiable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case maximize, center
    case nextMonitor, prevMonitor
    case cycleLayout

    var id: String { rawValue }

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
        case .nextMonitor:        return "Next Monitor"
        case .prevMonitor:        return "Prev Monitor"
        case .cycleLayout:        return "Cycle Layout"
        }
    }

    var defaultBinding: HotKeyBinding {
        let mods = HotKeyBinding.defaultModifiers
        switch self {
        case .leftHalf:           return HotKeyBinding(keyCode: UInt32(kVK_LeftArrow), modifiers: mods)
        case .rightHalf:          return HotKeyBinding(keyCode: UInt32(kVK_RightArrow), modifiers: mods)
        case .topHalf:            return HotKeyBinding(keyCode: UInt32(kVK_UpArrow), modifiers: mods)
        case .bottomHalf:         return HotKeyBinding(keyCode: UInt32(kVK_DownArrow), modifiers: mods)
        case .topLeftQuarter:     return HotKeyBinding(keyCode: UInt32(kVK_ANSI_U), modifiers: mods)
        case .topRightQuarter:    return HotKeyBinding(keyCode: UInt32(kVK_ANSI_I), modifiers: mods)
        case .bottomLeftQuarter:  return HotKeyBinding(keyCode: UInt32(kVK_ANSI_J), modifiers: mods)
        case .bottomRightQuarter: return HotKeyBinding(keyCode: UInt32(kVK_ANSI_K), modifiers: mods)
        case .maximize:           return HotKeyBinding(keyCode: UInt32(kVK_Return), modifiers: mods)
        case .center:             return HotKeyBinding(keyCode: UInt32(kVK_ANSI_C), modifiers: mods)
        case .nextMonitor:        return HotKeyBinding(keyCode: UInt32(kVK_ANSI_N), modifiers: mods)
        case .prevMonitor:        return HotKeyBinding(keyCode: UInt32(kVK_ANSI_P), modifiers: mods)
        case .cycleLayout:        return HotKeyBinding(keyCode: UInt32(kVK_ANSI_L), modifiers: mods)
        }
    }
}

/// Resolve binding: custom if set, otherwise default.
func resolvedBinding(for action: HotKeyAction) -> HotKeyBinding {
    AppSettings.shared.customHotKeys[action.rawValue] ?? action.defaultBinding
}

// MARK: - Key Code Name Lookup

func keyCodeName(_ keyCode: UInt32) -> String {
    switch Int(keyCode) {
    case kVK_LeftArrow:  return "←"
    case kVK_RightArrow: return "→"
    case kVK_UpArrow:    return "↑"
    case kVK_DownArrow:  return "↓"
    case kVK_Return:     return "⏎"
    case kVK_Tab:        return "⇥"
    case kVK_Space:      return "Space"
    case kVK_Delete:     return "⌫"
    case kVK_Escape:     return "⎋"
    case kVK_ANSI_A:     return "A"
    case kVK_ANSI_B:     return "B"
    case kVK_ANSI_C:     return "C"
    case kVK_ANSI_D:     return "D"
    case kVK_ANSI_E:     return "E"
    case kVK_ANSI_F:     return "F"
    case kVK_ANSI_G:     return "G"
    case kVK_ANSI_H:     return "H"
    case kVK_ANSI_I:     return "I"
    case kVK_ANSI_J:     return "J"
    case kVK_ANSI_K:     return "K"
    case kVK_ANSI_L:     return "L"
    case kVK_ANSI_M:     return "M"
    case kVK_ANSI_N:     return "N"
    case kVK_ANSI_O:     return "O"
    case kVK_ANSI_P:     return "P"
    case kVK_ANSI_Q:     return "Q"
    case kVK_ANSI_R:     return "R"
    case kVK_ANSI_S:     return "S"
    case kVK_ANSI_T:     return "T"
    case kVK_ANSI_U:     return "U"
    case kVK_ANSI_V:     return "V"
    case kVK_ANSI_W:     return "W"
    case kVK_ANSI_X:     return "X"
    case kVK_ANSI_Y:     return "Y"
    case kVK_ANSI_Z:     return "Z"
    case kVK_ANSI_0:     return "0"
    case kVK_ANSI_1:     return "1"
    case kVK_ANSI_2:     return "2"
    case kVK_ANSI_3:     return "3"
    case kVK_ANSI_4:     return "4"
    case kVK_ANSI_5:     return "5"
    case kVK_ANSI_6:     return "6"
    case kVK_ANSI_7:     return "7"
    case kVK_ANSI_8:     return "8"
    case kVK_ANSI_9:     return "9"
    default:             return "Key\(keyCode)"
    }
}
