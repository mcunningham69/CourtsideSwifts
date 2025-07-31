//
//  PlayerListView.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 5/7/2025.
//


import SwiftUI
import Combine
import CoreData

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
                
                if let message = viewModel.toastMessage {
                    ToastView(message: message, backgroundColor: viewModel.toastColor, position: viewModel.toastPosition)
                }
                
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
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(player.playerName ?? "Unnamed Player")
                                .font(.headline)
                                .bold()
                                .foregroundColor(.black)
                                .opacity(player.attendingSession ? 0.5 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: player.attendingSession)
                            
                            
                            if player.isTopRank {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                            }
                            
                            if player.attendingSession {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
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
                    .listRowBackground(player.attendingSession ? Color.gray.opacity(0.05) : Color.clear)
                }
                
                .environment(\.editMode, .constant(.active))
                .frame(maxHeight: .infinity)
                
                // Add new player row
                HStack {
                    TextField("New Player Name", text: $viewModel.newPlayerName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Add") {
                        Task {
                            do {
                                try await viewModel.addPlayer()
                            } catch {
                                print("❌ Failed to add player:", error)
                            }
                        }
                    }
                    
                }
                .padding(.horizontal)
                
                // Check-in / Check-out / Sync buttons
                HStack {
                    Button("Check In") {
                        Task {
                            do {
                                try await viewModel.checkInSelected(sessionViewModel: sessionViewModel)
                                // ✅ Show success toast
                                viewModel.showToast(message: "Checked in successfully", color: .green, position: .bottom)
                            } catch {
                                print("❌ Check-in failed: \(error)")
                            }
                            
                        }
                    }
                    
                    .buttonStyle(.borderedProminent)
                    
                    Button("Finished") {
                        
                        Task {
                            try? await viewModel.checkOutSelected(sessionViewModel: sessionViewModel)
                            viewModel.showToast(message: "Checked out successfully", color: .blue, position: .bottom)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Reset") {
                        Task {
                            do {
                                // 🧹 Soft reset local Core Data fields only
                                let didReset = await AppInitialisationService.shared.resetSessionDataIfNeeded()
                                
                                if didReset{
                                    // 🔁 Sync reset states to Azure (only affected players)
                                    try await PlayerApiService.shared.syncPendingPlayersToAzure()
                                    
                                    // 🔄 Clear Core Data and fetch fresh data from Azure
                                    //  try await PlayerApiService.shared.resetAndFetchFreshData()
                                    
                                    // 🧠 Reload view and reconnect WebSocket
                                    viewModel.debouncedReload()
                                    sessionViewModel.loadParticipantsFromCoreData()
                                    
                                    if !WebSocketManager.shared.isConnected {
                                        WebSocketManager.shared.connect()
                                    }
                                    // ✅ Toast confirmation
                                    viewModel.showToast(message: "Session reset complete", color: .green, position: .bottom)
                                    
                                    
                                } else {
                                    print("Reset skipped: No pending players to reset")
                                    viewModel.showToast(message: "Nothing to reset", color: .orange, position: .bottom)
                                                
                                }
                                
                            } catch {
                                print("❌ Failed during reset flow: \(error)")
                                viewModel.showToast(message: "Reset failed", color: .red, position: .bottom)
                            }
                        }
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
       /* if let message = viewModel.infoMessage {
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
        }*/
        
    }
}



#Preview {
    PlayerListView(
        viewModel: PlayerListViewModel(),
        sessionViewModel: PlayingSessionViewModel(sessionID: UUID(), refreshTrigger: Just(()).eraseToAnyPublisher())
    )
}


enum ToastPosition {
    case top, bottom
}

struct ToastView: View {
    let message: String
    let backgroundColor: Color
    let position: ToastPosition

    var body: some View {
        Text(message)
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor.opacity(0.95))
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(position == .top ? .top : .bottom, 40)
            .transition(.move(edge: position == .top ? .top : .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: message)
    }
}





