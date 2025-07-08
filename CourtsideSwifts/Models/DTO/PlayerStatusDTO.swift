//
//  PlayerStatusDTO.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 4/7/2025.
//

import Foundation
import CoreData
import SwiftUICore


struct PlayerStatusDTO: Codable, Identifiable, Hashable {
    var id: UUID { PlayerStatusDTO.uuid(from: playerID)}
    var playerID: Int32
    var playerName: String?
    var firstName: String?
    var surname: String?
    var email: String?
    var visits: Int32
    var isPlaying: Bool
    var isWaiting: Bool
    var isSelectable: Bool
    var isFacilitator: Bool
    var isChoosing: Bool
    var isTimeOut: Bool
    var warmingUp: Bool
    var grade: String?
    var gamesCount: Int32
    var isChosen: Bool
    var isAdmin: Bool
    var courtNo: Int32
    var attendingSession: Bool
    var firstVisit: Date?
    var lastVisit: Date?
    var startedAt: String?
    var finishedAt: String?
    var orderOfPlay: Int32
    var squareID: String?
    var gameID: Int32
    var playerCategories: Int
    var durationInSeconds: Int32
    var needsSync: Bool? = false
    
    //UUID converted from integer
    static func uuid(from id: Int32) -> UUID{
        let hex = String(format: "%012d", id)
        return UUID(uuidString: "00000000-0000-0000-0000-\(hex)") ?? UUID()
    }
    
    enum CodingKeys: String, CodingKey {
        case playerID = "playerid"
        case playerName = "playername"
        case firstName = "firstname"
        case surname
        case email
        case visits
        case isPlaying = "isplaying"
        case isWaiting = "iswaiting"
        case isSelectable = "isselectable"
        case isFacilitator = "isfacilitator"
        case isChoosing = "ischoosing"
        case isTimeOut = "istimeout"
        case warmingUp = "warmingup"
        case grade
        case gamesCount = "gamescount"
        case isChosen = "ischosen"
        case isAdmin = "isadmin"
        case courtNo = "courtno"
        case attendingSession = "attendingsession"
        case firstVisit = "firstvisit"
        case lastVisit = "lastvisit"
        case startedAt = "startedat"
        case finishedAt = "finishedat"
        case orderOfPlay = "orderofplay"
        case squareID = "squareid"
        case gameID = "gameid"
        case playerCategories = "playercategories"
        case needsSync = "needsSync"
        case durationInSeconds = "duartioninseconds"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        func decodeBool(forKey key: CodingKeys) throws -> Bool {
            if let intVal = try? container.decode(Int.self, forKey: key) {
                return intVal != 0
            }
            return try container.decode(Bool.self, forKey: key)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = Calendar(identifier: .gregorian)

        playerID = try container.decode(Int32.self, forKey: .playerID)
        playerName = try container.decodeIfPresent(String.self, forKey: .playerName)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        surname = try container.decodeIfPresent(String.self, forKey: .surname)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        visits = try container.decode(Int32.self, forKey: .visits)
        isPlaying = try container.decode(Bool.self, forKey: .isPlaying)
        isWaiting = try container.decode(Bool.self, forKey: .isWaiting)
        isSelectable = try container.decode(Bool.self, forKey: .isSelectable)
        isFacilitator = try container.decode(Bool.self, forKey: .isFacilitator)
        isChoosing = try container.decode(Bool.self, forKey: .isChoosing)
        isTimeOut = try container.decode(Bool.self, forKey: .isTimeOut)
        warmingUp = try container.decode(Bool.self, forKey: .warmingUp)
        grade = try container.decodeIfPresent(String.self, forKey: .grade)
        gamesCount = try container.decode(Int32.self, forKey: .gamesCount)
        isChosen = try container.decode(Bool.self, forKey: .isChosen)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        courtNo = try container.decode(Int32.self, forKey: .courtNo)
        attendingSession = try container.decode(Bool.self,forKey: .attendingSession)
        needsSync = try container.decode(Bool.self, forKey: .needsSync)
        durationInSeconds = try container.decode(Int32.self, forKey: .durationInSeconds)


        // ✅ Manually decode and format date strings
        if let firstVisitStr = try container.decodeIfPresent(String.self, forKey: .firstVisit) {
            firstVisit = dateFormatter.date(from: firstVisitStr)
        } else {
            firstVisit = nil
        }

        if let lastVisitStr = try container.decodeIfPresent(String.self, forKey: .lastVisit) {
            lastVisit = dateFormatter.date(from: lastVisitStr)
        } else {
            lastVisit = nil
        }

        startedAt = try container.decodeIfPresent(String.self, forKey: .startedAt)
        finishedAt = try container.decodeIfPresent(String.self, forKey: .finishedAt)
        orderOfPlay = try container.decode(Int32.self, forKey: .orderOfPlay)
        squareID = try container.decodeIfPresent(String.self, forKey: .squareID)
        gameID = try container.decode(Int32.self, forKey: .gameID)
        playerCategories = try container.decode(Int.self, forKey: .playerCategories)
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


    
    init(from entity: PlayerStatus) {
        self.playerID = entity.playerID
        self.playerName = entity.playerName
        self.firstName = entity.firstName
        self.surname = entity.surname
        self.email = entity.email
        self.visits = Int32(entity.visits)
        self.isPlaying = entity.isPlaying
        self.isWaiting = entity.isWaiting
        self.isSelectable = entity.isSelectable
        self.isFacilitator = entity.isFacilitator
        self.isChoosing = entity.isChoosing
        self.isTimeOut = entity.isTimeOut
        self.warmingUp = entity.warmingUp
        self.grade = entity.grade
        self.gamesCount = Int32(entity.gamesCount)
        self.isChosen = entity.isChosen
        self.isAdmin = entity.isAdmin
        self.courtNo = Int32(entity.courtNo)
        self.attendingSession = entity.attendingSession
        self.firstVisit = entity.firstVisit
        self.lastVisit = entity.lastVisit
        self.startedAt = entity.startedAt
        self.finishedAt = entity.finishedAt
        self.orderOfPlay = Int32(entity.orderOfPlay)
        self.squareID = entity.squareID
        self.gameID = Int32(entity.gameID)
        self.playerCategories = Int(entity.playerCategories)
        self.needsSync = entity.needsSync
        self.durationInSeconds = entity.durationInSeconds
    }
    
    func toEntity(context: NSManagedObjectContext) -> PlayerStatus {
        let entity = PlayerStatus(context: context)
        entity.playerID = self.playerID
        entity.playerName = self.playerName
        entity.firstName = self.firstName
        entity.surname = self.surname
        entity.email = self.email
        entity.visits = Int32(self.visits)
        entity.isPlaying = self.isPlaying
        entity.isWaiting = self.isWaiting
        entity.isSelectable = self.isSelectable
        entity.isFacilitator = self.isFacilitator
        entity.isChoosing = self.isChoosing
        entity.isTimeOut = self.isTimeOut
        entity.warmingUp = self.warmingUp
        entity.grade = self.grade
        entity.gamesCount = Int32(self.gamesCount)
        entity.isChosen = self.isChosen
        entity.isAdmin = self.isAdmin
        entity.courtNo = Int32(self.courtNo)
        entity.attendingSession = self.attendingSession ?? false
        entity.firstVisit = self.firstVisit
        entity.lastVisit = self.lastVisit
        entity.startedAt = self.startedAt
        entity.finishedAt = self.finishedAt
        entity.orderOfPlay = Int32(self.orderOfPlay)
        entity.squareID = self.squareID
        entity.gameID = Int32(self.gameID)
        entity.playerCategories = Int32(self.playerCategories)
        entity.needsSync = self.needsSync ?? false
        
        return entity
    }
    
    init(
        playerID: Int32,
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
        firstVisit: Date? = nil,
        lastVisit: Date? = nil,
        startedAt: String? = nil,
        finishedAt: String? = nil,
        orderOfPlay: Int32 = 0,
        squareID: String? = nil,
        gameID: Int32 = 0,
        playerCategories: Int = 0,
        needsSync: Bool = false,
        durationInSeconds: Int32 = 0
    ) {
        self.playerID = playerID
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
        self.firstVisit = firstVisit
        self.lastVisit = lastVisit
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.orderOfPlay = orderOfPlay
        self.squareID = squareID
        self.gameID = gameID
        self.playerCategories = playerCategories
        self.needsSync = needsSync
        self.durationInSeconds = durationInSeconds
    }

    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PlayerStatusDTO, rhs: PlayerStatusDTO) -> Bool {
        lhs.id == rhs.id
    }
     

}

extension PlayerStatusDTO {
    var gradeColor: Color {
        switch grade?.uppercased() {
        case "A1": return .red
        case "A2": return .red
        case "B1":  return .orange
        case "B2":  return .orange
        case "C1":  return .green
        case "C2":  return .green
        case "D1":  return .blue
        case "D2":  return .blue
        default:   return .gray
        }
    }

    var isTopRank: Bool {
        guard let g = grade?.uppercased() else { return false }
        return g == "A1" || g == "A2"
    }
}

