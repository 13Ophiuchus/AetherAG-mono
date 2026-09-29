transaction(publicKey: String, signatureAlgorithm: UInt8, hashAlgorithm: UInt8, weight: UFix64) {
    prepare(payer: auth(BorrowValue) &Account) {
        let key = PublicKey(
            publicKey: publicKey.decodeHex(),
            signatureAlgorithm: SignatureAlgorithm(rawValue: signatureAlgorithm)!
        )
        let account = Account(payer: payer)
        account.keys.add(
            publicKey: key,
            hashAlgorithm: HashAlgorithm(rawValue: hashAlgorithm)!,
            weight: weight
        )
    }
}
