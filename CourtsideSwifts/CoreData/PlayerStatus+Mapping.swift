//
//  PlayerStatus+Mapping.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 4/7/2025.
//
import Foundation
import CoreData

import CoreData

extension PlayerStatus {
    static func createOrUpdate(from dto: PlayerStatusDTO, in context: NSManagedObjectContext) -> PlayerStatus {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "uuid == %@", dto.uuid as CVarArg)

        let entity: PlayerStatus

        if let existing = try? context.fetch(request).first {
            entity = existing
        } else {
            entity = PlayerStatus(context: context)
            entity.uuid = dto.uuid              // Always set at creation
        }

        // MARK: - Optional fields
        entity.playerName = dto.playerName
        entity.firstName = dto.firstName
        entity.surname = dto.surname
        entity.email = dto.email
        entity.grade = dto.grade
        entity.startedAt = dto.startedAt
        entity.finishedAt = dto.finishedAt
        entity.squareID = dto.squareID

        // MARK: - Required state flags
        entity.isPlaying = dto.isPlaying
        entity.isWaiting = dto.isWaiting
        entity.isSelectable = dto.isSelectable
        entity.isFacilitator = dto.isFacilitator
        entity.isChoosing = dto.isChoosing
        entity.isTimeOut = dto.isTimeOut
        entity.warmingUp = dto.warmingUp
        entity.isChosen = dto.isChosen
        entity.isAdmin = dto.isAdmin
        entity.attendingSession = dto.attendingSession
        entity.notified = dto.notified
        entity.needsSync = dto.needsSync ?? false

        // MARK: - Stats
        entity.visits = dto.visits
        entity.gamesCount = dto.gamesCount
        entity.courtNo = dto.courtNo
        entity.orderOfPlay = dto.orderOfPlay
        entity.gameID = dto.gameID
        entity.playerCategories = Int32(dto.playerCategories)
        entity.durationInSeconds = dto.durationInSeconds

        return entity
    }
}



