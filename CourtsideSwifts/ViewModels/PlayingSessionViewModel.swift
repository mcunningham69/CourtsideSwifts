import Foundation
import Combine
import CoreData

@MainActor
class PlayingSessionViewModel: ObservableObject {
    @Published var swapCandidates: [PlayerStatusDTO] = []
    
    @Published var currentSecondTick = Date()
    
    @Published var latestGameID: Int32 = 0

    private var isReloading = false
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
    @Published var useGradeFilter: Bool = false {
        didSet {
            // Clear selected players if any of them are now ineligible
            selectedWaitingPlayers.removeAll()

            // Re-evaluate isSelectable for all players
            loadParticipantsFromCoreData()
        }
    }

    
    private let context = PersistenceController.shared.container.viewContext
    private var cancellables = Set<AnyCancellable> ()
    @Published var selectedWaitingPlayers: Set<UUID> = []

    /// Subscribes to a refresh trigger, loads participants, and seeds play order
    init(refreshTrigger: AnyPublisher<Void, Never>) {
        // 1️⃣  Connect WebSocket immediately
        WebSocketManager.shared.connect()

        // 2️⃣  Listen for player updates pushed from the backend
        NotificationCenter.default.publisher(for: .webSocketDidReceivePlayerUpdate)
            .compactMap { $0.object as? PlayerStatusDTO }
            .sink { [weak self] dto in
                self?.handlePlayerUpdate(dto)   // ← your Core Data update helper
            }
            .store(in: &cancellables)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.loadParticipantsFromCoreData()
            self.seedNextPlayOrder()
        }

        refreshTrigger
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.reloadParticipantsSafely()
            }
            .store(in: &cancellables)
    }
    
    
    private func handlePlayerUpdate(_ dto: PlayerStatusDTO) {
        let context = PersistenceController.shared.container.viewContext
        
        context.perform {
            let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "uuid == %@", dto.uuid as CVarArg)

            do {
                let entity = try context.fetch(request).first ?? PlayerStatus(context: context)
                dto.copyTo(entity: entity)

                // Inject orderOfPlay if needed
                if entity.attendingSession && entity.orderOfPlay <= 1 {
                    let maxOrderRequest = NSFetchRequest<NSDictionary>(entityName: "PlayerStatus")
                    maxOrderRequest.resultType = .dictionaryResultType
                    maxOrderRequest.propertiesToFetch = ["orderOfPlay"]
                    maxOrderRequest.predicate = NSPredicate(format: "attendingSession == true")
                    maxOrderRequest.sortDescriptors = [NSSortDescriptor(key: "orderOfPlay", ascending: false)]
                    maxOrderRequest.fetchLimit = 1

                    if let result = try context.fetch(maxOrderRequest).first,
                       let maxOrder = result["orderOfPlay"] as? Int32 {
                        entity.orderOfPlay = maxOrder + 1
                    } else {
                        entity.orderOfPlay = 1
                    }

                    print("🔢 Injected new orderOfPlay = \(entity.orderOfPlay) for player \(dto.uuid)")
                }

                entity.needsSync = true
                try context.save()
                SyncCoordinator.shared.requestSync()

            } catch {
                print("❌ Core Data error while applying WS update:", error)
            }
        }
    }


    


    @MainActor
    func reloadParticipantsSafely() {
        guard !isReloading else { return }
        isReloading = true
        
        Task { @MainActor in
            self.loadParticipantsFromCoreData()
            self.seedNextPlayOrder()
            self.isReloading = false
        }
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

        guard
            let c1 = p1.categoryEnum,
            let c2 = p2.categoryEnum
        else {
            print("❌ Missing category")
            return
        }

        let lower: Set<PlayerCategory> = [.pending, .waiting]
        let upper: Set<PlayerCategory> = [.chosen,  .playing]

        let from: PlayerStatusDTO
        let to  : PlayerStatusDTO

        if lower.contains(c1) && upper.contains(c2) {
            from = p1; to = p2
        } else if upper.contains(c1) && lower.contains(c2) {
            from = p2; to = p1
        } else {
            print("❌ Invalid swap selection")
            return
        }

        // --- Core Data fetch ---
        let fetch: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        fetch.predicate = NSPredicate(
            format: "uuid == %@ OR uuid == %@",
            from.uuid as CVarArg,
            to.uuid as CVarArg
        )


        do {
            let results = try context.fetch(fetch)
            guard
                let fromEntity = results.first(where: { $0.uuid == from.uuid }),
                let toEntity   = results.first(where: { $0.uuid == to.uuid })
            else {
                print("❌ Could not locate both players")
                return
            }

            // --- Swap category and flags ---
            swap(&fromEntity.playerCategories, &toEntity.playerCategories)
            swap(&fromEntity.isWaiting,       &toEntity.isWaiting)
            swap(&fromEntity.isPlaying,       &toEntity.isPlaying)
            swap(&fromEntity.isChosen,        &toEntity.isChosen)
            swap(&fromEntity.courtNo,         &toEntity.courtNo)

            fromEntity.needsSync = true
            toEntity.needsSync   = true

            try context.save()
            print("✅ Players swapped & Core Data saved")

            // 🔔 Debounced sync to Azure
            SyncCoordinator.shared.requestSync()

            // --- UI refresh ---
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
                player.uuid == p1.uuid || player.uuid == p2.uuid
            })
        }

        for court in courtsToCheck {
            if let idx1 = court.players.firstIndex(where: { $0.uuid == p1.uuid }) {
                court.players[idx1] = PlayerStatusDTO(from: p2)
            }
            if let idx2 = court.players.firstIndex(where: { $0.uuid == p2.uuid }) {
                court.players[idx2] = PlayerStatusDTO(from: p1)
            }
        }

        // ✅ 4. Trigger UI refresh
        objectWillChange.send()
        
        let context = PersistenceController.shared.container.viewContext
        context.performAndWait {
            do {
                try context.save()
                SyncCoordinator.shared.requestSync()
            } catch {
                print("❌ Failed to save swapped court sessions: \(error)")
            }
        }

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

        // ✅ Get the chooser
        guard let chooser = waitingGroup.players.first(where: { $0.isChoosing }) else { return }

        let players = waitingGroup.players

        // ✅ Get eligible players excluding chooser, using full eligibility logic
        let eligibleOthers = players.filter {
            $0.id != chooser.id &&
            isSelectableForChooserInternal(players: players, chooser: chooser, target: $0)
        }

        // ✅ Shuffle and pick 3
        let selected = Array(eligibleOthers.shuffled().prefix(3))

        // ✅ Update selection (by ID)
        selectedWaitingPlayers = Set(selected.map { $0.id })
    }


    
    /// Persist a single player's DTO to Core Data and reload
    func updatePlayer(_ player: PlayerStatusDTO) {
        // Use bulk update for consistency, even with one player
        _ = PlayerStatusDTO.bulkCreateOrUpdate(from: [player], in: context, fromAzure: false)

        do {
            if context.hasChanges {
                try context.save()
            }

            // Slight delay to ensure UI update occurs after context save
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadParticipantsFromCoreData()
            }
        } catch {
            print("❌ Failed to save player update: \(error)")
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
            self.latestGameID = nextGameID

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadParticipantsFromCoreData()
            }

            seedNextPlayOrder()
            
            objectWillChange.send()

        }
    
    private func saveContextAndScheduleSync() {
        do {
            try context.save()
            SyncCoordinator.shared.requestSync()   // 🔔 Debounced upload
        } catch {
            print("❌ Core Data save error: \(error)")
        }
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
            let coreDataPlayers = try context.fetch(request)
            var players = coreDataPlayers.map { PlayerStatusDTO(from: $0) }

            // 🔁 Determine chooser
            let chooser = players.first(where: { $0.isChoosing && $0.categoryEnum == .waiting })

            // 🧠 Compute isSelectable
            players = players.map { player in
                var updated = player
                updated.isSelectable = isSelectableForChooserInternal(players: players, chooser: chooser, target: player)
                return updated
            }
            
            // 🧪 Debug: Confirm isSelectable values
       /*     for player in players {
                print("👁️ \(player.playerName ?? "Unnamed") isSelectable: \(player.isSelectable)")
            }*/

            // ✅ Persist isSelectable for all updated players in one bulk operation
            PlayerStatusDTO.bulkCreateOrUpdate(from: players, in: context, fromAzure: false)

            // ✅ Delegate grouping AND chooser assignment
            self.groupedParticipants = ParticipantSection.group(players)

        } catch {
            print("❌ Failed to load participants: \(error.localizedDescription)")
        }

        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    func refreshSelectability() {
        let chooser = players.first(where: { $0.isChoosing && $0.categoryEnum == .waiting })

        players = players.map { player in
            var updated = player
            updated.isSelectable = isSelectableForChooserInternal(players: players, chooser: chooser, target: player)
            return updated
        }

        // 🔁 Sync to Core Data if needed
        let context = PersistenceController.shared.container.viewContext
        PlayerStatusDTO.bulkCreateOrUpdate(from: players, in: context, fromAzure: false)

        do {
            try context.save()
        } catch {
            print("❌ Failed to persist isSelectable: \(error)")
        }

        // Update groupings
        groupedParticipants = ParticipantSection.group(players)
    }


    func isSelectableForChooserInternal(players: [PlayerStatusDTO], chooser: PlayerStatusDTO?, target: PlayerStatusDTO) -> Bool {
        guard useGradeFilter, let chooser = chooser else { return true }

        let gradeOrder = ["A1", "A2", "B1", "B2", "C1", "C2", "D1", "D2"]

        let chooserGrade = chooser.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let targetGrade  = target.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""

        guard let chooserIndex = gradeOrder.firstIndex(of: chooserGrade),
              let targetIndex  = gradeOrder.firstIndex(of: targetGrade) else {
            return false
        }

        // ✅ Always allow if target is same, lower, or up to 2 grades higher
        if targetIndex >= chooserIndex || targetIndex >= chooserIndex - 2 {
            if targetIndex <= chooserIndex + 2 {
                return true
            }
        }

        // ✅ Count eligible players in the allowed range (chooserIndex+2 and below)
        let eligiblePlayers = players.filter {
            guard let grade = $0.grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                  let index = gradeOrder.firstIndex(of: grade) else { return false }

            return $0.attendingSession && index <= chooserIndex + 2
        }

        if eligiblePlayers.count < 3 {
            print("⚠️ Relaxing grade rule: only \(eligiblePlayers.count) eligible players for chooser \(chooser.playerName ?? "")")
            return true
        }

        return false
    }





    
  

    private func persistSelectable(_ dto: PlayerStatusDTO, isSelectable: Bool) {
        var copy = dto
        copy.isSelectable = isSelectable
        copy.needsSync = true

        _ = PlayerStatusDTO.bulkCreateOrUpdate(from: [copy], in: context, fromAzure: false)

        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("❌ Failed to persist isSelectable: \(error)")
        }
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
            guard let entity = allEntities.first(where: { $0.uuid == player.uuid }) else { return }

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
                    $0.uuid != entity.uuid // exclude the one just timed out
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

        // ✅ Flatten and filter all chosen players from all groups
        let chosenPlayers = groupedParticipants
            .flatMap { $0.players }
            .filter { $0.categoryEnum == .chosen }

        // ✅ Prepare updated DTOs
        let updated = chosenPlayers.map { dto -> PlayerStatusDTO in
            var copy = dto
            copy.playerCategories = PlayerCategory.playing.rawValue
            copy.isChosen = false
            copy.isChoosing = false
            copy.gamesCount = (copy.gamesCount == 0) ? 1 : (copy.gamesCount + 1)
            return copy
        }

        // ✅ Perform batch update in Core Data
        _ = PlayerStatusDTO.bulkCreateOrUpdate(from: updated, in: context, fromAzure: false)

        do {
            if context.hasChanges {
                try context.save()
                print("✅ Moved Chosen players to Playing")
                loadParticipantsFromCoreData()
            }
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

