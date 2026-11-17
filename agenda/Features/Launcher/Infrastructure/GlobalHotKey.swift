import AppKit
import Carbon.HIToolbox

/// A system-wide keyboard shortcut registered through Carbon, which works inside the app sandbox.
///
/// The shortcut stays registered while the instance is alive and is removed on deinit.
/// The action runs on the main thread.
final class GlobalHotKey {
    private static let signature: OSType = 0x41_47_4E_44 // "AGND"
    private static var nextID: UInt32 = 1

    private let id: UInt32
    private let action: () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Control-Option-Space, the shortcut that opens the launcher from any app.
    static func launcher(action: @escaping () -> Void) -> GlobalHotKey? {
        GlobalHotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), action: action)
    }

    /// Returns `nil` when the system refuses the shortcut, for example because another app owns it.
    init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        id = Self.nextID
        Self.nextID += 1
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var pressed = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &pressed
                )
                guard status == noErr else { return status }
                // Carbon delivers application-target events on the main thread.
                return MainActor.assumeIsolated {
                    Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue().handle(pressed)
                }
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        guard handlerStatus == noErr else { return nil }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        // A failed init still runs deinit, which removes the handler installed above.
        guard registerStatus == noErr else { return nil }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    private func handle(_ pressed: EventHotKeyID) -> OSStatus {
        guard pressed.signature == Self.signature, pressed.id == id else { return OSStatus(eventNotHandledErr) }
        action()
        return noErr
    }
}
