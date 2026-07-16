import Foundation
import Combine

// AppState.swift
// Created by shadowed1

final class AppState: ObservableObject {

    static let shared: AppState = {
        AppState()
    }()

    @Published var isRunning: Bool = false
    @Published var menuBarFilled: Bool = false
    @Published var menuBarLarge: Bool = false

    var startAction: (() -> Void)?
    var stopAction:  (() -> Void)?

    private init() {}

    func toggle() {
        isRunning ? stopAction?() : startAction?()
    }

    func pulseMenuBarIcon() {
        let pulses = 3
        let interval = 0.33
        for i in 0..<(pulses * 2) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                self.menuBarFilled = (i % 2 == 0)
                self.menuBarLarge  = (i % 2 == 0)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(pulses * 2) * interval) {
            self.menuBarFilled = self.isRunning
            self.menuBarLarge  = false
        }
    }
}
