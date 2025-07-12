import SwiftUI

struct GroupedPlayerListView: View {
    let group: ParticipantSection
    @ObservedObject var viewModel: PlayingSessionViewModel
    @Binding var showTimeoutConfirmation: Bool
    
    var body: some View {
        if ["Pending", "Waiting", "Chosen", "Playing"].contains(group.category) {
            Section(header: Text(group.category).font(.headline)) {
                ForEach(group.players) { player in
                    playerRow(for: player)
                }
            }
        } else {
            let color = group.players.first?.gameColor ?? .primary
            let courtNo = group.players.first?.courtNo
            let category = group.category

            Section(
                header:
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(category)
                                .font(.caption)
                                .padding(6)
                                .background(color.opacity(0.2))
                                .foregroundColor(color)
                                .cornerRadius(8)
                            Spacer()
                        }

                        if let courtNo = courtNo, category.starts(with: "Court") {
                            HStack(spacing: 6) {
                                Label("Court \(courtNo)", systemImage: "sportscourt")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                statusBadge(for: category) // ✅ call your helper here
                            }
                            .padding(.leading, 6)
                        } else {
                            statusBadge(for: category) // ✅ fallback for "Team X"
                                .padding(.leading, 6)
                        }
                    }
            ) {
               /* if viewModel.isInSwapMode {
                    Text("Swap Mode Active")
                        .font(.caption)
                        .padding(6)
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(8)
                        .padding(.horizontal)
                } else {
                    Text("Selection Mode")
                        .font(.caption)
                        .padding(6)
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }*/

                ForEach(group.players) { player in
                    PlayerRowView(
                        player: player,
                        isInSwapMode: viewModel.isInSwapMode,
                        isSelected: viewModel.swapCandidates.contains(where: { $0.id == player.id }),
                        onTap: {
                            if viewModel.isInSwapMode {
                                viewModel.toggleSwapCandidate(player)
                            }
                        },
                        viewModel: viewModel
                    )
                }
            }
        }



    }
    
    @ViewBuilder
    private func playerRow(for player: PlayerStatusDTO) -> some View {
        let showTimeout = ["Waiting", "Playing", "Chosen"].contains(group.category)
        let isEligible = viewModel.isSelectableForChooser(player)
        
        // ✅ This ensures selectedWaitingPlayers highlights in non-swap mode
        let isSelected: Bool = viewModel.isInSwapMode
        ? viewModel.swapCandidates.contains(where: { $0.id == player.id })
        : viewModel.selectedWaitingPlayers.contains(player.id)
        
        let row = PlayerRowView(
            player: player,
            isInSwapMode: viewModel.isInSwapMode,
            isSelected: isSelected,
            onTap: {
                if viewModel.isInSwapMode {
                    viewModel.toggleSwapCandidate(player)
                } else if group.category == "Waiting" && !player.isChoosing {
                    if isEligible {
                        viewModel.toggleSelection(for: player)
                    }
                }
            },
            viewModel: viewModel
        )
        
        if showTimeout && !viewModel.isInSwapMode {
#if os(macOS)
            HStack {
                row
                Spacer(minLength: 8)
                Button {
                    viewModel.playerToTimeout = player
                    showTimeoutConfirmation = true
                } label: {
                    Image(systemName: "clock.fill").foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
#else
            row
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        viewModel.playerToTimeout = player
                        showTimeoutConfirmation = true
                    } label: {
                        Label("Time Out", systemImage: "clock.fill")
                    }
                }
#endif
        } else {
            row
        }
    }
}

struct GroupedPlayerListView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}

@ViewBuilder
private func statusBadge(for category: String) -> some View {
    switch category {
    case let cat where cat.starts(with: "Court"):
        Text("🟢 Playing")
            .font(.caption2)
            .foregroundColor(.gray)
    case let cat where cat.starts(with: "Team"):
        Text("🔵 Chosen")
            .font(.caption2)
            .foregroundColor(.gray)
    default:
        EmptyView()
    }
}

