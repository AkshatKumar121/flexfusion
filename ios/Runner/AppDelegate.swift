import Flutter
import UIKit
import UserNotifications
import HealthKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let restNotificationId = "flexfusion.workout.rest"
  private let healthStore = HKHealthStore()
  private var healthEventSink: FlutterEventSink?
  private var healthQueriesStarted = false

  private let healthTypes: [(HKQuantityTypeIdentifier, HKUpdateFrequency)] = [
    (.stepCount, .hourly),
    (.distanceWalkingRunning, .immediate),
    (.activeEnergyBurned, .immediate),
    (.appleExerciseTime, .immediate)
  ]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    startHealthObservers()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    UNUserNotificationCenter.current().delegate = self
    let healthMethodChannel = FlutterMethodChannel(
      name: "com.flexfusion/apple_health_sync",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    healthMethodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: "App delegate unavailable", details: nil))
        return
      }
      switch call.method {
      case "startObservers":
        self.startHealthObservers()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    let healthEventChannel = FlutterEventChannel(
      name: "com.flexfusion/apple_health_events",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    healthEventChannel.setStreamHandler(self)

    let channel = FlutterMethodChannel(
      name: "com.flexfusion/rest_timer",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      guard let self = self else { result(FlutterError(code: "UNAVAILABLE", message: "App delegate unavailable", details: nil)); return }
      switch call.method {
      case "requestPermission":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "NOTIFICATION_PERMISSION", message: error.localizedDescription, details: nil))
            } else {
              result(granted)
            }
          }
        }
      case "scheduleRest":
        guard let args = call.arguments as? [String: Any],
              let endMilliseconds = args["endAt"] as? Double else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing rest timer end timestamp", details: nil))
          return
        }
        let seconds = max(1, (endMilliseconds / 1000 - Date().timeIntervalSince1970))
        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Your rest timer has finished. Ready for the next set?"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: self.restNotificationId, content: content, trigger: trigger)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [self.restNotificationId])
        center.add(request) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(FlutterError(code: "NOTIFICATION_SCHEDULE", message: error.localizedDescription, details: nil))
            } else {
              result(true)
            }
          }
        }
      case "cancelRest":
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [self.restNotificationId])
        center.removeDeliveredNotifications(withIdentifiers: [self.restNotificationId])
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startHealthObservers() {
    for (identifier, frequency) in healthTypes {
      guard let sampleType = HKObjectType.quantityType(forIdentifier: identifier) else {
        continue
      }

      if !healthQueriesStarted {
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completion, error in
          defer { completion() }
          if let error = error {
            NSLog("[AppleHealth] Observer error for %@: %@", identifier.rawValue, error.localizedDescription)
            return
          }
          DispatchQueue.main.async {
            self?.healthEventSink?(identifier.rawValue)
          }
        }
        healthStore.execute(query)
      }

      healthStore.enableBackgroundDelivery(for: sampleType, frequency: frequency) { success, error in
        if let error = error {
          NSLog("[AppleHealth] Background delivery setup failed for %@: %@", identifier.rawValue, error.localizedDescription)
        } else {
          NSLog("[AppleHealth] Background delivery %@ for %@", success ? "enabled" : "not enabled", identifier.rawValue)
        }
      }
    }
    healthQueriesStarted = true
  }
}

extension AppDelegate: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    healthEventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    healthEventSink = nil
    return nil
  }
}
