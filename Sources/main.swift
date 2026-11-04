import AppKit
import Foundation
import Darwin

func restoreCommand() -> Int32 {
    let bridge = DisplayBridge()
    guard bridge.available else { print(bridge.capabilityText); return 3 }
    let lockPath = supportDirectory().appendingPathComponent("guardian.lock").path
    let fd = Darwin.open(lockPath, O_CREAT | O_RDWR, 0o600)
    guard fd >= 0 else { print("無法建立恢復程序鎖定。"); return 5 }
    defer { flock(fd, LOCK_UN); Darwin.close(fd) }
    guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
        // Ask the existing single writer to restore; do not race it with a second transaction.
        DistributedNotificationCenter.default().postNotificationName(restoreNotificationName,
            object: nil, userInfo: nil, deliverImmediately: true)
        print("已通知執行中的安全監控恢復內建螢幕。")
        for _ in 0..<24 {
            Thread.sleep(forTimeInterval: 0.25)
            if bridge.builtinOnline() { print("已確認內建螢幕回到線上桌面。"); return 0 }
        }
        print("尚未確認恢復。請先重新接上外接螢幕；若系統失去回應，請正常重新啟動。")
        return 4
    }
    if bridge.builtinOnline() { print("內建螢幕已在線上桌面；未更動其他螢幕。"); return 0 }
    print(bridge.attemptRestore())
    for i in 0..<12 {
        Thread.sleep(forTimeInterval: 0.25)
        if bridge.builtinOnline() {
            try? FileManager.default.removeItem(at: recoveryURL)
            print("已確認內建螢幕回到線上桌面。背光狀態請目視確認。")
            return 0
        }
        if i == 7 { print(bridge.attemptRestore()) }
    }
    print("未能確認恢復。請重新插上 HDMI／USB-C，再試一次；仍失敗時正常重新啟動。未自動重開機。")
    return 4
}

signal(SIGPIPE, SIG_IGN)
let arguments = CommandLine.arguments
if arguments.count > 1 {
    switch arguments[1] {
    case "--guardian":
        guard arguments.count == 4, let builtin = UInt32(arguments[2]), let external = UInt32(arguments[3]) else {
            fputs("Invalid guardian arguments\n", stderr); exit(2)
        }
        // No second GUI or menu item for the independent safety helper.
        let guardian = DisplayGuardian(builtin: builtin, external: external)
        guard guardian.start() else { exit(3) }
        withExtendedLifetime(guardian) { RunLoop.main.run() }
    case "--restore": exit(restoreCommand())
    case "--diagnose": print(DisplayBridge().diagnostics())
    default:
        print("iMac Solo \(soloVersion)\n--diagnose  Read-only diagnostics\n--restore   Enable built-in display only")
        exit(2)
    }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = SoloAppDelegate()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
