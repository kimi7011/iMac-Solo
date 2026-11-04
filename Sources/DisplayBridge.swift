import Foundation
import AppKit
import CoreGraphics
import Darwin

let soloVersion = "0.1.0-experimental"
let soloBundleID = "local.imacsolo.app"
let restoreNotificationName = Notification.Name("local.imacsolo.restore")

func monotonicNow() -> Double { ProcessInfo.processInfo.systemUptime }
func supportDirectory() -> URL {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let dir = root.appendingPathComponent("iMacSolo", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
    return dir
}
func logLine(_ text: String) {
    let url = supportDirectory().appendingPathComponent("events.log")
    let bytes = Data((ISO8601DateFormatter().string(from: Date()) + " " + text + "\n").utf8)
    // Bound local log size; no network, host name, account name, or serial numbers.
    if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 512_000 {
        try? FileManager.default.removeItem(at: url)
    }
    if !FileManager.default.fileExists(atPath: url.path) {
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
    }
    if let handle = try? FileHandle(forWritingTo: url) {
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: bytes)
    }
}
func sysctlText(_ key: String) -> String {
    var count = 0
    guard sysctlbyname(key, nil, &count, nil, 0) == 0, count > 0 else { return "unknown" }
    var data = [CChar](repeating: 0, count: count)
    guard sysctlbyname(key, &data, &count, nil, 0) == 0 else { return "unknown" }
    return String(cString: data)
}

func hardwareModel() -> String { sysctlText("hw.model") }

struct SoloFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
struct RecoveryRecord: Codable {
    let builtinID: UInt32
    let bootID: String
    let vendor: UInt32
    let model: UInt32
    let uptime: Double
    let created: Date
}
let recoveryURL = supportDirectory().appendingPathComponent("recovery.json")

final class DisplayBridge {
    typealias GetList = @convention(c) (UInt32, UnsafeMutablePointer<UInt32>?, UnsafeMutablePointer<UInt32>?) -> Int32
    typealias ConfigureEnabled = @convention(c) (CGDisplayConfigRef?, UInt32, Bool) -> Int32
    private var handles: [UnsafeMutableRawPointer] = []
    private var listFunction: GetList?
    private var configureFunction: ConfigureEnabled?
    private var names: [UInt32: String] = [:]

    init() {
        for path in ["/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight",
                     "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"] {
            if let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) { handles.append(handle) }
        }
        // Resolve at runtime. Missing private symbols must not crash launch.
        for handle in handles {
            if listFunction == nil, let p = dlsym(handle, "CGSGetDisplayList") {
                listFunction = unsafeBitCast(p, to: GetList.self)
            }
            if configureFunction == nil, let p = dlsym(handle, "CGSConfigureDisplayEnabled") {
                configureFunction = unsafeBitCast(p, to: ConfigureEnabled.self)
            }
        }
        // Handles intentionally remain loaded for process lifetime.
    }
    var available: Bool { listFunction != nil && configureFunction != nil }
    var capabilityText: String {
        available ? "已找到顯示器控制介面；不代表本機已通過實測" : "系統缺少必要介面；僅提供診斷，不執行停用"
    }

    func onlineIDs() throws -> Set<UInt32> {
        var ids = [UInt32](repeating: 0, count: 128)
        var count: UInt32 = 0
        let result = CGGetOnlineDisplayList(UInt32(ids.count), &ids, &count)
        guard result == .success, count < UInt32(ids.count) else {
            throw SoloFailure(message: "無法可靠讀取線上顯示器：\(result.rawValue)。")
        }
        return Set(ids.prefix(Int(count)))
    }
    func allIDs() throws -> [UInt32] {
        guard let list = listFunction else { return Array(try onlineIDs()).sorted() }
        var ids = [UInt32](repeating: 0, count: 128)
        var count: UInt32 = 0
        let result = list(UInt32(ids.count), &ids, &count)
        guard result == 0, count < UInt32(ids.count) else {
            throw SoloFailure(message: "顯示器控制介面列舉失敗：\(result)。")
        }
        return Array(Set(ids.prefix(Int(count))).union(try onlineIDs())).sorted()
    }
    func snapshot() throws -> [DisplayInfo] {
        let ids = try allIDs()
        let online = try onlineIDs()
        for screen in NSScreen.screens {
            if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
                names[n.uint32Value] = screen.localizedName
            }
        }
        return ids.compactMap { id in
            // Some invalid IDs return UINT_MAX from boolean_t functions. == 1 is intentional.
            let builtin = CGDisplayIsBuiltin(id) == 1
            let isOnline = online.contains(id)
            let vendor = CGDisplayVendorNumber(id)
            let model = CGDisplayModelNumber(id)
            if !builtin && !isOnline && vendor == 0 && model == 0 { return nil }
            return DisplayInfo(id: id, name: names[id] ?? (builtin ? "iMac 內建螢幕" : "外接螢幕 #\(id)"),
                builtin: builtin, online: isOnline, active: isOnline && CGDisplayIsActive(id) == 1,
                asleep: CGDisplayIsAsleep(id) == 1, mirrored: CGDisplayIsInMirrorSet(id) == 1,
                vendor: vendor, model: model, width: Int(CGDisplayPixelsWide(id)), height: Int(CGDisplayPixelsHigh(id)))
        }
    }
    func setEnabled(_ enabled: Bool, id: UInt32) throws -> Int32 {
        guard let configure = configureFunction, listFunction != nil else {
            throw SoloFailure(message: "此系統缺少顯示器控制介面；未更動設定。")
        }
        var config: CGDisplayConfigRef?
        let begin = CGBeginDisplayConfiguration(&config)
        guard begin == .success, let config = config else {
            throw SoloFailure(message: "無法開始顯示器設定：\(begin.rawValue)。")
        }
        let configured = configure(config, id, enabled)
        guard configured == 0 else {
            CGCancelDisplayConfiguration(config)
            throw SoloFailure(message: "系統拒絕顯示器設定：\(configured)。")
        }
        // Session ONLY. Never kCGConfigurePermanently and never NVRAM/system settings.
        let complete = CGCompleteDisplayConfiguration(config, .forSession)
        logLine("configure id=\(id) enabled=\(enabled) commit=\(complete.rawValue)")
        // A commit status alone is not proof; callers verify fresh display enumeration.
        return complete.rawValue
    }
    func saveRecovery(_ panel: DisplayInfo) throws {
        let record = RecoveryRecord(builtinID: panel.id, bootID: sysctlText("kern.bootsessionuuid"), vendor: panel.vendor, model: panel.model,
                                    uptime: monotonicNow(), created: Date())
        let data = try JSONEncoder().encode(record)
        try data.write(to: recoveryURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recoveryURL.path)
    }
    func recoveryRecord() -> RecoveryRecord? {
        guard let data = try? Data(contentsOf: recoveryURL), let record = try? JSONDecoder().decode(RecoveryRecord.self, from: data),
              Date().timeIntervalSince(record.created) < 7 * 24 * 3600 else { return nil }
        return record
    }
    func restoreCandidate(preferred: UInt32? = nil) -> UInt32? {
        // Always re-enumerate. Display IDs may change across hotplug/wake.
        if let current = try? snapshot(), let panel = current.first(where: { $0.builtin }) { return panel.id }
        if let preferred = preferred { return preferred } // known in this active guardian session
        // Recovery is enable-only. Never use a cached ID to disable a display.
        if let record = recoveryRecord(), record.bootID != "unknown",
           record.bootID == sysctlText("kern.bootsessionuuid"), monotonicNow() >= record.uptime { return record.builtinID }
        return nil
    }
    func builtinOnline() -> Bool {
        guard let infos = try? snapshot() else { return false }
        return infos.contains { $0.builtin && $0.online }
    }
    func attemptRestore(preferred: UInt32? = nil) -> String {
        if builtinOnline() { return "內建螢幕已在線上。" }
        guard let id = restoreCandidate(preferred: preferred) else {
            return "找不到可用的內建螢幕識別碼；請重新接上外接螢幕，再試恢復。"
        }
        do {
            let result = try setEnabled(true, id: id)
            return "已送出恢復要求（代碼 \(result)），正在確認實際狀態。"
        } catch { return error.localizedDescription }
    }
    func diagnostics() -> String {
        let infos = (try? snapshot()) ?? []
        var lines = ["iMac Solo \(soloVersion)", "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
                     "硬體型號: \(hardwareModel())", "控制介面: \(capabilityText)",
                     "本機 iMac M1 / macOS 27 實測: 尚未由本工具作者驗證", ""]
        for d in infos {
            lines.append("\(d.name) [id=\(d.id)] \(d.width)×\(d.height)")
            lines.append("  builtin=\(d.builtin) online=\(d.online) active=\(d.active) asleep=\(d.asleep) mirror=\(d.mirrored)")
            lines.append("  vendor=\(String(d.vendor, radix:16)) model=\(String(d.model, radix:16)) externalCandidate=\(d.usableExternal)")
        }
        lines.append("\n未包含帳號、電腦名稱、螢幕序號、截圖或檔案內容。")
        return lines.joined(separator: "\n")
    }
}
