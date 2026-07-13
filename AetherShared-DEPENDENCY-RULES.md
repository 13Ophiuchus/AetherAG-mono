# AetherShared Dependency Rules

- AetherSharedCore: no internal dependencies.
- AetherSharedIdentity: depends only on AetherSharedCore.
- AetherSharedProtocols: depends on AetherSharedCore + AetherSharedIdentity.
- AetherShared must NEVER depend on AGWallet, AetherAG, Vapor, Flow, or BigInt.
- AGWallet and AetherAG may depend on AetherShared targets, never the reverse.

## Dynamic-key array decoding (DynamicCodingKeys / DynamicKeyedArray)

- `DynamicCodingKeys` and `DynamicKeyedArray<Element>` / `KeyedArrayGroup<Element>` live in
  `AetherSharedCore` (`DynamicCodingKeys.swift`, `DynamicKeyedArrayDecoding.swift`).
- Foundation-only. No Vapor/Flow/BigInt imports are permitted in these files.
- Use `DynamicKeyedArray<Element>` when a JSON object's keys are dynamic (unknown at compile
  time) and each value is an array — e.g. claims grouped by issuer-defined field name, or
  credential subject data keyed by arbitrary attribute names.
- Use the `decodeDynamicKeyedArray(ofElement:forKey:)` container helpers when the dynamic-key
  object is nested inside a known key, rather than at the JSON root.
- Identity DTOs (`AetherSharedIdentity/Credentials/*`) that need dynamic/claims-style decoding
  must import `AetherSharedCore` and reuse these helpers — do not redeclare a local
  `DynamicCodingKeys` or hand-roll an equivalent in `AetherSharedIdentity` or any consumer
  package (`AetherAGMailShared`, `AetherAGMailClientCore`, `AetherAGMailServer`).
- `AetherSharedProtocols` and any future shared modules follow the same rule: dynamic-key
  decoding is a Core-layer concern, never duplicated downstream.
