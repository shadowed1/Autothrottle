import SwiftUI

struct UninstallConfirmView: View {

    @Binding var isUninstalling: Bool
    @State private var animationStart = Date()
    @State private var updateTask: Task<Void, Never>? = nil

    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {

            Image(systemName: "trash.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.red, .yellow, .red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .hueRotation(.degrees(
                    Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 10) * 36
                ))

            Text("Uninstall Autothrottle?")
                .font(.title3)
                .bold()

            VStack(alignment: .leading, spacing: 6) {
                label("Sudoers:", detail: "/etc/sudoers.d/autothrottle")
                label("Config:", detail: "~/Library/Application Support/Autothrottle")
                label("Temp files:", detail: "/tmp/autothrottle*")
                label("Autothrottle.app:", detail: "Moved to Trash")
            }
            .padding(.horizontal, 8)

            Text("Elevated permissions required to remove Autothrottle.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {

                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
                    .disabled(isUninstalling)

                Button(role: .destructive) {
                    onConfirm()
                } label: {
                    if isUninstalling {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Uninstall")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isUninstalling)
                .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(28)
        .frame(width: 380)

        .onAppear {
            updateTask = Task {
            }
        }
        .onDisappear {
            updateTask?.cancel()
            updateTask = nil
        }
    }

    private func label(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "minus.circle.fill")
                .foregroundColor(.red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
