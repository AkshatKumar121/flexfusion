import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let restNotificationId = "flexfusion.workout.rest"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "com.flexfusion/rest_timer",
      binaryMessenger: engineBridge.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
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
}
