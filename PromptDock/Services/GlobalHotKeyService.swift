import AppKit
import Carbon
import Foundation

struct HotKeyCombination: Codable, Equatable, Hashable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultQuickSearch = HotKeyCombination(
        keyCode: UInt32(kVK_ANSI_P),
        modifiers: UInt32(cmdKey | shiftKey)
    )

    var displayText: String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        text += Self.keyName(for: keyCode)
        return text
    }

    var isValid: Bool {
        let required = UInt32(cmdKey | optionKey | controlKey)
        return modifiers & required != 0
            && !Self.modifierOnlyKeyCodes.contains(keyCode)
    }

    static func from(event: NSEvent) -> HotKeyCombination {
        let flags = event.modifierFlags.intersection(
            .deviceIndependentFlagsMask
        )
        var carbonModifiers: UInt32 = 0
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        return HotKeyCombination(
            keyCode: UInt32(event.keyCode),
            modifiers: carbonModifiers
        )
    }

    private static let modifierOnlyKeyCodes: Set<UInt32> = [
        54, 55, 56, 57, 58, 59, 60, 61, 62, 63
    ]

    private static func keyName(for keyCode: UInt32) -> String {
        if let translatedName = translatedKeyName(for: keyCode) {
            return translatedName
        }

        let names: [UInt32: String] = [
            UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B",
            UInt32(kVK_ANSI_C): "C", UInt32(kVK_ANSI_D): "D",
            UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
            UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H",
            UInt32(kVK_ANSI_I): "I", UInt32(kVK_ANSI_J): "J",
            UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
            UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N",
            UInt32(kVK_ANSI_O): "O", UInt32(kVK_ANSI_P): "P",
            UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
            UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T",
            UInt32(kVK_ANSI_U): "U", UInt32(kVK_ANSI_V): "V",
            UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
            UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
            UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1",
            UInt32(kVK_ANSI_2): "2", UInt32(kVK_ANSI_3): "3",
            UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
            UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7",
            UInt32(kVK_ANSI_8): "8", UInt32(kVK_ANSI_9): "9",
            UInt32(kVK_Space): "Space", UInt32(kVK_Tab): "Tab",
            UInt32(kVK_Return): "↩", UInt32(kVK_Delete): "⌫",
            UInt32(kVK_Escape): "Esc", UInt32(kVK_UpArrow): "↑",
            UInt32(kVK_DownArrow): "↓", UInt32(kVK_LeftArrow): "←",
            UInt32(kVK_RightArrow): "→"
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }

    private static func translatedKeyName(for keyCode: UInt32) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?
            .takeRetainedValue(),
              let property = TISGetInputSourceProperty(
                inputSource,
                kTISPropertyUnicodeKeyLayoutData
              )
        else { return nil }

        let data = unsafeBitCast(property, to: CFData.self)
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafePointer<UCKeyboardLayout>(
            OpaquePointer(bytes)
        )
        var deadKeyState: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 8)
        var actualLength = 0
        let status = UCKeyTranslate(
            layout,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            characters.count,
            &actualLength,
            &characters
        )
        guard status == noErr, actualLength > 0 else { return nil }
        let name = String(
            utf16CodeUnits: characters,
            count: actualLength
        ).uppercased(with: .current)
        guard name.unicodeScalars.allSatisfy({ !$0.properties.isWhitespace })
        else { return nil }
        return name
    }
}

enum HotKeyConflictStatus: Equatable {
    case available
    case systemConflict
    case internalConflict
    case registrationFailed(OSStatus)
    case invalid
    case disabled

    var localizedDescription: String {
        switch self {
        case .available:
            String(localized: "No system conflict detected")
        case .systemConflict:
            String(localized: "Conflicts with a macOS system shortcut")
        case .internalConflict:
            String(localized: "Conflicts with a PromptDock shortcut")
        case .registrationFailed:
            String(localized: "This shortcut could not be registered")
        case .invalid:
            String(localized: "Include Command, Option, or Control and another key")
        case .disabled:
            String(localized: "Global quick search is off")
        }
    }
}

@MainActor
final class GlobalHotKeyService: ObservableObject {
    @Published private(set) var combination: HotKeyCombination
    @Published private(set) var conflictStatus: HotKeyConflictStatus = .disabled

    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var isEnabled = false

    init() {
        if let data = UserDefaults.standard.data(
            forKey: AppPreferences.globalQuickSearchHotKey
        ), let saved = try? JSONDecoder().decode(
            HotKeyCombination.self,
            from: data
        ) {
            combination = saved
        } else {
            combination = .defaultQuickSearch
        }
        installEventHandler()
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            _ = register(combination)
        } else {
            unregisterCurrent()
            conflictStatus = .disabled
        }
    }

    @discardableResult
    func apply(_ candidate: HotKeyCombination) -> Bool {
        guard candidate.isValid else { return rejectCandidate(with: .invalid) }
        guard !Self.internalShortcuts.contains(candidate) else {
            return rejectCandidate(with: .internalConflict)
        }
        guard !Self.conflictsWithSystemShortcut(candidate) else {
            return rejectCandidate(with: .systemConflict)
        }

        let previous = combination
        unregisterCurrent()
        guard !isEnabled || register(candidate) else {
            let failureStatus = conflictStatus
            _ = register(previous)
            conflictStatus = failureStatus
            return false
        }

        combination = candidate
        if !isEnabled { conflictStatus = .disabled }
        persist(candidate)
        return true
    }

    private func rejectCandidate(with status: HotKeyConflictStatus) -> Bool {
        if isEnabled, hotKeyRef == nil {
            _ = register(combination)
        }
        conflictStatus = status
        return false
    }

    func resetToDefault() {
        _ = apply(.defaultQuickSearch)
    }

    func suspendForRecording() {
        unregisterCurrent()
    }

    func resumeAfterRecording() {
        guard isEnabled else {
            conflictStatus = .disabled
            return
        }
        _ = register(combination)
    }

    private func register(_ candidate: HotKeyCombination) -> Bool {
        var registeredRef: EventHotKeyRef?
        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: 1
        )
        let status = RegisterEventHotKey(
            candidate.keyCode,
            candidate.modifiers,
            identifier,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &registeredRef
        )
        guard status == noErr, let registeredRef else {
            conflictStatus = .registrationFailed(status)
            return false
        }
        hotKeyRef = registeredRef
        conflictStatus = .available
        return true
    }

    private func unregisterCurrent() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func installEventHandler() {
        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, event != nil else {
                    return OSStatus(eventNotHandledErr)
                }
                let service = Unmanaged<GlobalHotKeyService>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in service.onTrigger?() }
                return OSStatus(noErr)
            },
            1,
            &specification,
            pointer,
            &eventHandlerRef
        )
    }

    private func persist(_ combination: HotKeyCombination) {
        guard let data = try? JSONEncoder().encode(combination) else {
            return
        }
        UserDefaults.standard.set(
            data,
            forKey: AppPreferences.globalQuickSearchHotKey
        )
    }

    private static let signature: OSType = 0x50444F43

    private static let internalShortcuts: Set<HotKeyCombination> = [
        HotKeyCombination(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey)),
        HotKeyCombination(keyCode: UInt32(kVK_ANSI_N), modifiers: UInt32(cmdKey | shiftKey)),
        HotKeyCombination(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(cmdKey | shiftKey)),
        HotKeyCombination(keyCode: UInt32(kVK_ANSI_E), modifiers: UInt32(cmdKey)),
        HotKeyCombination(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | shiftKey)),
        HotKeyCombination(keyCode: UInt32(kVK_ANSI_G), modifiers: UInt32(cmdKey)),
        HotKeyCombination(keyCode: UInt32(kVK_ANSI_G), modifiers: UInt32(cmdKey | shiftKey))
    ]

    private static func conflictsWithSystemShortcut(
        _ candidate: HotKeyCombination
    ) -> Bool {
        var unmanagedArray: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&unmanagedArray) == noErr,
              let array = unmanagedArray?.takeRetainedValue() as? [NSDictionary]
        else { return false }

        return array.contains { dictionary in
            guard (dictionary[kHISymbolicHotKeyEnabled] as? Bool) == true,
                  let code = dictionary[kHISymbolicHotKeyCode] as? NSNumber,
                  let modifiers = dictionary[kHISymbolicHotKeyModifiers]
                    as? NSNumber
            else { return false }
            return code.uint32Value == candidate.keyCode
                && modifiers.uintValue
                    == symbolicModifierMask(for: candidate.modifiers)
        }
    }

    private static func symbolicModifierMask(
        for carbonModifiers: UInt32
    ) -> UInt {
        var flags: NSEvent.ModifierFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbonModifiers & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonModifiers & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonModifiers & UInt32(controlKey) != 0 { flags.insert(.control) }
        return flags.rawValue
    }
}
