import Foundation

var tests = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    tests += 1
    guard condition() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
}
func display(_ id: UInt32, builtin: Bool = false, online: Bool = true, active: Bool = true,
             asleep: Bool = false, mirrored: Bool = false, vendor: UInt32 = 0x610,
             model: UInt32 = 42, width: Int = 1920, height: Int = 1080, name: String = "HDMI Monitor") -> DisplayInfo {
    DisplayInfo(id: id, name: name, builtin: builtin, online: online, active: active,
                asleep: asleep, mirrored: mirrored, vendor: vendor, model: model, width: width, height: height)
}
let panel = display(1, builtin: true, name: "iMac")
let monitor = display(2)
func refuses(_ list: [DisplayInfo], internalID: UInt32 = 1, external: UInt32 = 2) -> Bool {
    SoloPolicy.refusal(displays: list, builtin: internalID, external: external) != nil
}
check(!refuses([panel, monitor]), "valid pair")
check(refuses([]), "empty list")
check(refuses([panel]), "no external")
check(refuses([monitor]), "no built-in")
check(refuses([panel, display(3, builtin: true), monitor]), "ambiguous built-in")
check(refuses([panel, monitor], internalID: 7), "stale built-in ID")
check(refuses([panel, monitor], external: 9), "missing external ID")
check(refuses([panel, monitor], external: 1), "never target same display")
check(refuses([display(1, builtin: true, online: false), monitor]), "built-in offline")
check(refuses([display(1, builtin: true, active: false), monitor]), "built-in inactive")
check(refuses([display(1, builtin: true, asleep: true), monitor]), "built-in asleep")
check(refuses([display(1, builtin: true, mirrored: true), monitor]), "built-in mirrored")
check(refuses([panel, display(2, online: false)]), "external offline")
check(refuses([panel, display(2, active: false)]), "external inactive")
check(refuses([panel, display(2, asleep: true)]), "external asleep")
check(refuses([panel, display(2, mirrored: true)]), "external mirrored")
check(refuses([panel, display(2, vendor: 0)]), "unknown vendor")
check(refuses([panel, display(2, vendor: UInt32.max)]), "invalid vendor")
check(refuses([panel, display(2, model: UInt32.max)]), "invalid model")
check(refuses([panel, display(2, vendor: 0x756e6b6e)]), "virtual vendor")
check(refuses([panel, display(2, model: 0x76697274)]), "virtual model")
check(refuses([panel, display(2, width: 1)]), "phantom width")
check(refuses([panel, display(2, height: 1)]), "phantom height")
for name in ["Virtual Display", "AIRPLAY", "Sidecar", "Dummy", "DisplayLink", "Duet", "Luna Display"] {
    check(refuses([panel, display(2, name: name)]), "reject \(name)")
}
check(!refuses([panel, display(4), monitor]), "explicit external selection")
check(!refuses([display(69733248, builtin: true), display(4294967294)],
               internalID: 69733248, external: 4294967294), "large opaque unsigned IDs")

func policy() -> GuardPolicy { GuardPolicy(started: 100, lastHeartbeat: 100) }
var p = policy()
check(p.action(now: 100) == .none, "start")
check(p.action(now: 109.9) == .none, "heartbeat not expired")
check(p.action(now: 110) == .restore, "heartbeat deadline")
p.lastHeartbeat = 119
check(p.action(now: 119.9) == .none, "trial not expired")
check(p.action(now: 120) == .restore, "trial deadline")
p = policy(); p.verifiedOffline = false
check(!p.confirm(now: 102), "cannot confirm before verification")
p.verifiedOffline = true
check(p.confirm(now: 102), "explicit confirmation")
p.lastHeartbeat = 160
check(p.action(now: 160) == .none, "kept beyond trial with heartbeat")
p.externalStillOnline = false
check(p.action(now: 160) == .restore, "unplug after keep")
p = policy(); p.parentAlive = false
check(p.action(now: 101) == .restore, "GUI process died")
p = policy(); p.manualRestore = true
check(p.action(now: 101) == .restore, "manual restore")
p = policy(); p.suspended = true
check(p.action(now: 1000) == .none, "no reconfiguration during sleep")
p.shuttingDown = true
check(p.action(now: 1000) == .stopForShutdown, "shutdown overrides sleep")
p = policy(); p.shuttingDown = true; p.manualRestore = true
check(p.action(now: 101) == .stopForShutdown, "shutdown overrides restore")
p = policy(); p.resumeNeedsRestore = true
check(p.action(now: 101) == .restore, "wake restores, never disables")
p = policy(); p.verifiedOffline = true; p.lastHeartbeat = 120
check(!p.confirm(now: 120), "no late confirmation")
p = policy(); p.verifiedOffline = true; p.externalStillOnline = false
check(!p.confirm(now: 102), "no confirmation after external loss")
p = policy(); p.verifiedOffline = true; p.suspended = true
check(!p.confirm(now: 102), "no confirmation during sleep")
p = policy()
check(p.action(now: 99) == .restore, "backward time fail-safe")
check(p.action(now: .nan) == .restore, "invalid time fail-safe")
check(p.action(now: .infinity) == .restore, "infinite time fail-safe")
print("PASS: \(tests) platform-independent safety-policy tests. No display APIs were called.")
