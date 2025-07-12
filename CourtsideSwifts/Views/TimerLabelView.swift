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
    let finishedAt: String?
    let tick: Date  // from viewModel, triggers every second
    
    @State private var displayedSeconds: Int = 0
    //private let formatter = DateFormatter.hhmmss
    private let formatter = ISO8601DateFormatter()

    
    var body: some View {
        Text("\(computedSeconds.asHoursMinutesSeconds())")
        //Text(displayedSeconds.asHoursMinutesSeconds())
            .font(.caption)
            .monospacedDigit()
            .transition(.opacity.combined(with: .scale))
            .animation(.easeInOut(duration: 0.2), value: displayedSeconds)
            .onAppear {
               // print("⏱ TimerLabelView appeared for player with startedAt = \(startedAt ?? "nil")")
                print("🪵 Input startedAt: \(startedAt ?? "nil")")
                print("🪵 Parsed ISO: \(String(describing: ISO8601DateFormatter().date(from: startedAt ?? "")))")

                displayedSeconds = computeCurrentSeconds()
            }

            .onChange(of: tick) {
                print("⚡️ Tick changed: \(tick)")
                displayedSeconds = computeCurrentSeconds()
            }
    }
    
    private var computedSeconds: Int {
            var total = baseSeconds

            guard let startStr = startedAt,
                  let start = formatter.date(from: startStr) else {
                print("🚫 Invalid or missing startedAt: \(startedAt ?? "nil")")
                return total
            }

            // If stopped, don't keep incrementing
            if let endStr = finishedAt,
               let end = formatter.date(from: endStr),
               end > start {
                return total
            }

            let elapsed = Int(Date().timeIntervalSince(start))
            print("🧮 Elapsed since start: \(elapsed) sec from \(start)")
            return total + max(0, elapsed)
        }
    
    
    private func computeCurrentSeconds() -> Int {
        let total = baseSeconds
       // let isoFormatter = ISO8601DateFormatter()

        print("🪵 Input startedAt: \(startedAt ?? "nil")")

        guard let startStr = startedAt,
              let start = formatter.date(from: startStr) else {
            print("🚫 Invalid or missing startedAt: \(startedAt ?? "nil")")
            return total
        }

        if let endStr = finishedAt,
           let end = formatter.date(from: endStr),
           end > start {
            print("⏱ Session finished. Ignoring extra time.")
            return total // base already includes duration
        }

        let elapsed = Int(Date().timeIntervalSince(start))
        print("🧮 Elapsed since start: \(elapsed) sec from \(start)")
        return total + max(0, elapsed)
    }


}

extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}


