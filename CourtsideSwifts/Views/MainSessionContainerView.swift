import SwiftUI
import Combine

struct MainSessionContainerView: View {
    @StateObject private var playerListVM = PlayerListViewModel()
    @StateObject private var sessionVM: PlayingSessionViewModel
    @StateObject private var courtsVM = CourtsViewModel()

    init() {
        let listVM = PlayerListViewModel()
        _playerListVM = StateObject(wrappedValue: listVM)
        _sessionVM = StateObject(wrappedValue:
            PlayingSessionViewModel(
                refreshTrigger: listVM.refreshSessionPublisher.eraseToAnyPublisher()
            )
        )
    }

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            NavigationStack {
                PlayerListView(viewModel: playerListVM, sessionViewModel: sessionVM)
                    .navigationDestination(for: String.self) { destination in
                        switch destination {
                        case "PlayingSession":
                            PlayingSessionView(viewModel: sessionVM)
                                .onAppear { sessionVM.loadParticipantsFromCoreData() }
                        case "Courts":
                            CourtListView(viewModel: courtsVM, sessionViewModel: sessionVM)
                        default:
                            EmptyView()
                        }
                    }
                    .onAppear { sessionVM.loadParticipantsFromCoreData() }
            }
        } else {
            containerLayout
        }
        #else
        containerLayout
        #endif
    }

    private var containerLayout: some View {
        HStack(spacing: 0) {
            // 🟩 Player List Panel
            PlayerListView(viewModel: playerListVM, sessionViewModel: sessionVM)
                .frame(minWidth: 280, maxWidth: 320)
                .background(Color(UIColor.systemGroupedBackground))

            Divider()

            // 🟦 Playing Session Panel
            PlayingSessionView(viewModel: sessionVM)
                .frame(minWidth: 300, maxWidth: .infinity)
                .onAppear { sessionVM.loadParticipantsFromCoreData() }

            Divider()

            // 🟥 Courts Panel
            CourtListView(viewModel: courtsVM, sessionViewModel: sessionVM)
                .frame(minWidth: 280, maxWidth: 340)
                .background(Color(UIColor.systemGroupedBackground))
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

#Preview {
    MainSessionContainerView()
}
