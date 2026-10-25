import AppKit
import Sparkle
import UserNotifications

/// Checks on open and every `SUScheduledCheckInterval` (6 hours), downloads in the
/// background and installs right away: Rootie is only busy for the instant it
/// routes a link, so there is no better moment to wait for.
@MainActor
final class NativeUpdater: NSObject, SPUUpdaterDelegate {
  private static let lastRunVersionKey = "lastRunVersion"

  private(set) var controller: SPUStandardUpdaterController!

  override init() {
    super.init()
    controller = SPUStandardUpdaterController(
      startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
  }

  func start() {
    controller.startUpdater()
    controller.updater.checkForUpdatesInBackground()
  }

  func menuItem() -> NSMenuItem {
    let item = NSMenuItem(
      title: "Check for Updates…",
      action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
      keyEquivalent: "")
    item.target = controller
    return item
  }

  /// Returns the new version when this launch is the first since an update.
  func versionUpdatedSinceLastRun(defaults: UserDefaults = .standard) -> String? {
    guard
      let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String
    else { return nil }
    let previous = defaults.string(forKey: Self.lastRunVersionKey)
    defaults.set(version, forKey: Self.lastRunVersionKey)
    guard let previous, ConfigMigrations.isVersion(version, newerThan: previous) else {
      return nil
    }
    return version
  }

  static func notifyUpdated(to version: String) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
      guard granted else { return }
      let content = UNMutableNotificationContent()
      content.title = "Rootie updated to \(version)"
      content.body = "Nothing to do on your end."
      UNUserNotificationCenter.current().add(
        UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
  }

  func updater(
    _ updater: SPUUpdater,
    willInstallUpdateOnQuit item: SUAppcastItem,
    immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
  ) -> Bool {
    immediateInstallHandler()
    return true
  }
}
