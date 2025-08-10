//
//  PlayerListViewModel.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//
import Foundation
import CoreData
import Combine
import SwiftUI


@MainActor
class PlayerListViewModel: ObservableObject {
    let refreshSessionPublisher = PassthroughSubject<Void, Never>() //for syncing with Azure
    @Published var infoMessage: String? = nil
    @Published var players: [PlayerStatusDTO] = [] {
        didSet {
            applySearchFilter()
        }
    }
    
    private var reloadTask: Task<Void, Never>?
    
  //  private var hasUserSetSortMode = false

    @Published var sortMode: SortMode = .visits {
        didSet {
          //  hasUserSetSortMode = true
            applySearchFilter()
        }
    }
    @Published var toastMessage: String? = nil
    @Published var toastColor: Color = .green
    @Published var toastPosition: ToastPosition = .bottom
    
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var newPlayerName: String = ""
    @Published var selectedPlayers: Set<PlayerStatusDTO> = []
    @Published var filteredPlayers: [PlayerStatusDTO] = []
    @Published var searchText: String = "" {
        didSet {
            applySearchFilter()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()


    @Published var isEmailSearch: Bool = false {
        didSet {
            applySearchFilter()
        }
    }
    
    private let context: NSManagedObjectContext
    private let apiService: PlayerApiService
    
    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        apiService: PlayerApiService = PlayerApiService()
    ) {
        self.context = context
        self.apiService = apiService
        
        // Load local first
        loadFromCoreData()

        // Fetch latest from server
        Task { await fetchFromAPI() }

        // Subscribe to WebSocket updates
        NotificationCenter.default.publisher(for: .webSocketDidReceivePlayerUpdate)
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] notification in
                        guard let updated = notification.object as? PlayerStatusDTO else { return }
                        Task {
                            await self?.handleWebSocketPlayerUpdate(updated)
                        }
                    }
                    .store(in: &cancellables)
    }
    
    func showToast(message: String, color: Color = .green, position: ToastPosition = .bottom, duration: TimeInterval = 2.0) {
        self.toastMessage = message
        self.toastColor = color
        self.toastPosition = position

        // Auto-hide after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            withAnimation {
                self.toastMessage = nil
            }
        }
    }

 /*   @MainActor
    func handleWebSocketUpdate(_ dto: PlayerStatusDTO) async {
        let context = PersistenceController.shared.container.viewContext
        print("🌐 WebSocket received full player update: \(dto.uuid)")

        // Sync to Core Data
        PlayerStatusDTO.syncPlayerStatus(dto, fromAzure: true, in: context)
        do {
            try context.save()
        } catch {
            print("❌ Failed to save WebSocket update: \(error)")
        }

        // Update in-memory model
        if let index = players.firstIndex(where: { $0.uuid == dto.uuid }) {
            players[index] = dto
        } else {
            players.append(dto)
        }

        applySearchFilter()
        refreshSessionPublisher.send()
    }*/
    
    @MainActor
    func handleWebSocketPlayerUpdate(_ updated: PlayerStatusDTO) async {
        let context = PersistenceController.shared.container.viewContext
        print("🌐 WebSocket received player update: \(updated.uuid)")

        // Overwrite local Core Data with incoming update
        PlayerStatusDTO.syncPlayerStatus(updated, fromAzure: true, in: context)
        do {
            try context.save()
        } catch {
            print("❌ Failed to save WebSocket update: \(error)")
        }

        // Reload from Core Data to update UI
        reloadFromCoreDataAndRefreshUI()
    }
    
    @MainActor
    func reloadFromCoreDataAndRefreshUI() {
        players = loadFromCoreData()
        applySearchFilter()
        refreshSessionPublisher.send()
    }


    @MainActor
    func debouncedReload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
            self?.loadFromCoreData()
        }
    }
    
    func applySearchFilter() {
        var result: [PlayerStatusDTO]

        if searchText.isEmpty {
            result = players
        } else if isEmailSearch {
            result = players.filter { $0.email?.localizedCaseInsensitiveContains(searchText) == true }
        } else {
            result = players.filter { $0.playerName?.localizedCaseInsensitiveContains(searchText) == true }
        }

        // ✅ First: prioritize attending players
        result = result.sorted {
            if $0.attendingSession == $1.attendingSession {
                switch sortMode {
                case .visits:
                    return $0.visits > $1.visits
                case .name:
                    return ($0.playerName ?? "") < ($1.playerName ?? "")
                }
            }
            return $0.attendingSession && !$1.attendingSession
        }
        
      //  print("🔍 Filter applied, sortMode = \(sortMode), isEmailSearch = \(isEmailSearch), searchText = \(searchText)")
     //   print("🧑‍🤝‍🧑 Result count: \(result.count)")
      //  for p in result {
          //  print("• \(p.playerName ?? "-") visits=\(p.visits), attending=\(p.attendingSession)")
       // }


        filteredPlayers = result
    }

    @MainActor
    func toggleAttendance(for player: PlayerStatusDTO) {
        guard let index = players.firstIndex(of: player) else { return }

        var updated = player
        updated.attendingSession.toggle()
        updated.needsSync = true

        players[index] = updated
        applySearchFilter()

        Task {
            let context = PersistenceController.shared.container.viewContext
            await context.perform {
                let fetch: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
                fetch.predicate = NSPredicate(format: "uuid == %@", player.uuid as CVarArg)

                if let entity = try? context.fetch(fetch).first {
                    entity.attendingSession = updated.attendingSession
                    entity.needsSync = true
                    
                    try? context.save()

                    // ✅ Debounced sync to Azure
                    SyncCoordinator.shared.requestSync()
                }
            }
        }

    }

    

    func loadFromCoreData() -> [PlayerStatusDTO] {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "playerName", ascending: true)]

        do {
            // ✅ Perform fetch in isolation
            let coreDataPlayers = try context.fetch(request)

            // ✅ Convert to DTOs in a separate step
            let dtos = coreDataPlayers.map { PlayerStatusDTO(from: $0) }

            // ✅ Assign to @Published var AFTER mutation is complete
            DispatchQueue.main.async {
                self.players = dtos
            }
        } catch {
            errorMessage = "Failed to load local data: \(error.localizedDescription)"
            
           
        }
        
        return []
    }

    
    /*func loadFromCoreData() {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "playerName", ascending: true)]

        do {
            let coreDataPlayers = try context.fetch(request)
            players = coreDataPlayers.map { PlayerStatusDTO(from: $0) }

            //if hasUserSetSortMode {
                applySearchFilter()
           // } else {
           //     filteredPlayers = players.sorted { $0.visits > $1.visits }
          //  }
        } catch {
            errorMessage = "Failed to load local data: \(error.localizedDescription)"
        }
    }*/

    
    func fetchFromAPI() async {
        do {
            try await apiService.fetchAndStorePlayers(context: context)
            loadFromCoreData() // Refresh UI after fetching
        } catch {
            errorMessage = "Failed to fetch data from server: \(error.localizedDescription)"
        }
    }
    
    func splitName(_ fullName: String) -> (firstName: String, surname: String) {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        
        let firstName = parts.first.map(String.init) ?? ""
        let surname = parts.dropFirst().first.map(String.init) ?? ""
        
        return (firstName, surname)
    }

    
    @MainActor
    func addPlayer() async throws {
        // Don't add empty names
        let trimmedName = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let (first, last) = splitName(trimmedName)
        
        //determine next playrID
       // let maxID = players.map({$0.playerID}).max() ?? 0
       // let nextID = maxID + 1

        var newDTO = PlayerStatusDTO(
            uuid: .placeholder,
            playerName: trimmedName,
            firstName: first,
            surname: last,
            changed_by: "swift_client",
            email: "",
            visits: 1,
            isPlaying: false,
            isWaiting: false,
            isSelectable: true,
            isFacilitator: false,
            isChoosing: false,
            isTimeOut: false,
            warmingUp: false,
            grade: "C1",
            gamesCount: 0,
            isChosen: false,
            isAdmin: false,
            courtNo: 0,
            attendingSession: true,
            startedAt: "",
            finishedAt: "",
            orderOfPlay: 0,
            squareID: "",
            gameID: 0,
            playerCategories: 1,
            needsSync: true,
            notified: false
        )
        
        newPlayerName = "" // Clear the input field
        
        PlayerStatusDTO.addPlayer(newDTO)
        
        debouncedReload()
        
       /* // 1. Save locally first
        let entity = PlayerStatus(context: context)
        newDTO.copyTo(entity: entity)
        try? context.save()  // allow failure if local-only draft

        // 2. Upload to Azure
        do {
            try await apiService.upload(&newDTO, context: context)

            // 3. Update Core Data with new uuid if changed
            if entity.uuid != newDTO.uuid {
                entity.uuid = newDTO.uuid
                try? context.save()
                
            }

            // 4. Sync with UI
          //  players.append(newDTO)
            //players = loadFromCoreData()

        } catch {
            print("❌ Add-player upload failed:", error)
        }*/

    }
   
    @MainActor
    func checkInSelected(sessionViewModel: PlayingSessionViewModel) async throws {
        let affected = players.filter {
            selectedPlayers.contains($0) && !$0.attendingSession
        }

        let checkedCount = affected.count
        guard checkedCount > 0 else {
            selectedPlayers.removeAll()
            applySearchFilter()
            return
        }

        let maxOrder = players.filter(\ .attendingSession)
                              .map(\ .orderOfPlay)
                              .max() ?? 0
        var nextOrder = maxOrder + 1

        for i in players.indices where selectedPlayers.contains(players[i]) {
            guard !players[i].attendingSession else { continue }

            players[i].changed_by = "swift_client"
            players[i].attendingSession = true
            players[i].visits += 1
            players[i].isChosen = false
            players[i].warmingUp = true
            players[i].playerCategories = 1 //PlayerCategory.waiting.rawValue
            players[i].needsSync = true
            players[i].orderOfPlay = nextOrder
            players[i].isPlaying = false
            players[i].isWaiting = true
            players[i].isSelectable = true
            players[i].isTimeOut = false
            players[i].gamesCount = 0
            players[i].courtNo = 0
            players[i].startedAt = ""
            players[i].finishedAt = ""
            players[i].needsSync = true
            players[i].notified = false

            nextOrder += 1
        }

        if let chooser = players
            .filter({ $0.attendingSession })
            .min(by: { $0.orderOfPlay < $1.orderOfPlay }) {
            players = players.map { player in
                var updated = player
                updated.isChoosing = (player.uuid == chooser.uuid)
                return updated
            }
        }

        sessionViewModel.refreshSelectability()

        // 🔄 Persist & upload players
        let playersToSync = players.filter { $0.needsSync == true }
        for dto in playersToSync {
            await PlayerStatusDTO.uploadThenSaveToCoreData(dto)
        }

        selectedPlayers.removeAll()
        applySearchFilter()

        showToast(message: "✅ \(checkedCount) checked in", color: .green)
    }

  
    
    @MainActor
    func checkOutSelected(sessionViewModel: PlayingSessionViewModel) async throws {
        let affected = players.filter {
            selectedPlayers.contains($0) && $0.attendingSession
        }

        let checkedCount = affected.count
        guard checkedCount > 0 else {
            selectedPlayers.removeAll()
            applySearchFilter()
            return
        }

        for i in players.indices where selectedPlayers.contains(players[i]) {
            players[i].attendingSession = false
            players[i].isChosen = false
            players[i].warmingUp = false
            players[i].isTimeOut = false
            players[i].playerCategories = 0
            players[i].gamesCount = 0
            players[i].needsSync = false  // ✅ Already synced
            players[i].orderOfPlay = 0
            players[i].isWaiting = false
            players[i].isPlaying = false
            players[i].isSelectable = false
            players[i].courtNo = 0
            players[i].startedAt = ""
            players[i].finishedAt = ""
            players[i].notified = false
        }

        sessionViewModel.refreshSelectability()
        
        await PlayerStatusDTO.checkOutPlayersAndSave(affected)

        // 🔄 Persist & upload players
        let playersToSync = players.filter { $0.needsSync == true }
        for dto in playersToSync {
            await PlayerStatusDTO.uploadThenSaveToCoreData(dto)
        }

        selectedPlayers.removeAll()
        applySearchFilter()
        refreshSessionPublisher.send()

        showToast(message: "🛑 Checked out \(checkedCount) player(s)", color: .orange)
    }




    private func updateCoreData(for dto: PlayerStatusDTO) {
        let entity = PlayerStatus.createOrUpdate(from: dto, in: context)
        entity.needsSync = true
        entity.attendingSession = dto.attendingSession

        do {
            try context.save()
            
            
        } catch {
            print("❌ Failed to save player: \(error.localizedDescription)")
        }
    }
    
    private func updateCoreData(for dtos: [PlayerStatusDTO]) {
        
        let context = PersistenceController.shared.container.viewContext

        context.perform {
            let entities = PlayerStatusDTO.bulkCreateOrUpdate(from: dtos, in: context, fromAzure: false)

            guard entities.count == dtos.count else {
                print("❌ Mismatch between DTOs and created entities.")
                return
            }

            for index in 0..<dtos.count {
                let dto = dtos[index]
                let entity = entities[index]

                entity.needsSync = true
                entity.attendingSession = dto.attendingSession
            }

            do {
                if context.hasChanges {
                    try context.save()
                    print("✅ Successfully saved \(entities.count) players with sync metadata.")
                }
            } catch {
                print("❌ Failed to save player updates: \(error.localizedDescription)")
            }
        }


    }


    
    private func saveContext() {
        do{
            try context.save( )
        }
        catch{
            print("Failed to save Core Data: \(error.localizedDescription)")
        }
    }
    
    func resetDatabaseForTesting() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PlayerStatus.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            try context.save()
            print("✅ Core Data reset complete.")
            loadFromCoreData() // reload with empty state
        } catch {
            print("❌ Failed to reset Core Data: \(error.localizedDescription)")
        }
    }


    enum SortMode: String, CaseIterable, Identifiable {
        case visits = "Most Visits"
        case name = "Name"

        var id: String { self.rawValue }
    }
    
}




 

