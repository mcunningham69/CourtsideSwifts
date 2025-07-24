//
//  CourtsViewModel.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 9/7/2025.
//

import Foundation
import Combine
import CoreData

@MainActor
class CourtsViewModel: ObservableObject {
    let refreshTrigger = PassthroughSubject<Void, Never>()
    
    @Published var courts: [CourtSession] = []
    
    private var timerCancellable: AnyCancellable?

    init() {
        // Create 3 default courts on load
        for i in 1...3 {
            let court = CourtSession(courtNumber: i)
            
            courts.append(court)
        }

        // Timer to update countdowns every second
        timerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
    
    func startPlay(on court: CourtSession, from sessionViewModel: PlayingSessionViewModel) async {
        guard court.players.count == 4 else { return }
        let context = PersistenceController.shared.container.viewContext
        let currentGameID = sessionViewModel.latestGameID

        context.performAndWait {
            do {
                let fetch: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
                fetch.predicate = NSPredicate(format: "gameID == %d AND isChosen == true", currentGameID)

                let chosenPlayers = try context.fetch(fetch)
                let now = Date()
                let isoFormatter = ISO8601DateFormatter()

                for entity in chosenPlayers {
                    entity.playerCategories = Int32(PlayerCategory.playing.rawValue)
                    entity.isChosen = false
                    entity.isPlaying = true
                    entity.isWaiting = false
                    entity.gamesCount += 1
                    entity.courtNo = Int32(court.courtNumber)
                    entity.startedAt = isoFormatter.string(from: now)
                    entity.finishedAt = nil
                    entity.needsSync = true
                }
                
                try context.save()
                
                // ✅ Debounced sync to Azure
                SyncCoordinator.shared.requestSync()

                // Refresh DTOs from Core Data to sync with UI
                court.players = chosenPlayers.map { PlayerStatusDTO(from: $0) }
            } catch {
                print("❌ Core Data error: \(error)")
            }
        }

        // ✅ Update in-memory CourtSession
        if let idx = courts.firstIndex(where: { $0.id == court.id }) {
            courts[idx].players = court.players
            courts[idx].isActive = true
            courts[idx].startTime = Date()
        }

        sessionViewModel.startTimer()
        sessionViewModel.loadParticipantsFromCoreData()

        DispatchQueue.main.async {
            sessionViewModel.objectWillChange.send()
            self.refreshTrigger.send()
        }
    }



    /// Stops play on the given court and moves players back to waiting
    func stopPlay(on court: CourtSession,from sessionViewModel: PlayingSessionViewModel) async {
        let context = PersistenceController.shared.container.viewContext
        let fetchAll: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        fetchAll.predicate = NSPredicate(format: "attendingSession == true")

        do {
            let allEntities = try context.fetch(fetchAll)
            let maxOrder = allEntities.map { $0.orderOfPlay }.max() ?? 0
            var nextOrder = maxOrder + 1

            for dto in court.players {
                if let entity = allEntities.first(where: { $0.uuid == dto.uuid }) {
                    entity.playerCategories = Int32(PlayerCategory.waiting.rawValue)
                    entity.isPlaying = false
                    entity.isChosen = false
                    entity.isChoosing = false
                    entity.warmingUp = false
                    entity.isWaiting = true
                    entity.gameID = 0
                    entity.courtNo = 0
                    
                    let now = Date()
                    let isoFormatter = ISO8601DateFormatter()
                    entity.finishedAt = isoFormatter.string(from: now)


                    // Add current duration to durationInSeconds
                    if let startedAtStr = entity.startedAt,
                       let startDate = isoFormatter.date(from: startedAtStr) {
                        let sessionDuration = Int32(now.timeIntervalSince(startDate))
                        entity.durationInSeconds += max(sessionDuration, 0)
                    }

                    entity.startedAt = nil
                                  
                    entity.orderOfPlay = nextOrder
                    entity.needsSync = true
                    nextOrder += 1
                }
            }

            try context.save()
            
            // ✅ Debounced sync to Azure
            SyncCoordinator.shared.requestSync()
            
        } catch {
            print("❌ Stop play failed: \(error)")
        }

        // Update local model
        if let idx = courts.firstIndex(where: { $0.id == court.id }) {
            courts[idx].isActive = false
            courts[idx].startTime = nil
            courts[idx].players.removeAll()
        }
        
        sessionViewModel.stopTimer()
        
        // ✅ Reload session to refresh groupedParticipants and selection states
        await MainActor.run {
            sessionViewModel.selectedWaitingPlayers.removeAll()
            sessionViewModel.loadParticipantsFromCoreData()
        }
        
        // Notify listeners
        refreshTrigger.send()
        
    }
    
 

    func resetCourt(_ court: CourtSession) {
        if let index = courts.firstIndex(where: { $0.id == court.id }) {
            courts[index].players.removeAll()
            courts[index].isActive = false
            courts[index].startTime = nil
        }
    }
    
    
    func addNewCourt() {
        let nextNumber = (courts.map { $0.courtNumber }.max() ?? 0) + 1
        courts.append(CourtSession(courtNumber: nextNumber))
    }

    /// Removes the last court, if any
    func removeLastCourt() {
        guard !courts.isEmpty else { return }
        courts.removeLast()
    }

    /// Removes a specific court by its ID
    func removeCourt(_ court: CourtSession) {
        courts.removeAll { $0.id == court.id }
    }


}
