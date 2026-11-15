import Foundation
import HealthKit

/// Beží tréning na hodinkách (HKWorkoutSession), číta tep a kalórie naživo,
/// dá sa pozastaviť a po páde appky sa obnoví.
@MainActor
final class WorkoutManager: NSObject, ObservableObject {
    static let shared = WorkoutManager()

    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeKcal: Double = 0
    @Published private(set) var running = false
    @Published private(set) var paused = false
    @Published private(set) var startDate: Date?
    @Published var errorMessage: String?

    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private let heartRateType = HKQuantityType(.heartRate)
    private let energyType = HKQuantityType(.activeEnergyBurned)

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "Apple Health nie je dostupné."
            return false
        }
        do {
            try await healthStore.requestAuthorization(
                toShare: [HKObjectType.workoutType()],
                read: [heartRateType, energyType, HKObjectType.workoutType()]
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
            attach(session)

            let start = Date()
            session.startActivity(with: start)
            try await builder?.beginCollection(at: start)

            startDate = start
            running = true
            paused = false
            activeKcal = 0
            errorMessage = nil
            PhoneLink.shared.send(state: "started", bpm: nil, kcal: 0)
        } catch {
            errorMessage = error.localizedDescription
            self.session = nil
            self.builder = nil
        }
    }

    /// Po páde alebo reštarte appky počas tréningu ho watchOS vráti.
    func recover() async {
        guard session == nil else { return }
        do {
            guard let recovered = try await healthStore.recoverActiveWorkoutSession()
            else { return }
            attach(recovered)
            startDate = recovered.startDate
            running = true
            paused = recovered.state == .paused
            PhoneLink.shared.send(state: phoneState, bpm: nil, kcal: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePause() {
        guard let session else { return }
        if paused { session.resume() } else { session.pause() }
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
        paused = false
        startDate = nil
        heartRate = 0
        PhoneLink.shared.send(state: "ended", bpm: nil, kcal: activeKcal)
    }

    private func attach(_ session: HKWorkoutSession) {
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: session.workoutConfiguration
        )
        session.delegate = self
        builder.delegate = self
        self.session = session
        self.builder = builder
    }

    private var phoneState: String { paused ? "paused" : "running" }

    fileprivate func publish(bpm: Double?, kcal: Double?) {
        if let bpm { heartRate = bpm }
        if let kcal { activeKcal = kcal }
        PhoneLink.shared.send(
            state: phoneState,
            bpm: heartRate > 0 ? heartRate : nil,
            kcal: activeKcal
        )
    }

    fileprivate func setPaused(_ value: Bool) {
        guard running, paused != value else { return }
        paused = value
        PhoneLink.shared.send(state: phoneState, bpm: nil, kcal: activeKcal)
    }
}

extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        let paused = toState == .paused
        Task { @MainActor in self.setPaused(paused) }
    }

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
        let hrType = HKQuantityType(.heartRate)
        let energyType = HKQuantityType(.activeEnergyBurned)
        var bpm: Double?
        var kcal: Double?
        if collectedTypes.contains(hrType),
           let q = workoutBuilder.statistics(for: hrType)?.mostRecentQuantity() {
            bpm = q.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        }
        if collectedTypes.contains(energyType),
           let q = workoutBuilder.statistics(for: energyType)?.sumQuantity() {
            kcal = q.doubleValue(for: .kilocalorie())
        }
        guard bpm != nil || kcal != nil else { return }
        let (b, k) = (bpm, kcal)
        Task { @MainActor in self.publish(bpm: b, kcal: k) }
    }
}
