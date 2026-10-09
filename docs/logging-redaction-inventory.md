# Logging and Redaction Inventory

## Never log
- Private keys, seed phrases, Secure Enclave references, or derived secrets.
- Authorization codes, pre-authorized codes, access tokens, refresh tokens, or bearer tokens.
- Holder proofs, JWT payloads, signed VCs, VPs, DID documents containing sensitive services, or complete request bodies.
- Unredacted email addresses, recipient addresses, account addresses, IP addresses, or transaction payloads.
- Message content submitted to wallet signing APIs.

## Permitted production metadata
- Component name and operation category.
- Chain family and non-sensitive environment/network name.
- Outcome, stable error category, and sanitized HTTP status.
- Request correlation ID, provided it is generated server-side.
- Redacted or salted identifiers only when operationally necessary.

## Findings to resolve
- [ ] AGWallet signing logs do not emit raw message text.
- [ ] Wallet send logs do not emit full recipient addresses or amounts by default.
- [ ] Transaction identifiers are treated as sensitive operational metadata and are redacted or debug-gated.
- [ ] Vapor route logs omit authorization, proof, VC, and token data.
- [ ] Errors are sanitized before being returned or logged.
- [ ] Unit tests assert that redaction is applied.
