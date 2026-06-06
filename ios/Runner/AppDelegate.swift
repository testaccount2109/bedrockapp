import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let channelName = "de.hostconnect.app/local_network"
  private static var permissionProbe: LocalNetworkPermissionProbe?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      AppDelegate.configureLocalNetworkChannel(controller)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  static func configureLocalNetworkChannel(_ controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "request":
        permissionProbe = LocalNetworkPermissionProbe()
        permissionProbe?.request { response in
          result(response)
          permissionProbe = nil
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

private final class LocalNetworkPermissionProbe {
  private let queue = DispatchQueue(label: "de.hostconnect.app.local-network-probe")
  private var browser: NWBrowser?
  private var completed = false

  func request(completion: @escaping ([String: Any]) -> Void) {
    let parameters = NWParameters.udp
    parameters.includePeerToPeer = true

    let browser = NWBrowser(
      for: .bonjour(type: "_hostconnect._udp", domain: nil),
      using: parameters
    )
    self.browser = browser

    let startedAt = Date()
    browser.stateUpdateHandler = { [weak self] state in
      guard let self = self else { return }
      switch state {
      case .ready:
        self.finish(
          status: "ready",
          message: "Network.framework Bonjour browser is ready",
          startedAt: startedAt,
          completion: completion
        )
      case .failed(let error):
        self.finish(
          status: "failed",
          message: "\(error)",
          startedAt: startedAt,
          completion: completion
        )
      case .waiting(let error):
        self.finish(
          status: "waiting",
          message: "\(error)",
          startedAt: startedAt,
          completion: completion
        )
      case .cancelled:
        self.finish(
          status: "cancelled",
          message: "Network.framework Bonjour browser was cancelled",
          startedAt: startedAt,
          completion: completion
        )
      case .setup:
        break
      @unknown default:
        self.finish(
          status: "unknown",
          message: "Network.framework Bonjour browser entered an unknown state",
          startedAt: startedAt,
          completion: completion
        )
      }
    }

    browser.start(queue: queue)

    queue.asyncAfter(deadline: .now() + 3.0) { [weak self] in
      self?.finish(
        status: "timeout",
        message: "Network.framework Bonjour browser kept running long enough to trigger local network privacy",
        startedAt: startedAt,
        completion: completion
      )
    }
  }

  private func finish(
    status: String,
    message: String,
    startedAt: Date,
    completion: @escaping ([String: Any]) -> Void
  ) {
    guard !completed else {
      return
    }
    completed = true
    browser?.cancel()
    browser = nil
    let response: [String: Any] = [
      "status": status,
      "message": message,
      "durationMs": Int(Date().timeIntervalSince(startedAt) * 1000),
      "serviceType": "_hostconnect._udp"
    ]
    DispatchQueue.main.async {
      completion(response)
    }
  }
}
