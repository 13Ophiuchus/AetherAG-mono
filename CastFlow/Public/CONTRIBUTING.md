# CONTRIBUTING.md

# Contributing to CastFlow

First and foremost, thank you for your interest in contributing to CastFlow.

Our goal is to build a world-class wireless display platform using modern Swift engineering practices, transparent collaboration, and a welcoming open-source community.

---

# Our Philosophy

CastFlow is built around a few simple principles:

- Security first
- Simplicity over cleverness
- Protocol-oriented architecture
- Testability
- Documentation
- Long-term maintainability

Every contribution should improve one or more of these principles.

---

# Code of Conduct

By participating in this project you agree to follow the project's Code of Conduct.

Please read:

```
CODE_OF_CONDUCT.md
```

before participating.

---

# Ways to Contribute

We welcome contributions in many forms.

## Code

- Features
- Bug fixes
- Performance improvements
- Tests
- Refactoring

---

## Documentation

- README improvements
- Architecture
- Tutorials
- API documentation
- Examples

---

## Testing

- Unit tests
- Integration tests
- Concurrency testing
- Performance testing
- Security testing

---

## Design

- Architecture reviews
- Sequence diagrams
- Mermaid diagrams
- UI mockups

---

# Before Opening an Issue

Please check:

- Existing issues
- Existing pull requests
- Roadmap
- Documentation

Duplicate issues make maintenance harder.

---

# Before Writing Code

Please:

1. Discuss major architectural changes first.
2. Keep pull requests focused.
3. Avoid unrelated formatting changes.
4. Include tests.
5. Update documentation.

---

# Development Requirements

Required:

- macOS 15+
- Xcode 16+
- Swift 6
- Swift Package Manager

---

# Build

```bash
swift build
```

---

# Test

```bash
swift test
```

---

# Formatting

Use:

- SwiftFormat
- SwiftLint

All pull requests must pass formatting checks.

---

# Branch Naming

Examples:

```
feature/plugin-sdk

feature/google-cast

feature/security

bugfix/session-cleanup

bugfix/audio-sync

docs/readme

docs/architecture

refactor/media-pipeline
```

---

# Commit Messages

Use Conventional Commits.

Examples:

```
feat(network): implement RTSP parser

feat(media): add Metal renderer

fix(session): resolve actor isolation issue

docs(readme): improve installation guide

refactor(plugin): simplify registration

test(network): add RTP validation tests
```

---

# Pull Request Requirements

Every PR should include:

- Description
- Motivation
- Testing performed
- Documentation updates
- Screenshots (if UI changes)

---

# Coding Standards

## Swift

Use:

- Swift 6
- async/await
- actors
- Sendable
- Dependency Injection

Avoid:

- Force unwraps
- Global mutable state
- Singleton patterns
- Massive classes

---

## Architecture

Follow:

- Feature-first organization
- Protocol-oriented programming
- One primary type per file
- Dependency inversion

---

## Documentation

Every public:

- type
- protocol
- actor
- function
- property

must include documentation comments.

---

# Testing Standards

New functionality requires:

- Unit tests
- Integration tests (where appropriate)
- Concurrency validation
- Edge case coverage

Target coverage:

**90%+**

---

# Security Contributions

Security improvements are always welcome.

Examples:

- Validation
- Authentication
- Replay protection
- Threat detection
- Logging
- Secure defaults

Please report vulnerabilities privately before opening a public issue.

---

# Plugin Contributions

Plugins should:

- Implement documented protocols
- Avoid internal APIs
- Be independently testable
- Be independently versioned where possible

---

# Documentation Contributions

Excellent documentation is considered a feature.

We especially welcome improvements to:

- Tutorials
- Architecture
- Diagrams
- API Reference
- Developer Guide
- Plugin SDK

---

# Review Process

Maintainers will review for:

- Architecture
- Correctness
- Tests
- Documentation
- Performance
- Security
- Maintainability

---

# What We Avoid

Please avoid:

- Large unrelated pull requests
- Unnecessary dependencies
- Experimental code without discussion
- Breaking public APIs without proposal

---

# Recognition

All meaningful contributions are appreciated.

Contributors may be recognized in release notes and project documentation.

---

# Thank You

Open source succeeds because of its community.

Thank you for helping make CastFlow a secure, maintainable, and extensible platform for the future of wireless display technology.
