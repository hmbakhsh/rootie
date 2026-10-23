import Foundation
import Testing

@testable import Rootie

struct MigrationsTests {
  private let legacyJSON = #"""
    {
      "browser": {"name": "Helium", "applicationPath": "/Applications/Helium.app",
        "userDataPath": "~/Library/Application Support/net.imput.helium"},
      "defaultProfile": "Personal",
      "rules": [
        {"name": "Dotted", "profile": "Work", "enabled": true,
          "match": {"host": ".Example.com.", "includeSubdomains": false}},
        {"name": "Wildcard", "profile": "Work", "enabled": true,
          "match": {"host": "*.linear.app", "includeSubdomains": false}},
        {"name": "Clean", "profile": "Work", "enabled": false,
          "match": {"host": "github.com", "includeSubdomains": false, "pathPrefix": "/org"}}
      ]
    }
    """#

  @Test("Rewrites hosts that v0.3 accepted so v0.4+ validation passes")
  func normalizesLegacyHosts() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("config.json")
    try Data(legacyJSON.utf8).write(to: url)

    let store = ConfigStore(configURL: url)
    #expect(store.load())
    let rules = try #require(store.config?.rules)
    #expect(rules.map(\.match.host) == ["example.com", "linear.app", "github.com"])
    #expect(rules.map(\.match.includeSubdomains) == [false, true, false])
    #expect(rules[2].match.pathPrefix == "/org")
    #expect(rules[2].enabled == false)
    #expect(try recordedVersion(in: directory) == "0.5.0")
    let backup = directory.appendingPathComponent("config.json.before-0.5.0")
    #expect(try String(contentsOf: backup, encoding: .utf8) == legacyJSON)
  }

  @Test("Runs each migration once, oldest first, and records progress")
  func runsPendingMigrationsInOrder() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("config.json")
    try Data("{}".utf8).write(to: url)
    try Data("0.6.0\n".utf8).write(to: directory.appendingPathComponent("migrated-version"))

    final class Recorder: @unchecked Sendable { var ran: [String] = [] }
    let recorder = Recorder()
    let migrations: [ConfigMigrations.Migration] = ["0.10.0", "0.5.0", "0.7.0"].sorted {
      ConfigMigrations.isVersion($1, newerThan: $0)
    }.map { version in (version, { _ in recorder.ran.append(version) }) }

    try ConfigMigrations.run(configURL: url, migrations: migrations)
    try ConfigMigrations.run(configURL: url, migrations: migrations)

    #expect(recorder.ran == ["0.7.0", "0.10.0"])
    #expect(try recordedVersion(in: directory) == "0.10.0")
  }

  @Test("A failed migration keeps the recorded version so the next load retries")
  func failedMigrationRetries() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("config.json")
    try Data("not json".utf8).write(to: url)
    let store = ConfigStore(configURL: url)

    #expect(!store.load())
    #expect(
      !FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("migrated-version").path))

    try Data(legacyJSON.utf8).write(to: url)
    #expect(store.load())
    #expect(try recordedVersion(in: directory) == "0.5.0")
  }

  @Test("Leaves clean configs and fresh installs untouched")
  func leavesCleanConfigsAlone() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("config.json")
    let store = ConfigStore(configURL: url)

    #expect(!store.load())
    #expect(try recordedVersion(in: directory) == "0.5.0")

    try store.save(TestFixtures.workConfig)
    let saved = try Data(contentsOf: url)
    try FileManager.default.removeItem(at: directory.appendingPathComponent("migrated-version"))
    #expect(store.load())
    #expect(try Data(contentsOf: url) == saved)
    #expect(
      !FileManager.default.fileExists(
        atPath: directory.appendingPathComponent("config.json.before-0.5.0").path))
  }

  @Test("Finds only Browser Router bundles to move to the Trash")
  @MainActor
  func findsOldApps() throws {
    let directory = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let other = directory.appendingPathComponent("other", isDirectory: true)
    for (parent, identifier) in [
      (directory, LegacyInstall.bundleIdentifier), (other, "com.example.unrelated"),
    ] {
      let contents = parent.appendingPathComponent("Browser Router.app/Contents")
      try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
      let plist = try PropertyListSerialization.data(
        fromPropertyList: ["CFBundleIdentifier": identifier], format: .xml, options: 0)
      try plist.write(to: contents.appendingPathComponent("Info.plist"))
    }

    let found = LegacyInstall.oldApps(in: [
      directory, other, directory.appendingPathComponent("missing"),
    ])
    #expect(found.map(\.path) == [directory.appendingPathComponent("Browser Router.app").path])
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func recordedVersion(in directory: URL) throws -> String {
    try String(contentsOf: directory.appendingPathComponent("migrated-version"), encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
