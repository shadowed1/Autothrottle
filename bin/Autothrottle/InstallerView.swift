import SwiftUI
import Security

// InstallerView.swift
// Created by shadowed1

struct InstallerView: View {

    @State private var installing = false
    @State private var errorMessage: String? = nil
    @State private var showSuccess = false

    @State private var installTask: Task<Void, Never>? = nil

    var onComplete: () -> Void

    var body: some View {
        ZStack {

            VStack(spacing: 20) {

                Image(systemName: "cpu")
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

                Text("Autothrottle Setup")
                    .font(.title)
                    .bold()

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                if installing {
                    ProgressView("Installing...")
                } else {
                    Button(action: install) {
                        Text("Install")
                            .bold()
                            .frame(width: 180)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Text("Permission is needed to install")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(40)
            .frame(width: 460)
            .blur(radius: showSuccess ? 4 : 0)
            .disabled(showSuccess)

            if showSuccess {
                successOverlay
            }
        }
        .frame(width: 460)

        .onDisappear {
            installTask?.cancel()
            installTask = nil
        }
    }

    private var successOverlay: some View {
        VStack(spacing: 16) {

            Image(systemName: "checkmark.circle.fill")
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

            Text("Installation Complete")
                .font(.title2)
                .bold()

            VStack(spacing: 4) {
                Text("Autothrottle runs in the Menu Bar.")
                
                HStack(spacing: 6) {
                    Text("Click the")
                    Image(systemName: "cpu")
                        .font(.title2)
                    Text("icon in the Menu Bar!")
                }
            }
            .multilineTextAlignment(.center)
            .foregroundColor(.secondary)

            Button("Get Started") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(36)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 20)
        .transition(.scale.combined(with: .opacity))
    }

    private func install() {
        errorMessage = nil
        installing = true

        installTask = Task {
            let result = await performInstall()

            await MainActor.run {
                installing = false

                if result {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showSuccess = true
                    }
                } else {
                    errorMessage = "Installation failed. Please try again."
                }
            }
        }
    }

    private func performInstall() async -> Bool {
        let rule = "%admin ALL=(root) NOPASSWD: /usr/bin/powermetrics, /usr/bin/pmset\n"
        let dest = "/etc/sudoers.d/autothrottle"

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("autothrottle_sudoers_\(UUID().uuidString)")

        do {
            try rule.write(to: tmpURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write temp file:", error)
            return false
        }

        let username = NSUserName()
        let appSupport = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Autothrottle").path

        let cmd = """
        cp "\(tmpURL.path)" "\(dest)" && \
        chmod 440 "\(dest)" && \
        chown root:wheel "\(dest)" && \
        mkdir -p "\(appSupport)" && \
        chown -R \(username) "\(appSupport)"
        """

        let safeCmd = cmd.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"/bin/bash -c \\\"\(safeCmd)\\\"\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to run osascript:", error)
            return false
        }

        return process.terminationStatus == 0
    }
}
