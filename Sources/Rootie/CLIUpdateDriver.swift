import Foundation
import Sparkle

@MainActor
final class CLIUpdateDriver: NSObject, SPUUserDriver, SPUUpdaterDelegate {
  private let bundle: Bundle
  private let presenter: CLIUpdatePresenter
  private let output: (String) -> Void
  private let errorOutput: (String) -> Void
  private var exitStatus: Int32?
  private var cancelled = false
  private var noUpdateStatus: Int32 = 0
  private var installationMessageShown = false

  private lazy var updater = SPUUpdater(
    hostBundle: bundle,
    applicationBundle: bundle,
    userDriver: self,
    delegate: self)

  init(
    bundle: Bundle,
    readInput: @escaping () -> String?,
    output: @escaping (String) -> Void,
    errorOutput: @escaping (String) -> Void
  ) {
    self.bundle = bundle
    presenter = CLIUpdatePresenter(readInput: readInput, output: output)
    self.output = output
    self.errorOutput = errorOutput
  }

  static func run(
    executablePath: String = CommandLine.arguments[0],
    searchPath: String? = ProcessInfo.processInfo.environment["PATH"],
    readInput: @escaping () -> String?,
    output: @escaping (String) -> Void,
    errorOutput: @escaping (String) -> Void
  ) throws -> Int32 {
    guard
      let appURL = RootieCLI.applicationURL(
        executablePath: executablePath, searchPath: searchPath),
      let bundle = Bundle(url: appURL)
    else {
      throw CLIUpdateError.appBundleNotFound
    }

    let driver = CLIUpdateDriver(
      bundle: bundle, readInput: readInput, output: output, errorOutput: errorOutput)
    return try driver.run()
  }

  private func run() throws -> Int32 {
    try updater.start()
    updater.checkForUpdates()
    while exitStatus == nil {
      RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
    }
    return exitStatus ?? 1
  }

  func show(
    _ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void
  ) {
    reply(SUUpdatePermissionResponse(automaticUpdateChecks: true, sendSystemProfile: false))
  }

  func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
    output("Checking for updates…")
  }

  func showUpdateFound(
    with appcastItem: SUAppcastItem,
    state: SPUUserUpdateState,
    reply: @escaping (SPUUserUpdateChoice) -> Void
  ) {
    if appcastItem.isInformationOnlyUpdate {
      errorOutput("This update must be installed manually from the Rootie release page.")
      reply(.dismiss)
      return
    }

    let accepted = presenter.confirm(
      installedVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")
        as? String ?? "unknown",
      latestVersion: appcastItem.displayVersionString,
      releaseNotes: appcastItem.itemDescription)
    if accepted {
      output("Downloading update…")
      reply(.install)
    } else {
      cancelled = true
      output("Update cancelled.")
      reply(.dismiss)
    }
  }

  func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {}

  func showUpdateReleaseNotesFailedToDownloadWithError(_ error: any Error) {
    errorOutput("Release notes could not be loaded: \(error.localizedDescription)")
  }

  func showUpdateNotFoundWithError(_ error: any Error, acknowledgement: @escaping () -> Void) {
    let nsError = error as NSError
    let reason = (nsError.userInfo[SPUNoUpdateFoundReasonKey] as? NSNumber)
      .flatMap { SPUNoUpdateFoundReason(rawValue: $0.int32Value) }
    if reason == .onLatestVersion || reason == .onNewerThanLatestVersion {
      output("Installed: \(displayVersion)")
      output("Latest: \(displayVersion)")
      output("Rootie is up to date.")
    } else {
      noUpdateStatus = 1
      errorOutput("No compatible update was found: \(nsError.localizedDescription)")
    }
    acknowledgement()
  }

  func showUpdaterError(_ error: any Error, acknowledgement: @escaping () -> Void) {
    let nsError = error as NSError
    let prefix: String
    switch UpdateFailure(error: nsError) {
    case .offline: prefix = "Could not check for updates"
    case .invalidFeed: prefix = "The update feed is invalid"
    case .verificationFailed: prefix = "The update could not be verified"
    case .installationFailed: prefix = "The update could not be installed"
    case .other: prefix = "The update failed"
    }
    errorOutput("\(prefix): \(nsError.localizedDescription)")
    acknowledgement()
  }

  func showDownloadInitiated(cancellation: @escaping () -> Void) {}
  func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
  func showDownloadDidReceiveData(ofLength length: UInt64) {}

  func showDownloadDidStartExtractingUpdate() {
    output("Verifying update…")
  }

  func showExtractionReceivedProgress(_ progress: Double) {}

  func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
    showInstallationMessage()
    reply(.install)
  }

  func showInstallingUpdate(
    withApplicationTerminated applicationTerminated: Bool,
    retryTerminatingApplication: @escaping () -> Void
  ) {
    showInstallationMessage()
  }

  func showUpdateInstalledAndRelaunched(
    _ relaunched: Bool,
    acknowledgement: @escaping () -> Void
  ) {
    output(relaunched ? "Rootie was updated and relaunched." : "Rootie was updated successfully.")
    acknowledgement()
  }

  func dismissUpdateInstallation() {}

  func updater(
    _ updater: SPUUpdater,
    didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
    error: (any Error)?
  ) {
    if cancelled {
      exitStatus = 0
    } else if let error = error as NSError?, error.domain == SUSparkleErrorDomain,
      error.code == Int(SUError.noUpdateError.rawValue)
    {
      exitStatus = noUpdateStatus
    } else {
      exitStatus = error == nil ? 0 : 1
    }
  }

  private var displayVersion: String {
    bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
  }

  private func showInstallationMessage() {
    guard !installationMessageShown else { return }
    installationMessageShown = true
    output("Installing update and relaunching Rootie…")
  }
}

enum CLIUpdateError: LocalizedError {
  case appBundleNotFound

  var errorDescription: String? {
    "Could not locate Rootie.app from this executable. Install Rootie before running rootie update."
  }
}
