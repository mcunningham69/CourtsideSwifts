//
//  PlayerCategory.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//

enum PlayerCategory: Int32, Codable {
    case none = 0
    case pending = 1
    case waiting = 2
    case chosen = 3
    case playing = 4
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int32.self)
        self = PlayerCategory(rawValue: rawValue) ?? .none
    }
}
