//
//  NetworkMonitor.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 6/7/2025.
//

import Network
import Foundation

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    @Published var isConnected: Bool = false

    private init() {
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isConnected = path.status == .satisfied
                if self.isConnected {
                    print("✅ Network restored – triggering sync")
                    Task {
                        await PlayerApiService.shared.syncPendingPlayersToAzure()
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }
}
