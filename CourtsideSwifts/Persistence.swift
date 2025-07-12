//
//  Persistence.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 4/7/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CourtsideSwifts")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
       // container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump

    }
}

extension PersistenceController {
    func migrateLegacyTimeFormatsToISO8601() {
        let context = self.container.viewContext
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "startedAt != nil OR finishedAt != nil")

        let legacyFormatter = DateFormatter()
        legacyFormatter.dateFormat = "HH:mm:ss"
        legacyFormatter.locale = Locale(identifier: "en_US_POSIX")
        legacyFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let isoFormatter = ISO8601DateFormatter()

        do {
            let results = try context.fetch(request)
            var updatedCount = 0

            for entity in results {
                var didChange = false

                if let legacyStart = entity.startedAt,
                   legacyStart.count == 8,
                   let parsedDate = legacyFormatter.date(from: legacyStart) {
                    entity.startedAt = isoFormatter.string(from: parsedDate)
                    didChange = true
                }

                if let legacyFinish = entity.finishedAt,
                   legacyFinish.count == 8,
                   let parsedDate = legacyFormatter.date(from: legacyFinish) {
                    entity.finishedAt = isoFormatter.string(from: parsedDate)
                    didChange = true
                }

                if didChange {
                    updatedCount += 1
                }
            }

            if updatedCount > 0 {
                try context.save()
                print("✅ Migration complete: \(updatedCount) records updated to ISO8601")
            }
        } catch {
            print("❌ Migration failed: \(error.localizedDescription)")
        }
    }
}

