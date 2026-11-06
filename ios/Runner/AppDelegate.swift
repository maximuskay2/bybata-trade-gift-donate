import Flutter
import UIKit
import GoogleMaps
import GoogleSignIn
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
    Messaging.messaging().delegate = self
    application.registerForRemoteNotifications()
    if let plistKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !plistKey.isEmpty {
      GMSServices.provideAPIKey(plistKey)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// With the UIScene lifecycle there is no window at launch, so plugins and
  /// app-level channels register here once the storyboard's engine exists.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: "maps_config",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler({ (call: FlutterMethodCall, result: FlutterResult) in
      if call.method == "setApiKey" {
        if let args = call.arguments as? [String: Any], let key = args["apiKey"] as? String, !key.isEmpty {
          GMSServices.provideAPIKey(key)
          result(true)
        } else {
          result(FlutterError(code: "invalid_args", message: "apiKey missing", details: nil))
        }
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if GIDSignIn.sharedInstance.handle(url) {
      return true
    }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("Failed to register for APNS: \(error)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
    let dataDict: [String: String] = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: dataDict
    )
  }
}
