//
//  PlayerListViewModel.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//
import Foundation
import CoreData

@MainActor
class PlayerListViewModel: ObservableObject {
    //@Published var players: [PlayerStatus] = []
    @Published var players: [PlayerStatusDTO] = []
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
  //  @Published var isEmailSearch: Bool = false
    @Published var newPlayerName: String = ""
   // @Published var searchText: String = ""
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
        for player in selectedPlayers {
            // Update player fields
            if let index = players.firstIndex(where: { $0.id == player.id }) {
                players[index].attendingSession = true
                players[index].isChosen = false
                players[index].warmingUp = true
                players[index].lastVisit = Date()
                players[index].playerCategories = 0
                players[index].needsSync = true
                saveContext()
            }
        }

        // Clear selection if desired
        selectedPlayers.removeAll()
    }

    func checkOutSelected() {
        for player in selectedPlayers {
            if let index = players.firstIndex(where: { $0.id == player.id }) {
                players[index].attendingSession = false
                players[index].isChosen = false
                players[index].warmingUp = false
                players[index].isTimeOut = false
                players[index].playerCategories = 0
                players[index].needsSync = true
                saveContext()
            }
        }

        selectedPlayers.removeAll()
    }
    
    private func saveContext() {
        do{
            try context.save( )
        }
        catch{
            print("Failed to save Core Data: \(error.localizedDescription)")
        }
    }

    enum SortMode: String, CaseIterable, Identifiable {
        case visits = "Most Visits"
        case name = "Name"

        var id: String { self.rawValue }
    }
    
}




 

