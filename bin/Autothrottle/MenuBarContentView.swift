import SwiftUI

// MenuBarContentView.swift
// Created by shadowed1

struct MenuBarContentView: View {
    @StateObject private var appState = AppState.shared
    let onStart: () -> Void
    let onStop:  () -> Void

    @State private var isHoveringHeader = false
    @StateObject private var store = ConfigStore.shared
    @State private var saveTask: DispatchWorkItem? = nil

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
            VStack(spacing: 14) {
                quickSlider(
                    label: "Autothrottle Speed",
                    valueLabel: speedLabel,
                    valueColor: speedColor,
                    slider: {
                        GradientSlider(
                            value: Binding(
                                get: { modeFromThreshold(store.config.threshold) },
                                set: { store.config.threshold = thresholdFromMode($0) }
                            ),
                            range: 1...11,
                            step: 1
                        )
                    }
                )

                quickSlider(
                    label: "Low Power Mode Cooldown",
                    valueLabel: cooldownLabel,
                    valueColor: .secondary,
                    slider: {
                        Slider(
                            value: Binding(
                                get: { Double(store.config.cooldown) / 60.0 },
                                set: { store.config.cooldown = Int($0 * 60.0) }
                            ),
                            in: 1...10,
                            step: 1
                        )
                    }
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            Divider().padding(.horizontal, 8).padding(.vertical, 4)

            VStack(spacing: 2) {
                SettingsLink {
                    MenuRowLabel(icon: "gear", iconColor: .secondary, label: "Settings", shortcut: "⌘,")
                }
                .buttonStyle(MenuRowButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    NSApp.activate(ignoringOtherApps: true)
                })

                MenuRow(icon: "power", iconColor: .red, label: "Quit", shortcut: "⌘Q") {
                    onStop()
                    NSApp.terminate(nil)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(width: 260)
        .padding(.bottom, 4)
        .onChange(of: store.config) {
            scheduleSave()
        }
    }

    @ViewBuilder
    private func quickSlider<S: View>(
        label: String,
        valueLabel: String,
        valueColor: Color,
        @ViewBuilder slider: () -> S
    ) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(valueLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
            }
            slider()
        }
    }

    private var speedLabel: String {
        modeLevel == 11 ? "Max" : "\(modeLevel)"
    }

    private var cooldownLabel: String {
        let minutes = store.config.cooldown / 60
        return minutes == 1 ? "1 min" : "\(minutes) min"
    }

    private var speedColor: Color { modeColor }
    
    private var modeLevel: Int {
        Int(modeFromThreshold(store.config.threshold).rounded())
    }

    private func baseThreshold(from s: Double) -> Double {
        0.90 + 0.09 * pow((s - 1.0) / 9.0, 0.4)
    }

    private func baseSensitivity(from t: Double) -> Double {
        let normalized = (t - 0.90) / 0.09
        let s = pow(max(normalized, 0), 1.0 / 0.4) * 9.0 + 1.0
        return min(max(s.isNaN ? 5 : s, 1), 10)
    }

    private func thresholdFromMode(_ m: Double) -> Double {
        if m >= 11 { return 0.75 }
        let inverted = 11.0 - m
        return baseThreshold(from: inverted)
    }

    private func modeFromThreshold(_ t: Double) -> Double {
        if t <= 0.76 { return 11 }
        let s = baseSensitivity(from: t)
        let inverted = 11.0 - s
        return min(max(inverted, 1), 11)
    }

    private var modeColor: Color {
        let stops: [(Double, Color)] = [
            (1,  Color(red: 0.45, green: 0.65, blue: 0.85)),
            (3,  .cyan),
            (5,  .green),
            (7,  .yellow),
            (9,  .orange),
            (11, .purple)
        ]
        let level = Double(modeLevel)
        for i in 0..<stops.count - 1 {
            let (l0, c0) = stops[i]
            let (l1, c1) = stops[i + 1]
            guard level <= l1 else { continue }
            let t = (level - l0) / (l1 - l0)
            return blendColors(c0, c1, t: t)
        }
        return .red
    }

    private func blendColors(_ a: Color, _ b: Color, t: Double) -> Color {
        let ca = NSColor(a).usingColorSpace(.sRGB) ?? NSColor(a)
        let cb = NSColor(b).usingColorSpace(.sRGB) ?? NSColor(b)
        func lerp(_ x: CGFloat, _ y: CGFloat) -> Double { Double(x) + (Double(y) - Double(x)) * t }
        return Color(
            red:   lerp(ca.redComponent,   cb.redComponent),
            green: lerp(ca.greenComponent, cb.greenComponent),
            blue:  lerp(ca.blueComponent,  cb.blueComponent)
        )
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = store.config
        let task = DispatchWorkItem {
            ConfigManager.shared.save(snapshot)
        }
        saveTask = task
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 1, execute: task)
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
