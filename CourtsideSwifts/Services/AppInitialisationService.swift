//
//  AppInitialisationService.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 13/7/2025.
//
import CoreData

class AppInitialisationService {
    static let shared = AppInitialisationService()

    func resetSessionDataIfNeeded() async -> Bool {
        let context = PersistenceController.shared.container.viewContext

        return await context.perform {
            let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
            request.predicate = NSPredicate(format: "attendingSession == YES")

            do {
                let results = try context.fetch(request)
                guard !results.isEmpty else {
                    print("ℹ️ No players attending. Nothing to reset.")
                    return false  // ⬅️ EARLY RETURN
                }

                for player in results {
                    player.attendingSession = false
                    player.playerCategories = 0
                    player.isChosen = false
                    player.isChoosing = false
                    player.orderOfPlay = 0
                    player.gameID = 0
                    player.courtNo = 0
                    player.startedAt = nil
                    player.finishedAt = nil
                    player.warmingUp = false
                    player.needsSync = true // mark for sync
                }

                try context.save()
                print("✅ Reset \(results.count) attending players")
                return true  // ⬅️ Indicate reset occurred
            } catch {
                print("❌ Failed to reset session: \(error)")
                return false
            }
        }
    }


}
