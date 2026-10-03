import Foundation

/// What went wrong talking to Explore. Server errors carry the stable code
/// to branch on and a message already in the interface language.
nonisolated enum APIError: Error, Sendable, Equatable {
    case server(status: Int, code: String, message: String, submissionID: String?, report: CheckReport?)
    case offline
    case timedOut
    case transport(String)
    case invalidResponse(String)

    var code: String? {
        if case let .server(_, code, _, _, _) = self { code } else { nil }
    }

    var status: Int? {
        if case let .server(status, _, _, _, _) = self { status } else { nil }
    }

    var report: CheckReport? {
        if case let .server(_, _, _, _, report) = self { report } else { nil }
    }

    var submissionID: String? {
        if case let .server(_, _, _, id, _) = self { id } else { nil }
    }

    var isUnauthorized: Bool { status == 401 }

    init(_ error: URLError) {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
            self = .offline
        case .timedOut:
            self = .timedOut
        default:
            self = .transport(error.localizedDescription)
        }
    }

    /// Reads an error response. Proxies in front of Explore may answer with
    /// HTML, so a body that is not Explore's JSON still maps to a message.
    init(status: Int, data: Data, decoder: JSONDecoder) {
        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            self = .server(
                status: status, code: envelope.error.code, message: envelope.error.message,
                submissionID: envelope.submissionID, report: envelope.checkReport
            )
            return
        }
        let code: String
        let message: String
        switch status {
        case 429:
            code = "rate_limited"
            message = String(localized: "Too many requests. Try again in a moment.")
        case 404:
            code = "not_found"
            message = String(localized: "Not found.")
        case 500...:
            code = "internal"
            message = String(localized: "Explore is having trouble right now. Try again later.")
        default:
            code = "invalid_request"
            message = String(localized: "Explore could not handle the request.")
        }
        self = .server(status: status, code: code, message: message, submissionID: nil, report: nil)
    }
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .server(_, _, message, _, _):
            message
        case .offline:
            String(localized: "You're offline. Check your connection and try again.")
        case .timedOut:
            String(localized: "Explore took too long to answer. Try again.")
        case .transport:
            String(localized: "Can't reach Explore right now.")
        case .invalidResponse:
            String(localized: "Explore sent a response the app doesn't understand.")
        }
    }
}

extension Error {
    /// A message fit for the interface.
    var readableMessage: String {
        (self as? LocalizedError)?.errorDescription ?? localizedDescription
    }

    var isCancellation: Bool {
        self is CancellationError || (self as? URLError)?.code == .cancelled
    }
}
