import Foundation

final class ConfigStore {
  private(set) var config: RouterConfig?
  private(set) var error: Error?

  let configURL: URL
  private let legacyConfigURLs: [URL]

  convenience init(fileManager: FileManager = .default) {
    self.init(
      homeDirectory: fileManager.homeDirectoryForCurrentUser,
      applicationSupportDirectory: fileManager.urls(
        for: .applicationSupportDirectory, in: .userDomainMask)[0])
  }

  init(homeDirectory: URL, applicationSupportDirectory: URL) {
    configURL =
      homeDirectory
      .appendingPathComponent(".rootie", isDirectory: true)
      .appendingPathComponent("config.json")
    legacyConfigURLs = [
      homeDirectory
        .appendingPathComponent(".browser-router", isDirectory: true)
        .appendingPathComponent("config.json"),
      applicationSupportDirectory
        .appendingPathComponent("browser-router", isDirectory: true)
        .appendingPathComponent("config.json"),
      applicationSupportDirectory
        .appendingPathComponent("dev.36labs.browser-router", isDirectory: true)
        .appendingPathComponent("config.json"),
    ]
  }

  init(configURL: URL) {
    self.configURL = configURL
    legacyConfigURLs = []
  }

  @discardableResult
  func load() -> Bool {
    do {
      try migrateLegacyConfigIfNeeded()
      try ConfigMigrations.run(configURL: configURL)
      guard FileManager.default.fileExists(atPath: configURL.path) else {
        throw ConfigError.missing
      }
      let data = try Data(contentsOf: configURL)
      let decoded = try JSONDecoder().decode(RouterConfig.self, from: data)
      try decoded.validate()
      config = decoded
      error = nil
      return true
    } catch {
      config = nil
      self.error = error
      return false
    }
  }

  func save(_ config: RouterConfig) throws {
    try config.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(config)
    try FileManager.default.createDirectory(
      at: configURL.deletingLastPathComponent(),
      withIntermediateDirectories: true)
    try data.write(to: configURL, options: .atomic)
    self.config = config
    error = nil
  }

  private func migrateLegacyConfigIfNeeded() throws {
    guard !FileManager.default.fileExists(atPath: configURL.path) else { return }

    if let legacyConfigURL = legacyConfigURLs.first(where: {
      FileManager.default.fileExists(atPath: $0.path)
    }) {
      try FileManager.default.createDirectory(
        at: configURL.deletingLastPathComponent(),
        withIntermediateDirectories: true)
      try FileManager.default.moveItem(at: legacyConfigURL, to: configURL)
      let legacyDirectory = legacyConfigURL.deletingLastPathComponent()
      if (try? FileManager.default.contentsOfDirectory(atPath: legacyDirectory.path))?.isEmpty
        == true
      {
        try? FileManager.default.removeItem(at: legacyDirectory)
      }
    }
  }
}
