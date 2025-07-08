//
//  PlayerListView.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//


import SwiftUI

struct PlayerListView: View {
    @ObservedObject var viewModel: PlayerListViewModel
    @ObservedObject var sessionViewModel: PlayingSessionViewModel

    @State private var showSession = false
    @StateObject private var apiService = PlayerApiService.shared

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
                    .onTapGesture {
                        hideKeyboard()
                    }

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
                            .foregroundColor(player.attendingSession ? .orange : .primary)
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
                .environment(\.editMode, .constant(.active)) // enable multiselect
                .frame(maxHeight: .infinity)

                Spacer()

                // Add new player row
                HStack {
                    TextField("New Player Name", text: $viewModel.newPlayerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("Add") {
                        viewModel.addPlayer()
                    }
                }
                .padding(.horizontal)

                // Check-in / Check-out / Sync buttons
                HStack {
                    Button("Check In") {
                        viewModel.checkInSelected()
                        Task{
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            sessionViewModel.loadParticipantsFromCoreData()
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Done") {
                        viewModel.checkOutSelected()
                        Task{
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            sessionViewModel.loadParticipantsFromCoreData()
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Reset") {
                        Task {
                            await apiService.resetAndFetchFreshData()
                        }
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    
                   /* //DEBUG ONLY
                    Button("Reset Core Data") {
                        viewModel.resetDatabaseForTesting()
                    }*/

                }

                // 🚀 Go to Playing Session Button (iPhone)
                Button("Go to Session") {
                    showSession = true
                    sessionViewModel.loadParticipantsFromCoreData()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)

                Spacer().frame(height: 10)
            }
            .padding()
            .navigationTitle("Add Players")
            .onAppear {
                viewModel.loadFromCoreData()
            }
            .navigationDestination(isPresented: $showSession) {
                PlayingSessionView(viewModel: sessionViewModel)
            }

            // 🔽 Syncing Banner
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





