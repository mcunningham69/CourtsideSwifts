import SwiftUI

struct PlayerRowView: View {
    let player: PlayerStatusDTO
    let isInSwapMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    @ObservedObject var viewModel: PlayingSessionViewModel

    // Computed property to choose the correct background color
    var backgroundColor: Color {
        if isInSwapMode {
            if isSelected {
                return Color.blue.opacity(0.3)
            }
            if let cat = player.categoryEnum {
                let upperGroup: Set<PlayerCategory> = [.chosen, .playing]
                let lowerGroup: Set<PlayerCategory> = [.pending, .waiting]
                if upperGroup.contains(cat) {
                    return Color.red.opacity(0.2)
                } else if lowerGroup.contains(cat) {
                    return Color.green.opacity(0.2)
                }
            }
            return Color.gray.opacity(0.2)
        } else {
            // ✅ Non-swap mode selection (e.g. from Waiting)
            if isSelected {
                return Color.blue.opacity(0.3)
            }
            return player.isChoosing ? Color.yellow.opacity(0.2) : Color.clear
        }
    }


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
       // let _ = print("👀 \(player.playerName ?? "") isSelected: \(isSelected)")

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
            
            if player.categoryEnum == .playing {
                TimerLabelView(
                    baseSeconds: Int(player.durationInSeconds),
                    startedAt: player.startedAt,
                    finishedAt: player.finishedAt,
                    tick: viewModel.currentSecondTick
                )
            }


            
           /* if player.categoryEnum == .playing {
                TimerLabelView(
                    baseSeconds: Int(player.durationInSeconds),
                    startedAt: player.startedAt,
                    tick: viewModel.currentSecondTick
                )
            }*/

            Text("\(player.visits) visits")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(backgroundColor)
        .cornerRadius(8)
        .contentShape(Rectangle()) // Makes the entire row tappable
        .onTapGesture {
            onTap()
        }
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }
}

extension Int {
    func asHoursMinutesSeconds() -> String {
        let hrs = self / 3600
        let mins = (self % 3600) / 60
        let secs = self % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
}

