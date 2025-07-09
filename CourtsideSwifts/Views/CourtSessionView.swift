//
//  CourtSessionView.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 9/7/2025.
//

import SwiftUI

struct CourtSessionView: View {
    @ObservedObject var sessionViewModel: PlayingSessionViewModel

    var body: some View {
        List {
            ForEach(sessionViewModel.activeCourts) { court in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Court \(court.courtNumber)")
                        .font(.headline)

                    ForEach(court.players) { player in
                        Text(player.playerName ?? "Unknown")
                            .font(.subheadline)
                    }

                    if court.isActive, let remaining = court.timeRemaining {
                        Text("⏱️ \(formatTime(remaining))")
                            .font(.caption)
                            .foregroundColor(court.hasExpired ? .red : .primary)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Active Courts")
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
}

