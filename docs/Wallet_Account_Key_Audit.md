# AetherAG-mono Wallet/Account/Key Architecture Audit

## Verified safe
- Public/KeyManagementBackups/KeyMan.backup: plaintext source backup, untracked,
  gitignored. No secret material. No action needed.

## Real key architecture (KeyManagerActor)
- Single master key model: generateMnemonic() -> generateMasterPrivateKey() ->
  storePrivateKey(_, for: "masterKey", requiresBiometrics:)
- Storage: KeychainKeyStorageProvider (Secure Enclave when biometrics available,
  else Keychain with userPresence access control)
- Per-chain address derivation exists for Solana (Ed25519) and Bitcoin
  (P2PKH/P2WPKH/P2TR via BIP32/84/86), both derived FROM the master key.
- Flow is the exception: storeFlowAddress(_:) / flowAddress() only persist and
  read a plain string. No derivation, no on-chain creation call exists.

## CONFIRMED GAP: No Flow account creation logic anywhere
Searched: AGWallet/Sources, AetherWalletKit/Data/FlowModule,
AetherWalletKit/Data/KeyManagementModule — zero matches for:
  - `Account(payer:` (Cadence Account-creation transaction)
  - Any function named createAccount/provisionWallet/createFlowAccount
FlowModule.swift explicitly comments that storeFlowAddress must be called
"once the corresponding Flow account has been created or discovered" —
implying this is either done manually, by a separate unbuilt service, or
not done at all yet.

## Architecture mismatch (informational)
The "Login ViewModels refactor" document (SeedPhraseLoginViewModel /
PrivateKeyLoginViewModel / KeyStoreLoginViewModel / FlowWalletKit.PrivateKey /
SeedPhraseKey / HDWallet) does NOT match this codebase's single-master-key
model and should not be implemented as drafted. If multi-key-type import is
a real product requirement, it needs new KeyManagerActor methods, not a
port of FRW-iOS's ViewModel layer.

## Remediation options for the Flow account-creation gap
1. Add a `createFlowAccount(payerConfig:)` function to FlowModule.swift that:
   - Derives a P256 public key from the master key (mirrors signFlowMessage's
     P256.Signing.PrivateKey usage)
   - Submits an `Account(payer:)` Cadence transaction signed by a funding
     issuer account (reuse FlowAccountService/FlowIssuerConfig from the
     server side)
   - Calls storeFlowAddress(_:) with the resulting address on success
2. Decide whether Flow address derivation should be legacy (raw master key)
   or hkdfV1 (chain-scoped), consistent with KeyDerivationVersion already
   used for Solana/Bitcoin.

## UPDATE (2026-09-29): Gap closed

The "No Flow account creation logic anywhere" gap noted above has been
resolved as of commit 9e44585. `FlowModule.swift` now implements
`createFlowAccount(issuerConfig:flowGateway:network:keyIdentifier:)`,
backed by:
- `FlowIssuerConfig` (Keychain-referenced issuer signing key, not plaintext)
- `FlowGatewayProtocol` / `LiveFlowGateway` (transaction submission + polling)
- `Cadence/create_user_account.cdc` (on-chain account creation script)
- Exponential-backoff transaction seal polling (90s deadline)
- Testnet-gated integration test scaffold in `FlowAccountCreationTests.swift`

Remaining open item: `LiveFlowGateway.sendTransaction` still contains a
`fatalError()` placeholder pending implementation against the installed
Flow SDK's actual transaction-builder API — account creation will compile
but crash at runtime until that's filled in.
