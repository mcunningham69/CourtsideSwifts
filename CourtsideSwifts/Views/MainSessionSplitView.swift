import SwiftUI
import Combine



extension Notification.Name {
    static let refreshSession = Notification.Name("refreshSession")
}

struct MainSplitView: View {
    @StateObject private var playerListViewModel = PlayerListViewModel()
    @StateObject private var playingSessionViewModel: PlayingSessionViewModel
    @StateObject private var courtsViewModel = CourtsViewModel()

    // Maintain navigation path for iPhone
    @State private var path: [Route] = []

    init() {
        let refreshPublisher = NotificationCenter.default
            .publisher(for: .refreshSession)
            .map { _ in () }
            .eraseToAnyPublisher()
        
        _playingSessionViewModel = StateObject(
            wrappedValue: PlayingSessionViewModel(refreshTrigger: refreshPublisher)
        )
    }

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            NavigationStack(path: $path) {
                PlayerListView(
                    viewModel: playerListViewModel,
                    sessionViewModel: playingSessionViewModel
                )
                .onAppear {
                    playerListViewModel.loadFromCoreData()
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            path.append(.courts)
                        } label: {
                            Label("Courts", systemImage: "sportscourt")
                        }
                    }
                }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .playingSession:
                        PlayingSessionView(viewModel: playingSessionViewModel)
                            .onAppear {
                                playingSessionViewModel.loadParticipantsFromCoreData()
                            }
                        
                    case .courts:
                        CourtListView(
                            viewModel: courtsViewModel,
                            sessionViewModel: playingSessionViewModel
                        )
                    }
                }
            }
        } else {
            splitViewLayout
        }
        #else
        splitViewLayout
        #endif
    }

    private var splitViewLayout: some View {
        NavigationSplitView {
            PlayerListView(
                viewModel: playerListViewModel,
                sessionViewModel: playingSessionViewModel
            )
            .onAppear { playerListViewModel.loadFromCoreData() }
            .onReceive(NotificationCenter.default.publisher(for: .refreshSession)) { _ in
                playerListViewModel.loadFromCoreData()
            }
        } content: {
            PlayingSessionView(viewModel: playingSessionViewModel)
                .onAppear { playingSessionViewModel.loadParticipantsFromCoreData() }
        } detail: {
            CourtListView(
                viewModel: courtsViewModel,
                sessionViewModel: playingSessionViewModel
            )
        }
    }
}

// MARK: - Routing Enum
private enum Route: Hashable {
    case playingSession, courts
}

#Preview {
    MainSplitView()
}

