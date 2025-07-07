//
//  PlayerStatus+Category.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//

import Foundation

extension PlayerStatus {
    var categoryEnum: PlayerCategory? {
        get {
            PlayerCategory(rawValue: Int(self.playerCategories))
        }
        set {
            if let value = newValue {
                self.playerCategories = Int32(value.rawValue)
            }
        }
    }
}
