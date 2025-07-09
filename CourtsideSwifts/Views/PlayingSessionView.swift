//
//  PlayingSessionView.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 8/7/2025.
//
import SwiftUI

struct PlayingSessionView: View {
    @ObservedObject var viewModel: PlayingSessionViewModel
    @State private var showTimeoutConfirmation = false
    
    
    var body: some View {
        ZStack(alignment: .top){
            NavigationView {
                VStack(spacing: 8) {
                    // 🔽 Chooser Banner
                    if let waitingGroup = viewModel.groupedParticipants.first(where: { $0.category == "Waiting" }),
                       !waitingGroup.players.isEmpty,
                       let chooser = waitingGroup.players.first(where: { $0.isChoosing }) {
                        
                        HStack {
                            Label(
                                title: {
                                    VStack(alignment: .leading) {
                                        Text(chooser.playerName ?? "Unknown")
                                            .font(.headline)
                                            .bold()
                                        
                                    }
                                },
                                icon: {
                                    Image(systemName: "crown.fill")
                                }
                            )
                            
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.yellow.opacity(0.9))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .padding(.top, 8)
                            .foregroundColor(.black)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.5), value: chooser.id)
                            /*.background(
                             RoundedRectangle(cornerRadius: 12)
                             .fill(Color.yellow.opacity(0.2))
                             )*/
                            .foregroundColor(.orange)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    Toggle("Use Grade Filter", isOn: $viewModel.useGradeFilter)
                        .toggleStyle(.switch)
                        .padding(.horizontal)
                    
                    
                    // 🔽 Main Grouped List
                    List {
                        ForEach(viewModel.groupedParticipants) { group in
                            // Default categories: no color styling
                            if ["Pending", "Waiting", "Chosen", "Playing"].contains(group.category) {
                                Section(header: Text(group.category).font(.headline)) {
                                    
                                    ForEach(group.players) { player in
                                        let showTimeout = ["Waiting", "Playing", "Chosen"].contains(group.category)
                                        let isEligible = viewModel.isSelectableForChooser(player)
                                        let isSelected = viewModel.selectedWaitingPlayers.contains(player.id)
                                        // Base row
                                        let baseRow: some View = Group {
                                            if group.category == "Waiting" && !player.isChoosing {
                                                PlayerRowView(player: player)
                                                    .contentShape(Rectangle())
                                                    .onTapGesture {
                                                        // let isEligible = viewModel.isSelectableForChooser(player)
                                                        print("👆 Tap on \(player.playerName ?? "Unnamed") — Eligible: \(isEligible)")
                                                        if isEligible {
                                                            viewModel.toggleSelection(for: player)
                                                        }
                                                    }
                                                
                                                    .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
                                                    .opacity(isEligible ? 1.0 : 0.3)
                                                    .help(isEligible ? "" : "Not eligible for selection")
                                                
                                            }
                                            
                                            
                                            else {
                                                PlayerRowView(player: player)
                                            }
                                        }
                                        
                                        if showTimeout {
                                            if isRunningOnMac {
                                                HStack {
                                                    baseRow
                                                    Spacer(minLength: 8)
                                                    Button {
                                                        viewModel.playerToTimeout = player
                                                        showTimeoutConfirmation = true
                                                    } label: {
                                                        Image(systemName: "clock.fill")
                                                            .foregroundColor(.red)
                                                    }
                                                    .buttonStyle(.plain)
                                                    .padding(.trailing, 8)
                                                }
                                            } else {
                                                baseRow
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                        Button(role: .destructive) {
                                                            viewModel.playerToTimeout = player
                                                            showTimeoutConfirmation = true
                                                        } label: {
                                                            Label("Time Out", systemImage: "clock.fill")
                                                        }
                                                    }
                                            }
                                        } else {
                                            baseRow
                                        }
                                    }
                                    
                                    
                                    /* ForEach(group.players) { player in
                                     if group.category == "Waiting" && !player.isChoosing {
                                     PlayerRowView(player: player)
                                     .contentShape(Rectangle())
                                     .onTapGesture {
                                     viewModel.toggleSelection(for: player)
                                     }
                                     .background(
                                     viewModel.selectedWaitingPlayers.contains(player.id)
                                     ? Color.blue.opacity(0.2)
                                     : Color.clear
                                     )
                                     } else {
                                     PlayerRowView(player: player)
                                     }
                                     }*/
                                    
                                    
                                }
                            } else {
                                // Team headers: colored capsule styling
                                Section(
                                    header:
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
                    }
                    
                    
                    
                    if viewModel.selectedWaitingPlayers.count == 3 {
                        Button("Confirm Selection") {
                            viewModel.confirmChooserSelection()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                    }
                }
                .navigationTitle("Playing Session")
            }
        }
    }
}

