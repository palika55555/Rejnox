import SwiftUI

private let violet = Color(red: 0.61, green: 0.36, blue: 1.0)
private let blue = Color(red: 0.33, green: 0.41, blue: 1.0)

struct ContentView: View {
    @EnvironmentObject private var workout: WorkoutManager

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(violet)
                    .accessibilityHidden(true)

                Text(workout.heartRate > 0 ? "\(Int(workout.heartRate.rounded()))" : "--")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel(
                        workout.heartRate > 0
                            ? "Tep \(Int(workout.heartRate.rounded())) úderov za minútu"
                            : "Tep zatiaľ nie je známy"
                    )

                Text("BPM")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if let start = workout.startDate {
                    Text(start, style: .timer)
                        .font(.caption.monospacedDigit())
                }

                Button(workout.running ? "Ukončiť" : "Začať tréning") {
                    Task {
                        if workout.running {
                            await workout.stop()
                        } else {
                            await workout.start()
                        }
                    }
                }
                .tint(workout.running ? .red : blue)
                .padding(.top, 4)

                if let message = workout.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("REJNOX")
    }
}
