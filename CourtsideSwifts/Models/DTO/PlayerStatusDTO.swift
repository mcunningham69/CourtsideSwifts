//
//  PlayerStatusDTO.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 4/7/2025.
//

import Foundation
import CoreData
import SwiftUICore
import SwiftUI


struct PlayerStatusDTO: Codable, Identifiable, Hashable {
    // MARK: - Identity
    var id: UUID { uuid }  // SwiftUI identifier
    var uuid: UUID         // Primary key for Core Data + sync

    // MARK: - Player Info
    var playerName: String?
    var firstName: String?
    var surname: String?
    var email: String?
    var grade: String?

    // MARK: - State Flags
    var isPlaying: Bool
    var isWaiting: Bool
    var isSelectable: Bool
    var isFacilitator: Bool
    var isChoosing: Bool
    var isTimeOut: Bool
    var warmingUp: Bool
    var isChosen: Bool
    var isAdmin: Bool
    var attendingSession: Bool
    var notified: Bool
    var needsSync: Bool = false

    // MARK: - Stats & Metadata
    var visits: Int32
    var gamesCount: Int32
    var courtNo: Int32
    var durationInSeconds: Int32
    var orderOfPlay: Int32
    var playerCategories: Int
    var gameID: Int32
    var squareID: String?

    // MARK: - Timing
    var startedAt: String?
    var finishedAt: String?

    // MARK: - Codable Mapping
    enum CodingKeys: String, CodingKey {
        case uuid
        case playerName = "playername"
        case firstName = "firstname"
        case surname, email, grade
        case visits
        case isPlaying = "isplaying"
        case isWaiting = "iswaiting"
        case isSelectable = "isselectable"
        case isFacilitator = "isfacilitator"
        case isChoosing = "ischoosing"
        case isTimeOut = "istimeout"
        case warmingUp = "warmingup"
        case isChosen = "ischosen"
        case isAdmin = "isadmin"
        case attendingSession = "attendingsession"
        case notified
        case gamesCount = "gamescount"
        case courtNo = "courtno"
        case durationInSeconds = "durationinseconds"
        case startedAt = "startedat"
        case finishedAt = "finishedat"
        case orderOfPlay = "orderofplay"
        case squareID = "squareid"
        case gameID = "gameid"
        case playerCategories = "playercategories"
        case needsSync = "needsSync"
    }

    // MARK: - Codable Init with Bool Handling
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode UUIDs
        uuid = try container.decode(UUID.self, forKey: .uuid)

        // Basic types
        playerName = try container.decodeIfPresent(String.self, forKey: .playerName)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        surname = try container.decodeIfPresent(String.self, forKey: .surname)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        grade = try container.decodeIfPresent(String.self, forKey: .grade)

        visits = try container.decode(Int32.self, forKey: .visits)
        gamesCount = try container.decode(Int32.self, forKey: .gamesCount)
        courtNo = try container.decode(Int32.self, forKey: .courtNo)
        durationInSeconds = try container.decode(Int32.self, forKey: .durationInSeconds)
        orderOfPlay = try container.decode(Int32.self, forKey: .orderOfPlay)
        gameID = try container.decode(Int32.self, forKey: .gameID)
        playerCategories = try container.decode(Int.self, forKey: .playerCategories)
        squareID = try container.decodeIfPresent(String.self, forKey: .squareID)
        startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
        finishedAt = try container.decodeIfPresent(String.self, forKey: .finishedAt)

        // Bool decoding with flexibility (Bool or Int)
        func decodeBool(forKey key: CodingKeys) throws -> Bool {
            if let intVal = try? container.decode(Int.self, forKey: key) {
                return intVal != 0
            }
            return try container.decode(Bool.self, forKey: key)
        }

        isPlaying = try decodeBool(forKey: .isPlaying)
        isWaiting = try decodeBool(forKey: .isWaiting)
        isSelectable = try decodeBool(forKey: .isSelectable)
        isFacilitator = try decodeBool(forKey: .isFacilitator)
        isChoosing = try decodeBool(forKey: .isChoosing)
        isTimeOut = try decodeBool(forKey: .isTimeOut)
        warmingUp = try decodeBool(forKey: .warmingUp)
        isChosen = try decodeBool(forKey: .isChosen)
        isAdmin = try decodeBool(forKey: .isAdmin)
        attendingSession = try decodeBool(forKey: .attendingSession)
        notified = try decodeBool(forKey: .notified)
        needsSync = try decodeBool(forKey: .needsSync)
    }

    // MARK: - Hashable & Equatable
    static func == (lhs: PlayerStatusDTO, rhs: PlayerStatusDTO) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var categoryEnum: PlayerCategory? {
        get {
            PlayerCategory(rawValue: playerCategories)
        }
        set {
            if let value = newValue {
                playerCategories = value.rawValue
            }
        }
    }
    
    var totalActiveSeconds: Int {
        let base = Int(durationInSeconds)
        let isoFormatter = ISO8601DateFormatter()
        //let legacyFormatter = DateFormatter.hhmmss

        // Try ISO 8601
        if let start = startedAt.flatMap({ isoFormatter.date(from: $0) }),
           let end = finishedAt.flatMap({ isoFormatter.date(from: $0) }),
           end > start {
            return base
        }

        // Still playing - use current time
        if let start = startedAt.flatMap({ isoFormatter.date(from: $0) }) {
            let extra = Int(Date().timeIntervalSince(start))
            return base + max(0, extra)
        }

        return base
    }
    
    init(from entity: PlayerStatus) {
        // MARK: - Identity
        self.uuid = entity.uuid ?? UUID()         // 💡 Use Core Data's UUID, fallback if missing

        // MARK: - Player Info
        self.playerName = entity.playerName
        self.firstName = entity.firstName
        self.surname = entity.surname
        self.email = entity.email
        self.grade = entity.grade

        // MARK: - State Flags
        self.isPlaying = entity.isPlaying
        self.isWaiting = entity.isWaiting
        self.isSelectable = entity.isSelectable
        self.isFacilitator = entity.isFacilitator
        self.isChoosing = entity.isChoosing
        self.isTimeOut = entity.isTimeOut
        self.warmingUp = entity.warmingUp
        self.isChosen = entity.isChosen
        self.isAdmin = entity.isAdmin
        self.attendingSession = entity.attendingSession
        self.notified = entity.notified
       // self.needsSync = entity.needsSync

        // MARK: - Stats & Metadata
        self.visits = Int32(entity.visits)
        self.gamesCount = Int32(entity.gamesCount)
        self.courtNo = Int32(entity.courtNo)
        self.durationInSeconds = entity.durationInSeconds
        self.orderOfPlay = Int32(entity.orderOfPlay)
        self.squareID = entity.squareID
        self.gameID = Int32(entity.gameID)
        self.playerCategories = Int(entity.playerCategories)

        // MARK: - Timing
        self.startedAt = entity.startedAt
        self.finishedAt = entity.finishedAt
    }


    
    func toEntity(context: NSManagedObjectContext) -> PlayerStatus {
        let entity = PlayerStatus(context: context)

        // MARK: - Identity
        entity.uuid = self.uuid                       // <- primary identity

        // MARK: - Player Info
        entity.playerName = self.playerName
        entity.firstName = self.firstName
        entity.surname = self.surname
        entity.email = self.email
        entity.grade = self.grade

        // MARK: - State Flags
        entity.isPlaying = self.isPlaying
        entity.isWaiting = self.isWaiting
        entity.isSelectable = self.isSelectable
        entity.isFacilitator = self.isFacilitator
        entity.isChoosing = self.isChoosing
        entity.isTimeOut = self.isTimeOut
        entity.warmingUp = self.warmingUp
        entity.isChosen = self.isChosen
        entity.isAdmin = self.isAdmin
        entity.attendingSession = self.attendingSession
        entity.notified = self.notified
      //  entity.needsSync = self.needsSync ?? false

        // MARK: - Stats & Metadata
        entity.visits = self.visits
        entity.gamesCount = self.gamesCount
        entity.courtNo = self.courtNo
        entity.durationInSeconds = self.durationInSeconds
        entity.orderOfPlay = self.orderOfPlay
        entity.squareID = self.squareID
        entity.gameID = self.gameID
        entity.playerCategories = Int32(self.playerCategories)

        // MARK: - Timing
        entity.startedAt = self.startedAt
        entity.finishedAt = self.finishedAt

        return entity
    }

    init(
        uuid: UUID = UUID(),
      //  playerID: UUID = UUID(),
        playerName: String? = nil,
        firstName: String? = nil,
        surname: String? = nil,
        email: String? = nil,
        visits: Int32 = 0,
        isPlaying: Bool = false,
        isWaiting: Bool = false,
        isSelectable: Bool = true,
        isFacilitator: Bool = false,
        isChoosing: Bool = false,
        isTimeOut: Bool = false,
        warmingUp: Bool = false,
        grade: String? = nil,
        gamesCount: Int32 = 0,
        isChosen: Bool = false,
        isAdmin: Bool = false,
        courtNo: Int32 = 0,
        attendingSession: Bool = false,
        startedAt: String? = nil,
        finishedAt: String? = nil,
        orderOfPlay: Int32 = 0,
        squareID: String? = nil,
        gameID: Int32 = 0,
        playerCategories: Int = 0,
        needsSync: Bool = false,
        durationInSeconds: Int32 = 0,
        notified: Bool = false
    ) {
        self.uuid = uuid
  //      self.playerID = playerID
        self.playerName = playerName
        self.firstName = firstName
        self.surname = surname
        self.email = email
        self.visits = visits
        self.isPlaying = isPlaying
        self.isWaiting = isWaiting
        self.isSelectable = isSelectable
        self.isFacilitator = isFacilitator
        self.isChoosing = isChoosing
        self.isTimeOut = isTimeOut
        self.warmingUp = warmingUp
        self.grade = grade
        self.gamesCount = gamesCount
        self.isChosen = isChosen
        self.isAdmin = isAdmin
        self.courtNo = courtNo
        self.attendingSession = attendingSession
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.orderOfPlay = orderOfPlay
        self.squareID = squareID
        self.gameID = gameID
        self.playerCategories = playerCategories
        self.needsSync = needsSync
        self.durationInSeconds = durationInSeconds
        self.notified = notified
    }

}

extension PlayerStatusDTO {
    var gradeColor: Color {
        guard let grade = grade?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() else {
                    return .gray
                }
        switch grade .uppercased() {
        case "A1": return .red
        case "A2": return .red
        case "B1":  return .orange
        case "B2":  return .orange
        case "C1":  return .green
        case "C2":  return .green
        case "D1":  return .blue
        case "D2":  return .blue
        default:   return .secondary
        }
    }
    
    var isTopRank: Bool {
        guard let g = grade?.uppercased() else { return false }
        return g == "A1" || g == "A2"
    }
}

extension PlayerStatusDTO {
    
    static func createOrUpdate(from dto: PlayerStatusDTO, in context: NSManagedObjectContext) -> PlayerStatus {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", dto.uuid as CVarArg)
        
        let entity: PlayerStatus
        
        do {
            if let existing = try context.fetch(request).first {
                entity = existing
            } else {
                entity = PlayerStatus(context: context)
                entity.uuid = dto.uuid
            }
        } catch {
            print("❌ Fetch error: \(error.localizedDescription)")
            entity = PlayerStatus(context: context)
            entity.uuid = dto.uuid
        }
        
        // Apply updates (single point of mutation)
        dto.copyTo(entity: entity)
        
        return entity
    }
    
    
    @discardableResult
    static func bulkCreateOrUpdate(
        from dtos: [PlayerStatusDTO],
        in context: NSManagedObjectContext,
        fromAzure: Bool = false
    ) -> [PlayerStatus] {
        guard !dtos.isEmpty else { return [] }
        
        // 🚦 Do everything on the private queue for safety
        var results: [PlayerStatus] = []
        context.performAndWait {
            //------------------------------------
            // 1️⃣  De‑duplicate by `uuid`
            //------------------------------------
            let uniqueDTOs = Dictionary(grouping: dtos, by: \.uuid)
                .compactMap { $0.value.first }
            let uuids = uniqueDTOs.map(\.uuid)
            print("🧮 Deduplicated \(dtos.count) DTOs to \(uniqueDTOs.count) unique records.")
            
            //------------------------------------
            // 2️⃣  Pre‑fetch any matching Core‑Data rows
            //------------------------------------
            let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
            request.predicate = uuids.count == 1 ?
            NSPredicate(format: "uuid == %@", uuids[0] as CVarArg) :
            NSPredicate(format: "uuid IN %@", uuids as NSArray)
            
            let existing = (try? context.fetch(request)) ?? []
            let entityMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.uuid, $0) })
            
            //------------------------------------
            // 3️⃣  Merge each DTO → Entity
            //------------------------------------
            for dto in uniqueDTOs {
                let entity = entityMap[dto.uuid] ?? PlayerStatus(context: context)
                
                let syncFlagBefore = entity.needsSync
                let didChange     = dto.copyTo(entity: entity, fromAzure: fromAzure)
                
                if fromAzure {
                    // 🔒 Keep whatever the local flag was – never overwrite from server rows
                    entity.needsSync = syncFlagBefore
                } else if dto.needsSync {
                    // ✏️ Local client explicitly wants this row synced
                    entity.needsSync = true
                }
                
                if didChange {
                    print("🔄 Updated player \(dto.uuid) — needsSync = \(entity.needsSync)")
                }
                results.append(entity)
            }
            
            //------------------------------------
            // 4️⃣  Single save if needed
            //------------------------------------
            if context.hasChanges {
                do {
                    try context.save()
                    print("✅ Saved \(results.count) players to Core Data")
                } catch {
                    print("❌ Failed saving context: \(error)")
                }
            } else {
                print("📭 No changes detected – skip save()")
            }
        }
        return results
    }
    


    
    // MARK: - Per‑row merge helper
    /// Copies **only the changed** fields from the DTO into the Core‑Data entity.
    /// Returns `true` if anything changed.
    @discardableResult
    func copyTo(entity: PlayerStatus, fromAzure: Bool = false) -> Bool {
        var didChange = false
        
        func update<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<PlayerStatus, T>, _ newValue: T) {
            if entity[keyPath: keyPath] != newValue {
                entity[keyPath: keyPath] = newValue
                didChange = true
            }
        }
        
        //------------------------------------
        // 🔐  Identity (never nil)
        //------------------------------------
        update(\.uuid, self.uuid)
        
        //------------------------------------
        // 📝  Optional Strings – keep existing if nil
        //------------------------------------
        if let name = playerName      { update(\.playerName, name) }
        if let first = firstName      { update(\.firstName, first) }
        if let last = surname         { update(\.surname, last) }
        if let mail = email           { update(\.email, mail) }
        if let grade = grade          { update(\.grade, grade) }
        if let start = startedAt      { update(\.startedAt, start) }
        if let finish = finishedAt    { update(\.finishedAt, finish) }
        if let sq = squareID          { update(\.squareID, sq) }
        
        //------------------------------------
        // 🚩  Booleans & ints
        //------------------------------------
        update(\.isPlaying,        isPlaying)
        update(\.isWaiting,        isWaiting)
        update(\.isSelectable,     isSelectable)
        update(\.isFacilitator,    isFacilitator)
        update(\.isChoosing,       isChoosing)
        update(\.isTimeOut,        isTimeOut)
        update(\.warmingUp,        warmingUp)
        update(\.isChosen,         isChosen)
        update(\.isAdmin,          isAdmin)
        update(\.attendingSession, attendingSession)
        update(\.notified,         notified)
        
        update(\.visits,             visits)
        update(\.gamesCount,         gamesCount)
        update(\.courtNo,            courtNo)
        update(\.durationInSeconds,  durationInSeconds)
        update(\.orderOfPlay,        orderOfPlay)
        update(\.gameID,             gameID)
        update(\.playerCategories,   Int32(playerCategories))
        
        //------------------------------------
        // 🔄  needsSync – only if this merge is *not* from Azure
        //------------------------------------
        if !fromAzure {
            update(\.needsSync, needsSync)
        }
        
        return didChange
    }
    
    static func addPlayer(_ dto: PlayerStatusDTO){
        Task {
            await uploadThenSaveToCoreData(dto)
        }
    }
    
    // MARK: - Wire into view model
    @MainActor func addToViewModel(_ viewModel: PlayerListViewModel) {
            PlayerStatusDTO.addPlayer(self)
            viewModel.loadFromCoreData()
        }
    
    // MARK: - Upload and persist logic
       static func uploadThenSaveToCoreData(_ dto: PlayerStatusDTO) async {
           do {
               // 🔼 First, upload to Azure
               let updated = try await PlayerApiService.shared.syncPlayerStatus(dto)

               // ✅ Then store to Core Data
               _ = syncPlayerStatus(updated, fromAzure: true,in: PersistenceController.shared.container.viewContext)

           } catch {
               // 🔁 If upload fails (e.g. offline), queue it locally
               print("⚠️ Upload failed: \(error.localizedDescription) — saving locally for retry")
               _ = syncPlayerStatus(dto, fromAzure: false,in: PersistenceController.shared.container.viewContext)
           }
       }
    
    static func checkOutPlayersAndSave(_ dtos: [PlayerStatusDTO]) async {
        do {
            // 🔼 Send checkout list to FastAPI
            try await PlayerApiService.shared.checkOutPlayers(dtos)

            // ✅ Then update Core Data for each player
            for dto in dtos {
                var updated = dto
                updated.attendingSession = false
                updated.isPlaying = false
                updated.isChosen = false
                updated.isWaiting = false
                updated.warmingUp = false
                updated.notified = false
                updated.courtNo = 0
                updated.startedAt = ""
                updated.finishedAt = ""
                updated.playerCategories = 0
                updated.gamesCount = 0
                updated.orderOfPlay = 0
                updated.isSelectable = false
                updated.isTimeOut = false
                updated.isChoosing = false
                updated.needsSync = false

                _ = syncPlayerStatus(updated, fromAzure: true, in: PersistenceController.shared.container.viewContext)
            }

        } catch {
            print("⚠️ Batch checkout failed: \(error.localizedDescription) — falling back to local-only update")
            for dto in dtos {
                _ = syncPlayerStatus(dto, fromAzure: false, in: PersistenceController.shared.container.viewContext)
            }
        }
    }
    
}

extension PlayerStatusDTO {
    /*@discardableResult
    static func syncPlayerStatus(_ dto: PlayerStatusDTO,
                                 fromAzure: Bool = false,
                                 in context: NSManagedObjectContext) -> PlayerStatus
    {
        bulkCreateOrUpdate(from: [dto], in: context, fromAzure: fromAzure).first!
    }*/
    
    @discardableResult
    static func syncPlayerStatus(_ dto: PlayerStatusDTO, fromAzure: Bool, in context: NSManagedObjectContext) -> PlayerStatus {
        let request = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", dto.uuid as CVarArg)
        let result = (try? context.fetch(request)) ?? []

        let entity = result.first ?? PlayerStatus(context: context)
        dto.copyTo(entity: entity)

        if fromAzure {
            entity.needsSync = false  // ✅ Prevent further uploads
        }

        return entity
    }

}



extension PlayerStatusDTO {
    var gameColor: Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .teal, .indigo, .mint, .cyan]
        let index = abs(Int(gameID)) % colors.count
        return colors[index]
    }
}

import Foundation

extension DateFormatter {
    static let hhmmss: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}



