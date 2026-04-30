import AppKit
import SwiftUI

final class HelpWindowController: NSWindowController {
    static let shared = HelpWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Autothrottle Help"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 400)
        window.center()
        window.contentView = NSHostingView(rootView: HelpView())
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct HelpView: View {
    @State private var content: AttributedString = AttributedString("Loading…")
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                Group {
                    if isLoading {
                        ProgressView("Fetching README…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(48)
                    } else {
                        Text(content)
                            .textSelection(.enabled)
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            Divider()

            HStack {
                Button("View on GitHub") {
                    if let u = URL(string: "https://github.com/shadowed1/Autothrottle") {
                        NSWorkspace.shared.open(u)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Button("Close") {
                    NSApp.windows
                        .first { $0.title == "Autothrottle Help" }?
                        .close()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 420, minHeight: 400)
        .task { await loadReadme() }
    }

    private func loadReadme() async {
        let remoteURL = URL(string: "https://raw.githubusercontent.com/shadowed1/Autothrottle/main/bin/HELP.md")!

        do {
            let (data, _) = try await URLSession.shared.data(from: remoteURL)
            guard let raw = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotDecodeContentData)
            }
            let attr = try AttributedString(
                markdown: raw,
                options: .init(
                    allowsExtendedAttributes: true,
                    interpretedSyntax: .inlineOnlyPreservingWhitespace
                )
            )
            content = attr
        } catch {
            content = AttributedString(
                "Could not load README.\n\nVisit https://github.com/shadowed1/Autothrottle for documentation.\n\nError: \(error.localizedDescription)"
            )
        }
        isLoading = false
    }
}
