//
//  PlayerDataSync.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//

/*import Foundation
import CoreData

class PlayerDataSync {
    static func syncPlayers(from dtos: [PlayerStatusDTO], context: NSManagedObjectContext) {
        context.perform {
            // ✅ Filter only those that need syncing
            let playersNeedingSync = dtos.filter { $0.needsSync == true }

            // ✅ Perform bulk update once
            PlayerStatusDTO.bulkCreateOrUpdate(from: playersNeedingSync, in: context)

            do {
                try context.save()
                print("✅ Core Data synced with \(playersNeedingSync.count) players.")
            } catch {
                print("❌ Failed to save Core Data: \(error)")
            }
        }
    }

}*/
