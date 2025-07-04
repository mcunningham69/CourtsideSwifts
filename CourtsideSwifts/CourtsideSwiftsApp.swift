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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
