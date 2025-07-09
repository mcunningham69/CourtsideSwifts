//
//  NavigationSplitView.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 8/7/2025.
//

import SwiftUI
import Combine

struct MainSessionSplitView: View {
    @StateObject private var listVM: PlayerListViewModel
    @StateObject private var sessionVM: PlayingSessionViewModel
    @StateObject private var courtsVM = CourtsViewModel()
    
    init() {
        let listVM = PlayerListViewModel()
        _listVM = StateObject(wrappedValue: listVM)
        _sessionVM = StateObject(wrappedValue:
            PlayingSessionViewModel(
                refreshTrigger: listVM.refreshSessionPublisher.eraseToAnyPublisher()
            )
        )
        
        // Initialize Courts VM
                _courtsVM = StateObject(wrappedValue: CourtsViewModel())
    }
    

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .phone {
            NavigationStack {
                PlayerListView(viewModel: listVM, sessionViewModel: sessionVM)
                    .navigationDestination(for: String.self) { destination in
                        switch destination {
                        case "PlayingSession":
                            PlayingSessionView(viewModel: sessionVM)
                        case "CourtSession":
                            CourtListView(courtsViewModel: courtsVM, sessionViewModel: sessionVM)
                        default:
                            EmptyView()
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
            PlayerListView(viewModel: listVM, sessionViewModel: sessionVM)
        } detail: {
            TabView {
                PlayingSessionView(viewModel: sessionVM)
                    .tabItem {
                        Label("Session", systemImage: "person.3")
                    }

                CourtListView(courtsViewModel: courtsVM, sessionViewModel: sessionVM)
                    .tabItem {
                        Label("Courts", systemImage: "sportscourt")
                    }
            }
        }
    }
}
