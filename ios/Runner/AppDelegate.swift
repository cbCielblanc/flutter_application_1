import Flutter
import UIKit

enum PythonRuntimeHooks {
  static func install() {
    let fileManager = FileManager.default
    let supportDirectory = NSSearchPathForDirectoriesInDomains(
      .applicationSupportDirectory,
      .userDomainMask,
      true
    ).first ?? NSTemporaryDirectory()
    let pythonDirectory = (supportDirectory as NSString).appendingPathComponent("python-runtime")
    if !fileManager.fileExists(atPath: pythonDirectory) {
      try? fileManager.createDirectory(atPath: pythonDirectory, withIntermediateDirectories: true)
    }
    setenv("PYTHONHOME", Bundle.main.bundlePath, 1)
    setenv("PYTHONPATH", pythonDirectory, 1)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    PythonRuntimeHooks.install()
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
