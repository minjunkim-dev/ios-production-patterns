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
- startup waits forever because a remote call has no upper bound;
- several entry points trigger the same initialization and observe partial state.

The package keeps those boundaries small enough to test deterministically.
Each pattern below starts with the production incident it came from. The
incidents are described generically; no product code or data is included.

## Included patterns

### 1. Fail-open version gate

> **Seen in production:** a remote update policy arrived with a malformed minimum version. A strict comparison would have treated every installed build as outdated and locked all users on the update screen.

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

> **Seen in production:** after the app returned to the foreground, a slow response from the previous fetch landed after the fresh one and pinned a stale program card on screen until the next restart.

`LatestRequestGate` is an actor that issues generation tokens. A response mutates UI state only if its token is still current.

```swift
let token = await gate.begin()
let response = try await api.load()

guard await gate.isCurrent(token) else { return }
state = .loaded(response)
```

Starting another request or calling `invalidate()` makes older work stale.

### 3. Bounded async operation

> **Seen in production:** startup awaited a remote policy call with no deadline. On a poor network the splash screen simply never went away.

`withTimeout` races an async operation against an explicit deadline and cancels the losing task.

```swift
let policy = try await withTimeout(nanoseconds: 3_000_000_000) {
    try await remoteConfig.fetchPolicy()
}
```

The caller owns the fallback policy, so timeout handling remains visible at the product boundary.

### 4. Shared startup coordinator

> **Seen in production:** the app delegate, a reconnecting scene, and a deep link each called the same initialization. Work ran twice and one caller observed a half-built state.

`StartupCoordinator` stores the running `Task`, so concurrent callers await the same build instead of starting another one. A finished value is reused; a transient failure returns to `idle` and retries on the next call.

```swift
let startup = StartupCoordinator(
    isPermanentFailure: { $0 is UnsupportedStoreFormat }
) {
    let configuration = try await loadConfiguration()
    let database = try await openDatabase(using: configuration)
    let session = try await restoreSession(from: database)
    return AppServices(configuration: configuration, database: database, session: session)
}

// Every entry point calls the same coordinator.
let services = try await startup.start()
```

Permanent failures are kept and rethrown instead of rebuilt. `reset()` discards the result after logout and cancels a build that is still running. The builder returns one complete value, so callers never see a partially initialized state.

## Test strategy

The repository was built with red-green-refactor cycles. Tests cover:

- older, equal, newer, and malformed version values;
- stale generation tokens and explicit invalidation;
- successful bounded work and timeout failure;
- one shared build for concurrent callers, reuse of the ready value, retry after a transient failure, a kept permanent failure, and `reset()` during and after a build.

Run locally:

```bash
swift test
```

## Design principles

- **Fail safely:** remote configuration must not accidentally lock out every user.
- **Make races explicit:** stale-response checks are a first-class policy, not scattered booleans.
- **Bound waiting:** startup and foreground synchronization need a visible timeout.
- **Share in-flight work:** store the running task, not a boolean, so re-entrant callers join it.
- **Prefer deterministic tests:** concurrency contracts should be reproducible without a device or server.
- **Keep product decisions outside utilities:** the package reports outcomes; the app decides UI and recovery.

## Requirements

- Swift 6.0+
- iOS 16+
- macOS 13+

## License

MIT
