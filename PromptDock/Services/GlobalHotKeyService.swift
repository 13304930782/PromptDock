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

        let value = Unmanaged<AnyObject>
            .fromOpaque(property)
            .takeUnretainedValue()
        guard let data = value as? NSData,
              data.length >= MemoryLayout<UCKeyboardLayout>.size
        else { return nil }
        let bytes = data.bytes.assumingMemoryBound(to: UInt8.self)
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
protocol GlobalHotKeyRegistering: AnyObject {
    var onTrigger: (() -> Void)? { get set }
    func register(_ combination: HotKeyCombination) -> OSStatus
    func unregister()
}

@MainActor
final class CarbonGlobalHotKeyRegistrar: GlobalHotKeyRegistering {
    var onTrigger: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let identifier = EventHotKeyID(
        signature: CarbonGlobalHotKeyRegistrar.fourCharacterCode("PDOC"),
        id: UInt32.random(in: 1...UInt32.max)
    )

    init() {
        installEventHandler()
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }

    func register(_ combination: HotKeyCombination) -> OSStatus {
        unregister()
        var registeredRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combination.keyCode,
            combination.modifiers,
            identifier,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &registeredRef
        )
        if status == noErr {
            hotKeyRef = registeredRef
        }
        return status
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func installEventHandler() {
        var specification = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // The handler is removed in deinit, so this callback cannot outlive self.
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData, let event else {
                    return OSStatus(eventNotHandledErr)
                }
                let registrar = Unmanaged<CarbonGlobalHotKeyRegistrar>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                var receivedID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &receivedID
                )
                guard status == noErr,
                      receivedID.signature == registrar.identifier.signature,
                      receivedID.id == registrar.identifier.id
                else {
                    return OSStatus(eventNotHandledErr)
                }
                Task { @MainActor in registrar.onTrigger?() }
                return OSStatus(noErr)
            },
            1,
            &specification,
            pointer,
            &eventHandlerRef
        )
    }

    private static func fourCharacterCode(_ value: String) -> OSType {
        value.utf8.reduce(0) { partialResult, byte in
            (partialResult << 8) | OSType(byte)
        }
    }
}

@MainActor
final class GlobalHotKeyService: ObservableObject {
    @Published private(set) var combination: HotKeyCombination
    @Published private(set) var conflictStatus: HotKeyConflictStatus = .disabled

    var onTrigger: (() -> Void)? {
        didSet { registrar.onTrigger = onTrigger }
    }

    private let registrar: GlobalHotKeyRegistering
    private var hasRegisteredHotKey = false
    private var isEnabled = false

    init(registrar: GlobalHotKeyRegistering? = nil) {
        self.registrar = registrar ?? CarbonGlobalHotKeyRegistrar()
        if let saved = AppPreferences.loadGlobalQuickSearchHotKey() {
            combination = saved
        } else {
            combination = .defaultQuickSearch
        }
        self.registrar.onTrigger = { [weak self] in
            self?.onTrigger?()
        }
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
        if isEnabled, !hasRegisteredHotKey {
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
        let status = registrar.register(candidate)
        guard status == noErr else {
            hasRegisteredHotKey = false
            conflictStatus = .registrationFailed(status)
            return false
        }
        hasRegisteredHotKey = true
        conflictStatus = .available
        return true
    }

    private func unregisterCurrent() {
        registrar.unregister()
        hasRegisteredHotKey = false
    }

    private func persist(_ combination: HotKeyCombination) {
        try? AppPreferences.saveGlobalQuickSearchHotKey(combination)
    }

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
