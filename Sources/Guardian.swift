import Foundation
import AppKit
import CoreGraphics
import Darwin

private let guardianDisplayCallback: CGDisplayReconfigurationCallBack = { _, flags, context in
    guard !flags.contains(.beginConfigurationFlag), let context = context else { return }
    let guardian = Unmanaged<DisplayGuardian>.fromOpaque(context).takeUnretainedValue()
    // Never issue a display transaction inside a CoreGraphics callback.
    DispatchQueue.main.async { guardian.tick() }
}

final class DisplayGuardian {
    private let bridge = DisplayBridge()
    private let builtinID: UInt32
    private let externalID: UInt32
    private var externalVendor: UInt32 = 0
    private var externalModel: UInt32 = 0
    private var policy: GuardPolicy
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var buffer = ""
    private var finished = false
    private var restoring = false
    private var restoringSince = 0.0
    private var retries = 0
    private var verificationDone = false
    private var initialError: String?
    private var activity: NSObjectProtocol?
    private var lockFD: Int32 = -1
    private var callbackRegistered = false
    private var controlObserver: NSObjectProtocol?

    init(builtin: UInt32, external: UInt32) {
        builtinID = builtin
        externalID = external
        let now = monotonicNow()
        policy = GuardPolicy(started: now, lastHeartbeat: now)
    }
    private func emit(_ event: String, _ message: String = "", restored: Bool? = nil) {
        var payload: [String: Any] = ["event": event, "message": message,
                                      "deadline": policy.started + SoloPolicy.trialSeconds]
        if let restored = restored { payload["restored"] = restored }
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           var text = String(data: data, encoding: .utf8) {
            text.append("\n")
            text.withCString { pointer in _ = Darwin.write(STDOUT_FILENO, pointer, strlen(pointer)) }
        }
    }
    func start() -> Bool {
        signal(SIGPIPE, SIG_IGN)
        // One writer at a time. The OS releases flock even if this process crashes.
        let path = supportDirectory().appendingPathComponent("guardian.lock").path
        lockFD = Darwin.open(path, O_CREAT | O_RDWR, 0o600)
        guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
            emit("error", "另一個安全控制程序仍在執行；本次未更動螢幕。")
            return false
        }
        do {
            guard bridge.available else { throw SoloFailure(message: bridge.capabilityText) }
            let infos = try bridge.snapshot()
            if let refusal = SoloPolicy.refusal(displays: infos, builtin: builtinID, external: externalID) {
                throw SoloFailure(message: refusal)
            }
            guard let panel = infos.first(where: { $0.id == builtinID }),
                  let external = infos.first(where: { $0.id == externalID }) else {
                throw SoloFailure(message: "顯示器剛剛變更，請重新測試。")
            }
            externalVendor = external.vendor
            externalModel = external.model
            try bridge.saveRecovery(panel) // Must succeed BEFORE turning anything off.
            installObservers()
            let flags = fcntl(STDIN_FILENO, F_GETFL)
            guard flags >= 0, fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK) == 0 else {
                throw SoloFailure(message: "無法建立獨立安全監控；未停用螢幕。")
            }
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                              reason: "Monitor display recovery")
            let clock = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
            timer = clock
            RunLoop.main.add(clock, forMode: .common)
            emit("starting", "即將停用內建螢幕；20 秒內未確認會嘗試還原。")
            // The ONLY disable operation in the application. There is no force mode,
            // disable-all, persistent disable, or auto-disable after wake/reboot.
            do { _ = try bridge.setEnabled(false, id: builtinID) }
            catch { initialError = error.localizedDescription }
            logLine("trial start builtin=\(builtinID) external=\(externalID)")
            return true
        } catch {
            emit("error", error.localizedDescription)
            cleanup()
            return false
        }
    }
    private func installObservers() {
        let center = NSWorkspace.shared.notificationCenter
        controlObserver = DistributedNotificationCenter.default().addObserver(forName: restoreNotificationName, object: nil, queue: .main) { [weak self] _ in
            self?.policy.manualRestore = true
            self?.tick()
        }
        observers.append(center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
            self?.policy.shuttingDown = true
            self?.tick()
        })
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.policy.suspended = true
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                if self.policy.suspended {
                    self.policy.suspended = false
                    self.policy.resumeNeedsRestore = true
                    self.tick()
                }
            })
        }
        let result = CGDisplayRegisterReconfigurationCallback(guardianDisplayCallback,
            Unmanaged.passUnretained(self).toOpaque())
        callbackRegistered = result == .success
    }
    private func readCommands() {
        var bytes = [UInt8](repeating: 0, count: 1024)
        while true {
            let n = Darwin.read(STDIN_FILENO, &bytes, bytes.count)
            if n == 0 { policy.parentAlive = false; break }
            if n < 0 {
                if errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR { policy.parentAlive = false }
                break
            }
            buffer += String(decoding: bytes.prefix(n), as: UTF8.self)
            if buffer.utf8.count > 16_384 { policy.manualRestore = true; buffer = ""; break }
            while let end = buffer.firstIndex(of: "\n") {
                let line = String(buffer[..<end])
                buffer.removeSubrange(...end)
                switch line {
                case "PING": policy.lastHeartbeat = monotonicNow()
                case "CONFIRM":
                    if policy.confirm(now: monotonicNow()) {
                        emit("kept", "已保留外接螢幕模式。睡眠喚醒後會嘗試恢復內建螢幕。")
                        logLine("user confirmed trial")
                    }
                case "RESTORE": policy.manualRestore = true
                case "SLEEP": policy.suspended = true
                case "WAKE":
                    if policy.suspended { policy.suspended = false; policy.resumeNeedsRestore = true }
                case "SHUTDOWN": policy.shuttingDown = true
                default: break
                }
            }
        }
    }
    func tick() {
        guard !finished else { return }
        readCommands()
        if policy.shuttingDown { finish(shutdown: true); return }
        if policy.suspended { return }
        let now = monotonicNow()
        if restoring {
            if bridge.builtinOnline() { finish(restored: true); return }
            // Bounded retries, always re-enumerating. No cycling the monitor power,
            // brute-force ID search, or repeated retries during shutdown.
            if now - restoringSince >= 2, retries == 0 {
                retries = 1
                logLine(bridge.attemptRestore(preferred: builtinID))
            }
            if now - restoringSince >= 5 { finish(restored: bridge.builtinOnline()) }
            return
        }
        let infos = try? bridge.snapshot()
        // An asleep-but-connected HDMI monitor is not a cable disconnect.
        policy.externalStillOnline = infos?.contains { d in
            d.id == externalID && d.online && !d.builtin &&
            d.vendor == externalVendor && d.model == externalModel && !d.looksVirtual
        } ?? false
        switch policy.action(now: now) {
        case .restore: beginRestore("安全條件改變、倒數到期或收到恢復要求。"); return
        case .stopForShutdown: finish(shutdown: true); return
        case .none: break
        }
        if !verificationDone && now - policy.started >= 1.5 {
            verificationDone = true
            let onlinePanel = infos?.contains { $0.builtin && $0.online } ?? true
            policy.verifiedOffline = !onlinePanel && policy.externalStillOnline
            if policy.verifiedOffline {
                emit("testing", "系統已將內建螢幕移出線上桌面。請目視確認內建面板沒有背光，並確認外接螢幕可用。")
            } else {
                beginRestore(initialError ?? "系統沒有確實停用內建螢幕；已取消，不使用黑色遮罩替代。")
            }
        }
        if policy.confirmed, let infos = infos, infos.contains(where: { $0.builtin && $0.online }) {
            // System/another app restored it. Never fight the OS or auto-disable again.
            finish(restored: true)
        }
    }
    private func beginRestore(_ reason: String) {
        guard !restoring, !policy.shuttingDown else { return }
        restoring = true
        restoringSince = monotonicNow()
        emit("restoring", reason)
        logLine("restore: \(reason)")
        logLine(bridge.attemptRestore(preferred: builtinID))
    }
    private func cleanup() {
        timer?.invalidate()
        if callbackRegistered {
            CGDisplayRemoveReconfigurationCallback(guardianDisplayCallback, Unmanaged.passUnretained(self).toOpaque())
        }
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observers.removeAll()
        if let observer = controlObserver { DistributedNotificationCenter.default().removeObserver(observer) }
        if let activity = activity { ProcessInfo.processInfo.endActivity(activity) }
        if lockFD >= 0 { flock(lockFD, LOCK_UN); Darwin.close(lockFD); lockFD = -1 }
    }
    private func finish(restored: Bool = false, shutdown: Bool = false) {
        guard !finished else { return }
        finished = true
        if shutdown {
            emit("shutdown", "系統正在登出或關機，已停止顯示器操作。")
        } else {
            if restored { try? FileManager.default.removeItem(at: recoveryURL) }
            emit("finished", restored ? "內建螢幕已回到線上桌面。" : "自動恢復未能確認成功。請重新插上外接螢幕，使用「緊急恢復.command」；仍失敗時正常重新啟動。", restored: restored)
        }
        cleanup()
        Darwin.exit(restored || shutdown ? 0 : 4)
    }
}
