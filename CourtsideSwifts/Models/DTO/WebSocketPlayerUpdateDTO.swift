//
//  WebSocketPlayerUpdateDTO.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 20/7/2025.
//
import Foundation

struct WebSocketPlayerUpdateDTO: Codable, Identifiable {
    var uuid: UUID
    var playerName: String
    var playerCategories: Int
    var attendingSession: Bool
    
    var id: UUID { uuid }
}

