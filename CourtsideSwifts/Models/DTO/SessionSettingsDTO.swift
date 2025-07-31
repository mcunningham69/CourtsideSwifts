//
//  SessionSettingsDTO.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 26/7/2025.
//

import Foundation
import CoreData

struct SessionSettingsDTO: Codable {
    let sessionID: UUID
    let userGradeFilter: Bool
    let updatedAt: Date
}


extension SessionSettingsDTO {
    static func saveToCoreData(_ dto: SessionSettingsDTO) async {
        let context = PersistenceController.shared.container.viewContext

        do {
            try await context.perform {
                let request: NSFetchRequest<SessionSettings> = SessionSettings.fetchRequest()
                request.predicate = NSPredicate(format: "sessionID == %@", dto.sessionID as CVarArg)

                let existing = try? context.fetch(request).first
                let entity = existing ?? SessionSettings(context: context)

                entity.sessionID = dto.sessionID
                entity.userGradeFilter = dto.userGradeFilter
                entity.updatedAt = dto.updatedAt

                try context.save()
                print("✅ SessionSettings saved to Core Data")
            }
        } catch {
            print("❌ Failed to save SessionSettings: \(error)")
        }
    }
    
    static func loadFromCoreData(sessionID: UUID) async -> SessionSettingsDTO? {
            let context = PersistenceController.shared.container.viewContext

            do {
                return try await context.perform {
                    let request: NSFetchRequest<SessionSettings> = SessionSettings.fetchRequest()
                    request.predicate = NSPredicate(format: "sessionID == %@", sessionID as CVarArg)
                    request.fetchLimit = 1

                    if let entity = try context.fetch(request).first {
                        return SessionSettingsDTO(
                            sessionID: entity.sessionID ?? UUID(),
                            userGradeFilter: entity.userGradeFilter,
                            updatedAt: entity.updatedAt ?? Date()
                        )
                    } else {
                        return nil
                    }
                }
            } catch {
                print("❌ Failed to load SessionSettings: \(error)")
                return nil
            }
        }
}

