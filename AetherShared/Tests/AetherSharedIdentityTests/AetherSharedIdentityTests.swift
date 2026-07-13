import Testing
@testable import AetherSharedIdentity

@Test func identityVersionExists() {
    #expect(!AetherSharedIdentity.version.isEmpty)
}
