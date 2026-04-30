import SwiftUI
import AppKit

// AboutView.swift
// Created by shadowed1

struct VersionInfo {
    let version: String
    let changelog: [String]
}

enum UpdateResult {
    case upToDate(current: String)
    case updateAvailable(current: String, latest: String, changelog: [String])
    case failed(String)
}

struct UpdateChecker {
    static let feedURL = "https://raw.githubusercontent.com/shadowed1/Autothrottle/main/bin/version"
    static let releasesURL = "https://github.com/shadowed1/Autothrottle/releases/latest"

    static var localVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    static func check() async -> UpdateResult {
        guard let url = URL(string: feedURL) else { return .failed("Bad feed URL.") }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let raw = String(data: data, encoding: .utf8) else {
                return .failed("Could not decode version file.")
            }
            guard let remote = parse(raw) else {
                return .failed("Version file format unrecognised.")
            }
            let local = localVersion
            if versionNumber(remote.version) > versionNumber(local) {
                return .updateAvailable(current: local, latest: remote.version, changelog: remote.changelog)
            } else {
                return .upToDate(current: local)
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private static func parse(_ raw: String) -> VersionInfo? {
        let lines = raw.components(separatedBy: .newlines)
        var version: String?
        var changelog: [String] = []
        var inChangelog = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("VERSION=") {
                version = String(trimmed.dropFirst("VERSION=".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed == "CHANGELOG" {
                inChangelog = true
            } else if trimmed == "END" {
                inChangelog = false
            } else if inChangelog, !trimmed.isEmpty {
                changelog.append(trimmed)
            }
        }
        guard let v = version else { return nil }
        return VersionInfo(version: v, changelog: changelog)
    }

    static func versionNumber(_ v: String) -> Int {
        let parts = v.split(separator: ".").compactMap { Int($0) }
        let major = parts.count > 0 ? parts[0] : 0
        let minor = parts.count > 1 ? parts[1] : 0
        let patch = parts.count > 2 ? parts[2] : 0
        return major * 100_000 + minor * 1_000 + patch
    }
}

final class AboutWindowController: NSWindowController, NSWindowDelegate {
    static let shared = AboutWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AboutView())

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct AboutView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var updateResult: UpdateResult? = nil
    @State private var isChecking = false
    @State private var supportExpanded = false
    @State private var checkTask: Task<Void, Never>? = nil

    private var appVersion: String { UpdateChecker.localVersion }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .hueRotation(.degrees(
                        Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 10) * 36
                    ))

                Text("Autothrottle")
                    .font(.title2).bold()

                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("By shadowed1")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            updateStatusView
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

            Divider()

            DisclosureGroup(isExpanded: $supportExpanded) {
                VStack(spacing: 8) {
                    supportButton(
                        label: "Sponsor on Github",
                        systemImage: "heart",
                        url: "https://github.com/sponsors/shadowed1"
                    )
                    supportButton(
                        label: "Buy Me A Coffee",
                        systemImage: "cup.and.saucer.fill",
                        url: "https://buymeacoffee.com/shadowed"
                    )
                }
                .padding(.top, 8)
                .frame(width: 276)
            } label: {
                Label("Support Autothrottle", systemImage: "heart.fill")
                    .font(.subheadline).bold()
                    .foregroundColor(.pink)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()

            HStack {
                Spacer()
                Button("Close") {
                    NSApp.keyWindow?.performClose(nil)
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 320)
        .fixedSize(horizontal: true, vertical: true)
        .onAppear {
            updateResult = nil
            checkTask = Task { await runCheck() }
        }
        .onDisappear {
            checkTask?.cancel()
            checkTask = nil
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateResult {
        case .none:
            if isChecking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking for updates…")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        case .upToDate(let current):
            Label("Up to date (v\(current))", systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .leading)

        case .updateAvailable(let current, let latest, let changelog):
            VStack(alignment: .leading, spacing: 8) {
                Label("v\(latest) available (you have v\(current))", systemImage: "arrow.down.circle.fill")
                    .font(.subheadline).bold()
                    .foregroundColor(.accentColor)

                if !changelog.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("What's new:")
                            .font(.caption).bold()
                            .foregroundColor(.secondary)
                        ForEach(changelog, id: \.self) { line in
                            Text(line).font(.caption)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                }

                Button("Download on GitHub") {
                    if let url = URL(string: UpdateChecker.releasesURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }

        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func runCheck() async {
        guard !Task.isCancelled else { return }
        isChecking = true
        defer { isChecking = false }
        updateResult = await UpdateChecker.check()
    }

    private func supportButton(label: String, systemImage: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { NSWorkspace.shared.open(u) }
        } label: {
            Label(label, systemImage: systemImage).frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }
}
