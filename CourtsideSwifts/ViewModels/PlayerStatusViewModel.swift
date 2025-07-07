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
                self.saveToCoreData(dtoList)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }

            self.isLoading = false
        }
    }

    private func saveToCoreData(_ dtoList: [PlayerStatusDTO]) {
        for dto in dtoList {
            _ = PlayerStatus.createOrUpdate(from: dto, in: context)
        }

        do {
            try context.save()
        } catch {
            print("Failed to save players to Core Data: \(error)")
        }
    }
}
