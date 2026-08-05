import Testing
@testable import AetherSharedCore

@Test func coreVersionExists() {
    #expect(!AetherSharedCore.version.isEmpty)
}
