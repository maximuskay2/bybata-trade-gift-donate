import Flutter
import UIKit
import GoogleMaps
import GoogleSignIn
import FirebaseCore
import FirebaseMessaging
import Speech
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, MessagingDelegate {
  private let deviceVoice = DeviceVoiceCapture()
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

    let voiceChannel = FlutterMethodChannel(
      name: "bybata/device_voice",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    let voiceEvents = FlutterEventChannel(
      name: "bybata/device_voice_events",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    voiceEvents.setStreamHandler(deviceVoice)
    voiceChannel.setMethodCallHandler({ (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "start" {
        self.deviceVoice.start(result: result)
      } else if call.method == "stop" {
        self.deviceVoice.stop()
        result(nil)
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

/// System speech recognizer. Words stream out the way keyboard dictation types.
final class DeviceVoiceCapture: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var pending: String?
  private let engine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private var tapInstalled = false
  private let recognizer = SFSpeechRecognizer(locale: Locale.current)

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    if let pending = pending {
      events(pending)
      self.pending = nil
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    stop()
    return nil
  }

  func start(result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { status in
      DispatchQueue.main.async {
        guard status == .authorized else {
          result(FlutterError(
            code: "denied",
            message: "Allow speech recognition to type with your voice.",
            details: nil
          ))
          return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
          DispatchQueue.main.async {
            guard allowed else {
              result(FlutterError(
                code: "denied",
                message: "Allow the microphone to type with your voice.",
                details: nil
              ))
              return
            }
            do {
              try self.begin()
              result(nil)
            } catch {
              result(FlutterError(code: "unavailable", message: error.localizedDescription, details: nil))
            }
          }
        }
      }
    }
  }

  func stop() {
    request?.endAudio()
    tearDown()
  }

  private func begin() throws {
    tearDown()
    guard let recognizer = recognizer, recognizer.isAvailable else {
      throw VoiceCaptureError.unavailable
    }
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
    try session.setActive(true, options: .notifyOthersOnDeactivation)

    let request = SFSpeechAudioBufferRecognitionRequest()
    request.shouldReportPartialResults = true
    self.request = request

    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      throw VoiceCaptureError.unavailable
    }
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      request.append(buffer)
    }
    tapInstalled = true
    engine.prepare()
    try engine.start()

    task = recognizer.recognitionTask(with: request) { [weak self] recognition, error in
      guard let self = self else { return }
      if let text = recognition?.bestTranscription.formattedString, !text.isEmpty {
        DispatchQueue.main.async { self.emit(text) }
      }
      if error != nil || recognition?.isFinal == true {
        DispatchQueue.main.async { self.tearDown() }
      }
    }
  }

  private func emit(_ text: String) {
    if let sink = sink {
      sink(text)
    } else {
      pending = text
    }
  }

  private func tearDown() {
    let current = task
    task = nil
    request = nil
    if engine.isRunning {
      engine.stop()
    }
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    current?.cancel()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}

private enum VoiceCaptureError: LocalizedError {
  case unavailable

  var errorDescription: String? {
    "Voice typing is not available on this device."
  }
}
