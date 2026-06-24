# Puck Clash Development Definition

## Concept

Puck Clash is a skill-based battle hockey iOS game. The core game remains ordinary ice hockey: players chase and control the puck, move, shoot, defend, and score. Skills add tactical moments without turning the game into a different genre.

Initial skill examples:

- Boost: short speed increase.
- Ice Block: temporary obstacle or defensive interruption.
- Fake Puck: brief deception around puck position or possession.
- Power Shot: stronger shot with cooldown and clear counterplay.

## Architecture Principle

SpriteKit owns rendering, input collection, animation, and visual effects. It should not own match rules.

Pure Swift `GameCore` owns:

- Match state.
- Simplified physics.
- Skill rules and cooldowns.
- Score rules.
- CPU decisions for the offline MVP.
- Deterministic snapshots that can later be sent over WebSocket.

## Tech Stack

- Swift.
- SwiftUI for app shell and screens outside the rink.
- SpriteKit for the rink scene, player input, and effects.
- Pure Swift GameCore for game simulation.
- `URLSessionWebSocketTask` later for app networking.
- Swift, Vapor, and WebSocket later for the server.

## MVP Scope

The first MVP is offline only:

- One local player versus one CPU opponent.
- One playable rink scene.
- Basic puck movement, possession, shooting, defending, scoring, and reset flow.
- A small skill set only after the ordinary hockey loop works.
- Simple match timer or score target.

## Future Server Plan

After the offline MVP is stable, add a local Vapor WebSocket server for development. Only after the local server proves the protocol and synchronization approach should remote server deployment be considered.

The future network model should exchange compact snapshots and player inputs derived from `GameCore`, not SpriteKit scene internals.
