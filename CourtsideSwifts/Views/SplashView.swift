//
//  SplashView.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 6/7/2025.
//
import SwiftUI
import CoreData

struct SplashView: View {
    @State private var isActive = false
    let persistenceController = PersistenceController.shared

    var body: some View {
        Group {
            if isActive {
                MainSplitView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            } else {
                VStack {
                    Image("SwiftsLogo")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .scaledToFit()

                    Text("Welcome to the Western Swifts Club")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .onAppear {
                    Task {
                        
                        //Wrap around refresh question if outside session hours TODO
                       // await clearStaleSessionIfNeeded()

                        // Optional: delay to allow user to view splash screen
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                        
                        await MainActor.run {
                            withAnimation {
                                isActive = true
                            }
                        }
                    }
                }
            }
        }
    }

    private func clearStaleSessionIfNeeded() async {
        let context = persistenceController.container.viewContext
        await context.perform {
            let request: NSFetchRequest<PlayerStatus> = PlayerStatus.fetchRequest()
            request.predicate = NSPredicate(format: "attendingSession == true")

            if let results = try? context.fetch(request) {
                for player in results {
                    player.attendingSession = false
                    player.playerCategories = PlayerCategory.pending.asInt32
                    player.isChoosing = false
                    player.isChosen = false
                    player.warmingUp = false
                    player.orderOfPlay = 0
                    player.gameID = 0
                    player.courtNo = 0
                    player.needsSync = true
                }

                try? context.save()
                
                SyncCoordinator.shared.requestSync()
            }
        }
    }
}


