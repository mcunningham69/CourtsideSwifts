//
//  PlayersByCategory.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 8/7/2025.
//
import Foundation
import CoreData
import SwiftUICore

class PlayersByCategory: ObservableObject, Identifiable {
    let id = UUID()
    var category: String
    @Published var players: [PlayerStatusDTO]
    var isSelectable: Bool

    init(category: String, players: [PlayerStatusDTO], isSelectable: Bool) {
        self.category = category
        self.players = players
        self.isSelectable = isSelectable
    }
}
