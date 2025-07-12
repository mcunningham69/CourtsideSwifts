//
//  TimeLabelView.swift
//  CourtsideSwifts
//
//  Created by Michael Cunningham on 12/7/2025.
//

import SwiftUI

struct TimerLabelView: View {
    let baseSeconds: Int
    let startedAt: String?
    let tick: Date  // from viewModel, triggers every second
    
    @State private var displayedSeconds: Int = 0
    private let formatter = DateFormatter.hhmmss
    
    var body: some View {
        Text(displayedSeconds.asHoursMinutesSeconds())
            .font(.caption)
            .monospacedDigit()
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.2), value: displayedSeconds)
            .onAppear {
                print("⏱ TimerLabelView appeared for player with startedAt = \(startedAt ?? "nil")")
                displayedSeconds = computeCurrentSeconds()
            }

            .onChange(of: tick) {
                print("⚡️ Tick changed: \(tick)")
                displayedSeconds = computeCurrentSeconds()
            }
    }
    
    private func computeCurrentSeconds() -> Int {
        var total = baseSeconds
        
        if let start = startedAt.flatMap({ formatter.date(from: $0) }) {
            let elapsed = Int(Date().timeIntervalSince(start))
            print("🧮 Elapsed: \(elapsed) sec from \(start)")

            total += max(0, elapsed)
        } else{
            print("🚫 Invalid or missing startedAt: \(startedAt ?? "nil")")
        }
        
        return total
    }
}

