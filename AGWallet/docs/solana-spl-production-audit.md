# Solana SPL Production Audit

## Preconditions
- [ ] Mint public key is parsed before RPC calls.
- [ ] Recipient public key is parsed before RPC calls.
- [ ] Sender and recipient associated token accounts are derived locally.
- [ ] Missing sender ATA maps to a safe insufficient-funds result.

## Amount and balance
- [ ] Amount is finite, positive, precisely representable, and within UInt64 range.
- [ ] Sender raw token balance is parsed safely.
- [ ] Exact balance is accepted and lower balance is rejected.

## Transaction construction
- [ ] Recipient ATA creation is idempotent.
- [ ] TransferChecked uses the expected mint and decimals.
- [ ] Recent blockhash is acquired after local validation.
- [ ] Broadcast uses base64 transaction encoding.

## Test evidence
- [ ] Invalid mint and recipient cause no RPC calls.
- [ ] Sender ATA and balance failures make no broadcast call.
- [ ] Existing and newly created recipient ATA cases pass.
- [ ] RPC/broadcast failure propagation is tested.
