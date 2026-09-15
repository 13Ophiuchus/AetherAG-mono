# Security Policy

## Supported Versions

| Component | Supported |
|---|---|
| AGWallet (wallet SDK) | ✅ |
| AetherAG mail/identity client | ✅ |
| AetherAGMailServer (Vapor backend) | ✅ |
| flow-swift-macos | ✅ |
| solana-swift-patched | ✅ |
| web3swift-concurrency | ✅ |

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report privately:
- **GitHub private vulnerability report**: use the "Report a vulnerability" button on the
  Security tab of this repository (preferred).
- **Email**: security@aether.ag

Please include:
1. Component and version affected.
2. Reproduction steps and proof-of-concept if available.
3. Assessed impact (key exposure, auth bypass, data leak, etc.).

## Response SLA

| Stage | Target |
|---|---|
| Initial acknowledgement | 2 business days |
| Triage and severity assessment | 5 business days |
| Patch / mitigation — critical or high | 14 calendar days |
| Patch / mitigation — medium or low | 30 calendar days |

## Disclosure Policy

Coordinated disclosure with a **90-day embargo** from initial report date.
Researchers are credited in release notes unless anonymity is requested.

## Scope

**In scope:**
- Private-key handling, Secure Enclave key derivation, and signing paths (AGWallet)
- OID4VCI token issuance, verifiable credential flows, DID/VP verification
  (AetherAGMailServer)
- JWT/JWKS handling, authentication, and authorisation in the Vapor backend
- Cryptographic signing paths — Bitcoin, EVM, Solana, Flow

**Out of scope:**
- Theoretical attacks with no practical exploitability
- Issues in upstream dependencies not introduced or patched by this project
- Social engineering or phishing
