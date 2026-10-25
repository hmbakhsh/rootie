import AppKit

/// One-way changes to `config.json`, applied oldest first on every load. The last
/// applied version is stored in `migrated-version` next to the config, so a user
/// who skips releases still gets every migration. A failed migration leaves the
/// recorded version unchanged and is retried on the next load.
enum ConfigMigrations {
  typealias Migration = (version: String, migrate: (URL) throws -> Void)

  static let all: [Migration] = [
    // v0.4.0 tightened host validation. Hosts that v0.2–v0.3 accepted
    // (".example.com", "Example.com.", "*.example.com") now invalidate the
    // whole config, so rewrite them the way those versions matched them.
    ("0.5.0", normalizeRuleHosts)
  ]

  static func run(configURL: URL, migrations: [Migration] = all) throws {
    let directory = configURL.deletingLastPathComponent()
    let recordURL = directory.appendingPathComponent("migrated-version")
    let recorded =
      (try? String(contentsOf: recordURL, encoding: .utf8))?
      .trimmingCharacters(in: .whitespacesAndNewlines) ?? "0"

    for migration in migrations where isVersion(migration.version, newerThan: recorded) {
      if FileManager.default.fileExists(atPath: configURL.path) {
        try migration.migrate(configURL)
      }
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try Data("\(migration.version)\n".utf8).write(to: recordURL, options: .atomic)
    }
  }

  static func isVersion(_ version: String, newerThan other: String) -> Bool {
    version.compare(other, options: .numeric) == .orderedDescending
  }

  static func normalizeRuleHosts(configURL: URL) throws {
    let data = try Data(contentsOf: configURL)
    guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      var rules = root["rules"] as? [[String: Any]]
    else { return }

    var changed = false
    for index in rules.indices {
      guard let original = rules[index]["match"] as? [String: Any],
        let host = original["host"] as? String
      else { continue }
      var match = original
      var normalized = URLMatch.normalizeHost(host)
      if normalized.hasPrefix("*.") {
        normalized.removeFirst(2)
        match["includeSubdomains"] = true
      }
      match["host"] = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "."))
      guard !NSDictionary(dictionary: match).isEqual(to: original) else { continue }
      rules[index]["match"] = match
      changed = true
    }
    guard changed else { return }

    try backUp(configURL, suffix: "before-0.5.0")
    root["rules"] = rules
    let output = try JSONSerialization.data(
      withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    try output.write(to: configURL, options: .atomic)
  }

  private static func backUp(_ url: URL, suffix: String) throws {
    let backupURL = url.deletingLastPathComponent()
      .appendingPathComponent("\(url.lastPathComponent).\(suffix)")
    guard !FileManager.default.fileExists(atPath: backupURL.path) else { return }
    try FileManager.default.copyItem(at: url, to: backupURL)
  }
}

/// Converge checks for installs that predate the Browser Router → Rootie rename.
@MainActor
enum LegacyInstall {
  static let bundleIdentifier = "io.github.hmbakhsh.browser-router"

  /// Old-name app bundles that are safe to move to the Trash.
  static func oldApps(in directories: [URL]) -> [URL] {
    directories
      .map { $0.appendingPathComponent("Browser Router.app") }
      .filter { Bundle(url: $0)?.bundleIdentifier == bundleIdentifier }
  }

  static func converge(
    defaultBrowserSetter: DefaultBrowserSetter,
    onError: @escaping (Error) -> Void
  ) {
    let handler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "http://example.com")!)
    if let handler, Bundle(url: handler)?.bundleIdentifier == bundleIdentifier {
      defaultBrowserSetter.makeDefault(appURL: Bundle.main.bundleURL) { error in
        if let error { Task { @MainActor in onError(error) } }
      }
    }

    let applicationDirectories = FileManager.default.urls(
      for: .applicationDirectory, in: [.userDomainMask, .localDomainMask])
    for app in oldApps(in: applicationDirectories) {
      try? FileManager.default.trashItem(at: app, resultingItemURL: nil)
    }
  }
}
