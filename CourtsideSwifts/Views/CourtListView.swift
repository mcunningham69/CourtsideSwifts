
import SwiftUI


struct CourtListView: View {
    @StateObject var courtsViewModel = CourtsViewModel()
    @ObservedObject var sessionViewModel: PlayingSessionViewModel

    var body: some View {
        NavigationView {
            List {
                ForEach(courtsViewModel.courtSessions) { court in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Court \(court.courtNumber)")
                                .font(.headline)

                            if court.isActive, let time = court.timeRemaining {
                                Spacer()
                                Text("⏱️ \(formatTime(time))")
                                    .foregroundColor(court.hasExpired ? .red : .primary)
                                    .bold()
                            }
                        }

                        if court.players.isEmpty {
                            Text("No players assigned")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(court.players, id: \.id) { player in
                                Text(player.playerName ?? "Unnamed Player")
                            }
                        }

                        if court.hasExpired {
                            Text("⏰ Time's up!")
                                .font(.caption)
                                .foregroundColor(.red)
                                .bold()
                        }

                        HStack {
                            if court.isActive {
                                Button("Stop Game") {
                                    courtsViewModel.resetCourt(court)
                                }
                                .buttonStyle(.bordered)
                                .foregroundColor(.red)
                            } else {
                                Button("Start Game") {
                                    let chosenPlayers = sessionViewModel.groupedParticipants
                                        .first(where: { $0.category == "Chosen" })?
                                        .players ?? []

                                    guard chosenPlayers.count == 4 else {
                                        print("⚠️ You must select 4 players first.")
                                        return
                                    }

                                    courtsViewModel.startCourt(court, with: chosenPlayers)

                                    // Optional: clear chosen players afterward
                                    sessionViewModel.moveChosenToPlaying()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Courts")
        }
    }

    func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
