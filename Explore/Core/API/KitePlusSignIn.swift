import AuthenticationServices
import CryptoKit
import Foundation

/// Signing in with a Kite Plus account through the Explore server
/// (docs/design/accounts.md section 1.1 in the explore repo). The system's
/// sign-in browser opens the server's start page with a PKCE challenge, the
/// server sends it back with a one-time code, and the code with the
/// verifier buys a session token. The app never sees the password.
nonisolated enum KitePlusSignIn {
    /// Where the server sends the browser back once Kite Plus is done.
    enum Callback: Equatable, Sendable {
        /// explore://app/auth/done. Any app could register the scheme, so
        /// it serves the servers this build cannot claim an address of.
        case scheme
        /// https://<host>/app/auth/done, claimed through Associated Domains.
        case https(host: String)

        var session: ASWebAuthenticationSession.Callback {
            switch self {
            case .scheme: .customScheme(KitePlusSignIn.scheme)
            case let .https(host): .https(host: host, path: KitePlusSignIn.donePath)
            }
        }
    }

    static let scheme = "explore"
    static let donePath = "/app/auth/done"
    /// The one server the app's Associated Domains entitlement names.
    static let claimedHost = "explore.kite.plus"

    /// Whether this build claims explore.kite.plus and takes the https
    /// callback. Off until the app is signed by a team with the Associated
    /// Domains entitlement; RELEASE.md says how to turn it on.
    static var httpsCallbackEnabled: Bool {
        let value = Bundle.main.object(forInfoDictionaryKey: "SignInHTTPSCallback") as? String
        return ["yes", "true", "1"].contains(value?.lowercased() ?? "")
    }

    static func callback(for server: URL, httpsEnabled: Bool) -> Callback {
        guard httpsEnabled, server.scheme?.lowercased() == "https", server.port == nil,
              server.host(percentEncoded: false)?.lowercased() == claimedHost
        else { return .scheme }
        return .https(host: claimedHost)
    }

    /// The server's page that starts a sign-in. switchAccount asks Kite
    /// Plus to offer its accounts instead of going on with the one the
    /// browser is signed in to.
    static func startURL(server: URL, challenge: String, switchAccount: Bool, callback: Callback) -> URL {
        var query = [
            URLQueryItem(name: "challenge", value: challenge),
            URLQueryItem(name: "client", value: "ios"),
        ]
        if switchAccount {
            query.append(URLQueryItem(name: "switch", value: "1"))
        }
        if callback == .scheme {
            query.append(URLQueryItem(name: "callback", value: "scheme"))
        }
        return server.appending(path: "auth/app/start").appending(queryItems: query)
    }

    /// Reads the address the sign-in came back to: the code to exchange, or
    /// why the server gave none.
    static func code(from url: URL, expecting callback: Callback) throws(KitePlusSignInError) -> String {
        guard matches(url, callback),
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { throw .loginFailed }
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw KitePlusSignInError(code: error)
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw .loginFailed
        }
        return code
    }

    private static func matches(_ url: URL, _ callback: Callback) -> Bool {
        let scheme = url.scheme?.lowercased()
        let host = url.host(percentEncoded: false)?.lowercased()
        switch callback {
        case .scheme:
            return scheme == Self.scheme && host == "app" && url.path(percentEncoded: false) == "/auth/done"
        case let .https(expected):
            return scheme == "https" && host == expected && url.path(percentEncoded: false) == donePath
        }
    }
}

/// A PKCE pair (RFC 7636): the verifier stays in the app, and the server
/// sees only its SHA-256 until the code is exchanged.
nonisolated struct PKCE: Sendable {
    let verifier: String

    var challenge: String { Self.challenge(for: verifier) }

    /// 32 random bytes, which make a 43 character verifier.
    init() {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        verifier = Self.base64URL(Data(bytes))
    }

    init(verifier: String) {
        self.verifier = verifier
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Why a Kite Plus sign-in came back without a code, as the server names it
/// in the callback's error parameter.
nonisolated enum KitePlusSignInError: Error, Equatable, Sendable {
    case loginExpired
    case loginFailed
    case accessDenied
    case unavailable
    case accountDisabled
    case emailInUse
    case emailUnverified
    case registrationClosed

    /// Codes this app does not know read as a failed sign-in.
    init(code: String) {
        switch code {
        case "login_expired": self = .loginExpired
        case "access_denied": self = .accessDenied
        case "unavailable": self = .unavailable
        case "account_disabled": self = .accountDisabled
        case "email_in_use": self = .emailInUse
        case "email_unverified": self = .emailUnverified
        case "registration_closed": self = .registrationClosed
        default: self = .loginFailed
        }
    }
}

extension KitePlusSignInError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .loginExpired:
            String(localized: "The sign-in expired. Try again.")
        case .loginFailed:
            String(localized: "Signing in with Kite Plus didn't work. Try again.")
        case .accessDenied:
            String(localized: "Signing in with Kite Plus was canceled.")
        case .unavailable:
            String(localized: "Kite Plus accounts are unavailable right now. Try again later.")
        case .accountDisabled:
            String(localized: "This account is disabled.")
        case .emailInUse:
            String(localized: "This email already belongs to an Explore account. Sign in with its password, then link Kite Plus under My Account on the Explore website.")
        case .emailUnverified:
            String(localized: "Verify your email in your Kite Plus account first.")
        case .registrationClosed:
            String(localized: "Registration is closed on this server right now.")
        }
    }
}
