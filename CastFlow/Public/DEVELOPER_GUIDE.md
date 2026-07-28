# Developer Guide

# CastFlow Developer Guide

Version: 1.0

---

# Introduction

Welcome to CastFlow.

This guide explains the project's architecture, development workflow, coding standards, testing strategy, and engineering practices. It is intended for contributors building or maintaining the core platform.

---

# Development Philosophy

Every change should improve at least one of the following:

- Security
- Reliability
- Performance
- Readability
- Maintainability
- Testability
- Documentation

Engineering quality takes precedence over implementation speed.

---

# Technology Stack

- Swift 6
- Swift Package Manager
- SwiftUI
- VideoToolbox
- Metal
- CoreAudio
- Network Framework
- OSLog

Optional:

- Flow Blockchain SDK

---

# Repository Structure

```
Sources/
    App/
    Core/
    Networking/
    Media/
    Rendering/
    Security/
    Plugins/
    Blockchain/
    UI/

Tests/

Documentation/

Scripts/

Examples/
```

---

# Architectural Principles

The application follows:

- Layered Architecture
- Protocol-Oriented Design
- Dependency Injection
- Feature Modules
- Actor Isolation

Dependencies should point inward toward abstractions.

---

# Concurrency

All asynchronous work should use:

- async/await
- actors
- Task Groups
- Sendable

Avoid:

- DispatchQueue for application logic
- Shared mutable state
- Unstructured concurrency

---

# Dependency Injection

Prefer constructor injection.

Avoid service locators and global singletons.

Example:

```swift
SessionCoordinator(
    network: networkService,
    renderer: renderer,
    logger: logger
)
```

---

# Coding Standards

Prefer:

- Small types
- Clear names
- Composition
- Immutability
- Explicit APIs

Avoid:

- Large classes
- Hidden side effects
- Force unwraps
- Deep inheritance

---

# Documentation

All public APIs must include DocC-compatible documentation comments.

Complex workflows should include Mermaid diagrams where appropriate.

---

# Testing Strategy

Required:

- Unit tests
- Integration tests
- Concurrency tests
- Performance benchmarks

Target coverage:

90%+

---

# Debugging

Useful tools include:

- Instruments
- Thread Sanitizer
- Address Sanitizer
- Memory Graph Debugger
- Metal Frame Capture

---

# Logging

Use structured logging through OSLog.

Log categories:

- App
- Network
- Media
- Rendering
- Plugin
- Blockchain
- Security

Never log secrets.

---

# Code Review Checklist

Reviewers should verify:

- Correctness
- Architecture
- Thread safety
- Test coverage
- Documentation
- Performance
- Security

---

# Release Process

1. Feature complete
2. Tests pass
3. Documentation updated
4. Changelog updated
5. Version bump
6. Git tag
7. GitHub Release

---

# Continuous Improvement

Architecture Decisions (ADRs) should document significant technical decisions.

Major design changes should be discussed before implementation.

---

# Conclusion

This guide serves as the engineering handbook for CastFlow contributors and evolves alongside the project.

