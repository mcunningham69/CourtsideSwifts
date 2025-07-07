//
//  PlayerAPIService.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//
import Foundation
import CoreData

class PlayerApiService: ObservableObject {
    private let context: NSManagedObjectContext
    private let apiURL = URL(string: "https://swiftsplayerapi2025.azurewebsites.net/api/playerstatus")!
    
    static let shared = PlayerApiService()
    
    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
            self.context = context
        }
    
    @Published var isSyncing: Bool = false
    
    func fetchAndStorePlayers(context: NSManagedObjectContext) async throws {
        let (data, response) = try await URLSession.shared.data(from: apiURL)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            decoder.dateDecodingStrategy = .formatted(formatter)

           // decoder.dateDecodingStrategy = .iso8601
            _ = try decoder.decode([PlayerStatusDTO].self, from: data)
        } catch {
            print("❌ Decoding error: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("Missing key '\(key.stringValue)' – \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch for type \(type) – \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("Missing value for type \(type) – \(context.debugDescription)")
                @unknown default:
                    print("Unknown decoding error")
                }
            }
        }
        
        let players = try decoder.decode([PlayerStatusDTO].self, from: data)

        try await context.perform {
            for dto in players {
                _ = PlayerStatus.createOrUpdate(from: dto, in: context)
            }
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    func syncPendingPlayersToAzure() async {
        
        await MainActor.run{
            self.isSyncing = true
        }
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "needsSync == true")

        do {
            let players = try context.fetch(request)

            for player in players {
                let dto = PlayerStatusDTO(from: player)
                let success = try await uploadToAzure(dto)
                if success {
                    player.needsSync = false
                }
            }

            try context.save()
        } catch {
            print("❌ Sync failed: \(error.localizedDescription)")
        }
        
        await MainActor.run{
            self.isSyncing = false
        }
    }

    private func uploadToAzure(_ dto: PlayerStatusDTO) async throws -> Bool {
        guard let url = URL(string: "https://yourapi.azurewebsites.net/api/playerstatus") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let data = try JSONEncoder().encode(dto)
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

}



