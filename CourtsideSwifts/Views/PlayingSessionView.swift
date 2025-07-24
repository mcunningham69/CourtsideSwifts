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

           
            
            List {
                ForEach(viewModel.groupedParticipants) { group in
                    GroupedPlayerListView(
                        group: group,
                        viewModel: viewModel,
                        showTimeoutConfirmation: $showTimeoutConfirmation
                    )
                }
            }
  
            let selectedWaitingCount = viewModel.groupedParticipants
                .first(where: { $0.category == "Waiting" })?
                .players
                .filter { viewModel.selectedWaitingPlayers.contains($0.id) }
                .count ?? 0

            if selectedWaitingCount == 3 {
                Button("Confirm Selection") {
                    viewModel.confirmChooserSelection()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Random Selection") {
                    viewModel.randomlySelectTeam()
                }
                .buttonStyle(.bordered)
                .padding(.bottom, 40)
            }

            
            // ✅ Add this below `body`
             var hasEnoughEligible: Bool {
                guard let waitingGroup = viewModel.groupedParticipants.first(where: { $0.category == "Waiting" }),
                      let chooser = waitingGroup.players.first(where: { $0.isChoosing }) else {
                    return false
                }

                 let eligible = waitingGroup.players.filter {
                     $0.id != chooser.id &&
                     viewModel.isSelectableForChooserInternal(
                         players: waitingGroup.players,
                         chooser: chooser,
                         target: $0
                     )
                 }
                return eligible.count >= 3
            }
        }
        .navigationTitle("Playing Session")

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
      /*  .onAppear {
            // only reload when this view appears
            viewModel.loadParticipantsFromCoreData()
        }*/
    }
}

#Preview {
    PlayingSessionView(viewModel: PlayingSessionViewModel(refreshTrigger: Just(())
        .eraseToAnyPublisher()))
}
