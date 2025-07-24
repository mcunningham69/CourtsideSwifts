//
//  SyncCoordinator.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 19/7/2025.
//

import Combine
import Foundation

final class SyncCoordinator {
    static let shared = SyncCoordinator()

    private var trigger = PassthroughSubject<Void, Never>()
    private var cancellables = Set<AnyCancellable>()

    init() {
        trigger
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink {
                Task {
                    print("⏫ Debounced sync triggered")
                    try await PlayerApiService.shared.syncPendingPlayersToAzure()
                }
            }
            .store(in: &cancellables)
    }

    func requestSync() {
        trigger.send(())
    }
}
