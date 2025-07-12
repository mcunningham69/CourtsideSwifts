//
//  CourtSessionView.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 9/7/2025.
//

import SwiftUI

/// Refactored to enable Start only when there's a group of 4 chosen players sharing the same gameID,
/// plus highlight the next team pre-start and visual warning when time expires.
struct CourtSessionView: View {
    @ObservedObject var court: CourtSession
    @ObservedObject var viewModel: CourtsViewModel
    @ObservedObject var sessionViewModel: PlayingSessionViewModel
    @State private var showTimeUpAlert = false
    
    var nextTeam: [PlayerStatusDTO]? {
        sessionViewModel.nextTeamForCourt(court, activeCourts: viewModel.courts)
    }

    var canStart: Bool {
        sessionViewModel.canStartCourt(court, activeCourts: viewModel.courts)
    }




    // MARK: - Computed Properties

    private var chosenGroups: [Int: [PlayerStatusDTO]] {
        guard let chosenSection = sessionViewModel.groupedParticipants.first(where: { $0.category == "Chosen" })
        else { return [:] }
        return Dictionary(grouping: chosenSection.players) { player in
            Int(player.gameID)
        }
    }





    // MARK: - Subviews

    private var headerControls: some View {
        HStack {
            Text("Court \(court.courtNumber)")
                .font(.headline)
            Spacer()
            startButton
            stopButton
        }
    }

    private var startButton: some View {
        Button("Start") {
            guard court.players.isEmpty else { return } // ✅ Prevent overwriting
            if let team = nextTeam {
                // ✅ Bump gamesCount in-place for UI purposes
                let updatedTeam = team.map { dto -> PlayerStatusDTO in
                    var copy = dto
                    copy.gamesCount = max(dto.gamesCount + 1, 1)
                    copy.playerCategories = PlayerCategory.playing.rawValue
                    copy.isPlaying = true
                    return copy
                }
                court.players = updatedTeam
            }

            Task {
                await viewModel.startPlay(on: court, from: sessionViewModel)
            }
        }
        .buttonStyle(.bordered)
        .disabled(!canStart)
    }



    private var stopButton: some View {
        Button("Stop") {
            Task {
                stopSession()
                await viewModel.stopPlay(on: court, from: sessionViewModel)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .disabled(!court.isActive)
    }
    
    private func stopSession() {
        for player in court.players {
            var updated = player
            // Move back to Waiting category
            updated.playerCategories = PlayerCategory.waiting.rawValue

            // Increment and assign play order
            sessionViewModel.nextPlayOrder += 1
            updated.orderOfPlay = Int32(sessionViewModel.nextPlayOrder)

            sessionViewModel.updatePlayer(updated)
        }
        court.players.removeAll()
        court.isActive = false
        court.startTime = nil
    }

    private var nextTeamView: some View {
        Group {
            if !court.isActive, let team = nextTeam {
                NextTeamDetailsView(team: team)
            } else {
                EmptyView()
            }
        }
    }




    private var activePlayerListView: some View {
        Group {
            if court.players.isEmpty {
                Text("No players assigned")
                    .foregroundColor(.gray)
                    .padding(.leading)
            } else {
                ForEach(court.players, id: \.id) { player in
                    HStack {
                        Text(player.playerName ?? "Unnamed")
                        Spacer()
                        Text("\(player.gamesCount) games")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }

    private var timerView: some View {
        Group {
            if court.isActive, let remaining = court.timeRemaining {
                HStack {
                    Spacer()
                    Text("⏱️ Remaining: \(formatTime(remaining))")
                        .font(.caption).bold()
                        .foregroundColor(court.hasExpired ? .red : .primary)
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerControls
            nextTeamView
            activePlayerListView
            timerView
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(court.hasExpired ? Color.red : Color.clear, lineWidth: 3)
                .animation(.easeInOut, value: court.hasExpired)
        )
        
        //Debug
        .onAppear {
          print("🔍 Sections:", sessionViewModel.groupedParticipants.map(\.category))
          print("🔍 Players in Chosen:", sessionViewModel.groupedParticipants
                  .first(where: { $0.category == "Chosen" })?.players.count ?? 0)
          print("🔍 canStart:", canStart)
        }
        
        .onChange(of: court.hasExpired) { _, new in
            if new { showTimeUpAlert = true }
        }
        .alert("Time’s up!", isPresented: $showTimeUpAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("12 minutes have elapsed on Court \(court.courtNumber).")
        }
    }

    // MARK: - Helpers

    private func formatTime(_ interval: TimeInterval) -> String {
        let m = Int(interval) / 60
        let s = Int(interval) % 60
        return String(format: "%02d:%02d", m, s)
    }
    


}

struct NextTeamDetailsView: View {
    let team: [PlayerStatusDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next Team:")
                .font(.subheadline).bold().foregroundColor(.accentColor)
            HStack {
                
                
                ForEach(team, id: \.id) { player in
                    
                    Text(player.playerName ?? "Unnamed")
                    
                    Spacer()
                    
                
                        .padding(6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(6)
                    
                }
            }

            Text("Waiting to start...")
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
        }
        .padding(.leading, 4)
    }
}






