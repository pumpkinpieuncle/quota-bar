import Testing
@testable import QuotaBar

@Test func updateVersionComparison() {
    // Strictly newer versions win; equal or older ones do not.
    #expect(AppUpdater.isNewer("1.3.2", than: "1.3.1"))
    #expect(AppUpdater.isNewer("1.4", than: "1.3.9"))
    #expect(AppUpdater.isNewer("2.0", than: "1.9.9"))
    #expect(AppUpdater.isNewer("1.10.0", than: "1.9.1"))
    #expect(!AppUpdater.isNewer("1.3.1", than: "1.3.1"))
    #expect(!AppUpdater.isNewer("1.3.0", than: "1.3.1"))
    #expect(!AppUpdater.isNewer("1.2.9", than: "1.3.1"))
}

@Test func updateVersionComparisonToleratesTagsAndSuffixes() {
    // Tags arrive as "v1.3.2"; build metadata like "-beta.1" is ignored.
    #expect(AppUpdater.isNewer("v1.3.2", than: "1.3.1"))
    #expect(!AppUpdater.isNewer("v1.3.1", than: "1.3.1"))
    #expect(AppUpdater.isNewer("1.3.2-beta.1", than: "1.3.1"))
}
