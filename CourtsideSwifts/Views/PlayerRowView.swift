//
//  PlayerRowView.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 8/7/2025.
//
import SwiftUI

struct PlayerRowView: View {
    let player: PlayerStatusDTO

    var categoryLabel: some View {
        let color = player.gameColor

        switch player.categoryEnum {
        case .playing:
            return Label("Playing", systemImage: "sportscourt")
                .foregroundColor(color)
                .labelStyle(.titleAndIcon)
                .eraseToAnyView()

        case .chosen:
            return Label("Chosen", systemImage: "checkmark.circle.fill")
                .foregroundColor(color)
                .labelStyle(.titleAndIcon)
                .eraseToAnyView()

        case .waiting:
            return Label("Waiting", systemImage: "hourglass.circle")
                .foregroundColor(.secondary)
                .labelStyle(.titleAndIcon)
                .eraseToAnyView()

        case .pending:
            return Label("Pending", systemImage: "figure.seated.seatbelt")
                .foregroundColor(.secondary)
                .labelStyle(.titleAndIcon)
                .eraseToAnyView()
            
        default:
            return Text("Unknown")
                .foregroundColor(.gray)
                .eraseToAnyView()
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(player.playerName ?? "Unnamed")
                        .font(.headline)
                        .bold()
                        .foregroundColor(player.isChoosing ? .yellow : .primary)
                    if player.isChoosing {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                    }
                }

                if let grade = player.grade {
                    Text("Grade: \(grade)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                categoryLabel
                    .font(.caption)
            }

            Spacer()

            Text("\(player.visits) visits")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(player.isChoosing ? Color.yellow.opacity(0.2) : Color.clear)
        .cornerRadius(8)
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}



/*struct PlayerRowView: View {
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
                } /*else if player.isChosen {
                    Text("✅ Chosen")
                        .foregroundColor(.blue)
                }*/
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
}*/
