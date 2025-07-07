//
//  PlayerDataSync.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//

import Foundation
import CoreData

class PlayerDataSync {
    static func syncPlayers(from dtos: [PlayerStatusDTO], context: NSManagedObjectContext) {
        context.perform {
            for dto in dtos {
                _ = PlayerStatus.createOrUpdate(from: dto, in: context)
            }

            do {
                try context.save()
                print("✅ Core Data synced with \(dtos.count) players.")
            } catch {
                print("❌ Failed to save Core Data: \(error)")
            }
        }
    }
}
