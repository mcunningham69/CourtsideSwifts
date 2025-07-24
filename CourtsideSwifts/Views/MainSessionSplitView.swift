import SwiftUI
import Combine

extension Notification.Name {
    static let refreshSession = Notification.Name("refreshSession")
}

struct MainSplitView: View {

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var playerListViewModel = PlayerListViewModel()
    @StateObject private var playingSessionViewModel: PlayingSessionViewModel
    @StateObject private var courtsViewModel = CourtsViewModel()

    @State private var path: [Route] = []
    @State private var didInitialise = false

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
                    initialiseDataOnLaunch()
                }
                .onChange(of: scenePhase) { oldValue, newValue in
                    if newValue == .active {
                        print("🌞 App resumed - syncing to Azure...")
                        Task {
                            try await PlayerApiService.shared.syncPendingPlayersToAzure()
                        }
                    }
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
            .onAppear {
                initialiseDataOnLaunch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .refreshSession)) { _ in
                playerListViewModel.loadFromCoreData()
            }
        } content: {
            PlayingSessionView(viewModel: playingSessionViewModel)
                .onAppear {
                    playingSessionViewModel.loadParticipantsFromCoreData()
                }
        } detail: {
            CourtListView(
                viewModel: courtsViewModel,
                sessionViewModel: playingSessionViewModel
            )
        }
    }

    private func initialiseDataOnLaunch() {
        guard !didInitialise else { return }
        didInitialise = true

        Task {
            do {
                try await PlayerApiService.shared.fetchAndStorePlayers(
                    context: PersistenceController.shared.container.viewContext
                )
                await MainActor.run {
                    playerListViewModel.loadFromCoreData()
                    playingSessionViewModel.loadParticipantsFromCoreData()
                }
                print("✅ Initial data load from Azure complete.")
            } catch {
                print("❌ Failed to initialise from Azure: \(error)")
            }
        }
    }
}

private enum Route: Hashable {
    case playingSession, courts
}

#Preview {
    MainSplitView()
}
