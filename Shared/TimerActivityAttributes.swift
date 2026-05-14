// TimerActivityAttributes — ActivityKit attributes shared between the main app
// and the widget extension. The state carries `startedAt` + optional `pausedAt`
// so the lock-screen view can render elapsed time via `Text(timerInterval:)`
// without our process having to wake up every second (PLAN v2.0 §6).

import Foundation
import ActivityKit

public struct TimerActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public let startedAt: Date
        public let pausedAt: Date?
        public let accumulatedSeconds: Int
        public let subjectName: String
        public let subjectColorHex: String
        public let targetSeconds: Int?

        public init(
            startedAt: Date,
            pausedAt: Date?,
            accumulatedSeconds: Int,
            subjectName: String,
            subjectColorHex: String,
            targetSeconds: Int?
        ) {
            self.startedAt = startedAt
            self.pausedAt = pausedAt
            self.accumulatedSeconds = accumulatedSeconds
            self.subjectName = subjectName
            self.subjectColorHex = subjectColorHex
            self.targetSeconds = targetSeconds
        }
    }

    public let sessionId: UUID

    public init(sessionId: UUID) {
        self.sessionId = sessionId
    }
}

public enum AppGroup {
    public static let identifier = "group.co.autopus.study"
}
