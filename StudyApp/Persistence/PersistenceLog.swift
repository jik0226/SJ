// Persistence — tiny logging helper so persistence failures stop being silent.
// `try?` patterns in CRUD paths now route here so future surfacing (banner,
// crash-reporter) is a one-line change.

import Foundation
import OSLog

enum Persistence {
    private static let logger = Logger(subsystem: "co.autopus.study", category: "persistence")

    static func log(_ error: Error, context: String) {
        logger.error("[persist] \(context, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
    }

    @discardableResult
    static func save<T>(
        _ block: () throws -> T,
        context: String
    ) -> T? {
        do {
            return try block()
        } catch {
            log(error, context: context)
            return nil
        }
    }
}
