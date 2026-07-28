# ARCHITECTURE.md

# CastFlow Architecture

Version 1.0

---

# Overview

CastFlow is designed as a **modular wireless display platform** rather than a single-purpose AirPlay receiver.

Every subsystem is isolated behind protocols and dependency injection, allowing future transport protocols, rendering engines, enterprise features, and blockchain services to evolve independently.

Core design principles:

- Modular
- Plugin-first
- Protocol-oriented
- Actor-isolated
- Secure by default
- Test-driven
- Enterprise ready

---

# High-Level Architecture

```text
                        CastFlow
                            │
     ┌──────────────────────┴──────────────────────┐
     │                                             │
   SwiftUI                                    Application
     │                                             │
     └──────────────────────┬──────────────────────┘
                            │
                     Dependency Container
                            │
      ┌──────────────┬──────────────┬──────────────┐
      │              │              │              │
 Networking       Security       Media         Plugins
      │              │              │              │
      └──────────────┴──────────────┴──────────────┘
                            │
                        Shared Core
                            │
                      Apple Frameworks
```

---

# Architectural Principles

## Modular Design

Every major feature is isolated into an independent module.

Advantages:

- Easier testing
- Independent evolution
- Cleaner ownership
- Smaller compile units
- Better dependency management

---

## Protocol-Oriented Design

Concrete implementations are never referenced directly.

Example:

```swift
protocol RendererProtocol
protocol DecoderProtocol
protocol TransportProtocol
protocol WalletProvider
```

Every service depends upon abstractions.

---

## Dependency Injection

All dependencies are injected.

Never use global singletons.

Preferred:

```swift
ApplicationContainer

↓

ServiceFactory

↓

Services

↓

Actors

↓

Models
```

---

# Layered Architecture

```text
SwiftUI

↓

Application

↓

Services

↓

Protocols

↓

Core

↓

Networking

↓

Foundation
```

Rules:

- Dependencies only point downward.
- UI never imports Networking.
- Networking never imports UI.
- Media never imports Blockchain.

---

# Core Modules

## App

Responsibilities:

- Application lifecycle
- Window management
- Menus
- Dependency injection
- Configuration
- Startup

---

## Core

Responsibilities:

- Coordinators
- Shared business logic
- Session management
- Feature registration
- Shared state

---

## Networking

Responsibilities:

- Bonjour
- RTSP
- RTP
- Packet parsing
- Session negotiation
- Metrics
- Logging

---

## Security

Responsibilities:

- Authentication
- FP-SRP
- AES encryption
- Session keys
- Replay protection
- Threat detection
- Secure logging

---

## Discovery

Responsibilities:

- Bonjour advertisement
- Bonjour browsing
- Service discovery
- Device capabilities
- Feature negotiation

---

## Media

Responsibilities:

- VideoToolbox
- CoreAudio
- Metal
- Synchronization
- Rendering
- Recording hooks

---

## Plugins

Responsibilities:

- Plugin loading
- Registration
- Version compatibility
- Lifecycle management
- Permissions

---

## Blockchain

Optional module.

Responsibilities:

- Wallet integration
- Licensing
- Marketplace
- NFT entitlements
- Revenue distribution
- Device registration

---

## Enterprise

Responsibilities:

- Fleet management
- Administration
- Policy enforcement
- Audit logging
- Device inventory

---

# Swift Concurrency

Swift 6 strict concurrency is mandatory.

Use:

- actors
- Sendable
- async/await
- Task
- TaskGroup

Avoid:

- DispatchQueue
- Locks
- Semaphores
- Global mutable state

---

# Primary Actors

```text
ApplicationActor

ConfigurationActor

DiscoveryActor

ReceiverActor

RTSPActor

RTPActor

SessionActor

MediaPipelineActor

VideoDecoderActor

AudioDecoderActor

RendererActor

RecorderActor

LoggerActor

MetricsActor

PluginActor

WalletActor

MarketplaceActor
```

---

# Session Flow

```text
Launch

↓

Bonjour Advertisement

↓

Device Discovery

↓

Connection Request

↓

Authentication

↓

FP-SRP Pairing

↓

Session Creation

↓

RTSP Negotiation

↓

AES Session Keys

↓

RTP Streaming

↓

Media Pipeline

↓

Rendering

↓

Disconnect

↓

Cleanup
```

---

# Media Pipeline

```text
Incoming Packet

↓

Validation

↓

Decrypt

↓

Reassembly

↓

NAL Parsing

↓

VideoToolbox

↓

CVPixelBuffer

↓

Metal Rendering

↓

Display
```

Goals:

- Zero-copy rendering
- Low latency
- Minimal allocations
- Hardware acceleration

---

# Security Pipeline

```text
Discovery

↓

Authentication

↓

Session Validation

↓

Key Exchange

↓

AES Encryption

↓

Packet Validation

↓

Replay Protection

↓

Media Pipeline

↓

Rendering
```

---

# Plugin Architecture

Every optional feature is a plugin.

```text
Plugin Manager

↓

Plugin Loader

↓

Capability Registry

↓

Dependency Resolver

↓

Plugin Runtime
```

Plugin lifecycle:

```text
Discover

↓

Load

↓

Initialize

↓

Register

↓

Activate

↓

Suspend

↓

Unload
```

---

# Plugin Categories

- AirPlay
- Google Cast
- Miracast
- Recording
- OBS
- Discord
- Zoom
- AI
- Enterprise
- Marketplace
- Analytics
- Remote Desktop

---

# Flow Architecture

Flow integration is completely optional.

```text
Wallet

↓

Scripts

↓

Transactions

↓

Contracts

↓

Licensing

↓

Marketplace

↓

Enterprise
```

Supported services:

- Wallet
- Licensing
- Marketplace
- Plugin Store
- Enterprise Licensing
- Device Registry
- Developer Registry

---

# Repository Layout

```text
CastFlow/

App/

Core/

Networking/

Security/

Discovery/

Media/

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

# Testing Strategy

Every module includes:

- Unit Tests
- Integration Tests
- Performance Tests
- Concurrency Tests
- Security Tests

Coverage target:

**90%+**

---

# Continuous Integration

Every pull request must:

- Build successfully
- Pass all tests
- Pass SwiftLint
- Pass SwiftFormat
- Pass static analysis
- Generate coverage report

---

# Documentation

Required documentation:

- README
- Whitepaper
- Funding Proposal
- Security Guide
- API Reference
- Plugin SDK
- Developer Guide
- Architecture Decision Records (ADRs)

---

# Design Goals

## Security

First-class security throughout the stack.

---

## Performance

Low latency.

Minimal memory allocations.

Hardware acceleration.

---

## Scalability

Protocol adapters.

Plugin architecture.

Enterprise deployment.

---

## Maintainability

Small modules.

Protocol-first.

Dependency injection.

Explicit ownership.

---

# Long-Term Vision

CastFlow is intended to become an extensible wireless display platform that enables:

- Multiple casting protocols
- Enterprise device management
- Plugin marketplace
- Secure media transport
- Optional decentralized licensing
- Commercial extensions
- Open-source community contributions

By maintaining strict architectural boundaries and modern Swift engineering practices, CastFlow is designed to remain adaptable and maintainable as new protocols, hardware capabilities, and deployment models emerge.
