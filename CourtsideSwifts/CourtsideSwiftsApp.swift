//
//  CourtsideSwiftsApp.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 4/7/2025.
//

import SwiftUI

@main
struct CourtsideSwiftsApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    
    init() {
        WebSocketManager.shared.connect()   // 👈 start WS on app launch
    }
    
    
    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(networkMonitor)
            
        }
    }
}
