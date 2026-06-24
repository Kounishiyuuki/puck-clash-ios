# Architecture

## SwiftUI

SwiftUI owns the app shell: launch flow, menus, settings screens, match setup, and embedding the SpriteKit rink view.

SwiftUI should pass high-level intents into the game screen and display summary state from `GameCore`. It should not contain match rules.

## SpriteKit

SpriteKit owns rink rendering, touch input, camera behavior, animations, sound triggers, particles, and other presentation effects.

SpriteKit should translate input into `GameCore` commands and render the latest `GameCore` snapshot. It should not be the source of truth for score, possession, skill cooldowns, or match state.

## GameCore

`GameCore` is pure Swift and should stay independent from SwiftUI, SpriteKit, persistence, and networking frameworks.

Responsibilities:

- Match state.
- Player, puck, and rink state.
- Simplified physics.
- Input command handling.
- Skill logic and cooldowns.
- Score and period or timer rules.
- CPU opponent behavior for the offline MVP.
- Snapshot generation for rendering and future networking.

## Networking

Networking is intentionally empty for the first milestone.

When requested later, the iOS app should use `URLSessionWebSocketTask` to send player inputs and receive match snapshots or authoritative corrections. Networking should depend on `GameCore` data structures, not SpriteKit objects.

## Data

No database or persistence is required for the initial MVP.

Short-term data should stay in memory. Add persistence only when there is a concrete product need such as local settings or saved practice preferences.

## Future Server

The future server should use Swift, Vapor, and WebSocket.

Server responsibilities may eventually include:

- Match rooms.
- WebSocket session management.
- Server-authoritative match progression or validation.
- Snapshot broadcast.
- Reconnect handling.

Do not add server code until explicitly requested.
