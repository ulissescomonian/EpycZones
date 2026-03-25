import Carbon
import Foundation

// Carbon hotkey callback — must be a non-capturing function usable as a C function pointer.
private func carbonHotKeyCallback(
    _: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event, let userData = userData else {
        return OSStatus(eventNotHandledErr)
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        UInt32(kEventParamDirectObject),
        UInt32(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.handleHotKey(id: hotKeyID.id)
    return noErr
}

final class HotKeyManager {
    static let shared = HotKeyManager()

    private var handlers: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1
    private var eventHandlerRef: EventHandlerRef?

    // FourCharCode signature: "EPZN"
    private let signature: OSType = {
        let chars: [UInt8] = [0x45, 0x50, 0x5A, 0x4E]  // E P Z N
        return OSType(chars[0]) << 24 | OSType(chars[1]) << 16 | OSType(chars[2]) << 8 | OSType(chars[3])
    }()

    private init() {
        installCarbonHandler()
    }

    // MARK: - Setup

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyCallback,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )
    }

    /// Register the default snap hotkeys.
    func registerDefaults() {
        let mods = UInt32(controlKey | optionKey)

        // Halves: Ctrl+Option + Arrow
        register(keyCode: UInt32(kVK_LeftArrow),  modifiers: mods, position: .leftHalf)
        register(keyCode: UInt32(kVK_RightArrow), modifiers: mods, position: .rightHalf)
        register(keyCode: UInt32(kVK_UpArrow),    modifiers: mods, position: .topHalf)
        register(keyCode: UInt32(kVK_DownArrow),  modifiers: mods, position: .bottomHalf)

        // Quarters: Ctrl+Option + U/I/J/K (spatial grid)
        //   U I
        //   J K
        register(keyCode: UInt32(kVK_ANSI_U), modifiers: mods, position: .topLeftQuarter)
        register(keyCode: UInt32(kVK_ANSI_I), modifiers: mods, position: .topRightQuarter)
        register(keyCode: UInt32(kVK_ANSI_J), modifiers: mods, position: .bottomLeftQuarter)
        register(keyCode: UInt32(kVK_ANSI_K), modifiers: mods, position: .bottomRightQuarter)

        // Maximize & Center
        register(keyCode: UInt32(kVK_Return), modifiers: mods, position: .maximize)
        register(keyCode: UInt32(kVK_ANSI_C), modifiers: mods, position: .center)

        // Move between monitors: Ctrl+Option + N/P
        register(keyCode: UInt32(kVK_ANSI_N), modifiers: mods) {
            WindowManager.moveToNextScreen()
        }
        register(keyCode: UInt32(kVK_ANSI_P), modifiers: mods) {
            WindowManager.moveToPreviousScreen()
        }

        // Cycle layouts: Ctrl+Option + L
        register(keyCode: UInt32(kVK_ANSI_L), modifiers: mods) {
            LayoutStore.shared.cycleLayout()
            LayoutNotification.show()
        }
    }

    /// Register hotkeys for zone indices 1-9 (Ctrl+Option+1 through Ctrl+Option+9).
    func registerZoneHotKeys() {
        let mods = UInt32(controlKey | optionKey)
        let numberKeyCodes: [UInt32] = [
            UInt32(kVK_ANSI_1), UInt32(kVK_ANSI_2), UInt32(kVK_ANSI_3),
            UInt32(kVK_ANSI_4), UInt32(kVK_ANSI_5), UInt32(kVK_ANSI_6),
            UInt32(kVK_ANSI_7), UInt32(kVK_ANSI_8), UInt32(kVK_ANSI_9),
        ]

        for (index, keyCode) in numberKeyCodes.enumerated() {
            let zoneIndex = index
            register(keyCode: keyCode, modifiers: mods) {
                WindowManager.snapToActiveZone(index: zoneIndex)
            }
        }
    }

    // MARK: - Registration

    private func register(keyCode: UInt32, modifiers: UInt32, position: SnapPosition) {
        register(keyCode: keyCode, modifiers: modifiers) {
            WindowManager.snap(to: position)
        }
    }

    private func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        handlers[id] = action

        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)

        if status == noErr, let ref = ref {
            hotKeyRefs.append(ref)
        }
    }

    // MARK: - Callback

    func handleHotKey(id: UInt32) {
        handlers[id]?()
    }

    deinit {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
        }
    }
}
