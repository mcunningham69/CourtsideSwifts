//
//  PlayerStatus+Category.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//

import Foundation

extension PlayerStatus {
    var categoryEnum: PlayerCategory {
        get {
            PlayerCategory(rawValue: Int(self.playerCategories)) ?? .none
        }
        set {
            self.playerCategories = Int32(newValue.rawValue)
        }
    }
}

