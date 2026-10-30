import Foundation
import Testing
@testable import ElisaKit

@Suite struct AppQuickActionTests {
    private let deployed: [String: Any] = [
        AppQuickAction.otaManifestURLInfoKey: "https://files.example.com/files/elisa-musica-manifest.plist"
    ]

    @Test func installLatestOpensTheItmsLinkForThePinnedManifest() {
        #expect(
            AppQuickAction.installLatest.url(infoDictionary: deployed)
                == URL(string: "itms-services://?action=download-manifest&url=https://files.example.com/files/elisa-musica-manifest.plist")
        )
    }

    @Test func deployedBuildOffersInstallLatest() {
        #expect(AppQuickAction.available(infoDictionary: deployed) == [.installLatest])
    }

    @Test func buildWithoutTheKeyOffersNothing() {
        let empty: [String: Any] = [AppQuickAction.otaManifestURLInfoKey: ""]
        // An unexpanded build setting is not a URL either.
        let unexpanded: [String: Any] = [AppQuickAction.otaManifestURLInfoKey: "$(ELISA_MUSICA_OTA_MANIFEST_URL)"]

        #expect(AppQuickAction.available(infoDictionary: nil).isEmpty)
        #expect(AppQuickAction.available(infoDictionary: empty).isEmpty)
        #expect(AppQuickAction.available(infoDictionary: unexpanded).isEmpty)
        #expect(AppQuickAction.installLatest.url(infoDictionary: empty) == nil)
    }

    @Test func shortcutTypesRoundTrip() {
        #expect(AppQuickAction(shortcutType: AppQuickAction.installLatest.rawValue) == .installLatest)
        #expect(AppQuickAction(shortcutType: "com.example.unknown") == nil)
    }
}
