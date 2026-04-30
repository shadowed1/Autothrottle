import Foundation
import AppKit

// UninstallerHelper.swift
// Created by shadowed1

enum UninstallError: LocalizedError {
    case scriptNotFound
    case privilegedStepFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "Autothrottle uninstall helper not found"
        case .privilegedStepFailed(let msg):
            return "Autothrottle uninstall failed: \(msg)"
        case .cancelled:
            return "Autothrottle uninstall cancelled."
        }
    }
}

struct UninstallHelper {
    static func uninstall(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            do {
                try runPrivilegedStep()

                cleanupUserFiles()
                moveAppToTrash()

                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func runPrivilegedStep() throws {
        guard let url = Bundle.main.url(forResource: "uninstall", withExtension: "sh") else {
            throw UninstallError.scriptNotFound
        }

        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )

        let escaped = url.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let source = #"do shell script "\#(escaped)" with administrator privileges"#
        var appleScriptError: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&appleScriptError)

        if let err = appleScriptError {
            if let code = err[NSAppleScript.errorNumber] as? Int, code == -128 {
                throw UninstallError.cancelled
            }
            let msg = err[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            throw UninstallError.privilegedStepFailed(msg)
        }
    }

    private static func cleanupUserFiles() {
        let fm = FileManager.default
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let configDir = appSupport.appendingPathComponent("Autothrottle")
            try? fm.removeItem(at: configDir)
        }
        for name in ["autothrottle.pid", "autothrottle_peak"] {
            try? fm.removeItem(atPath: "/tmp/\(name)")
        }
    }

    private static func moveAppToTrash() {
        guard var appURL = Bundle.main.bundleURL.standardized as URL? else { return }
        appURL = appURL.resolvingSymlinksInPath()
        let path = appURL.path
        let isInstalled = path.hasPrefix("/Applications") ||
                          path.hasPrefix("/Users/") && path.contains("/Applications")
        guard isInstalled else { return }

        try? FileManager.default.trashItem(at: appURL, resultingItemURL: nil)
    }
}
