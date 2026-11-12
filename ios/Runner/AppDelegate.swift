import Flutter
import HealthKit
import UIKit
import UserNotifications
import WatchConnectivity

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var watchBridge: WatchBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Pripomienky tréningu sa zobrazia aj keď je appka otvorená.
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "RejnoxWatchBridge") {
      watchBridge = WatchBridge(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// Most medzi Apple Watch a Flutterom:
/// - kanál "rejnox/watch": status, startWorkout, stopWorkout
/// - stream "rejnox/watch_heart_rate": tep z hodiniek naživo
final class WatchBridge: NSObject, FlutterStreamHandler, WCSessionDelegate {
  private let healthStore = HKHealthStore()
  private var sink: FlutterEventSink?

  init(messenger: FlutterBinaryMessenger) {
    super.init()
    FlutterEventChannel(name: "rejnox/watch_heart_rate", binaryMessenger: messenger)
      .setStreamHandler(self)
    FlutterMethodChannel(name: "rejnox/watch", binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        self?.handle(call, result: result)
      }
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      guard WCSession.isSupported() else {
        result(["paired": false, "installed": false, "reachable": false])
        return
      }
      let session = WCSession.default
      result([
        "paired": session.isPaired,
        "installed": session.isWatchAppInstalled,
        "reachable": session.isReachable,
      ])

    case "startWorkout":
      // Spustí Rejnox na hodinkách rovno v režime tréningu.
      let config = HKWorkoutConfiguration()
      config.activityType = .traditionalStrengthTraining
      config.locationType = .indoor
      healthStore.startWatchApp(with: config) { success, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(
              code: "start_failed", message: error.localizedDescription, details: nil))
          } else {
            result(success)
          }
        }
      }

    case "stopWorkout":
      let session = WCSession.default
      if WCSession.isSupported() && session.isReachable {
        session.sendMessage(["command": "stop"], replyHandler: nil, errorHandler: nil)
        result(true)
      } else {
        result(false)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  private func forward(_ payload: [String: Any]) {
    DispatchQueue.main.async { [weak self] in self?.sink?(payload) }
  }

  // MARK: WCSessionDelegate

  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {}

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    // Po prepnutí na iné hodinky sa treba znova aktivovať.
    WCSession.default.activate()
  }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    forward(message)
  }

  func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    forward(applicationContext)
  }
}
