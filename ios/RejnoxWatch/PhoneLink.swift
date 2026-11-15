import Foundation
import WatchConnectivity

/// Spojenie hodiniek s iPhonom: posiela tep a kalórie, prijíma príkazy
/// stop / pause / resume.
final class PhoneLink: NSObject, WCSessionDelegate {
    static let shared = PhoneLink()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// state: started / running / paused / ended
    func send(state: String, bpm: Double?, kcal: Double?) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var payload: [String: Any] = [
            "type": "heartRate",
            "state": state,
            "at": Date().timeIntervalSince1970,
        ]
        if let bpm { payload["bpm"] = bpm }
        if let kcal { payload["kcal"] = kcal }

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            // Keď iPhone práve nepočúva, aspoň posledný stav.
            try? session.updateApplicationContext(payload)
        }
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(command: message["command"] as? String)
    }

    /// Príkaz z iPhonu, keď hodinky neboli v dosahu (doručí sa neskôr).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(command: userInfo["command"] as? String)
    }

    private func handle(command: String?) {
        Task { @MainActor in
            let workout = WorkoutManager.shared
            switch command {
            case "stop": await workout.stop()
            case "pause": if !workout.paused { workout.togglePause() }
            case "resume": if workout.paused { workout.togglePause() }
            default: break
            }
        }
    }
}
