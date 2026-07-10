import Foundation

enum NetworkingPlaceholder {
    static let isNetworkingImplemented = false
}

// Boundary to whatever actually carries an online match's traffic. It lives in the
// networking layer (not GameCore) so GameCore stays Foundation-only and free of any
// networking vocabulary. No concrete real-network transport exists yet:
// OnlineMatchSession is driven entirely through this protocol, and tests use a mock.
protocol MatchTransport: AnyObject {
    // Client -> server: the local player's latest stick input, tagged with the tick
    // of the last snapshot it was based on (for future reconciliation).
    func sendHomeInput(moveVector: Vector2?, tick: Int)
    // Server -> client: an authoritative snapshot to render. A real transport must
    // deliver this on the main thread, since RinkScene.update consumes it there.
    var onSnapshot: ((MatchSnapshot) -> Void)? { get set }
    // The server or link dropped. Received here but not surfaced to the UI yet.
    var onDisconnect: (() -> Void)? { get set }
}

// Server-authoritative online session (skeleton). Unlike LocalMatchSession it owns no
// GameEngine and runs no local physics: the server is the sole authority, so the
// session simply hands back the latest snapshot the transport delivered and forwards
// local input to the server. There is no prediction/reconciliation yet, and it is not
// wired into the UI — Online Match remains a Coming Soon placeholder.
final class OnlineMatchSession: MatchSession {
    let config: MatchConfig
    private let transport: MatchTransport
    // Latest authoritative snapshot; until the server sends one, this is the agreed
    // initial board so the presentation layer always has something to render.
    private var latestSnapshot: MatchSnapshot

    init(config: MatchConfig, transport: MatchTransport) {
        self.config = config
        self.transport = transport
        self.latestSnapshot = MatchSnapshot(
            tick: 0,
            state: .initial(config: config),
            isAuthoritative: true
        )
        transport.onSnapshot = { [weak self] snapshot in
            self?.latestSnapshot = snapshot
        }
    }

    var state: GameState {
        latestSnapshot.state
    }

    // Normalize a released / zero stick to "no input" (matching LocalMatchSession),
    // then forward it to the server tagged with the last snapshot's tick. No local
    // simulation happens here.
    func setHomeInput(moveVector: Vector2?) {
        let normalized: Vector2?
        if let moveVector, moveVector != .zero {
            normalized = moveVector
        } else {
            normalized = nil
        }
        transport.sendHomeInput(moveVector: normalized, tick: latestSnapshot.tick)
    }

    // Server-authoritative: no local stepping. deltaTime is unused for now; the latest
    // snapshot received from the transport is returned as-is (the initial fallback
    // until the first server snapshot arrives).
    @discardableResult
    func advance(deltaTime: TimeInterval) -> MatchSnapshot {
        latestSnapshot
    }
}
