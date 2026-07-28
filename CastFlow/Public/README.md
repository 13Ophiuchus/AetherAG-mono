# README.md

# CastFlow

> **A modern, secure, modular wireless display platform for macOS written in Swift 6.**

![Swift](https://img.shields.io/badge/Swift-6-orange.svg)
![Platform](https://img.shields.io/badge/macOS-15%2B-blue.svg)
![License](https://img.shields.io/badge/License-Apache%202.0-green.svg)
![Concurrency](https://img.shields.io/badge/Swift-Strict%20Concurrency-success.svg)
![Architecture](https://img.shields.io/badge/Architecture-Plugin%20First-purple.svg)

---

# Vision

CastFlow is a next-generation wireless display platform built entirely in Swift 6.

Rather than implementing a single casting technology, CastFlow provides a modular framework capable of supporting multiple wireless display protocols through a common media pipeline.

Current focus:

- AirPlay-compatible receiver
- Native macOS performance
- Swift 6 strict concurrency
- Metal rendering
- VideoToolbox decoding

Future protocol support includes:

- Google Cast
- Miracast Bridge
- WebRTC
- SRT
- RIST
- NDI
- Enterprise transports

---

# Why CastFlow?

Existing casting applications are often:

- Closed source
- Platform-specific
- Monolithic
- Difficult to extend
- Dependent on proprietary SDKs

CastFlow aims to become an open, extensible platform with a modern architecture emphasizing:

- Security
- Performance
- Maintainability
- Plugin extensibility
- Enterprise readiness

---

# Core Features

## Networking

- Bonjour Discovery
- RTSP Session Management
- RTP Streaming
- Session Negotiation
- Connection Validation
- Metrics
- Logging

---

## Media

- VideoToolbox Hardware Decoding
- Metal Rendering
- CoreAudio Playback
- Low-Latency Pipeline
- Frame Synchronization
- Zero-Copy Rendering (where possible)

---

## Security

- FP-SRP Authentication
- AES Session Encryption
- Replay Protection
- Nonce Validation
- Secure Session Management
- Packet Validation
- Rate Limiting
- Threat Detection

---

## Swift 6

Built around modern Swift language features.

- Actors
- Sendable
- async/await
- AsyncSequence
- Strict Concurrency
- Dependency Injection
- Protocol-Oriented Design

---

## Plugin Platform

Everything optional is implemented as a plugin.

Examples:

- AirPlay
- Google Cast
- Recording
- OBS
- Zoom
- Discord
- AI Upscaling
- Enterprise
- Analytics
- Blockchain

---

# Architecture

```
                     CastFlow
                         │
        ┌────────────────┴───────────────┐
        │                                │
     SwiftUI                        Core Services
        │                                │
        ├──────────────┬─────────────────┤
        │              │
   Networking      Media Pipeline
        │              │
        │              │
   Security       VideoToolbox
        │              │
        │              │
     Plugins        Metal
        │
        ├──────────────┐
        │              │
 Blockchain      Enterprise
```

---

# Repository Structure

```
CastFlow/

App/

Core/

Networking/

Security/

Media/

Discovery/

Protocols/

Plugins/

Blockchain/

Enterprise/

Shared/

Configuration/

Utilities/

UI/

Resources/

Documentation/

Tests/

Scripts/
```

---

# Project Goals

Priority order:

1. Security
2. Stability
3. Reliability
4. Performance
5. Maintainability
6. Extensibility
7. Testability
8. Documentation

---

# Technology Stack

## Language

Swift 6

## Package Manager

Swift Package Manager

## UI

SwiftUI

## Rendering

Metal

## Video

VideoToolbox

## Audio

CoreAudio

## Networking

SwiftNIO

Network Framework

Bonjour

RTSP

RTP

## Cryptography

swift-crypto

AES

FP-SRP

## Logging

swift-log

## Metrics

swift-metrics

---

# Design Principles

- Feature-first architecture
- Protocol-first design
- Dependency Injection
- Actors for shared mutable state
- Immutable models
- Testable services
- Modular components
- Clean boundaries

---

# Dependency Rules

```
UI

↓

Application

↓

Services

↓

Core

↓

Protocols

↓

Foundation
```

No circular dependencies.

---

# Plugin Architecture

Plugins communicate through protocols only.

Supported plugin lifecycle:

1. Discover
2. Load
3. Register
4. Activate
5. Suspend
6. Unload

---

# Flow Blockchain

Flow integration is optional.

The receiver functions completely without blockchain connectivity.

Flow provides:

- Wallets
- Software Licensing
- Enterprise Licensing
- Marketplace
- Plugin Purchases
- NFT Licenses
- Revenue Distribution
- Device Registry

---

# Security

Security is built in from the beginning.

Features include:

- Threat Modeling
- Replay Protection
- Session Rotation
- Secure Defaults
- Packet Validation
- Header Validation
- Codec Validation
- Memory Safety
- Secure Logging

---

# Performance

Performance goals:

- Hardware accelerated decoding
- Low-latency rendering
- Minimal allocations
- Zero-copy rendering where possible
- Efficient actor communication

---

# Development

Requirements:

- Xcode 16+
- Swift 6
- macOS 15+

Clone:

```bash
git clone https://github.com/your-org/CastFlow.git
```

Build:

```bash
swift build
```

Test:

```bash
swift test
```

Run:

```bash
swift run
```

---

# Testing

The project includes:

- Unit Tests
- Integration Tests
- Security Tests
- Network Tests
- Performance Tests
- Concurrency Tests
- Decoder Tests
- Plugin Tests

Target Coverage:

> 90%

---

# Documentation

Documentation includes:

- Architecture
- Whitepaper
- Funding Proposal
- Security Guide
- Plugin SDK
- Developer Guide
- API Reference
- Roadmap

---

# Roadmap

## Phase 1

- Project bootstrap
- Architecture
- Dependency Injection
- Networking

## Phase 2

- RTSP
- RTP
- Bonjour
- Security

## Phase 3

- VideoToolbox
- Metal
- Audio

## Phase 4

- Plugin SDK
- Recording
- OBS

## Phase 5

- Flow Integration
- Marketplace
- Licensing

## Phase 6

- Enterprise
- Device Management
- Administration

---

# Contributing

Contributions are welcome.

Please read:

- CONTRIBUTING.md
- CODE_OF_CONDUCT.md
- SECURITY.md

before submitting pull requests.

---

# License

Licensed under the Apache 2.0 License.

See LICENSE for details.

---

# Acknowledgements

CastFlow builds upon modern Swift technologies and the Apple platform while embracing open architecture, modularity, and long-term maintainability.

---

# Project Status

🚧 Active Development

The architecture is designed to support years of incremental evolution while maintaining compatibility, modularity, and production-quality engineering standards.
