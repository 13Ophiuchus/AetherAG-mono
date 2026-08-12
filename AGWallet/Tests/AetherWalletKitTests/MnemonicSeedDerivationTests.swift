import Testing
import Foundation
@testable import AetherWalletKit

@Suite("Mnemonic BIP-39 seed derivation")
struct MnemonicSeedDerivationTests {

    @Test("Known BIP-39 test vector produces expected seed")
    func testKnownVectorSeed() throws {
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        let mnemonic = Mnemonic(words: words)
        let seed = mnemonic.seed(passphrase: "")

        let expectedSeedHex = "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4"
        let actualSeedHex = seed.map { String(format: "%02x", $0) }.joined()
        #expect(seed.count == 64)
        #expect(actualSeedHex == expectedSeedHex)
    }

    @Test("Seed derivation produces 64-byte output regardless of iteration guard")
    func testSeedLength() throws {
        let words = Array(repeating: "abandon", count: 11) + ["about"]
        let mnemonic = Mnemonic(words: words)
        let seed = mnemonic.seed(passphrase: "TREZOR")

        #expect(seed.count == 64)
    }
}
