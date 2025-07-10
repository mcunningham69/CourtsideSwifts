import SwiftUI

struct GroupedPlayerListView: View {
    let group: ParticipantSection
    @ObservedObject var viewModel: PlayingSessionViewModel
    @Binding var showTimeoutConfirmation: Bool

    var body: some View {
        if ["Pending", "Waiting", "Chosen", "Playing"].contains(group.category) {
            Section(header: Text(group.category).font(.headline)) {
                ForEach(group.players) { player in
                    let showTimeout = ["Waiting", "Playing", "Chosen"].contains(group.category)
                    let isEligible = viewModel.isSelectableForChooser(player)
                    let isSelected = viewModel.selectedWaitingPlayers.contains(player.id)

                    let baseRow: some View = Group {
                        if group.category == "Waiting" && !player.isChoosing {
                            PlayerRowView(player: player)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isEligible {
                                        viewModel.toggleSelection(for: player)
                                    }
                                }
                                .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                                .opacity(isEligible ? 1.0 : 0.3)
                                .help(isEligible ? "" : "Not eligible for selection")
                        } else {
                            PlayerRowView(player: player)
                        }
                    }

                    if showTimeout {
                        #if os(macOS)
                        HStack {
                            baseRow
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
                        baseRow
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
                        baseRow
                    }
                }
            }
        } else {
            // Team headers: colored capsule styling
            Section(header:
                HStack {
                    Text(group.category)
                        .font(.caption)
                        .padding(6)
                        .background(group.players.first?.gameColor.opacity(0.2))
                        .foregroundColor(group.players.first?.gameColor ?? .primary)
                        .cornerRadius(8)
                    Spacer()
                }
            ) {
                ForEach(group.players) { player in
                    PlayerRowView(player: player)
                }
            }
        }
    }
}

struct GroupedPlayerListView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyView()
    }
}
