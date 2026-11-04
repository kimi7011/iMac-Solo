import AppKit
import Foundation
import CoreGraphics
import Darwin

final class SoloAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let bridge = DisplayBridge()
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private var titleLabel: NSTextField!
    private var detailLabel: NSTextField!
    private var stateLabel: NSTextField!
    private var screenPicker: NSPopUpButton!
    private var testButton: NSButton!
    private var keepButton: NSButton!
    private var restoreButton: NSButton!
    private var child: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var incoming = ""
    private var heartbeat: Timer?
    private var deadline = 0.0
    private var stage = "idle"
    private var terminalEvent = false
    private var shuttingDown = false
    private var pendingQuit = false
    private var selectedExternal: UInt32?
    private var observers: [NSObjectProtocol] = []
    private var activity: NSObjectProtocol?
    private var emergencyRunning = false
    private var lastRefresh = 0.0
    private var confirmationOpen = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        signal(SIGPIPE, SIG_IGN)
        // Prevent a second GUI instance; the guardian has its own process lock.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: soloBundleID)
            .filter { $0.processIdentifier != getpid() }
        if let other = others.first {
            other.activate(options: [.activateIgnoringOtherApps])
            NSApp.terminate(nil)
            return
        }
        buildWindow()
        buildMenu()
        installObservers()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.timerTick() }
        heartbeat = timer
        RunLoop.main.add(timer, forMode: .common)
        refreshDisplays()
        showPanel(nil)
    }
    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular) -> NSTextField {
        let item = NSTextField(wrappingLabelWithString: text)
        item.font = .systemFont(ofSize: size, weight: weight)
        item.maximumNumberOfLines = 0
        item.isSelectable = true
        return item
    }
    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 690, height: 650),
                          styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "iMac Solo · 內建螢幕控制"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 26)
        ])
        titleLabel = label("只留下你正在使用的螢幕。", size: 25, weight: .semibold)
        stack.addArrangedSubview(titleLabel)
        let subtitle = label("免費・本機執行・繁體中文    |    0.1.0 實驗版", size: 13)
        subtitle.textColor = .secondaryLabelColor
        stack.addArrangedSubview(subtitle)
        let warning = label("針對 iMac M1／macOS 27 製作，但尚未在這組硬體實測。\n這不是黑色遮罩；將嘗試讓內建顯示器離線。不能保證面板完全斷電或絕不黑屏。", size: 13)
        stack.addArrangedSubview(warning)
        detailLabel = label("讀取螢幕中…", size: 12)
        detailLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(detailLabel)
        stack.addArrangedSubview(label("保留的有線 HDMI 螢幕", size: 13, weight: .semibold))
        screenPicker = NSPopUpButton(frame: .zero, pullsDown: false)
        screenPicker.target = self
        screenPicker.action = #selector(selectionChanged(_:))
        stack.addArrangedSubview(screenPicker)
        screenPicker.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stateLabel = label("準備就緒。請先儲存工作，並退出其他螢幕控制工具。", size: 13, weight: .medium)
        stack.addArrangedSubview(stateLabel)
        stateLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stateLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 55).isActive = true
        testButton = NSButton(title: "測試 20 秒：只用外接螢幕", target: self, action: #selector(startTrial(_:)))
        testButton.bezelStyle = .rounded
        restoreButton = NSButton(title: "恢復內建螢幕", target: self, action: #selector(restore(_:)))
        restoreButton.bezelStyle = .rounded
        restoreButton.keyEquivalent = "\u{1b}"
        let row = NSStackView(views: [testButton, restoreButton])
        row.orientation = .horizontal
        row.spacing = 12
        stack.addArrangedSubview(row)
        keepButton = NSButton(title: "確認：外接正常，內建螢幕沒有背光 → 保留", target: self, action: #selector(keep(_:)))
        keepButton.bezelStyle = .rounded
        keepButton.isEnabled = false
        stack.addArrangedSubview(keepButton)
        let diagnose = NSButton(title: "複製診斷資訊", target: self, action: #selector(copyDiagnostics(_:)))
        let settings = NSButton(title: "開啟系統顯示器設定", target: self, action: #selector(openSettings(_:)))
        diagnose.bezelStyle = .rounded
        settings.bezelStyle = .rounded
        let footer = NSStackView(views: [diagnose, settings])
        footer.spacing = 10
        stack.addArrangedSubview(footer)
        let note = label("20 秒內未確認會嘗試還原。睡眠喚醒後恢復，不會自行再次關屏。\n關閉此視窗仍會留在選單列；請用「恢復並結束」停止程式。", size: 11)
        note.textColor = .secondaryLabelColor
        stack.addArrangedSubview(note)
        for item in [titleLabel!, warning, detailLabel!, note] {
            item.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }
    private func buildMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "display", accessibilityDescription: "iMac Solo")
        statusItem.button?.toolTip = "iMac Solo：內建螢幕控制"
        let menu = NSMenu()
        menu.autoenablesItems = false
        func add(_ title: String, _ selector: Selector, _ key: String = "") {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        add("開啟控制面板", #selector(showPanel(_:)))
        add("測試只用外接螢幕…", #selector(startTrial(_:)))
        add("恢復內建螢幕", #selector(restore(_:)))
        menu.addItem(.separator())
        add("複製診斷資訊", #selector(copyDiagnostics(_:)))
        add("開啟本機記錄資料夾", #selector(openLogs(_:)))
        add("使用與救援說明", #selector(openHelp(_:)))
        menu.addItem(.separator())
        add("恢復並結束", #selector(quit(_:)), "q")
        statusItem.menu = menu
    }
    private func installObservers() {
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { [weak self] _ in
            self?.shuttingDown = true
            self?.send("SHUTDOWN")
        })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.send("SLEEP") })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.send("WAKE")
            self?.refreshDisplays()
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                                               object: nil, queue: .main) { [weak self] _ in self?.refreshDisplays() })
    }
    private func timerTick() {
        if child?.isRunning == true {
            send("PING")
            if stage == "testing" || stage == "starting" {
                let left = max(0, Int(ceil(deadline - monotonicNow())))
                window.title = "iMac Solo · \(left) 秒後嘗試還原"
                keepButton.isEnabled = stage == "testing" && left > 0
            }
        }
        if monotonicNow() - lastRefresh > 3 { refreshDisplays() }
    }
    private func refreshDisplays() {
        guard window != nil else { return }
        lastRefresh = monotonicNow()
        do {
            let displays = try bridge.snapshot()
            let was = selectedExternal
            screenPicker.removeAllItems()
            for d in displays.filter({ $0.usableExternal }) {
                screenPicker.addItem(withTitle: "\(d.name)  ·  \(d.width)×\(d.height)")
                screenPicker.lastItem?.representedObject = NSNumber(value: d.id)
            }
            if let was = was, let item = screenPicker.itemArray.first(where: { ($0.representedObject as? NSNumber)?.uint32Value == was }) {
                screenPicker.select(item)
            }
            selectedExternal = (screenPicker.selectedItem?.representedObject as? NSNumber)?.uint32Value
            let panelText = displays.first(where: { $0.builtin }).map { $0.online ? "內建螢幕：線上" : "內建螢幕：離線" } ?? "內建螢幕：目前無法列舉"
            detailLabel.stringValue = "\(ProcessInfo.processInfo.operatingSystemVersionString)  ·  \(hardwareModel())\n\(panelText)  ·  \(bridge.capabilityText)"
            let panel = displays.first(where: { $0.builtin })
            let okay = panel != nil && selectedExternal != nil && bridge.available &&
                SoloPolicy.refusal(displays: displays, builtin: panel!.id, external: selectedExternal!) == nil
            testButton.isEnabled = child == nil && !emergencyRunning && okay
            screenPicker.isEnabled = child == nil
            restoreButton.isEnabled = !emergencyRunning
        } catch {
            detailLabel.stringValue = error.localizedDescription
            testButton.isEnabled = false
        }
    }
    @objc func selectionChanged(_ sender: Any?) {
        selectedExternal = (screenPicker.selectedItem?.representedObject as? NSNumber)?.uint32Value
    }
    @objc func showPanel(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel(nil)
        return true
    }
    private func placeOnExternal(_ id: UInt32) -> Bool {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
        }) else { return false }
        let rect = screen.visibleFrame
        guard rect.width >= window.frame.width, rect.height >= window.frame.height else { return false }
        window.setFrameOrigin(NSPoint(x: rect.midX - window.frame.width / 2,
                                      y: rect.midY - window.frame.height / 2))
        showPanel(nil)
        return true
    }
    @objc func startTrial(_ sender: Any?) {
        guard child == nil, !emergencyRunning, !confirmationOpen else { showPanel(nil); return }
        refreshDisplays()
        guard let external = selectedExternal,
              let displays = try? bridge.snapshot(), let panel = displays.first(where: { $0.builtin }), bridge.available else {
            showMessage("尚未符合測試條件", "請接好有線 HDMI 螢幕、喚醒兩個螢幕，並關閉鏡像顯示。")
            return
        }
        if let refusal = SoloPolicy.refusal(displays: displays, builtin: panel.id, external: external) {
            showMessage("未更動顯示器", refusal)
            return
        }
        guard placeOnExternal(external) else {
            showMessage("無法安全顯示確認視窗", "外接桌面需至少有 690×680 的可用邏輯空間；請調整顯示器縮放後再試。")
            return
        }
        let alert = NSAlert()
        alert.messageText = "這個視窗確實顯示在你的 HDMI 螢幕上嗎？"
        alert.informativeText = "先儲存工作並退出 BetterDisplay、Lunar 等其他顯示器管理工具。\n\n測試使用非公開介面，可能失敗、黑屏或需重新啟動。沒有任何程式能保證自動還原一定成功。\n\n確認後只嘗試停用內建螢幕。若 20 秒內未按「保留」，獨立監控程序會嘗試還原。請勿在首次測試時拔線。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "確定在 HDMI 上，開始測試")
        confirmationOpen = true
        alert.beginSheetModal(for: window) { [weak self] response in
            self?.confirmationOpen = false
            guard response == .alertSecondButtonReturn else { return }
            self?.launchGuardian(builtin: panel.id, external: external)
        }
    }
    private func launchGuardian(builtin: UInt32, external: UInt32) {
        guard child == nil, !shuttingDown else { return }
        let process = Process()
        let input = Pipe()
        let output = Pipe()
        process.executableURL = Bundle.main.executableURL
        process.arguments = ["--guardian", String(builtin), String(external)]
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        terminalEvent = false
        incoming = ""
        deadline = monotonicNow() + SoloPolicy.trialSeconds
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            DispatchQueue.main.async { self?.receive(data) }
        }
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self?.guardianExited() }
        }
        child = process
        inputPipe = input
        outputPipe = output
        stage = "starting"
        stateLabel.stringValue = "獨立安全監控啟動中；正在確認系統是否真的停用內建螢幕…"
        do {
            try process.run()
            activity = ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep,
                                                              reason: "Display guardian heartbeat")
            send("PING")
        } catch {
            terminalEvent = true
            cleanupChild()
            stateLabel.stringValue = "無法啟動安全監控，未停用螢幕：\(error.localizedDescription)"
        }
        refreshDisplays()
    }
    private func send(_ command: String) {
        guard child?.isRunning == true, let file = inputPipe?.fileHandleForWriting else { return }
        let data = Data((command + "\n").utf8)
        try? file.write(contentsOf: data)
    }
    private func receive(_ data: Data) {
        incoming += String(decoding: data, as: UTF8.self)
        while let end = incoming.firstIndex(of: "\n") {
            let line = String(incoming[..<end])
            incoming.removeSubrange(...end)
            guard let bytes = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
                  let event = object["event"] as? String else { continue }
            if let d = object["deadline"] as? Double { deadline = d }
            stateLabel.stringValue = object["message"] as? String ?? ""
            stage = event
            if event == "testing" {
                keepButton.isEnabled = monotonicNow() < deadline
                if let external = selectedExternal { _ = placeOnExternal(external) }
            } else { keepButton.isEnabled = false }
            if event == "kept" {
                window.title = "iMac Solo · 只使用外接螢幕"
                statusItem.button?.toolTip = "iMac Solo：外接螢幕模式；按選單可恢復"
            }
            if ["finished", "error", "shutdown"].contains(event) {
                terminalEvent = true
                window.title = "iMac Solo · 內建螢幕控制"
                if event == "shutdown" { shuttingDown = true }
            }
        }
    }
    private func cleanupChild() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        try? inputPipe?.fileHandleForWriting.close()
        inputPipe = nil
        outputPipe = nil
        child = nil
        if let token = activity { ProcessInfo.processInfo.endActivity(token) }
        activity = nil
        keepButton.isEnabled = false
    }
    private func guardianExited() {
        let hadTerminal = terminalEvent
        cleanupChild()
        stage = "idle"
        window.title = "iMac Solo · 內建螢幕控制"
        statusItem.button?.toolTip = "iMac Solo：內建螢幕控制"
        if !hadTerminal && !shuttingDown {
            stateLabel.stringValue = "安全監控異常結束，正在另行嘗試恢復內建螢幕。"
            runEmergencyRestore()
        } else if pendingQuit { NSApp.reply(toApplicationShouldTerminate: true) }
        refreshDisplays()
    }
    @objc func keep(_ sender: Any?) {
        guard stage == "testing", monotonicNow() < deadline else { return }
        send("CONFIRM")
        keepButton.isEnabled = false
    }
    @objc func restore(_ sender: Any?) {
        guard !shuttingDown else { return }
        if child?.isRunning == true {
            stage = "restoring"
            keepButton.isEnabled = false
            send("RESTORE")
            stateLabel.stringValue = "正在要求獨立監控程序恢復內建螢幕…"
        } else { runEmergencyRestore() }
    }
    private func runEmergencyRestore() {
        guard !emergencyRunning else { return }
        emergencyRunning = true
        let process = Process()
        let pipe = Pipe()
        process.executableURL = Bundle.main.executableURL
        process.arguments = ["--restore"]
        process.standardOutput = pipe
        process.standardError = pipe
        process.terminationHandler = { [weak self] _ in
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.emergencyRunning = false
                self.stateLabel.stringValue = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                self.refreshDisplays()
                if self.pendingQuit { NSApp.reply(toApplicationShouldTerminate: true) }
            }
        }
        do { try process.run() }
        catch {
            emergencyRunning = false
            stateLabel.stringValue = "恢復程序無法啟動：\(error.localizedDescription)"
            if pendingQuit { NSApp.reply(toApplicationShouldTerminate: true) }
        }
        refreshDisplays()
    }
    @objc func copyDiagnostics(_ sender: Any?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(bridge.diagnostics(), forType: .string)
        if child == nil { stateLabel.stringValue = "已複製診斷資訊，可直接貼回對話；不含帳號或序號。" }
    }
    @objc func openLogs(_ sender: Any?) { NSWorkspace.shared.open(supportDirectory()) }
    @objc func openHelp(_ sender: Any?) {
        if let url = Bundle.main.url(forResource: "Guide", withExtension: "html") { NSWorkspace.shared.open(url) }
    }
    @objc func openSettings(_ sender: Any?) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") { NSWorkspace.shared.open(url) }
    }
    @objc func quit(_ sender: Any?) { NSApp.terminate(nil) }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if shuttingDown { send("SHUTDOWN"); return .terminateNow }
        if child?.isRunning == true {
            pendingQuit = true
            restore(nil)
            return .terminateLater
        }
        if emergencyRunning { pendingQuit = true; return .terminateLater }
        return .terminateNow
    }
    func applicationWillTerminate(_ notification: Notification) {
        heartbeat?.invalidate()
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Closing the control window must not silently destroy the safety process.
        sender.orderOut(nil)
        return false
    }
    private func showMessage(_ title: String, _ text: String) {
        showPanel(nil)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "知道了")
        alert.beginSheetModal(for: window)
    }
}
