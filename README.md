# Puck Clash

Puck Clash is a skill-based battle hockey iOS game built around ordinary ice hockey first: take the puck, move it, shoot, defend, and score. Tactical skills such as Boost, Ice Block, Fake Puck, and Power Shot should add depth without replacing the core hockey loop.

## Current Goal

The first milestone is an offline CPU match. SpriteKit should render and collect input while a pure Swift `GameCore` owns match state, simplified physics, skill logic, score logic, cooldowns, and network-ready snapshots.

## Stack

- iOS app: Swift, SwiftUI, SpriteKit
- Game logic: pure Swift `GameCore`
- Future networking: `URLSessionWebSocketTask`
- Future server: Swift, Vapor, WebSocket

## Scope Guardrails

- No online networking yet.
- No external dependencies.
- No Firebase, authentication, database, ranking, ads, analytics, or monetization.
- No broad rewrites or speculative systems before the offline MVP needs them.

See `Docs/` for the development definition, architecture notes, MVP scope, and Codex workflow rules.
