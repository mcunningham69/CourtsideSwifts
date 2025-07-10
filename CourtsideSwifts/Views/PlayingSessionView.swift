import SwiftUI
import Combine

struct PlayingSessionView: View {
    @ObservedObject var viewModel: PlayingSessionViewModel
    @State private var showTimeoutConfirmation = false

    var body: some View {
        // Use the outer NavigationStack, drop internal NavigationView
        VStack(spacing: 8) {
            // 🔽 Chooser Banner
            if let waitingGroup = viewModel.groupedParticipants.first(where: { $0.category == "Waiting" }),
               !waitingGroup.players.isEmpty,
               let chooser = waitingGroup.players.first(where: { $0.isChoosing }) {

                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text(chooser.playerName ?? "Unknown")
                                .font(.headline)
                                .bold()
                        }
                    } icon: {
                        Image(systemName: "crown.fill")
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.yellow.opacity(0.9))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .foregroundColor(.black)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.5), value: chooser.id)

                    Spacer()
                }
                .padding(.horizontal)
            }

            Toggle("Use Grade Filter", isOn: $viewModel.useGradeFilter)
                .toggleStyle(.switch)
                .padding(.horizontal)

            // 🔽 Main Grouped List
            /*List {
                ForEach(viewModel.groupedParticipants) { group in
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
            }*/
            
            List {
                ForEach(viewModel.groupedParticipants) { group in
                    GroupedPlayerListView(
                        group: group,
                        viewModel: viewModel,
                        showTimeoutConfirmation: $showTimeoutConfirmation
                    )
                }
            }
            
            if viewModel.selectedWaitingPlayers.count == 3 {
                Button("Confirm Selection") {
                    viewModel.confirmChooserSelection()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Random Selection") {
                    viewModel.randomlySelectTeam()
                }
                .buttonStyle(.bordered)
            }
            
            // ✅ Add this below `body`
             var hasEnoughEligible: Bool {
                guard let waitingGroup = viewModel.groupedParticipants.first(where: { $0.category == "Waiting" }),
                      let chooser = waitingGroup.players.first(where: { $0.isChoosing }) else {
                    return false
                }

                let eligible = waitingGroup.players.filter {
                    $0.id != chooser.id && viewModel.isSelectableForChooser($0)
                }

                return eligible.count >= 3
            }

            
       /*     if viewModel.selectedWaitingPlayers.count != 3 {
                Button("Randomly Select Team") {
                    viewModel.randomlySelectTeam()
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 4)
            }



            if viewModel.selectedWaitingPlayers.count == 3 {
                Button("Confirm Selection") {
                    viewModel.confirmChooserSelection()
                    
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }*/
        }
        .navigationTitle("Playing Session")
        // Add the Courts button here in the nav bar
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // append to the NavigationStack path from MainSplitView
                    NotificationCenter.default.post(name: .refreshSession, object: ())
                }) {
                    Label("Courts", systemImage: "sportscourt")
                }
            }
        }
        .alert("Time Out Player?", isPresented: $showTimeoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Confirm", role: .destructive) {
                if let p = viewModel.playerToTimeout {
                    viewModel.timeoutPlayer(p)
                }
            }
        } message: {
            Text("This will move the player back to Pending.")
        }
        .onAppear {
            // only reload when this view appears
            viewModel.loadParticipantsFromCoreData()
        }
    }
}

#Preview {
    PlayingSessionView(viewModel: PlayingSessionViewModel(refreshTrigger: Just(())
        .eraseToAnyPublisher()))
}
