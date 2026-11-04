import Foundation

// Platform-independent, fail-closed rules. Tests run without touching a display.
struct DisplayInfo: Codable, Equatable {
    let id: UInt32
    let name: String
    let builtin: Bool
    let online: Bool
    let active: Bool
    let asleep: Bool
    let mirrored: Bool
    let vendor: UInt32
    let model: UInt32
    let width: Int
    let height: Int

    var looksVirtual: Bool {
        let n = name.lowercased()
        return vendor == 0 || vendor == UInt32.max || model == UInt32.max ||
            vendor == 0x756e6b6e || model == 0x76697274 ||
            ["virtual", "airplay", "sidecar", "dummy", "displaylink", "duet", "luna display"].contains { n.contains($0) }
    }
    // A heuristic, not proof of a physical connection. The user must also confirm
    // that the control window is visibly on the actual wired HDMI monitor.
    var usableExternal: Bool {
        !builtin && online && active && !asleep && !mirrored &&
        !looksVirtual && width > 1 && height > 1
    }
}

enum SoloPolicy {
    static let trialSeconds: Double = 20
    static let heartbeatSeconds: Double = 10

    static func refusal(displays: [DisplayInfo], builtin: UInt32, external: UInt32) -> String? {
        let internalDisplays = displays.filter { $0.builtin }
        guard internalDisplays.count == 1, let panel = internalDisplays.first,
              panel.id == builtin else { return "無法唯一辨識內建螢幕；不執行停用。" }
        guard panel.online && panel.active && !panel.asleep else {
            return "內建螢幕目前不是可測試狀態；請先恢復並喚醒螢幕。"
        }
        guard !panel.mirrored else { return "請先在系統設定關閉鏡像顯示，使用延伸桌面。" }
        guard external != builtin, let output = displays.first(where: { $0.id == external }),
              output.usableExternal else {
            return "找不到已喚醒的實體外接螢幕，或偵測到鏡像／虛擬顯示器；已拒絕停用。"
        }
        return nil
    }
}

enum GuardAction: Equatable { case none, restore, stopForShutdown }

struct GuardPolicy {
    let started: Double
    var lastHeartbeat: Double
    var confirmed = false
    var verifiedOffline = false
    var suspended = false
    var resumeNeedsRestore = false
    var shuttingDown = false
    var parentAlive = true
    var externalStillOnline = true
    var manualRestore = false

    func action(now: Double) -> GuardAction {
        // Never reconfigure displays while macOS is logging out/powering off.
        if shuttingDown { return .stopForShutdown }
        if suspended { return .none }
        if manualRestore || resumeNeedsRestore || !parentAlive || !externalStillOnline { return .restore }
        if !now.isFinite || now < started || now - lastHeartbeat >= SoloPolicy.heartbeatSeconds { return .restore }
        if !confirmed && now - started >= SoloPolicy.trialSeconds { return .restore }
        return .none
    }
    mutating func confirm(now: Double) -> Bool {
        guard verifiedOffline, !suspended, action(now: now) == .none,
              now - started < SoloPolicy.trialSeconds else { return false }
        confirmed = true
        return true
    }
}
