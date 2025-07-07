//
//  SplashView.swift
//  CourtsideSwifts
//
//  Created by Mike Cunningham on 6/7/2025.
//
import SwiftUI

struct SplashView: View {
    @State private var isActive = false
    let persistenceController = PersistenceController.shared

    var body: some View {
        Group {
            if isActive {
                PlayerListView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            } else {
                VStack {
                    Image("SwiftsLogo") // Ensure this image exists in assets
                        .resizable()
                        .frame(width: 120, height: 120)
                        .scaledToFit()

                    Text("Welcome to the Western Swfits Club")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}

