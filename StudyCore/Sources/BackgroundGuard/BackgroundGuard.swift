// BackgroundGuard — runtime that consumes SceneSignals and emits decisions.
// The iOS layer wires up actual adapters; tests drive it with synthetic signals.
//
// This module is intentionally decoupled from TimerEngine to keep the policy
// pure and unit-testable on macOS.

import Foundation

@MainActor
public final class BackgroundGuard {
    public private(set) var lastDecision: GuardAction = .ignore
    public var onDecision: ((SceneSignal, GuardAction) -> Void)?

    private let policy: GuardPolicy
    private var contextProvider: () -> GuardContext

    public init(
        policy: GuardPolicy = GuardPolicy(),
        contextProvider: @escaping () -> GuardContext
    ) {
        self.policy = policy
        self.contextProvider = contextProvider
    }

    public func ingest(_ signal: SceneSignal) {
        let ctx = contextProvider()
        let action = policy.decide(signal: signal, context: ctx)
        lastDecision = action
        onDecision?(signal, action)
    }

    public func ingest(_ signals: [SceneSignal]) {
        signals.forEach(ingest)
    }
}
