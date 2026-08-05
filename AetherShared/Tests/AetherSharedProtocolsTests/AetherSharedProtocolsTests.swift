import Testing
@testable import AetherSharedProtocols

@Test func protocolsVersionExists() {
    #expect(!AetherSharedProtocols.version.isEmpty)
}
