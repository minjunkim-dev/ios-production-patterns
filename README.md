# iOS Production Patterns

[![Swift](https://img.shields.io/badge/Swift-6.0-F05138.svg?logo=swift&logoColor=white)](https://www.swift.org)
[![CI](https://github.com/minjunkim-dev/ios-production-patterns/actions/workflows/ci.yml/badge.svg)](https://github.com/minjunkim-dev/ios-production-patterns/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A small Swift package that turns recurring mobile-production failure modes into explicit, testable policies.

This repository contains independently written examples. It does **not** include company source code, private APIs, customer data, or internal assets.

## Why these patterns

Mobile applications often fail at boundaries rather than happy paths:

- remote update policy is malformed and blocks every user;
- an older async response overwrites a newer screen state;
- startup waits forever because a remote call has no upper bound.

The package keeps those boundaries small enough to test deterministically.

## Included patterns

### 1. Fail-open version gate

`VersionGate` requires an update only when both semantic versions are valid and the current version is lower than the minimum.

```swift
let decision = VersionGate.evaluate(
    current: "2.1.0",
    minimum: "2.1.1"
)
// .requireUpdate
```

Malformed remote input resolves to `.allow`, preventing a broken payload from globally blocking app startup.

### 2. Latest-request-wins gate

`LatestRequestGate` is an actor that issues generation tokens. A response mutates UI state only if its token is still current.

```swift
let token = await gate.begin()
let response = try await api.load()

guard await gate.isCurrent(token) else { return }
state = .loaded(response)
```

Starting another request or calling `invalidate()` makes older work stale.

### 3. Bounded async operation

`withTimeout` races an async operation against an explicit deadline and cancels the losing task.

```swift
let policy = try await withTimeout(nanoseconds: 3_000_000_000) {
    try await remoteConfig.fetchPolicy()
}
```

The caller owns the fallback policy, so timeout handling remains visible at the product boundary.

## Test strategy

The repository was built with red-green-refactor cycles. Tests cover:

- older, equal, newer, and malformed version values;
- stale generation tokens and explicit invalidation;
- successful bounded work and timeout failure.

Run locally:

```bash
swift test
```

## Design principles

- **Fail safely:** remote configuration must not accidentally lock out every user.
- **Make races explicit:** stale-response checks are a first-class policy, not scattered booleans.
- **Bound waiting:** startup and foreground synchronization need a visible timeout.
- **Prefer deterministic tests:** concurrency contracts should be reproducible without a device or server.
- **Keep product decisions outside utilities:** the package reports outcomes; the app decides UI and recovery.

## Requirements

- Swift 6.0+
- iOS 16+
- macOS 13+

## License

MIT
