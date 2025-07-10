//
//  PlayerListView.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//


import SwiftUI
import Combine

struct PlayerListView: View {
    @ObservedObject var viewModel: PlayerListViewModel
    @ObservedObject var sessionViewModel: PlayingSessionViewModel

    @State private var showSession = false
    @StateObject private var apiService = PlayerApiService.shared

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
        && !ProcessInfo.processInfo.isMacCatalystApp
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 16) {
                // Toggle for name/email search
                Toggle(isOn: $viewModel.isEmailSearch) {
                    Text(viewModel.isEmailSearch ? "Show Grade" : "Show Email")
                        .font(.subheadline)
                }
                .padding(.horizontal)

                // Search Field
                TextField(viewModel.isEmailSearch ? "Search.." : "Search..", text: $viewModel.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .onTapGesture { hideKeyboard() }

                // Sort Picker
                Picker("Sort by", selection: $viewModel.sortMode) {
                    ForEach(PlayerListViewModel.SortMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // List of players (multi-select)
                List(viewModel.filteredPlayers, id: \.self, selection: $viewModel.selectedPlayers) { player in
                    VStack(alignment: .leading) {
                        Text(player.playerName ?? "Unnamed Player")
                            .font(.headline)
                            .foregroundColor(player.attendingSession ? .red : .primary)
                            .animation(.easeIn, value: player.attendingSession)

                        if player.isTopRank {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                        }

                        if viewModel.isEmailSearch {
                            Text(player.email ?? "")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else if let grade = player.grade, !grade.isEmpty {
                            Text("Grade: \(grade)")
                                .font(.caption)
                                .foregroundColor(player.gradeColor)
                        }
                    }
                }
                .environment(\.editMode, .constant(.active))
                .frame(maxHeight: .infinity)

                // Add new player row
                HStack {
                    TextField("New Player Name", text: $viewModel.newPlayerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("Add") { viewModel.addPlayer() }
                }
                .padding(.horizontal)

                // Check-in / Check-out / Sync buttons
                HStack {
                    Button("Check In") {
                        viewModel.checkInSelected()
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            sessionViewModel.loadParticipantsFromCoreData()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Done") {
                        viewModel.checkOutSelected()
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            sessionViewModel.loadParticipantsFromCoreData()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        Task { await apiService.resetAndFetchFreshData() }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                }

                // iPhone: navigate to session
                if isPhone {
                    Button("Go to Session") {
                        showSession = true
                        sessionViewModel.loadParticipantsFromCoreData()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }

                Spacer().frame(height: 10)
            }
            .padding()
            .navigationTitle("Players")
            .navigationDestination(isPresented: $showSession) {
                PlayingSessionView(viewModel: sessionViewModel)
            }

            // Sync banner
            if apiService.isSyncing {
                HStack {
                    ProgressView()
                    Text("Syncing with cloud...")
                        .font(.caption)
                        .padding(.leading, 4)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.9))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: apiService.isSyncing)
            }
        }
        // reload on appear or session changes
        .onAppear { viewModel.loadFromCoreData() }
        .onReceive(NotificationCenter.default.publisher(for: .refreshSession)) { _ in
            viewModel.loadFromCoreData()
        }

        
        // Info toast
        if let message = viewModel.infoMessage {
            Text(message)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.95))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: viewModel.infoMessage)
        }
    }
}

#Preview {
    PlayerListView(
        viewModel: PlayerListViewModel(),
        sessionViewModel: PlayingSessionViewModel(refreshTrigger: Just(()).eraseToAnyPublisher())
    )
}




