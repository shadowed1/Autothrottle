import SwiftUI

struct MenuBarContentView: View {
    @StateObject private var appState = AppState.shared
    let onStart: () -> Void
    let onStop:  () -> Void
    
    @State private var isHoveringHeader = false

    var body: some View {
        VStack(spacing: 0) {
            Button(action: { appState.isRunning ? onStop() : onStart() }) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(appState.isRunning ? Color.green.opacity(0.18) : Color.secondary.opacity(0.10))
                            .frame(width: 32, height: 32)
                        Image(systemName: appState.isRunning ? "cpu.fill" : "cpu")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(appState.isRunning ? .green : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Autothrottle")
                            .font(.system(size: 13, weight: .semibold))
                        Text(appState.isRunning ? "Running" : "Stopped")
                            .font(.system(size: 11))
                            .foregroundStyle(appState.isRunning ? .green : .secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isHoveringHeader ? Color.primary.opacity(0.06) : .clear)
                )
            }
            .buttonStyle(.plain)
            .onHover { isHoveringHeader = $0 }
            .padding(.horizontal, 6)
            .padding(.top, 6)

            Divider().padding(.horizontal, 8).padding(.vertical, 4)

            VStack(spacing: 2) {
                SettingsLink {
                    MenuRowLabel(icon: "gear", iconColor: .secondary, label: "Settings", shortcut: "⌘,")
                }
                .buttonStyle(MenuRowButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    NSApp.activate(ignoringOtherApps: true)
                })
                .buttonStyle(MenuRowButtonStyle())

                MenuRow(icon: "power", iconColor: .red, label: "Quit", shortcut: "⌘Q") {
                    onStop()
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(width: 230)
        .padding(.bottom, 4)
    }
}

private struct MenuRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let shortcut: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13))
                Spacer()
                Text(shortcut)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct MenuRowLabel: View {
    let icon: String
    let iconColor: Color
    let label: String
    let shortcut: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }
}

private struct MenuRowButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.08) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .onHover { isHovered = $0 }
    }
}
