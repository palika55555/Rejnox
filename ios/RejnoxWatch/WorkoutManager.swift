import Foundation
import HealthKit

/// Beží tréning na hodinkách (HKWorkoutSession) a číta tep naživo.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()

    @Published private(set) var heartRate: Double = 0
    @Published private(set) var running = false
    @Published private(set) var startDate: Date?
    @Published var errorMessage: String?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private let heartRateType = HKQuantityType(.heartRate)

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Apple Health nie je dostupné."
            return false
        }
        do {
            try await healthStore.requestAuthorization(
                toShare: [HKObjectType.workoutType()],
                read: [heartRateType, HKObjectType.workoutType()]
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func start(with configuration: HKWorkoutConfiguration? = nil) async {
        guard session == nil else { return }
        guard await requestAuthorization() else { return }

        let config = configuration ?? {
            let c = HKWorkoutConfiguration()
            c.activityType = .traditionalStrengthTraining
            c.locationType = .indoor
            return c
        }()

        do {
            let session = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: config
            )
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )
            session.delegate = self
            builder.delegate = self
            self.session = session
            self.builder = builder

            let start = Date()
            session.startActivity(with: start)
            try await builder.beginCollection(at: start)

            startDate = start
            running = true
            errorMessage = nil
            PhoneLink.shared.send(state: "started", bpm: nil)
        } catch {
            errorMessage = error.localizedDescription
            self.session = nil
            self.builder = nil
        }
    }

    func stop() async {
        guard let session, let builder else { return }
        session.end()
        do {
            try await builder.endCollection(at: Date())
            _ = try await builder.finishWorkout()
        } catch {
            errorMessage = error.localizedDescription
        }
        self.session = nil
        self.builder = nil
        running = false
        startDate = nil
        heartRate = 0
        PhoneLink.shared.send(state: "ended", bpm: nil)
    }

    fileprivate func publish(bpm: Double) {
        heartRate = bpm
        PhoneLink.shared.send(state: "running", bpm: bpm)
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {}

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        let message = error.localizedDescription
        Task { @MainActor in self.errorMessage = message }
    }
}

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let type = HKQuantityType(.heartRate)
        guard collectedTypes.contains(type),
              let quantity = workoutBuilder.statistics(for: type)?.mostRecentQuantity()
        else { return }
        let bpm = quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        Task { @MainActor in self.publish(bpm: bpm) }
    }
}
