import Foundation
import Combine
import CoreData

@MainActor
class PlayingSessionViewModel: ObservableObject {
    @Published var swapCandidates: [PlayerStatusDTO] = []
    
    @Published var currentSecondTick = Date()

    private var timer: Timer?

    @Published var courts: [CourtSession] = []
    var activeCourts: [CourtSession] {
        courts.filter { $0.isActive }
    }

   // @Published var groupedParticipants: [PlayersByCategory] = []
    var groupedParticipants: [ParticipantSection] = []
    
    @Published var isInSwapMode: Bool = false
    
    
    
    @Published var players: [PlayerStatusDTO] = [] {
        didSet {
            updateGroupedParticipants()
        }
    }



    @Published var playerToTimeout: PlayerStatusDTO? = nil
    @Published var nextPlayOrder: Int = 0
    @Published var useGradeFilter: Bool = true {
        didSet {
            // Re-evaluate isSelectable for all players
            loadParticipantsFromCoreData()
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
        
        //self.resetAllStartedAtToNil()
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                self.currentSecondTick = Date() // triggers SwiftUI to update views
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    
    func toggleSwapCandidate(_ player: PlayerStatusDTO) {
        if swapCandidates.contains(where: { $0.id == player.id }) {
            swapCandidates.removeAll(where: { $0.id == player.id })
        } else {
            if swapCandidates.count < 2 {
                swapCandidates.append(player)
            } else {
                swapCandidates = [player] // Reset with the new selection
            }
        }

        print("🔁 Swap candidates: \(swapCandidates.map { $0.playerName ?? "?" })")
    }
    
    func areSwapCandidatesValid() -> Bool {
        guard swapCandidates.count == 2 else { return false }

        guard let c1 = swapCandidates[0].categoryEnum,
              let c2 = swapCandidates[1].categoryEnum else {
            return false
        }


        let lowerGroup: Set<PlayerCategory> = [.pending, .waiting]
        let upperGroup: Set<PlayerCategory> = [.chosen, .playing]

        return (lowerGroup.contains(c1) && upperGroup.contains(c2)) ||
               (upperGroup.contains(c1) && lowerGroup.contains(c2))
    }

    func performSwap() {
        guard swapCandidates.count == 2 else { return }

        let p1 = swapCandidates[0]
        let p2 = swapCandidates[1]

        // Safely unwrap categories
        guard let c1 = p1.categoryEnum,
              let c2 = p2.categoryEnum else {
            print("❌ Missing category")
            return
        }

        let lowerGroup: Set<PlayerCategory> = [.pending, .waiting]
        let upperGroup: Set<PlayerCategory> = [.chosen, .playing]

        let from: PlayerStatusDTO
        let to: PlayerStatusDTO

        if lowerGroup.contains(c1) && upperGroup.contains(c2) {
            from = p1
            to = p2
        } else if upperGroup.contains(c1) && lowerGroup.contains(c2) {
            from = p2
            to = p1
        } else {
            print("❌ Invalid swap selection")
            return
        }

        // Fetch both entities from Core Data using playerID (Int)
        let fetchRequest: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "playerID == %d OR playerID == %d", from.playerID, to.playerID)

        do {
            let results = try context.fetch(fetchRequest)
            
            guard let fromEntity = results.first(where: { $0.playerID == from.playerID }),
                  let toEntity   = results.first(where: { $0.playerID == to.playerID }) else {
                print("❌ Could not locate both players in Core Data")
                return
            }

            // Swap category
            let tempCategory = fromEntity.playerCategories
            fromEntity.playerCategories = toEntity.playerCategories
            toEntity.playerCategories = tempCategory

            // Swap flags
            swap(&fromEntity.isWaiting, &toEntity.isWaiting)
            swap(&fromEntity.isPlaying, &toEntity.isPlaying)
            swap(&fromEntity.isChosen,  &toEntity.isChosen)

            // Swap courtNo if either is playing
            let tempCourtNo = fromEntity.courtNo
            fromEntity.courtNo = toEntity.courtNo
            toEntity.courtNo = tempCourtNo

            fromEntity.needsSync = true
            toEntity.needsSync = true

            try? context.save()
            print("✅ Players swapped and Core Data saved")

            swapCandidates.removeAll()
            loadParticipantsFromCoreData()
        } catch {
            print("❌ Swap failed: \(error)")
        }
    }
    
    @MainActor
    func mergeWaitingPlayers(_ newPlayers: [PlayerStatusDTO]) async {
        if let index = groupedParticipants.firstIndex(where: { $0.category == PlayerCategory.waiting.displayName  }) {
            groupedParticipants[index].players = newPlayers
        } else {
            let newGroup = ParticipantSection(category: PlayerCategory.waiting.displayName , players: newPlayers)
            groupedParticipants.append(newGroup)
        }
        objectWillChange.send()  // ✅ Triggers UI update without reloading everything
    }



    func updateGroupedParticipants() {
        groupedParticipants = ParticipantSection.group(players)
    }


    func updateCourtSessions(forSwap p1: PlayerStatus, and p2: PlayerStatus) {
        // ✅ 1. Swap courtNo between entities
        let court1 = p1.courtNo
        p1.courtNo = p2.courtNo
        p2.courtNo = court1

        // ✅ 2. Mark as needing sync
        p1.needsSync = true
        p2.needsSync = true

        // ✅ 3. Update in-memory court lists if needed (for live UI)
        let courtsToCheck = courts.filter { court in
            court.players.contains(where: { player in
                player.playerID == p1.playerID || player.playerID == p2.playerID
            })
        }

        for court in courtsToCheck {
            if let idx1 = court.players.firstIndex(where: { $0.playerID == p1.playerID }) {
                court.players[idx1] = PlayerStatusDTO(from: p2)
            }
            if let idx2 = court.players.firstIndex(where: { $0.playerID == p2.playerID }) {
                court.players[idx2] = PlayerStatusDTO(from: p1)
            }
        }

        // ✅ 4. Trigger UI refresh
        objectWillChange.send()
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

    

    func loadParticipantsFromCoreData() {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "attendingSession == true")
        NotificationCenter.default.post(name: .refreshSession, object: nil)

        do {
            var players = try context.fetch(request).map { PlayerStatusDTO(from: $0) }

            // 🔁 Determine chooser
            let chooser = players.first(where: { $0.isChoosing && $0.categoryEnum == .waiting })

            // 🧠 Compute isSelectable and persist
            players = players.map { player in
                var updated = player
                updated.isSelectable = isSelectableForChooserInternal(players: players, chooser: chooser, target: player)
                persistSelectable(updated, isSelectable: updated.isSelectable)
                return updated
            }

            // ✅ Delegate grouping AND chooser assignment
            self.groupedParticipants = ParticipantSection.group(players)
        } catch {
            print("❌ Failed to load participants: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }


    private func isSelectableForChooserInternal(players: [PlayerStatusDTO], chooser: PlayerStatusDTO?, target: PlayerStatusDTO) -> Bool {
        guard useGradeFilter, let chooser = chooser else { return true }

        let gradeOrder = ["A1", "A2", "B1", "B2", "C1", "C2", "D1", "D2"]

        let chooserGrade = chooser.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let targetGrade  = target.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""

        guard let chooserIndex = gradeOrder.firstIndex(of: chooserGrade),
              let targetIndex  = gradeOrder.firstIndex(of: targetGrade) else {
            return false
        }

        // ✅ A1, A2, B1 can choose anyone
        if chooserIndex <= 2 { return true }

        // ✅ Count eligible players in grade range
        let eligibleCount = players
            .filter { $0.categoryEnum == .waiting }
            .filter {
                guard let g = $0.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                      let idx = gradeOrder.firstIndex(of: g) else { return false }
                return idx <= chooserIndex + 2
            }
            .count

        // ✅ Relax if fewer than 4 eligible players
        if eligibleCount < 4 {
            return true
        }

        // ✅ Unrestricted if chooser is A1, A2, B1 (indexes 0, 1, 2)
        if chooserIndex <= 2 { return true }

        // ✅ Allow same grade or lower
        if targetIndex >= chooserIndex { return true }

        // ✅ Allow up to 2 grades higher
        if chooserIndex - targetIndex <= 2 { return true }

        return false



    }



    private func persistSelectable(_ dto: PlayerStatusDTO, isSelectable: Bool) {
        let entity = PlayerStatusDTO.createOrUpdate(from: dto, in: context)
        entity.isSelectable = isSelectable
        entity.needsSync = true
        try? context.save()
    }

    func toggleSelection(for player: PlayerStatusDTO) {
        // ✅ Max 3 selected waiting players
        if selectedWaitingPlayers.contains(player.id) {
            selectedWaitingPlayers.remove(player.id)
        } else {
            if selectedWaitingPlayers.count < 3 {
                selectedWaitingPlayers.insert(player.id)
            } else {
                print("❌ Only 3 players can be selected with the chooser.")
            }
        }
    }
   /* func toggleSelection(for player: PlayerStatusDTO) {
        let isEligible = isSelectableForChooser(player)
        print("🎯 Toggling \(player.playerName ?? "Unknown"), eligible: \(isEligible)")

        guard isEligible else { return }

        if selectedWaitingPlayers.contains(player.id) {
            selectedWaitingPlayers.remove(player.id)
        } else {
            // ✅ Only allow up to 4 selected players
            if selectedWaitingPlayers.count >= 4 {
                return // Do nothing
            }
            
            selectedWaitingPlayers.insert(player.id)
        }
        
        
    }*/
    
    //DELETE ??
    func isSelectableForChooser(_ target: PlayerStatusDTO) -> Bool {
        guard useGradeFilter else {
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
            persistSelectable(target, isSelectable: false)
            return false
        }

        // ✅ A1, A2, B1 can select anyone
        if chooserIndex <= 2 {
            persistSelectable(target, isSelectable: true)
            return true
        }

        // ✅ Eligible waiting players within grade range
        let eligiblePlayers = groupedParticipants
            .first(where: { $0.category == "Waiting" })?
            .players
            .filter { player in
                guard let g = player.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                      let index = gradeOrder.firstIndex(of: g) else { return false }
                return index >= chooserIndex - 2 && index <= chooserIndex
            } ?? []

        // ✅ Relax if not enough eligible players to form a team
        if eligiblePlayers.count < 4 {
            print("⚠️ Relaxing grade rule: only \(eligiblePlayers.count) eligible players for chooser \(chooser.playerName ?? "")")
            persistSelectable(target, isSelectable: true)
            return true
        }

        let allowed: Bool

        if chooserIndex <= 2 {
            allowed = true
        } else if targetIndex >= chooserIndex {
            allowed = true
        } else {
            allowed = chooserIndex - targetIndex <= 2
        }

        persistSelectable(target, isSelectable: allowed)
        return allowed
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

    private func isGradeSelectable(chooserIndex: Int, targetIndex: Int) -> Bool {
        if chooserIndex <= 2 { return true }
        if targetIndex >= chooserIndex { return true }
        return chooserIndex - targetIndex <= 2
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


    func resetAllStartedAtToNil() {
        

        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()

        do {
            let players = try context.fetch(request)
            for player in players {
                player.startedAt = nil
            }
            try context.save()
            print("✅ All startedAt fields set to nil.")
        } catch {
            print("❌ Failed to reset startedAt fields: \(error)")
        }
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
         //   print("✅ New chooser assigned (if any)")

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
                
                // Increment game count safely
                if entity.gamesCount == 0 {
                    entity.gamesCount = 1
                } else {
                    entity.gamesCount += 1
                }

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
            print("❌ Sync failedn with cloud: \(error.localizedDescription)")
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

