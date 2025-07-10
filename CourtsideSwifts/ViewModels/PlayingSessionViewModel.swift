import Foundation
import Combine
import CoreData

@MainActor
class PlayingSessionViewModel: ObservableObject {
    @Published var courts: [CourtSession] = []
    var activeCourts: [CourtSession] {
        courts.filter { $0.isActive }
    }

   // @Published var groupedParticipants: [PlayersByCategory] = []
    var groupedParticipants: [ParticipantSection] = []

    @Published var playerToTimeout: PlayerStatusDTO? = nil
    @Published var nextPlayOrder: Int = 0
    @Published var useGradeFilter: Bool = true {
        didSet {
            // Refresh UI if needed
            objectWillChange.send()
        }
    }

    private let context = PersistenceController.shared.container.viewContext
    private var cancellables = Set<AnyCancellable> ()
    @Published var selectedWaitingPlayers: Set<UUID> = []

    /// Subscribes to a refresh trigger, loads participants, and seeds play order
    init(refreshTrigger: AnyPublisher<Void, Never>) {
        // Initial load and seed
        loadParticipantsFromCoreData()
        seedNextPlayOrder()

        // Subscribe to external refresh and reseed
        refreshTrigger
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.loadParticipantsFromCoreData()
                self.seedNextPlayOrder()
            }
            .store(in: &cancellables)
    }
    
    
    /// Seed nextPlayOrder based on highest existing order
    private func seedNextPlayOrder() {
        let orders: [Int] = groupedParticipants
            .flatMap { $0.players }
            .compactMap {Int( $0.orderOfPlay) }
        nextPlayOrder = orders.max() ?? 0

    }
    
    func randomlySelectTeam() {
        guard let waitingGroup = groupedParticipants.first(where: { $0.category == "Waiting" }) else { return }

        // Get the chooser
        guard let chooser = waitingGroup.players.first(where: { $0.isChoosing }) else { return }

        // Get eligible players excluding chooser
        let eligibleOthers = waitingGroup.players
            .filter { $0.id != chooser.id && isSelectableForChooser($0) }

        // Shuffle and pick 3
        let selected = Array(eligibleOthers.shuffled().prefix(3))

        // Update the selection
        selectedWaitingPlayers = Set(selected.map { $0.id })
    }

    
    /// Persist a single player's DTO to Core Data and reload
    func updatePlayer(_ player: PlayerStatusDTO) {
        let entity = PlayerStatus.createOrUpdate(from: player, in: context)
        entity.playerCategories = Int32(player.playerCategories)
        entity.orderOfPlay      = Int32(player.orderOfPlay)
        entity.gameID           = player.gameID
        do {
            try context.save()
            loadParticipantsFromCoreData()
        } catch {
            print("Failed to save player update: \(error)")
        }
    }
    
    /// Confirm the chooser and selected waiting players as a new "Chosen" team
            /// Confirm the chooser (auto-selected) and selected waiting players as a new "Chosen" team
        func confirmChooserSelection() {
            // Auto-pick chooser: lowest orderOfPlay in "Waiting"
            guard let waitingSection = groupedParticipants.first(where: { $0.category == "Waiting" }),
                  let chooserDTO = waitingSection.players.min(by: { $0.orderOfPlay < $1.orderOfPlay })
            else { return }

            // Gather selected waiting DTOs
            let selectedDTOs = groupedParticipants.flatMap { $0.players }
                .filter { selectedWaitingPlayers.contains($0.id) }

            // Build the team: chooser + selected
            let teamDTOs = [chooserDTO] + selectedDTOs

            // Compute next gameID (one higher than existing max)
            let allGameIDs = groupedParticipants.flatMap { $0.players }.map { $0.gameID }
            let maxGameID = allGameIDs.max() ?? 0
            let nextGameID: Int32 = maxGameID + 1

            // Update each DTO to Chosen
            for var dto in teamDTOs {
                dto.playerCategories = PlayerCategory.chosen.rawValue
                dto.isChosen         = true
                dto.isChoosing       = false
                dto.gameID           = nextGameID
                updatePlayer(dto)
            }

            // Reset selection state
            selectedWaitingPlayers.removeAll()

            // Refresh data and reseed play order
            loadParticipantsFromCoreData()
            seedNextPlayOrder()
            
            objectWillChange.send()

        }

    
    
    // MARK: - Sync Methods
        func syncWithTimeout(seconds: Double = 10.0) async {
            showSyncBanner = true
            defer { showSyncBanner = false }

            do {
                try await withTimeout(seconds: seconds) {
                    await self.performCloudSync()
                }
                print("✅ Sync successful")
            } catch {
                print("⏱️ Sync timeout or failed: \(error.localizedDescription)")
            }
        }

        private func performCloudSync() async {
            do{
                try await PlayerApiService.shared.fetchAndStorePlayers(context: context)
            } catch {
                print("❌ Error during cloud sync: \(error.localizedDescription)")
            }

            loadParticipantsFromCoreData()
        }

        private func withTimeout<T>(
            seconds: Double,
            operation: @escaping () async throws -> T
        ) async throws -> T {
            try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask { try await operation() }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    throw URLError(.timedOut)
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        }

    

    /// Loads participants from Core Data into groupedParticipants
    func loadParticipantsFromCoreData() {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "attendingSession == true")
        NotificationCenter.default.post(name: .refreshSession, object: nil)

        do {
            let players = try context.fetch(request).map { PlayerStatusDTO(from: $0) }

            var groups: [ParticipantSection] = []

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
                    groups.append(ParticipantSection(category: "Chosen", players: []))
                    let groupedByGameID = Dictionary(grouping: filtered) { $0.gameID }
                    for (gameID, playersInGame) in groupedByGameID.sorted(by: { $0.key < $1.key }) {
                        groups.append(
                            ParticipantSection(category: "Team \(gameID)", players: playersInGame)
                        )
                    }
                } else {
                    groups.append(
                        ParticipantSection(category: category.displayName, players: filtered)
                    )
                }
            }

            self.groupedParticipants = groups

            // 🔁 Enforce chooser logic
            let allPlayers = groups.flatMap { $0.players }
            let waitingPlayers = allPlayers.filter { $0.categoryEnum == .waiting }
            let nonWaitingPlayers = allPlayers.filter { $0.categoryEnum != .waiting }

            var chooserAssigned = false

            for player in nonWaitingPlayers {
                if player.isChoosing {
                    let entity = PlayerStatusDTO.createOrUpdate(from: player, in: context)
                    entity.isChoosing = false
                }
            }

            for player in waitingPlayers.sorted(by: { $0.orderOfPlay < $1.orderOfPlay }) {
                let entity = PlayerStatusDTO.createOrUpdate(from: player, in: context)
                if !chooserAssigned {
                    entity.isChoosing = true
                    chooserAssigned = true
                    print("🟡 Assigned chooser: \(player.playerName ?? "")")
                } else {
                    entity.isChoosing = false
                }
            }

            try context.save()

        } catch {
            print("❌ Failed to load participants: \(error.localizedDescription)")
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
    

    func canStartCourt(_ court: CourtSession, activeCourts: [CourtSession]) -> Bool {
        let alreadyAssignedIDs = activeCourts.flatMap { $0.players.map(\.id) }

        let availableChosenTeams = groupedParticipants
            .filter { $0.category.starts(with: "Team ") }
            .map { $0.players }
            .filter { team in
                team.count == 4 && !team.contains(where: { alreadyAssignedIDs.contains($0.id) })
            }

        return !availableChosenTeams.isEmpty
    }


    func nextTeamForCourt(_ court: CourtSession, activeCourts: [CourtSession]) -> [PlayerStatusDTO]? {
        let chosenTeams = groupedParticipants
            .filter { $0.category.starts(with: "Team ") }

        // Extract player IDs already playing on active courts
        let assignedPlayerIDs = Set(activeCourts.flatMap { court in
            court.players.map { $0.id }
        })

        for team in chosenTeams {
            let teamPlayerIDs = Set(team.players.map { $0.id })

            // Must be exactly 4 and not overlap with players on court
            if team.players.count == 4 && assignedPlayerIDs.isDisjoint(with: teamPlayerIDs) {
                return team.players
            }
        }

        return nil
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
    
    @MainActor
    func syncWithCloud() async {
        showSyncBanner = true
        do {
            try await withTimeout(seconds: 10.0) {
                try await PlayerApiService.shared.fetchAndStorePlayers(context: self.context)
            }
            print("✅ Sync completed")
            loadParticipantsFromCoreData()
        } catch {
            print("❌ Sync failed: \(error.localizedDescription)")
        }
        showSyncBanner = false
    }


    @Published var showSyncBanner = false

    func triggerBanner() {
        showSyncBanner = true
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000) // 3 sec
            showSyncBanner = false
        }
    }

}

