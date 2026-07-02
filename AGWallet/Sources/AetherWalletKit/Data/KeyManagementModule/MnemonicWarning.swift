import Foundation

extension Mnemonic {
    static let _productionWarning: Void = {
        #if !DEBUG
        fatalError("Mnemonic.generate() is a stub. Replace with real BIP39 before shipping.")
        #endif
    }()
}
