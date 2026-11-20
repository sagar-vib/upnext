import Carbon.HIToolbox
import Foundation

struct HotKey {
    let keyCode: UInt32
    let modifiers: UInt32
    let display: String

    static let togglePanel = HotKey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(optionKey), display: "⌥K")
    static let joinMeeting = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey), display: "⌥V")
}

/// System-wide shortcuts via Carbon hot keys, which need no Accessibility permission.
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    private var registered: [UInt32: (ref: EventHotKeyRef, action: () -> Void)] = [:]
    private var nextID: UInt32 = 1
    private var handlerInstalled = false

    func register(_ hotKey: HotKey, action: @escaping () -> Void) {
        installHandlerIfNeeded()
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x5550_4E58), id: id)
        let status = RegisterEventHotKey(hotKey.keyCode, hotKey.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        guard status == noErr, let ref else {
            NSLog("Upnext: could not register shortcut \(hotKey.display) (status \(status))")
            return
        }
        registered[id] = (ref: ref, action: action)
    }

    func unregisterAll() {
        for entry in registered.values {
            UnregisterEventHotKey(entry.ref)
        }
        registered.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        registered[id]?.action()
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), hotKeyHandler, 1, &eventType, nil, nil)
        handlerInstalled = true
    }
}

private func hotKeyHandler(_ nextHandler: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }
    let id = hotKeyID.id
    // Carbon delivers hot key events on the main thread.
    MainActor.assumeIsolated {
        HotKeyCenter.shared.fire(id)
    }
    return noErr
}
