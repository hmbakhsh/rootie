import Foundation
import Testing

struct UpdateBundleConfigurationTests {
  @Test("Bundle config uses the signed, self-applying Sparkle feed")
  func sparkleConfiguration() throws {
    let plistURL = repositoryRoot.appendingPathComponent("Resources/Info.plist")
    let data = try Data(contentsOf: plistURL)
    let plist = try #require(
      PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

    #expect(
      plist["SUFeedURL"] as? String
        == "https://github.com/hmbakhsh/rootie/releases/latest/download/appcast.xml")
    #expect(plist["SUPublicEDKey"] as? String == "7e38BHArNTB69QPfvFxx4CqbDDSgiv+nPi6lgZIEJrQ=")
    #expect(plist["SUEnableAutomaticChecks"] as? Bool == true)
    #expect(plist["SUScheduledCheckInterval"] as? Int == 6 * 3600)
    #expect(plist["SUAutomaticallyUpdate"] as? Bool == true)
    #expect(plist["SUAllowsAutomaticUpdates"] as? Bool == true)
    #expect(plist["SUEnableInstallerLauncherService"] == nil)
    #expect(plist["SUVerifyUpdateBeforeExtraction"] as? Bool == true)
    #expect(plist["SURequireSignedFeed"] as? Bool == true)
    #expect(plist["SUSignedFeedFailureExpirationInterval"] as? Int == 0)
  }

  private var repositoryRoot: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
  }
}
