@testable import AetherSharedIdentity
import Testing

@Test func identityVersionExists() {
    #expect(!AetherSharedIdentity.version.isEmpty)
}
