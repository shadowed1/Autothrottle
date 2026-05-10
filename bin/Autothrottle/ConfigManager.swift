import Foundation

// ConfigManager.swift
// Created by shadowed1

struct Config: Equatable {
    var threshold: Double = 0.9493
    var cooldown: Int = 120
    var idleThreshold: Int = 90
    var loadThreshold: Int = 50
    var triggerCount: Int = 3
}

class ConfigManager {

    static let shared = ConfigManager()

    private let configDir: URL
    private let configFile: URL

    private init() {
        configDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Autothrottle")
        configFile = configDir.appendingPathComponent("config")
    }

    func load() -> Config {
        var config = Config()

        guard let text = try? String(contentsOf: configFile, encoding: .utf8) else {
            return config
        }

        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard parts.count == 2 else { continue }
            let key = parts[0]
            let value = parts[1]

            switch key {
            case "THRESHOLD":       config.threshold      = Double(value) ?? config.threshold
            case "COOLDOWN":        config.cooldown       = Int(value)    ?? config.cooldown
            case "IDLE_THRESHOLD":  config.idleThreshold  = Int(value)    ?? config.idleThreshold
            case "LOAD_THRESHOLD":  config.loadThreshold  = Int(value)    ?? config.loadThreshold
            case "TRIGGER_COUNT":   config.triggerCount   = Int(value)    ?? config.triggerCount
            default: break
            }
        }

        return config
    }
    
    func signalReload() {
        let pidFile = URL(fileURLWithPath: "/tmp/autothrottle.pid")
        guard
            let text = try? String(contentsOf: pidFile, encoding: .utf8),
            let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            print("autothrottle not running (no PID file)")
            return
        }
        kill(pid, SIGHUP)
        print("Sent SIGHUP to PID \(pid)")
    }

    func save(_ config: Config) {
        do {
            try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

            let text = """
            THRESHOLD=\(config.threshold)
            COOLDOWN=\(config.cooldown)
            IDLE_THRESHOLD=\(config.idleThreshold)
            LOAD_THRESHOLD=\(config.loadThreshold)
            TRIGGER_COUNT=\(config.triggerCount)
            """

            try text.write(to: configFile, atomically: true, encoding: .utf8)
            print("Config saved to \(configFile.path)")
            signalReload()
        } catch {
            print("Failed to save config:", error)
        }
    }

    var isSudoersInstalled: Bool {
        FileManager.default.fileExists(atPath: "/etc/sudoers.d/autothrottle")
    }
}
