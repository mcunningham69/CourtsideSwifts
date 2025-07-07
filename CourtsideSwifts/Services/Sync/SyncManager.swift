//
//  SyncManager.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 4/7/2025.
//
/*class SyncManager {
    static let shared = SyncManager()
    private init() {}

    let baseURL = URL(string: "https://yourapi.azurewebsites.net/api/playerstatus")!

    func fetchFromAzure(context: NSManagedObjectContext) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: baseURL)
            let players = try JSONDecoder().decode([PlayerStatusDTO].self, from: data)

            for dto in players {
                try await upsert(dto: dto, context: context)
            }

            try context.save()
        } catch {
            print("Download error: \(error)")
        }
    }

    func uploadToAzure(context: NSManagedObjectContext) async {
        let fetch: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        do {
            let players = try context.fetch(fetch)
            let dtos = players.map { PlayerStatusDTO(from: $0) }
            let data = try JSONEncoder().encode(dtos)

            var request = URLRequest(url: baseURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = data

            let (_, response) = try await URLSession.shared.data(for: request)
            print("Upload complete: \(response)")
        } catch {
            print("Upload error: \(error)")
        }
    }

    private func upsert(dto: PlayerStatusDTO, context: NSManagedObjectContext) async throws {
        let fetch = PlayerStatus.fetchRequest()
        fetch.predicate = NSPredicate(format: "playerID == %d", dto.playerID)
        if let existing = try context.fetch(fetch).first as? PlayerStatus {
            existing.update(from: dto)
        } else {
            let newPlayer = PlayerStatus(context: context)
            newPlayer.update(from: dto)
        }
    }
}*/


