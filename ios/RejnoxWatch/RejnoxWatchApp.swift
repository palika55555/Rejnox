import HealthKit
import SwiftUI
import WatchKit

/// Rejnox pre Apple Watch: tréning s tepom naživo.
@main
struct RejnoxWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(WorkoutManager.shared)
        }
    }
}

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        PhoneLink.shared.activate()
    }

    /// Tréning bežal, keď appka spadla alebo sa reštartovala.
    func handleActiveWorkoutRecovery() {
        Task { @MainActor in await WorkoutManager.shared.recover() }
    }

    /// iPhone spustil tréning cez HKHealthStore.startWatchApp(with:).
    func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
        Task { @MainActor in
            await WorkoutManager.shared.start(with: workoutConfiguration)
        }
    }
}
