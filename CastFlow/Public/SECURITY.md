# SECURITY.md

# CastFlow Security Policy

Version: 1.0

---

# Security Philosophy

Security is a core architectural principle of CastFlow.

It is not treated as a feature that is added after implementation.

Every subsystem must assume that all external input is potentially malicious.

Security is implemented using multiple independent layers rather than relying on a single defensive mechanism.

---

# Security Goals

The project prioritizes:

- Confidentiality
- Integrity
- Availability
- Authentication
- Authorization
- Auditability
- Maintainability

---

# Threat Model

CastFlow assumes the following attack surfaces:

## Network

- Malformed RTSP packets
- Invalid RTP payloads
- Replay attacks
- Packet flooding
- Session hijacking
- Service discovery abuse

---

## Media

- Corrupted video streams
- Invalid codecs
- Oversized payloads
- Decoder crashes
- Memory exhaustion

---

## Plugins

- Malicious plugins
- Unsigned plugins
- Dependency injection attacks
- Unauthorized API access

---

## Enterprise

- Unauthorized administration
- Configuration tampering
- Audit log manipulation

---

# Security Principles

## Zero Trust

Never trust:

- Clients
- Network packets
- Headers
- Payload lengths
- Codec identifiers
- Metadata

Every input must be validated.

---

## Least Privilege

Every component receives only the permissions it requires.

Plugins receive only the APIs explicitly granted.

---

## Defense in Depth

Security layers include:

```
Discovery

↓

Authentication

↓

Session Validation

↓

Encryption

↓

Packet Validation

↓

Media Validation

↓

Rendering

↓

Audit Logging
```

---

## Fail Secure

Failures should result in:

- Connection termination
- Resource cleanup
- Error logging
- No undefined behavior

---

# Authentication

Supported mechanisms may include:

- FP-SRP pairing (where applicable)
- Enterprise authentication providers
- Future identity providers through plugins

Authentication modules must remain isolated from media processing.

---

# Session Security

Each session must maintain:

- Unique Session ID
- Cryptographic nonce
- Session timestamp
- Activity timeout
- Replay detection state

Sessions are isolated from one another.

---

# Encryption

Where transport encryption is used:

- Generate unique session keys
- Avoid key reuse
- Protect key material in memory
- Zeroize sensitive buffers when practical

The specific encryption mechanism depends on the negotiated transport protocol.

---

# Packet Validation

Every packet must validate:

- Length
- Header format
- Sequence number
- Timestamp (if applicable)
- Payload size
- Codec compatibility

Malformed packets must be rejected without crashing the application.

---

# Replay Protection

Replay protection should include:

- Nonce validation
- Sequence validation
- Timestamp checks
- Duplicate packet detection

---

# Rate Limiting

Protect against resource exhaustion by limiting:

- New connection attempts
- Authentication failures
- Packet processing rate
- Discovery requests
- Plugin API requests

---

# Logging

Security logs should record:

- Failed authentication
- Invalid packets
- Session creation
- Session termination
- Plugin loading
- Security policy violations

Sensitive data must never be written to logs.

---

# Secrets

Never store:

- Passwords
- Private keys
- Session keys
- Tokens

in source control or plaintext configuration files.

Use platform-provided secure storage where appropriate.

---

# Plugin Security

Plugins must:

- Declare capabilities
- Be version compatible
- Register through the Plugin Manager
- Use documented APIs only

Plugins must not directly modify internal application state.

---

# Dependency Management

Dependencies should:

- Be actively maintained
- Have compatible licenses
- Be reviewed before adoption
- Receive regular updates

Prefer Apple frameworks whenever possible.

---

# Memory Safety

The project benefits from Swift's memory safety features.

Avoid:

- UnsafeMutablePointer
- UnsafeRawPointer
- Manual memory management

unless required for interoperability with system frameworks.

---

# Concurrency Safety

Use:

- actors
- Sendable
- async/await

Avoid:

- Shared mutable state
- Race conditions
- Unsynchronized global variables

---

# Responsible Disclosure

If you discover a security issue:

1. Do not create a public issue.
2. Report privately to the maintainers.
3. Provide reproduction steps.
4. Allow reasonable time for remediation before public disclosure.

---

# Supported Versions

Security fixes are provided for supported release branches as documented in the project roadmap.

---

# Security Roadmap

Future work may include:

- Plugin sandboxing
- Signed plugin verification
- Certificate pinning (where appropriate)
- Hardware-backed key storage
- Enhanced audit reporting
- Enterprise policy enforcement
- Automated security scanning

---

# Security Commitment

CastFlow is committed to continuous security improvement through code review, automated testing, dependency management, and community collaboration.

Security is considered an ongoing engineering practice rather than a one-time milestone.
