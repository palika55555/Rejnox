import Foundation
import WatchConnectivity

/// Spojenie hodiniek s iPhonom: posiela tep, prijíma príkaz na ukončenie.
final class PhoneLink: NSObject, WCSessionDelegate {
    static let shared = PhoneLink()

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// state: started / running / ended
    func send(state: String, bpm: Double?) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        var payload: [String: Any] = [
            "type": "heartRate",
            "state": state,
            "at": Date().timeIntervalSince1970,
        ]
        if let bpm { payload["bpm"] = bpm }

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
        if message["command"] as? String == "stop" {
            Task { @MainActor in await WorkoutManager.shared.stop() }
        }
    }
}
