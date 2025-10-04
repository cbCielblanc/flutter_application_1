import Cocoa
import FlutterMacOS

enum PythonRuntimeHooks {
  static func install() {
    let fileManager = FileManager.default
    let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fileManager.temporaryDirectory
    let pythonDirectory = supportDirectory.appendingPathComponent("python-runtime", isDirectory: true)
    if !fileManager.fileExists(atPath: pythonDirectory.path) {
      try? fileManager.createDirectory(at: pythonDirectory, withIntermediateDirectories: true)
    }
    setenv("PYTHONHOME", Bundle.main.bundlePath, 1)
    setenv("PYTHONPATH", pythonDirectory.path, 1)
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    PythonRuntimeHooks.install()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
