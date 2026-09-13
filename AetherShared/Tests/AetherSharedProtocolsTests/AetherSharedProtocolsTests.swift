@testable import AetherSharedProtocols
import Testing

@Test func protocolsVersionExists() {
    #expect(!AetherSharedProtocols.version.isEmpty)
}
