//
//  PlayerStatusViewModel.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//

import Foundation
import CoreData
import Combine

@MainActor
class PlayerStatusViewModel: ObservableObject {
    @Published var players: [PlayerStatusDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service = PlayerStatusService()
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func loadPlayers() {
        isLoading = true
        errorMessage = nil

        service.fetchPlayerStatuses { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let dtoList):
                self.players = dtoList
                self.syncNewPlayers(dtoList)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }

            self.isLoading = false
        }
    }

    private func syncNewPlayers(_ dtoList: [PlayerStatusDTO]) {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()

        do {
            let existing = try context.fetch(request)
            let existingIDs = Set(existing.map { $0.uuid })

            let newPlayers = dtoList.filter { !existingIDs.contains($0.uuid) }

            if !newPlayers.isEmpty {
                print("🆕 Found \(newPlayers.count) new players. Adding to Core Data...")
            }

            let entities = PlayerStatusDTO.bulkCreateOrUpdate(from: dtoList, in: context, fromAzure: false)

            guard entities.count == dtoList.count else {
                print("❌ Mismatch: \(dtoList.count) DTOs vs \(entities.count) entities")
                return
            }

            if context.hasChanges {
                try context.save()
                print("✅ Saved \(entities.count) players to Core Data")
            }
        } catch {
            print("❌ Core Data fetch/save error: \(error)")
        }
    }


  /*  func loadPlayers() {
        isLoading = true
        errorMessage = nil

        service.fetchPlayerStatuses { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let dtoList):
                self.players = dtoList
                self.saveToCoreData(dtoList)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }

            self.isLoading = false
        }
    }*/

    private func saveToCoreData(_ dtoList: [PlayerStatusDTO]) {
        let entities = PlayerStatusDTO.bulkCreateOrUpdate(from: dtoList, in: context, fromAzure: false)

        guard entities.count == dtoList.count else {
            print("❌ Mismatch: \(dtoList.count) DTOs vs \(entities.count) entities")
            return  // ✅ This exits the function
        }

        do {
            if context.hasChanges {
                try context.save()
                print("✅ Saved \(entities.count) players to Core Data")
            }
        } catch {
            print("❌ Failed to save players to Core Data: \(error)")
        }
    }


}
