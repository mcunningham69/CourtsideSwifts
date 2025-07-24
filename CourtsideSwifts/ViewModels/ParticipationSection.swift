//
//  ParticipationSection.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 10/7/2025.
//
import SwiftUI


// MARK: - ParticipantSection helper

struct ParticipantSection: Identifiable {
    let id = UUID()
    let category: String
    var players: [PlayerStatusDTO]
        
    var categoryEnum: PlayerCategory? {
        PlayerCategory.fromDisplayName(category)
    }
     
    static func group(_ dtos: [PlayerStatusDTO]) -> [ParticipantSection] {
        var sections: [ParticipantSection] = []

        for category in PlayerCategory.allCases {
            // Filter players by category
            let filtered = dtos
                .filter { $0.categoryEnum == category }
                .sorted {
                    switch category {
                    case .waiting, .pending:
                        return $0.orderOfPlay < $1.orderOfPlay
                    case .chosen, .playing:
                        return $0.gameID < $1.gameID
                    }
                }

            switch category {
            case .chosen:
                sections.append(ParticipantSection(category: "Chosen", players: []))
               // sections.append(ParticipantSection(category: .chosen, players: []))

                let groupedByGame = Dictionary(grouping: filtered, by: { $0.gameID })
                let sortedKeys = groupedByGame.keys.sorted()
                for key in sortedKeys {
                    if let players = groupedByGame[key] {
                        //sections.append(ParticipantSection(category: "Team \(key)", players: players))
                        sections.append(ParticipantSection(category: "Team \(key)", players: players))
                    }
                }

            case .playing:
               sections.append(ParticipantSection(category: "Playing", players: []))
                //sections.append(ParticipantSection(category: .playing, players: []))

                let groupedByGameID = Dictionary(grouping: filtered, by: { $0.gameID })
                let sortedGameIDs = groupedByGameID.keys.sorted()

                for gameID in sortedGameIDs {
                    guard let playersInTeam = groupedByGameID[gameID] else { continue }

                    // Try to determine court number from players (assume all same court)
                    let uniqueCourts = Set(playersInTeam.compactMap { $0.courtNo })

                    let label: String
                    if uniqueCourts.count == 1, let court = uniqueCourts.first {
                        label = "Court \(court)"
                    } else if uniqueCourts.isEmpty {
                        label = "Unassigned Court"
                    } else {
                        label = "Mixed Courts"
                    }

                    sections.append(ParticipantSection(category: label, players: playersInTeam))
                }


            default:
                sections.append(ParticipantSection(category: category.displayName, players: filtered))


            }
        }

        // 🟡 Chooser assignment logic
        let allPlayers = sections.flatMap { $0.players }

        let waitingPlayers = allPlayers
            .filter { $0.categoryEnum == .waiting }
            .sorted { $0.orderOfPlay < $1.orderOfPlay }

        let nonWaitingPlayers = allPlayers.filter { $0.categoryEnum != .waiting }

        let context = PersistenceController.shared.container.viewContext

        // ✅ Update non-waiting players: set isChoosing = false
        let updatedNonWaiting = nonWaitingPlayers.map { dto -> PlayerStatusDTO in
            var copy = dto
            copy.isChoosing = false
            return copy
        }

        // ✅ Update waiting players: assign a single chooser
        var chooserAssigned = false
        let updatedWaiting = waitingPlayers.map { dto -> PlayerStatusDTO in
            var copy = dto
            copy.isChoosing = !chooserAssigned
            chooserAssigned = true
            return copy
        }

        // ✅ Combine and update in Core Data
        let updated = updatedNonWaiting + updatedWaiting
        PlayerStatusDTO.bulkCreateOrUpdate(from: updated, in: context, fromAzure: false)

        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("❌ Failed to save chooser updates: \(error)")
        }


        try? context.save()

        return sections
    }

    
   /* static func group(_ dtos: [PlayerStatusDTO]) -> [ParticipantSection] {
        var sections: [ParticipantSection] = []
        
        for category in PlayerCategory.allCases {
            // Filter DTOs by categoryEnum
            let filtered = dtos
                .filter { $0.categoryEnum == category }
                .sorted(by: {
                    switch category {
                    case .waiting, .pending:
                        return $0.orderOfPlay < $1.orderOfPlay
                    case .chosen, .playing:
                        return $0.gameID < $1.gameID
                    }
                })
            
            switch category {
            case .chosen:
                sections.append(ParticipantSection(category: "Chosen", players: []))
                let grouped = Dictionary(grouping: filtered, by: { $0.gameID })
                for (gameID, players) in grouped.sorted(by: { $0.key < $1.key }) {
                    sections.append(
                        ParticipantSection(
                            category: "Team \(gameID)",
                            players: players
                        )
                    )
                }
                
            case .playing:
                sections.append(ParticipantSection(category: "Playing", players: []))

                let grouped = Dictionary(grouping: filtered, by: { $0.gameID })

                for (_, players) in grouped.sorted(by: { $0.key < $1.key }) {
                    let uniqueCourts = Set(players.compactMap { $0.courtNo })

                    let label: String
                    if uniqueCourts.count == 1, let court = uniqueCourts.first {
                        label = "Court \(court)"
                    } else if uniqueCourts.isEmpty {
                        label = "Unassigned Court"
                    } else {
                        label = "Mixed Courts"
                    }

                    sections.append(
                        ParticipantSection(
                            category: label,
                            players: players
                        )
                    )
                }

            default:
                sections.append(
                    ParticipantSection(
                        category: category.displayName,
                        players: filtered
                    )
                )
            }
        }
        
        return sections
    }
    */
}
