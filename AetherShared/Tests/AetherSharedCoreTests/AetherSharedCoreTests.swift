@testable import AetherSharedCore
import Testing

@Test func coreVersionExists() {
    #expect(!AetherSharedCore.version.isEmpty)
}
