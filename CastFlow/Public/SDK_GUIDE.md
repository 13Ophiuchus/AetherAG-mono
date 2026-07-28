# Plugin SDK Guide

# CastFlow Plugin SDK

**Version:** 1.0

**Status:** Draft

---

# Overview

The CastFlow Plugin SDK enables developers to extend the platform without modifying the core application.

Plugins are designed to be:

- Safe
- Modular
- Versioned
- Independently testable
- Future compatible

The core application remains responsible for networking, media transport, security, and lifecycle management. Plugins extend capabilities through documented APIs.

												---

												# Design Goals

												The SDK is built around several principles:

													- Stable public APIs
												- Strong type safety
												- Swift 6 concurrency
												- Actor isolation
												- Minimal runtime overhead
												- Backward compatibility where practical

Plugins should never rely on internal implementation details.

---

# Plugin Architecture

```
CastFlow

Plugin Manager Actor
│
┌───────┼────────┐
│       │        │
Recording   Analytics   OBS
Plugin      Plugin      Plugin
│       │        │
└───────┼────────┘
│
Public SDK APIs
│
Core Application
```

Plugins communicate only through the SDK.

---

# Project Layout

```
Plugins/

├── ExamplePlugin/
│
├── OBSPlugin/
│
├── DiscordPlugin/
│
├── ZoomPlugin/
│
└── RecordingPlugin/
```

Each plugin should be independently buildable.

---

# Plugin Lifecycle

Every plugin follows the same lifecycle.

```
Discover

↓

Validate

↓

Load

↓

Initialize

↓

Register

↓

Run

↓

Suspend

↓

Resume

↓

Unload
```

---

# Plugin Manifest

Every plugin must include a manifest.

Example:

```json
{
	"identifier": "com.castflow.recording",
	"name": "Recording Plugin",
	"version": "1.0.0",
	"minimumSDK": "1.0",
	"author": "CastFlow Community",
	"license": "MIT",
	"capabilities": [
		"recording"
	]
}
```

---

# Required Metadata

Every plugin declares:

- Identifier
- Display Name
- Version
- SDK Version
- Author
- License
- Description
- Supported Platforms
- Required Permissions

---

# Plugin Protocol

Example:

```swift
public protocol CastFlowPlugin: Sendable {

	var identifier: String { get }

	var version: String { get }

	func initialize() async throws

	func start() async throws

	func stop() async

	func shutdown() async
}
```

---

# Plugin Manager

The Plugin Manager is responsible for:

											- Discovery
										- Loading
										- Validation
										- Dependency checks
										- Registration
										- Updates
										- Removal

										Plugins never manage themselves.

										---

										# Plugin Categories

										Current categories include:

											- Recording
										- Streaming
										- Analytics
										- Integrations
										- Automation
										- Enterprise
										- Diagnostics
										- User Interface

										Future categories may be added without affecting existing plugins.

										---

										# Dependency Rules

										Plugins:

											May depend on

										- CastFlow SDK
										- Apple Frameworks

										Should avoid

										- Internal modules
										- Undocumented APIs
										- Private symbols

										---

										# Version Compatibility

										Each plugin specifies:

											```
											Minimum SDK

										Maximum SDK (optional)

										Plugin Version
										```

										Example:

											```
											SDK 1.0+

										Plugin 2.3.1
										```

										---

										# Security

										Plugins execute with least privilege.

										Permissions may include:

											- Recording
										- Notifications
										- Network Access
										- File Access
										- Analytics

										Permissions are declared—not assumed.

										---

										# Thread Safety

										Plugins should:

											- Use actors
										- Avoid shared mutable state
										- Prefer immutable models
										- Support structured concurrency

										Avoid:

											- Locks
										- Global state
										- Thread-local storage

										---

										# Event System

										Plugins receive events from the application.

										Examples:

											- Session Started
										- Session Ended
										- Device Connected
										- Device Discovered
										- Video Frame Available
										- Audio Frame Available
										- Error Raised

										Events should be processed asynchronously.

										---

										# Services Available

										Plugins may access approved services such as:

											- Logging
										- Configuration
										- Metrics
										- Session Information
										- Device Registry

										Future services may be added through API evolution.

										---

										# Logging

										Use the provided logging interface.

										Example categories:

											- Plugin
										- Network
										- Analytics
										- Recording

										Never write directly to internal log files.

										---

										# Error Handling

										Recoverable failures should:

											- Return typed errors
										- Log useful diagnostics
										- Avoid crashing the application

										Fatal failures should trigger plugin unloading rather than application termination.

										---

										# Testing

										Every plugin should include:

											```
											Tests/

										Unit/

										Integration/

										Fixtures/
										```

										Recommended coverage:

											90%+

										---

										# Distribution

										Plugins may be distributed through:

											- GitHub Releases
										- Enterprise deployment
										- Future Marketplace

										Unsigned or incompatible plugins may be rejected depending on application policy.

										---

										# Best Practices

										Recommended:

											- Small focused plugins
										- Documented APIs
										- Stable interfaces
										- Dependency injection
										- Comprehensive tests

										Avoid:

											- Large monolithic plugins
										- Internal API usage
										- Excessive dependencies
										- Blocking operations

										---

										# Future SDK Features

										Potential future enhancements include:

											- Plugin sandboxing
										- Digital signatures
										- Capability negotiation
										- Dynamic updates
										- Marketplace integration
										- SDK code generation

										---

										# Summary

										The Plugin SDK enables a secure ecosystem while preserving the integrity, stability, and performance of the CastFlow core platform.
