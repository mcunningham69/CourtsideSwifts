import Foundation
import Combine
import CoreData

@MainActor
class PlayingSessionViewModel: ObservableObject {
    @Published var courts: [CourtSession] = []

    var activeCourts: [CourtSession] {
        courts.filter { $0.isActive }
    }

    @Published var groupedParticipants: [PlayersByCategory] = []
    @Published var playerToTimeout: PlayerStatusDTO? = nil
    @Published var useGradeFilter: Bool = true {
        didSet {
            // Refresh UI if needed
            objectWillChange.send()
        }
    }



    private let context = PersistenceController.shared.container.viewContext
    private var cancellables = Set<AnyCancellable> ()
    @Published var selectedWaitingPlayers: Set<UUID> = []

    
    //subscribe
    init(refreshTrigger: AnyPublisher<Void, Never>){
        //subscribe to refresh signal
        refreshTrigger
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadParticipantsFromCoreData()
            }
        
            .store(in: &cancellables)
    }

    func loadParticipantsFromCoreData() {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "attendingSession == true")
        
        do {
            let players = try context.fetch(request).map { PlayerStatusDTO(from: $0) }
            
            var groups: [PlayersByCategory] = []
            
            for category in PlayerCategory.allCases {
                let filtered = players
                    .filter { $0.categoryEnum == category }
                    .sorted(by: {
                        switch category {
                        case .waiting, .pending:
                            return $0.orderOfPlay < $1.orderOfPlay
                        case .chosen, .playing:
                            return $0.gameID < $1.gameID
                        }
                    })
                
                if category == .chosen {
                    // Add placeholder header for "Chosen"
                    groups.append(
                        PlayersByCategory(
                            category: "Chosen",
                            players: [],
                            isSelectable: false
                        )
                    )

                    // Then split into teams
                    let groupedByGameID = Dictionary(grouping: filtered) { $0.gameID }
                    for (gameID, playersInGame) in groupedByGameID.sorted(by: { $0.key < $1.key }) {
                        groups.append(
                            PlayersByCategory(
                                category: "Team \(gameID)",
                                players: playersInGame,
                                isSelectable: false
                            )
                        )
                    }
                }

                else {
                    // ✅ Default group handling
                    let isSelectable = (category == .waiting || category == .pending)
                    
                    groups.append(
                        PlayersByCategory(
                            category: category.displayName,
                            players: filtered,
                            isSelectable: isSelectable
                        )
                    )
                }
            }
            
            self.groupedParticipants = groups
        } catch {
            print("❌ Failed to fetch attending players: \(error.localizedDescription)")
        }
    }
    
    func toggleSelection(for player: PlayerStatusDTO) {
        let isEligible = isSelectableForChooser(player)
        print("🎯 Toggling \(player.playerName ?? "Unknown"), eligible: \(isEligible)")

        guard isEligible else { return }

        if selectedWaitingPlayers.contains(player.id) {
            selectedWaitingPlayers.remove(player.id)
        } else {
            selectedWaitingPlayers.insert(player.id)
        }
    }


 /*   func toggleSelection(for player: PlayerStatusDTO) {
        guard player.categoryEnum == .waiting else { return }

        if selectedWaitingPlayers.contains(player.id) {
            selectedWaitingPlayers.remove(player.id)
        } else if selectedWaitingPlayers.count < 3 {
            selectedWaitingPlayers.insert(player.id)
        }
    }*/

    func isSelectableForChooser(_ target: PlayerStatusDTO) -> Bool {
        
        if !useGradeFilter, !useGradeFilter {
            return true
        }
        guard let chooser = groupedParticipants
            .flatMap({ $0.players })
            .first(where: { $0.isChoosing }) else {
            return false
        }

        let gradeOrder: [String] = ["A1", "A2", "B1", "B2", "C1", "C2", "D1", "D2"]

        let chooserGrade = chooser.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let targetGrade = target.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""

        guard let chooserIndex = gradeOrder.firstIndex(of: chooserGrade),
              let targetIndex = gradeOrder.firstIndex(of: targetGrade) else {
            print("⚠️ Invalid grade(s): chooser=\(chooser.grade ?? "nil"), target=\(target.grade ?? "nil")")
            return false
        }

        // ✅ A1, A2, B1 can choose anyone
        if chooserIndex <= 2 { return true }
        
        // ✅ Check how many eligible players (by grade rule) are available
        let eligiblePlayers = groupedParticipants
            .first(where: { $0.category == "Waiting" })?
            .players
            .filter { waitingPlayer in
                guard let waitingGradeIndex = gradeOrder.firstIndex(of: waitingPlayer.grade ?? "") else { return false }
                return waitingGradeIndex >= chooserIndex - 2 && waitingGradeIndex <= chooserIndex
            } ?? []

        let eligibleCount = eligiblePlayers.count

        // ✅ Relax rule if fewer than 4 eligible players to select from
        if eligibleCount < 4 {
            print("⚠️ Relaxing grade rule: only \(eligibleCount) eligible players for chooser \(chooser.playerName ?? "")")
            return true
        }
        

        if chooserIndex >= 3 {
            // B2 or lower — restrict to at most 2 levels above
            return targetIndex >= chooserIndex - 2 && targetIndex <= chooserIndex
        } else {
            // B1 or higher can pick anyone
            return true
        }


    }





    
    func confirmChooserSelection() {
        guard selectedWaitingPlayers.count == 3 else { return }

        let allPlayers = groupedParticipants.flatMap { $0.players }
        guard let chooser = allPlayers.first(where: { $0.isChoosing }) else { return }
        
        let selectedPlayers = allPlayers.filter { selectedWaitingPlayers.contains($0.id) }

        let group = [chooser] + selectedPlayers

        let isValid = selectedPlayers.allSatisfy { target in
            canChoose(chooser: chooser, target: target, groupSoFar: group)
        }

        guard isValid else {
            print("❌ Invalid selection: one or more players exceed allowed grade difference")
            return
        }


        let context = PersistenceController.shared.container.viewContext
        
        // 0. Get next gameID
        let gameIDFetch: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "PlayerStatus")
        gameIDFetch.resultType = .dictionaryResultType
        gameIDFetch.propertiesToFetch = ["gameID"]
        gameIDFetch.sortDescriptors = [NSSortDescriptor(key: "gameID", ascending: false)]
        gameIDFetch.fetchLimit = 1

        var nextGameID: Int32 = 1
        if let result = try? context.fetch(gameIDFetch).first as? [String: Int32],
           let maxGameID = result["gameID"] {
            nextGameID = maxGameID + 1
        }

        // 1. Move chooser + selected players to Chosen
        let chosenIDs = selectedWaitingPlayers.union([chooser.id])

        for player in allPlayers {
            if chosenIDs.contains(player.id) {
                let entity = PlayerStatusDTO.createOrUpdate(from: player, in: context)
                entity.playerCategories = Int32(PlayerCategory.chosen.rawValue)
                entity.isChosen = true
                entity.isChoosing = false
                entity.gameID = nextGameID // ✅ assign team ID
            }
        }


        // 2. Assign new chooser from remaining Waiting players
        let remainingWaiting = allPlayers
            .filter { $0.categoryEnum == .waiting && !chosenIDs.contains($0.id) }
            .sorted(by: { $0.orderOfPlay < $1.orderOfPlay })

        if let newChooser = remainingWaiting.first {
            let entity = PlayerStatusDTO.createOrUpdate(from: newChooser, in: context)
            entity.isChoosing = true
        }

        // 3. Save
        do {
            try context.save()
            print("✅ Selection confirmed and saved.")
        } catch {
            print("❌ Failed to save selection: \(error)")
        }

        // 4. Reset and refresh
        selectedWaitingPlayers.removeAll()
        loadParticipantsFromCoreData()
    }
    
    func timeoutPlayer(_ player: PlayerStatusDTO) {
        let context = PersistenceController.shared.container.viewContext

        // 1. Get all currently attending players
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "attendingSession == true")

        do {
            let allEntities = try context.fetch(request)

            // 2. Find the one to update
            guard let entity = allEntities.first(where: { $0.playerID == player.playerID }) else { return }

            // 3. Get max orderOfPlay
            let maxOrder = allEntities.map { $0.orderOfPlay }.max() ?? 0
            entity.orderOfPlay = maxOrder + 1

            // 4. Update category and flags
            entity.playerCategories = Int32(PlayerCategory.pending.rawValue)
            entity.isChosen = false
            entity.isChoosing = false
            entity.isPlaying = false
            entity.needsSync = true

            // 5. Save timeout
            try context.save()
            print("✅ Player timed out and moved to Pending")

            // 6. Assign new chooser from remaining Waiting players
            let remainingWaiting = allEntities
                .filter {
                    $0.playerCategories == Int32(PlayerCategory.waiting.rawValue) &&
                    $0.playerID != entity.playerID // exclude the one just timed out
                }
                .sorted(by: { $0.orderOfPlay < $1.orderOfPlay })

            // 7. Reset all isChoosing
            for p in allEntities {
                p.isChoosing = false
            }

            if let nextChooser = remainingWaiting.first {
                nextChooser.isChoosing = true
            }

            try context.save()
            print("✅ New chooser assigned (if any)")

            // 8. Refresh UI
            loadParticipantsFromCoreData()
        } catch {
            print("❌ Failed to timeout player or assign new chooser: \(error)")
        }
    }

    func canChoose(chooser: PlayerStatusDTO, target: PlayerStatusDTO, groupSoFar: [PlayerStatusDTO]) -> Bool {
        
        let gradeOrder: [String] = ["A1", "A2", "B1", "B2", "C1", "C2", "D1", "D2"]

        guard let chooserIndex = gradeOrder.firstIndex(of: chooser.grade ?? ""),
              let targetIndex = gradeOrder.firstIndex(of: target.grade ?? "") else {
            return false // Unknown grades
        }

        // ✅ Exception: If A1 is already in group
        if groupSoFar.contains(where: { $0.grade == "A1" || chooser.grade == "A1" || target.grade == "A1" }) {
            return true
        }

        // ✅ A1, A2, B1 can choose anyone
        if chooserIndex <= 2 { return true }

        // ✅ Others can pick up to 2 grades higher
        return targetIndex <= chooserIndex + 2
    }


    func moveChosenToPlaying() {
        let context = PersistenceController.shared.container.viewContext

        for group in groupedParticipants {
            for player in group.players where player.categoryEnum == .chosen {
                let entity = PlayerStatusDTO.createOrUpdate(from: player, in: context)
                entity.playerCategories = Int32(PlayerCategory.playing.rawValue)
                entity.isChosen = false
                entity.isChoosing = false
            }
        }

        do {
            try context.save()
            print("✅ Moved Chosen players to Playing")
            loadParticipantsFromCoreData()
        } catch {
            print("❌ Failed to update player status: \(error)")
        }
    }


}

