//
//  PlayerListViewModel.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//
import Foundation
import CoreData
import Combine

@MainActor
class PlayerListViewModel: ObservableObject {
    let refreshSessionPublisher = PassthroughSubject<Void, Never>() //for syncing with Azure
    @Published var infoMessage: String? = nil
    @Published var players: [PlayerStatusDTO] = []
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

    @Published var isEmailSearch: Bool = false {
        didSet {
            applySearchFilter()
        }
    }
    
    @Published var sortMode: SortMode = .visits {
        didSet {
            applySearchFilter()
        }
    }

    
    
    private let context: NSManagedObjectContext
    private let apiService: PlayerApiService
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
         apiService: PlayerApiService = PlayerApiService()) {
        self.context = context
        self.apiService = apiService
        loadFromCoreData()           // Load local first
        Task { await fetchFromAPI() } // Then fetch latest from server
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

        filteredPlayers = result
    }


    
    func loadFromCoreData() {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "playerName", ascending: true)]
        
        do {
            let coreDataPlayers = try context.fetch(request)
            players = coreDataPlayers.map { PlayerStatusDTO(from: $0) }
            filteredPlayers = players.sorted { $0.visits > $1.visits }
                
            // players = try context.fetch(request)
            print("Core Data fetched \(players.count) players from Core Data")
        } catch {
            errorMessage = "Failed to load local data: \(error.localizedDescription)"
        }
    }
    
    func fetchFromAPI() async {
        do {
            try await apiService.fetchAndStorePlayers(context: context)
            loadFromCoreData() // Refresh UI after fetching
        } catch {
            errorMessage = "Failed to fetch data from server: \(error.localizedDescription)"
        }
    }
    
    func addPlayer() {
        // Don't add empty names
        let trimmedName = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        //determine next playrID
        let maxID = players.map({$0.playerID}).max() ?? 0
        let nextID = maxID + 1
        
        let newDTO = PlayerStatusDTO(
            playerID: nextID, // or generate based on last ID
            playerName: trimmedName,
            firstName: "",
            surname: "",
            email: "",
            visits: 0,
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
            attendingSession: false,
            firstVisit: Date(),
            lastVisit: Date(),
            startedAt: "",
            finishedAt: "",
            orderOfPlay: 0,
            squareID: "",
            gameID: 0,
            playerCategories: 0
        )
        
        players.append(newDTO)
        newPlayerName = "" // Clear the input field
    }
    
    func checkInSelected() {
        let affected = players.filter {
            selectedPlayers.contains($0) && !$0.attendingSession
        }
        let checkedCount = affected.count

        guard checkedCount > 0 else {
            selectedPlayers.removeAll()
            applySearchFilter()
            return
        }

        let maxOrder = players
            .filter { $0.attendingSession }
            .map { $0.orderOfPlay }
            .max() ?? 0

        var nextOrder = maxOrder + 1

        for i in players.indices {
            if selectedPlayers.contains(players[i]) {
                guard !players[i].attendingSession else { continue }

                players[i].attendingSession = true
                players[i].visits += 1
                players[i].isChosen = false
                players[i].warmingUp = true
                players[i].lastVisit = Date()
                players[i].playerCategories = PlayerCategory.waiting.rawValue
                players[i].needsSync = true
                players[i].orderOfPlay = nextOrder
                nextOrder += 1

                updateCoreData(for: players[i])
            }
        }

        applySearchFilter()
        selectedPlayers.removeAll()

        // Assign chooser
        for i in players.indices {
            players[i].isChoosing = false
        }

        if let chooserIndex = players.enumerated()
            .filter ({ $0.element.attendingSession  })
            .min(by: { $0.element.orderOfPlay < $1.element.orderOfPlay })?.offset {
            players[chooserIndex].isChoosing = true
            updateCoreData(for: players[chooserIndex])
        }

        infoMessage = "✅ Checked in \(checkedCount) player(s)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.infoMessage = nil
        }

        refreshSessionPublisher.send()

        Task {
            await PlayerApiService.shared.syncPendingPlayersToAzure()
        }
    }


    
    func checkOutSelected() {
        let affected = players.filter {
            selectedPlayers.contains($0) && $0.attendingSession
        }
        let checkedCount = affected.count

        guard checkedCount > 0 else {
            selectedPlayers.removeAll()
            applySearchFilter()
            return
        }

        for i in players.indices {
            if selectedPlayers.contains(players[i]) {
                guard players[i].attendingSession else { continue }

                players[i].attendingSession = false
                players[i].isChosen = false
                players[i].warmingUp = false
                players[i].isTimeOut = false
                players[i].playerCategories = 0
                players[i].needsSync = true
                players[i].gamesCount = 0

                updateCoreData(for: players[i])
            }
        }

        applySearchFilter()
        selectedPlayers.removeAll()

        refreshSessionPublisher.send()

        Task {
            await PlayerApiService.shared.syncPendingPlayersToAzure()
        }

        infoMessage = "🛑 Checked out \(checkedCount) player(s)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.infoMessage = nil
        }
    }



    private func updateCoreData(for dto: PlayerStatusDTO) {
        let entity = PlayerStatus.createOrUpdate(from: dto, in: context)
       // let entity = dto.toEntity(context: context)
        entity.needsSync = true
        entity.attendingSession = dto.attendingSession

        do {
            try context.save()
        } catch {
            print("❌ Failed to save player: \(error.localizedDescription)")
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




 

