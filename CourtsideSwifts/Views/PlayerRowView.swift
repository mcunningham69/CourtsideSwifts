//
//  PlayerRowView.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 8/7/2025.
//
import SwiftUI

struct PlayerRowView: View {
    let player: PlayerStatusDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(player.playerName ?? "Unknown")
                    .fontWeight(player.isChoosing ? .bold : .regular)
                
                if player.isChoosing {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .accessibilityLabel("You are choosing")
                }
                
                Spacer()
                
                if player.isChosen {
                    Text("Chosen")
                        .font(.caption)
                        .padding(6)
                        .background(player.gameColor.opacity(0.2))
                        .foregroundColor(player.gameColor)
                        .cornerRadius(8)
                }

                
                if player.isPlaying {
                    Text("🎾 Playing")
                        .foregroundColor(.green)
                } else if player.isWaiting {
                    Text("🕓 Waiting")
                        .foregroundColor(.orange)
                } else if player.isChosen {
                    Text("✅ Chosen")
                        .foregroundColor(.blue)
                }
            }

            // 👇 Add grade below name
            if let grade = player.grade, !grade.isEmpty {
                Text("Grade: \(grade)")
                    .font(.caption)
                    .foregroundColor(player.gradeColor)
            }
        }
        .padding(.vertical, 4)
    }
}
