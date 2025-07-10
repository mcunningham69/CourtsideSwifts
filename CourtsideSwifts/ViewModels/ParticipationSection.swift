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

    /// Groups flat DTO list into sections by category and, for Chosen, by gameID
    static func group(_ dtos: [PlayerStatusDTO]) -> [ParticipantSection] {
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

            if category == .chosen {
                // Placeholder header
                sections.append(ParticipantSection(category: "Chosen", players: []))
                // Group chosen by gameID into teams
                let grouped = Dictionary(grouping: filtered, by: { $0.gameID })
                for (gameID, players) in grouped.sorted(by: { $0.key < $1.key }) {
                    sections.append(
                        ParticipantSection(
                            category: "Team \(gameID)",
                            players: players
                        )
                    )
                }
            } else {
                // Default single section for others
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
}
