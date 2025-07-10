import Foundation

class CourtSession: ObservableObject, Identifiable {
//struct CourtSession: Identifiable, Hashable {
    let id: UUID
    @Published var courtNumber: Int
    
   // @Published var players: [PlayerStatusDTO]
    
    var players: [PlayerStatusDTO] = [] {
        didSet {
            print("🟥 court.players SET for Court \(courtNumber):", players.map { $0.playerName ?? "Unnamed" })
        }
    }

    
    @Published var isActive = false
    @Published var startTime: Date?


    var timeRemaining: TimeInterval? {
        guard isActive, let start = startTime else { return nil }
        let elapsed = Date().timeIntervalSince(start)
        let limit: TimeInterval = 12 * 60 // 12 minutes
        return max(0, limit - elapsed)
    }

    var hasExpired: Bool {
        guard let rem = timeRemaining else { return false}
        return rem <= 0
    }
    


    init(courtNumber: Int, players: [PlayerStatusDTO] = [], isActive: Bool = false, startTime: Date? = nil) {
        self.id = UUID()
        self.courtNumber = courtNumber
        self.players = players
        self.isActive = isActive
        self.startTime = startTime
    }
}
