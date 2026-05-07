import Cocoa
import SwiftUI

// AppDelegate.swift
// Created by shadowed1

final class InstallerWindowController: NSWindowController, NSWindowDelegate {

    override func windowDidLoad() {
        super.windowDidLoad()
        window?.delegate = self
    }

    convenience init(onComplete: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Autothrottle Setup"

        let hc = NSHostingController(rootView: InstallerView(onComplete: onComplete))
        hc.sizingOptions = []
        window.contentViewController = hc

        window.center()

        self.init(window: window)
    }

    func show() {
        if window?.isVisible == true {
            window?.makeKeyAndOrderFront(nil)
        } else {
            showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        window?.delegate = nil
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {

    var scriptProcess: Process?
    var installerWindowController: InstallerWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.startAction = { [weak self] in self?.start() }
        AppState.shared.stopAction  = { [weak self] in self?.stop() }
        rewireSystemMenuItems()

        if !ConfigManager.shared.isSudoersInstalled {
            showInstaller()
        }
        func start() { }

        func stop() { }
    }

    private var didRewireMenus = false
    func applicationDidBecomeActive(_ notification: Notification) {
        guard !didRewireMenus else { return }
        didRewireMenus = true
        rewireSystemMenuItems()
    }

    private func rewireSystemMenuItems() {
        guard let mainMenu = NSApp.mainMenu else { return }

        if let appMenu = mainMenu.item(at: 0)?.submenu {
            for item in appMenu.items
            where item.action == #selector(NSApplication.orderFrontStandardAboutPanel(_:)) {
                item.target = self
                item.action = #selector(showAboutWindow)
                break
            }
        }

        if let helpMenu = mainMenu.items.last?.submenu {
            for item in helpMenu.items
            where item.action == #selector(NSApplication.showHelp(_:)) {
                item.target = self
                item.action = #selector(showHelpWindow)
                break
            }
        }
    }

    func showInstaller() {
        let wc = InstallerWindowController {
            DispatchQueue.main.async {
                self.installerWindowController?.close()
                self.installerWindowController = nil
            }
        }
        wc.show()
        installerWindowController = wc
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppState.shared.pulseMenuBarIcon()
        return true
    }
    @objc func start() {
        guard scriptProcess == nil else { return }

        guard let scriptURL = Bundle.main.url(forResource: "autothrottle", withExtension: "sh") else {
            print("autothrottle.sh not found in bundle")
            return
        }

        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: scriptURL.path
        )

        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = [scriptURL.path]
        process.environment = ProcessInfo.processInfo.environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let output = String(decoding: handle.availableData, as: UTF8.self)
            if !output.isEmpty { print("[autothrottle]", output, terminator: "") }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.scriptProcess = nil
                AppState.shared.isRunning = false
                print("autothrottle script terminated")
            }
        }

        do {
            try process.run()
            scriptProcess = process
            AppState.shared.isRunning = true
            print("autothrottle script started (PID \(process.processIdentifier))")
        } catch {
            print("Failed to start autothrottle:", error)
        }
        AppState.shared.isRunning = true
        AppState.shared.menuBarFilled = true
    }

    @objc func stop() {
        guard let process = scriptProcess else { return }
        kill(process.processIdentifier, SIGTERM)
        scriptProcess = nil
        AppState.shared.isRunning = false
        print("SIGTERM sent to autothrottle script")
        AppState.shared.isRunning = false
        AppState.shared.menuBarFilled = false
    }

    @objc func showAboutWindow(_ sender: Any?) {
        AboutWindowController.shared.show()
    }

    @objc func showHelpWindow(_ sender: Any?) {
        HelpWindowController.shared.show()
    }

    @objc func quit() {
        stop()
        NSApp.terminate(nil)
    }
}
