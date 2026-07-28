# API Design Guide

# CastFlow API Design Guide

**Version:** 1.0

**Status:** Draft

---

# Introduction

The CastFlow API is designed around modern Swift engineering principles.

Primary goals:

- Stable interfaces
- Strong typing
- Clear ownership
- Protocol-oriented architecture
- Async-first APIs
- Actor isolation
- Backward compatibility

The API should remain intuitive while supporting future protocol adapters, plugins, and enterprise features.

---

# Design Principles

Every public API should be:

- Predictable
- Discoverable
- Testable
- Thread-safe
- Well documented
- Extensible

---

# API Philosophy

Prefer explicit APIs over clever abstractions.

Good:

```swift
session.start()
```

Avoid:

```swift
manager.execute(.begin)
```

Use descriptive names whenever possible.

---

# Public API Surface

The SDK should expose only the minimum necessary public interfaces.

```
Public
│
├── Models
├── Protocols
├── Services
├── Plugin APIs
└── Utilities

Internal

├── Networking
├── Security
├── Media Pipeline
├── Rendering
└── Session Internals
```

Internal implementation details should never leak into public APIs.

---

# Naming Conventions

Types

```swift
SessionCoordinator
```

Protocols

```swift
SessionManaging
```

Actors

```swift
NetworkActor
```

Enums

```swift
ConnectionState
```

Errors

```swift
SessionError
```

Configuration

```swift
RendererConfiguration
```

---

# Swift API Design

Follow Apple's Swift API Design Guidelines.

Prefer:

```swift
startSession()
```

Instead of

```swift
doStartSession()
```

Prefer:

```swift
func connect(to device: Device)
```

Instead of

```swift
func connect(_ d: Device)
```

---

# Async APIs

Long-running operations should be asynchronous.

Example:

```swift
public protocol SessionManaging {

    func connect() async throws

    func disconnect() async

}
```

Avoid completion handlers unless interoperability requires them.

---

# Actor Isolation

Services that own mutable state should be actors.

Example:

```swift
public actor SessionCoordinator {

    public func start() async throws

}
```

Avoid exposing mutable shared state.

---

# Errors

Define typed errors.

Example:

```swift
enum SessionError: Error {

    case authenticationFailed

    case invalidPacket

    case timeout

    case unsupportedCodec

}
```

Avoid generic NSError values.

---

# Result Types

Use throws for failures.

Prefer:

```swift
try await session.start()
```

instead of

```swift
Result<Success, Error>
```

unless asynchronous composition specifically benefits from Result.

---

# Configuration Objects

Avoid large parameter lists.

Instead:

```swift
RendererConfiguration
```

rather than

```swift
Renderer(width:height:fps:...)
```

Configuration should be immutable after initialization where practical.

---

# Protocol-Oriented APIs

Depend on abstractions.

Example:

```swift
protocol VideoDecoder
```

instead of

```swift
VideoToolboxDecoder
```

Concrete implementations remain replaceable.

---

# Dependency Injection

Inject dependencies.

Example:

```swift
SessionCoordinator(
    network: NetworkManaging,
    renderer: Rendering,
    logger: Logging
)
```

Avoid service locators.

---

# Events

Expose events using AsyncSequence when appropriate.

Example:

```swift
for await event in session.events {

}
```

Benefits:

- Structured concurrency
- Cancellation support
- Low overhead

---

# Versioning

Public APIs follow Semantic Versioning.

Breaking changes require:

Major version increment

Examples:

```
1.x

↓

2.0
```

---

# Deprecation

Deprecated APIs should include:

```swift
@available(*, deprecated)
```

along with migration guidance.

---

# Documentation

Every public symbol requires documentation.

Include:

- Description
- Parameters
- Return value
- Throws
- Example

Example:

```swift
/// Starts a new streaming session.
///
/// - Throws:
///   SessionError.authenticationFailed
```

---

# Thread Safety

Document concurrency guarantees.

Example:

```
Actor Isolated

Thread Safe

MainActor
```

should be clearly identified.

---

# API Evolution

Future additions should:

- Extend protocols
- Introduce new types
- Preserve existing behavior

Avoid unnecessary breaking changes.

---

# Plugin APIs

Plugins interact exclusively with stable SDK interfaces.

Plugins must never access:

- Internal networking
- Internal rendering
- Session implementation details
- Private state

---

# Security

Public APIs must never expose:

- Session keys
- Authentication secrets
- Internal credentials
- Raw private tokens

---

# Testing

Every public API should include:

- Unit tests
- Documentation examples
- Error handling tests
- Concurrency tests

---

# API Review Checklist

Before release verify:

- Naming consistency
- Thread safety
- Documentation
- Test coverage
- Binary compatibility
- Performance
- Security

---

# Conclusion

The CastFlow API is intended to remain small, stable, and intentionally designed. Public interfaces should evolve carefully, prioritizing clarity and long-term maintainability over short-term convenience.
