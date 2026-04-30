import SwiftUI

struct SettingsView: View {

    @State private var config: Config = ConfigManager.shared.load()
    @State private var saved = false
    @State private var saveTask: DispatchWorkItem? = nil
    @State private var peakMHz: Int = 3200
    @State private var showUninstallConfirm = false
    @State private var isUninstalling = false
    @State private var uninstallError: String? = nil
    @State private var showUninstallError = false
    @StateObject private var appState = AppState.shared


    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(appState.isRunning ? "Autothrottle Running" : "Autothrottle Stopped")
                            .font(.subheadline)
                            .foregroundColor(appState.isRunning ? .green : .secondary)
                            .bold()
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.isRunning },
                        set: { _ in appState.toggle() }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
                .padding(.vertical, 2)
            }
            
            GroupBox(label: Text("Main").font(.headline)) {
                VStack(spacing: 16) {

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Autothrottle Speed")
                                    .font(.subheadline)
                                    .bold()
                                Text("Higher values increase performance, but increase temps.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(modeLabel)
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .frame(width: 52, alignment: .trailing)
                                    .foregroundColor(modeColor)

                                Text("\(thresholdMHz) MHz")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .frame(width: 72, alignment: .trailing)
                                    .foregroundColor(modeColor)
                            }
                        }

                        GradientSlider(
                            value: Binding(
                                get: { modeFromThreshold(config.threshold) },
                                set: { config.threshold = thresholdFromMode($0) }
                            ),
                            range: 1...11,
                            step: 1
                        )
                    }

                    row(
                        label: "Low Power Mode Cooldown",
                        description: "Duration to stay in Low Power Mode before toggling off.",
                        value: Binding(
                            get: { Double(config.cooldown) / 60.0 },
                            set: { config.cooldown = Int($0 * 60.0) }
                        ),
                        range: 1...10,
                        step: 1,
                        format: {
                            let minutes = Int($0)
                            return minutes == 1 ? "1 minute" : "\(minutes) minutes"
                        }
                    )
                }
                .padding(.top, 8)
            }

            GroupBox(label: Text("Advanced").font(.headline)) {
                VStack(spacing: 16) {
                    row(
                        label: "Ignore CPU Usage Below",
                        description: "Skip throttle detection if CPU usage is below this value.",
                        value: Binding(
                            get: { Double(100 - config.idleThreshold) },
                            set: { config.idleThreshold = 100 - Int($0) }
                        ),
                        range: 5...20,
                        step: 5,
                        format: { "\(Int($0))%" }
                    )
                    row(
                        label: "Detect CPU Usage Above",
                        description: "Detect throttling when CPU usage is above value.",
                        value: Binding(
                            get: { Double(100 - config.loadThreshold) },
                            set: { config.loadThreshold = 100 - Int($0) }
                        ),
                        range: 30...80,
                        step: 5,
                        format: { "\(Int($0))%" }
                    )

                    row(
                        label: "Throttle Count",
                        description: "Consecutive throttling before Low Power Mode toggles on.",
                        value: Binding(
                            get: { Double(config.triggerCount) },
                            set: { config.triggerCount = Int($0) }
                        ),
                        range: 1...10,
                        step: 1,
                        format: { "\(Int($0))" }
                    )
                }
                .padding(.top, 8)
            }

            HStack {
                Button("Uninstall") {
                    showUninstallConfirm = true
                }
                .tint(.pink)
                .disabled(isUninstalling)

                Button("About") { AboutWindowController.shared.show() }
                    .tint(.indigo)
                    .buttonStyle(.bordered)

                Spacer()

                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.subheadline)
                        .transition(.opacity)
                }
            }
        }
        .padding(28)
        .frame(width: 520)
        .onAppear { loadPeak() }
        .onDisappear { flushPendingSave() }
        .onChange(of: config) {
            scheduleSave()
        }
        .sheet(isPresented: $showUninstallConfirm) {
            UninstallConfirmView(
                isUninstalling: $isUninstalling,
                onConfirm: {
                    showUninstallConfirm = false
                    performUninstall()
                },
                onCancel: {
                    showUninstallConfirm = false
                }
            )
        }
        .alert("Uninstall Failed", isPresented: $showUninstallError, presenting: uninstallError) { _ in
            Button("OK", role: .cancel) {}
        } message: { msg in
            Text(msg)
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = config
        let task = DispatchWorkItem {
            ConfigManager.shared.save(snapshot)
            DispatchQueue.main.async {
                withAnimation { saved = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { saved = false }
                }
            }
        }
        saveTask = task
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2, execute: task)
    }

    private func flushPendingSave() {
        guard let task = saveTask, !task.isCancelled else { return }
        task.cancel()
        let snapshot = config
        DispatchQueue.global(qos: .userInitiated).async {
            ConfigManager.shared.save(snapshot)
        }
    }

    private func performUninstall() {
        isUninstalling = true

        if let delegate = NSApp.delegate as? AppDelegate {
            delegate.stop()
        }

        UninstallHelper.uninstall { result in
            isUninstalling = false
            switch result {
            case .success:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NSApp.terminate(nil)
                }
            case .failure(let error):
                if case UninstallError.cancelled = error { return }
                uninstallError = error.localizedDescription
                showUninstallError = true
            }
        }
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

    private var modeLevel: Int {
        Int(modeFromThreshold(config.threshold).rounded())
    }

    private var modeLabel: String {
        modeLevel == 11 ? "Max" : "\(modeLevel)"
    }

    private var thresholdMHz: Int {
        if modeLevel == 11 { return peakMHz }
        let minScale = 0.75
        let maxScale = 0.99
        let t = Double(modeLevel - 1) / 9.0
        let scale = minScale + (maxScale - minScale) * t
        return Int((scale * Double(peakMHz)).rounded())
    }

    private func loadPeak() {
        let url = URL(fileURLWithPath: "/tmp/autothrottle_peak")
        DispatchQueue.global().async {
            if let text = try? String(contentsOf: url, encoding: .utf8),
               let val = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)), val > 0 {
                DispatchQueue.main.async { peakMHz = val }
            }
        }
    }

    private func row(
        label: String,
        description: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.subheadline).bold()
                    Text(description).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.subheadline)
                    .monospacedDigit()
                    .frame(width: 52, alignment: .trailing)
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
