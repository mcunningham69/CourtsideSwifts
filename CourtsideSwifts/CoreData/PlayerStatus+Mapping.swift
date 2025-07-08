//
//  PlayerStatus+Mapping.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 4/7/2025.
//
import Foundation
import CoreData

extension PlayerStatus {
    static func createOrUpdate(from dto: PlayerStatusDTO, in context: NSManagedObjectContext) -> PlayerStatus {
        let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
        request.predicate = NSPredicate(format: "playerID == %d", dto.playerID)

        let player = (try? context.fetch(request).first) ?? PlayerStatus(context: context)

        player.playerID = Int32(dto.playerID)
        player.playerName = dto.playerName
        player.firstName = dto.firstName
        player.surname = dto.surname
        player.email = dto.email
        player.visits = Int32(dto.visits)
        player.isPlaying = dto.isPlaying
        player.isWaiting = dto.isWaiting
        player.isSelectable = dto.isSelectable
        player.isFacilitator = dto.isFacilitator
        player.isChoosing = dto.isChoosing
        player.isTimeOut = dto.isTimeOut
        player.warmingUp = dto.warmingUp
        player.grade = dto.grade
        player.gamesCount = Int32(dto.gamesCount)
        player.isChosen = dto.isChosen
        player.isAdmin = dto.isAdmin
        player.courtNo = Int32(dto.courtNo)
        player.attendingSession = dto.attendingSession
        player.firstVisit = dto.firstVisit
        player.lastVisit = dto.lastVisit
        player.startedAt = dto.startedAt
        player.finishedAt = dto.finishedAt
        player.orderOfPlay = Int32(dto.orderOfPlay)
        player.squareID = dto.squareID
        player.gameID = Int32(dto.gameID)
        player.playerCategories = Int32(dto.playerCategories)
        player.durationInSeconds = Int32(dto.durationInSeconds)

        return player
    }
}



