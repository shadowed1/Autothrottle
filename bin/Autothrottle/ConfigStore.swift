import Foundation
import SwiftUI
import Combine

//  ConfigStore.swift
//  Created by shadowed1

final class ConfigStore: ObservableObject {
    static let shared = ConfigStore()

    @Published var config: Config {
        didSet {
            scheduleSave()
        }
    }

    private var saveTask: DispatchWorkItem?

    private init() {
        self.config = ConfigManager.shared.load()
    }

    func reload() {
        config = ConfigManager.shared.load()
    }

    private func scheduleSave() {
        saveTask?.cancel()

        let snapshot = config
        let task = DispatchWorkItem {
            ConfigManager.shared.save(snapshot)
        }

        saveTask = task
        DispatchQueue.global(qos: .background)
            .asyncAfter(deadline: .now() + 1.5, execute: task)
    }
}
