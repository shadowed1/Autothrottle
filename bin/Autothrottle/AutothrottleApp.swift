import SwiftUI

// AutothrottleApp.swift
// Created by shadowed1

@main
struct AutothrottleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(
                onStart: { appDelegate.start() },
                onStop:  { appDelegate.stop()  }
            )
        } label: {
            Image(systemName: appState.menuBarFilled ? "cpu.fill" : "cpu")
                .font(.system(size: appState.menuBarLarge ? 18 : 13, weight: .regular))
                .animation(.easeInOut(duration: 0.15), value: appState.menuBarLarge)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Autothrottle") {
                    AboutWindowController.shared.show()
                }
            }
        }
    }
}
