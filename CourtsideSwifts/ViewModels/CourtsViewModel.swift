//
//  CourtsViewModel.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 9/7/2025.
//

import Foundation
import Combine

@MainActor
class CourtsViewModel: ObservableObject {
    let refreshTrigger = PassthroughSubject<Void, Never>()
    
    @Published var courtSessions: [CourtSession] = []
    private var timerCancellable: AnyCancellable?

    init() {
        // Create 3 default courts on load
        for i in 1...3 {
            let court = CourtSession(courtNumber: i)
            courtSessions.append(court)
        }

        // Timer to update countdowns every second
        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }

    func startCourt(_ court: CourtSession, with players: [PlayerStatusDTO]) {
        if let index = courtSessions.firstIndex(where: { $0.id == court.id }) {
            courtSessions[index].players = players
            courtSessions[index].isActive = true
            courtSessions[index].startTime = Date()
        }
    }

    func resetCourt(_ court: CourtSession) {
        if let index = courtSessions.firstIndex(where: { $0.id == court.id }) {
            courtSessions[index].players.removeAll()
            courtSessions[index].isActive = false
            courtSessions[index].startTime = nil
        }
    }
    
    func stopGame(for court: CourtSession) {
        var court = court
        
        let context = PersistenceController.shared.container.viewContext

        for player in court.players {
            let entity = PlayerStatusDTO.createOrUpdate(from: player, in: context)
            entity.playerCategories = Int32(PlayerCategory.waiting.rawValue)
            entity.isChosen = false
            entity.isChoosing = false
            entity.gameID = 0
        }

        court.players.removeAll()

        do {
            try context.save()
            print("✅ Players returned to Waiting")
        } catch {
            print("❌ Failed to stop game: \(error)")
        }

        // Trigger UI refresh
        refreshTrigger.send()
    }

}
