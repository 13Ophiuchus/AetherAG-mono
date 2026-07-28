# AGENT_PROMPT.md

```text
# CastFlow — Master Engineering Specification

Version: 1.0
Target Platform: macOS 15+
Language: Swift 6
Package Manager: Swift Package Manager
Architecture: Feature-First Modular Architecture
Concurrency: Swift 6 Strict Concurrency
License: Apache-2.0 (recommended)

==============================================================================
MISSION
==============================================================================

You are acting as an elite software engineering team consisting of:

• Principal Swift Engineer
• macOS Framework Engineer
• Distributed Systems Architect
• Security Engineer
• Network Protocol Engineer
• Media Pipeline Engineer
• Blockchain Architect
• DevOps Engineer
• Technical Writer
• QA Automation Engineer
• Performance Engineer
• Product Architect

Your responsibility is to design and implement CastFlow as a production-quality
open-source macOS application.

Never generate demo code.

Never generate placeholder implementations.

Never generate fake networking.

Every implementation must compile.

Every feature must be documented.

Every public API must be documented.

Everything must be testable.

Everything must be modular.

Everything must follow Swift 6 strict concurrency.

==============================================================================
PROJECT OVERVIEW
==============================================================================

CastFlow is a native macOS wireless display platform.

It is NOT simply an AirPlay receiver.

It is designed as a modular wireless display platform capable of supporting
multiple transport protocols through protocol adapters.

Initial supported transport:

• AirPlay-compatible receiver

Future transports include:

• Google Cast
• Miracast Bridge
• WebRTC
• SRT
• RIST
• NDI
• Custom Enterprise Transport

These must all plug into the same media pipeline.

==============================================================================
CORE PRINCIPLES
==============================================================================

Priority order:

1 Security

2 Stability

3 Reliability

4 Performance

5 Maintainability

6 Extensibility

7 Testability

8 Documentation

9 Simplicity

10 Developer Experience

==============================================================================
DESIGN PHILOSOPHY
==============================================================================

The application must be modular.

The application must be plugin driven.

No subsystem should require another subsystem to exist.

Blockchain is optional.

Enterprise is optional.

Plugins are optional.

Core networking must compile independently.

Media pipeline must compile independently.

UI must not know networking implementation details.

Networking must not know UI implementation details.

==============================================================================
ARCHITECTURE
==============================================================================

CastFlow/

App/

Core/

Networking/

Media/

Security/

Discovery/

Protocols/

Blockchain/

Plugins/

Enterprise/

Shared/

Configuration/

Utilities/

UI/

Documentation/

Tests/

Scripts/

Resources/

==============================================================================
MODULE RESPONSIBILITIES
==============================================================================

App

Application lifecycle

Dependency injection

Bootstrapping

Settings

Menus

Window management

----------------------------------------------------

Core

Shared business logic

Application coordinator

Session coordinator

Feature registration

State management

----------------------------------------------------

Networking

Bonjour

RTSP

RTP

Packet parser

Session negotiation

Transport management

Metrics

Logging

----------------------------------------------------

Media

VideoToolbox

Metal

CoreAudio

Synchronization

Frame scheduling

Hardware acceleration

Rendering

Recording hooks

Future AI processing

----------------------------------------------------

Security

Authentication

FP-SRP

AES

Key generation

Key storage

Nonce generation

Replay protection

Packet validation

Threat detection

Secure logging

----------------------------------------------------

Discovery

Bonjour advertisement

Bonjour browsing

Capability negotiation

Device information

Service registration

----------------------------------------------------

Protocols

Interfaces only.

No implementations.

Everything protocol-first.

Example:

ReceiverProtocol

MediaPipelineProtocol

SessionProtocol

RendererProtocol

DecoderProtocol

CryptoProvider

Logger

MetricsProvider

ConfigurationProvider

WalletProvider

LicenseProvider

MarketplaceProvider

==============================================================================
DEPENDENCY RULES
==============================================================================

Dependencies always point downward.

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

Networking

↓

Foundation

Forbidden

UI importing Networking

Networking importing UI

Blockchain importing Media

Media importing Blockchain

Circular dependencies

Singletons

Global mutable state

==============================================================================
CONCURRENCY
==============================================================================

Swift 6 Strict Concurrency

Use

Actors

Sendable

async/await

Task

TaskGroup

AsyncSequence

Avoid

DispatchQueue

Locks

Semaphores

Shared mutable globals

UnsafeMutablePointer unless absolutely required.

==============================================================================
ACTORS
==============================================================================

ApplicationActor

SessionActor

BonjourActor

ReceiverActor

RTSPActor

RTPActor

MediaPipelineActor

VideoDecoderActor

AudioDecoderActor

RendererActor

RecorderActor

MetricsActor

LoggerActor

WalletActor

TransactionActor

MarketplaceActor

PluginActor

ConfigurationActor

==============================================================================
NETWORK STACK
==============================================================================

Bonjour Discovery

↓

Capability Exchange

↓

Authentication

↓

FP-SRP Pairing

↓

RTSP Negotiation

↓

AES Session Key

↓

RTP Streaming

↓

VideoToolbox

↓

Metal Rendering

==============================================================================
MEDIA PIPELINE
==============================================================================

Network Packet

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

Metal

↓

Display

Zero-copy whenever possible.

No unnecessary memory copies.

==============================================================================
SECURITY REQUIREMENTS
==============================================================================

Implement

Threat Modeling

Least Privilege

Replay Protection

Nonce Validation

Session Rotation

Key Rotation

Rate Limiting

Packet Validation

Header Validation

Codec Validation

Secure Defaults

Certificate Validation (where applicable)

Memory Zeroization

Audit Logging

Tamper Detection

No secret may appear in logs.

==============================================================================
PLUGIN ARCHITECTURE
==============================================================================

Every optional capability must be implemented as a plugin.

Examples

AirPlay

Google Cast

Miracast

Recording

OBS

Discord

Zoom

AI Upscaling

Marketplace

Blockchain

Enterprise

Analytics

Remote Desktop

Plugin lifecycle

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

Plugins communicate only through protocols.

==============================================================================
FLOW BLOCKCHAIN
==============================================================================

Flow integration is OPTIONAL.

The receiver must remain fully functional without Flow.

Flow provides

Wallets

Subscriptions

Marketplace

Licensing

Enterprise Licensing

NFT Software Licenses

Plugin Purchases

Revenue Sharing

Device Registry

Developer Registry

Future Governance

No media pipeline dependency.

==============================================================================
TESTING
==============================================================================

Required

Unit Tests

Integration Tests

Performance Tests

Concurrency Tests

Security Tests

Decoder Tests

Network Tests

Protocol Tests

Plugin Tests

Coverage target

90%

==============================================================================
CI/CD
==============================================================================

GitHub Actions

Swift Testing

SwiftLint

SwiftFormat

Static Analysis

Coverage

Signed Releases

Automatic CHANGELOG

Semantic Versioning

Conventional Commits

==============================================================================
DOCUMENTATION
==============================================================================

Generate

README.md

ARCHITECTURE.md

WHITEPAPER.md

FUNDING_PROPOSAL.md

ROADMAP.md

SECURITY.md

CONTRIBUTING.md

CODE_OF_CONDUCT.md

CHANGELOG.md

Plugin SDK Guide

Developer Guide

API Reference

Architecture Diagrams

Sequence Diagrams

Deployment Guide

==============================================================================
QUALITY REQUIREMENTS
==============================================================================

Every public API documented.

One primary type per file.

No force unwraps.

Dependency Injection everywhere.

Protocol-first.

No dead code.

No TODO comments.

No fake implementations.

No placeholder methods.

No duplicate logic.

No God objects.

Everything production ready.

==============================================================================

FINAL OBJECTIVE

Build CastFlow as an extensible wireless display platform for macOS with:

• Modern Swift 6 architecture
• Modular networking
• Secure media streaming
• Actor-based concurrency
• Plugin ecosystem
• Optional Flow blockchain services
• Enterprise-ready scalability
• Open-source community friendliness

The resulting codebase should be maintainable for years, support future transport protocols without architectural rewrites, and serve as a foundation for both community contributions and commercial extensions.
```
