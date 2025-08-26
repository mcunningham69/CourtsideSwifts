//
//  PlayerAPIService.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//
import Foundation
import CoreData

enum PlayerApiError: Error {
    case invalidURL
    case serverError(Int)
}

final class PlayerApiService: ObservableObject {
    private let context: NSManagedObjectContext
    private let baseURL = "https://swifts-player-sync.azurewebsites.net"
    
    static let shared = PlayerApiService()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }
    
    @Published var isSyncing: Bool = false

    // MARK: - Fetch All Players
    func fetchAndStorePlayers(context: NSManagedObjectContext) async throws {
        guard let url = URL(string: baseURL) else { return }
        
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601 // ISO8601 or adjust as needed
        
        let players = try decoder.decode([PlayerStatusDTO].self, from: data)
        print("📥 Decoded \(players.count) players from server")

        PlayerStatusDTO.bulkCreateOrUpdate(from: players, in: context, fromAzure: true)

        if context.hasChanges {
            try context.save()
        }
    }
    
    func getPlayerStatus(byID id: UUID) async throws -> PlayerStatusDTO? {
        let url = URL(string: "\(baseURL)/players/\(id)")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ API response invalid")
            return nil
        }

        let dto = try JSONDecoder().decode(PlayerStatusDTO.self, from: data)
        return dto
    }

  
    
    private func createPlayer(_ dto: PlayerStatusDTO) async throws -> [PlayerStatusDTO] {
        let url = URL(string: "\(baseURL)/players")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([dto])
        
        print("📨 POST payload:\n", String(data: request.httpBody ?? .init(), encoding: .utf8) ?? "—")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("🔵 Status code:", httpResponse.statusCode)
        print("📩 Response body:", String(data: data, encoding: .utf8) ?? "∅")
        
        switch httpResponse.statusCode {
        case 200, 201, 204:
            return try JSONDecoder().decode([PlayerStatusDTO].self, from: data)
        default:
            throw NSError(domain: "CreatePlayer", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Server error \(httpResponse.statusCode)"
            ])
        }
    }

    func updateSessionSettings(_ dto: SessionSettingsDTO) async throws {
        let url = URL(string: "\(baseURL)/players/sessions/update")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(dto)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
    
    func loadSessionSettings(sessionID: UUID) async throws -> SessionSettingsDTO? {
        let url = URL(string: "\(baseURL)/players/sessions/\(sessionID.uuidString)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(SessionSettingsDTO.self, from: data)
    }



    func fetchSessionSettings(for sessionID: UUID) async throws -> SessionSettingsDTO {
        let url = URL(string: "https://swifts-player-sync.azurewebsites.net/session-settings/\(sessionID.uuidString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        switch httpResponse.statusCode {
        case 200:
            // ✅ Success: decode single DTO, not array
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SessionSettingsDTO.self, from: data)

        case 404:
            print("⚠️ Session not found → Default session will be used.")
            return SessionSettingsDTO(
                sessionID: sessionID,
                userGradeFilter: false,
                updatedAt: Date()
            )

        default:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Failed to fetch session settings: \(httpResponse.statusCode) → \(errorMessage)")
            throw URLError(.badServerResponse)
        }
    }

    

    
    // MARK: - Checkout Players
        func checkOutPlayers(_ players: [PlayerStatusDTO]) async throws {
            let url = URL(string: "\(baseURL)/players/checkout")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let payload = players.map { PlayerCheckOutDTO(uuid: $0.uuid.uuidString) }
            request.httpBody = try JSONEncoder().encode(payload)

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        }




    func upload(_ dto: inout PlayerStatusDTO,
                context: NSManagedObjectContext) async throws {

        // ✅ 1️⃣ Determine if this is a new player
            let isNewPlayer = (dto.uuid == .placeholder)
        
        // 2️⃣ Upload to Azure (POST for new, PUT for existing)
        if isNewPlayer {
            guard let created = try await createPlayer(dto).first else {
                throw NSError(domain: "Upload",
                              code: 0,
                              userInfo: [NSLocalizedDescriptionKey: "Server did not return a valid player"])
            }
            dto = created
        } else {
            let ok = try await uploadToAzure(dto)
            guard ok else {
                throw NSError(domain: "Upload",
                              code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "PUT failed on server"])
            }
            // use original `dto` since PUT returns no updated values
        }
        
        // 3️⃣ Save to Core Data
            context.performAndWait {
                let entity = PlayerStatusDTO.createOrUpdate(from: dto, in: context)
                entity.needsSync = false
                do {
                    try context.save()
                } catch {
                    print("❌ Core Data save failed after upload: \(error)")
                }
            }
    }

    
    // MARK: - Upload Player Updates
    private func uploadToAzure(_ dto: PlayerStatusDTO) async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/players/\(dto.uuid)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(dto)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse {
            if (200..<300).contains(httpResponse.statusCode) {
                print("✅ PATCH success for \(dto.uuid)")
                return true
            } else {
                let body = String(data: data, encoding: .utf8) ?? "No response body"
                print("🔴 PATCH failed: \(body)")
            }
        }
        return false
    }


    
    // MARK: - Sync All Pending
    func syncPendingPlayersToAzure() async throws {
        await MainActor.run { self.isSyncing = true }
        print("🔁 Starting sync of pending players")
        
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == true")

        do {
            let players = try context.fetch(request)
            print("🔍 Found \(players.count) players needing sync")
            
            for player in players {
                let dto = PlayerStatusDTO(from: player)
                let success = try await uploadToAzure(dto)
                if success {
                    print("✅ Synced player \(dto.uuid)")
                    player.needsSync = false
                }
            }

            try context.save()
        } catch {
                print("❌ Sync failed: \(error.localizedDescription)")
                throw error
            }

            await MainActor.run { self.isSyncing = false }
        }
    
    // MARK: - Retry Failed on App Resume
    func retryPendingUpdates() {
        Task {
            try await self.syncPendingPlayersToAzure()
        }
    }

    // MARK: - Reset Core Data & Reload
    func resetLocalData() async throws {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PlayerStatus.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        try context.execute(deleteRequest)
        try context.save()
        
        let count = try context.count(for: PlayerStatus.fetchRequest())
        print("🧹 Core Data count after reset: \(count)")  // should be 0

    }

    @MainActor
    func resetAndFetchFreshData() async throws {
        isSyncing = true
        do {
            try await resetLocalData()
            let context = self.context
            let allDTOs = try await fetchAllDTOs()

            // 🔍 Filter only those that are attending
            let attendingDTOs = allDTOs.filter { $0.attendingSession }
            
            guard !attendingDTOs.isEmpty else {
                print("ℹ️ No players attending session. Reset skipped.")
                return
            }

            // ✅ Only update local Core Data with attending players
            PlayerStatusDTO.bulkCreateOrUpdate(from: attendingDTOs, in: context, fromAzure: false)

            try context.save()
            print("✅ Core Data reset and fresh sync complete with \(attendingDTOs.count) players.")
        } catch {
            print("❌ Reset & sync failed: \(error.localizedDescription)")
            throw error
        }
        isSyncing = false
    }

    
    func fetchAllDTOs() async throws -> [PlayerStatusDTO] {
        guard let url = URL(string: baseURL) else { throw PlayerApiError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PlayerApiError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PlayerStatusDTO].self, from: data)
    }


    func syncPlayerStatus(_ dto: PlayerStatusDTO) async throws -> PlayerStatusDTO {
        var copy = dto
        try await upload(&copy, context: self.context)
        return copy
    }
    
    
}

extension UUID {
    static let placeholder = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}











