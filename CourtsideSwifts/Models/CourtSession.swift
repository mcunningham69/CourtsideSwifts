import Foundation

struct CourtSession: Identifiable, Hashable {
    let id: UUID
    var courtNumber: Int
    var players: [PlayerStatusDTO]
    var isActive: Bool
    var startTime: Date?

    var timeRemaining: TimeInterval? {
        guard let startTime else { return nil }
        let elapsed = Date().timeIntervalSince(startTime)
        let limit: TimeInterval = 12 * 60 // 12 minutes
        return max(0, limit - elapsed)
    }

    var hasExpired: Bool {
        timeRemaining == 0
    }

    init(courtNumber: Int, players: [PlayerStatusDTO] = [], isActive: Bool = false, startTime: Date? = nil) {
        self.id = UUID()
        self.courtNumber = courtNumber
        self.players = players
        self.isActive = isActive
        self.startTime = startTime
    }
}
