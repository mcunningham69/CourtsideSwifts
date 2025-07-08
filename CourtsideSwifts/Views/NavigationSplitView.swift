//
//  NavigationSplitView.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 8/7/2025.
//
import SwiftUI

struct MainSessionSplitView: View {
    @StateObject private var listVM: PlayerListViewModel
    @StateObject private var sessionVM: PlayingSessionViewModel
    
    

    init() {
        // Temporary instance to create the ViewModel with a publisher
        let tempListVM = PlayerListViewModel()
        _listVM = StateObject(wrappedValue: tempListVM)
        _sessionVM = StateObject(wrappedValue:
            PlayingSessionViewModel(refreshTrigger: tempListVM.refreshSessionPublisher.eraseToAnyPublisher())
        )
    }

    var body: some View {
        NavigationSplitView {
            PlayerListView(viewModel: listVM, sessionViewModel: sessionVM)
        } detail: {
            PlayingSessionView(viewModel: sessionVM)
        }
    }
}


