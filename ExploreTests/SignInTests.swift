import Foundation
import Testing
@testable import Explore

struct PKCETests {
    @Test func matchesTheRFCExample() {
        // RFC 7636, appendix B.
        #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func verifiersAreRandomAndURLSafe() {
        let pkce = PKCE()
        let urlSafe = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        #expect(pkce.verifier.count == 43)
        #expect(pkce.verifier.unicodeScalars.allSatisfy(urlSafe.contains))
        #expect(pkce.verifier != PKCE().verifier)
        #expect(pkce.challenge.count == 43)
        #expect(pkce.challenge.unicodeScalars.allSatisfy(urlSafe.contains))
        #expect(pkce.challenge == PKCE.challenge(for: pkce.verifier))
    }
}

struct KitePlusSignInTests {
    private let official = URL(string: "https://explore.kite.plus")!
    private let local = URL(string: "http://localhost:8080")!

    @Test func httpsCallbackOnlyOnTheClaimedServerWhenTurnedOn() {
        #expect(KitePlusSignIn.callback(for: official, httpsEnabled: true) == .https(host: "explore.kite.plus"))
        #expect(KitePlusSignIn.callback(for: URL(string: "https://Explore.Kite.Plus/")!, httpsEnabled: true) == .https(host: "explore.kite.plus"))
        #expect(KitePlusSignIn.callback(for: official, httpsEnabled: false) == .scheme)
        #expect(KitePlusSignIn.callback(for: URL(string: "https://explore.example.com")!, httpsEnabled: true) == .scheme)
        #expect(KitePlusSignIn.callback(for: URL(string: "http://explore.kite.plus")!, httpsEnabled: true) == .scheme)
        #expect(KitePlusSignIn.callback(for: URL(string: "https://explore.kite.plus:8443")!, httpsEnabled: true) == .scheme)
        #expect(KitePlusSignIn.callback(for: local, httpsEnabled: true) == .scheme)
    }

    @Test func httpsCallbackIsOffInThisBuild() {
        #expect(!KitePlusSignIn.httpsCallbackEnabled)
    }

    @Test func startAddressAsksForTheSchemeCallback() {
        let url = KitePlusSignIn.startURL(server: local, challenge: "abc-_", switchAccount: false, callback: .scheme)
        #expect(url.absoluteString == "http://localhost:8080/auth/app/start?challenge=abc-_&client=ios&callback=scheme")
    }

    @Test func startAddressForAnotherAccountOnTheClaimedServer() {
        let url = KitePlusSignIn.startURL(
            server: official, challenge: "abc", switchAccount: true, callback: .https(host: "explore.kite.plus")
        )
        #expect(url.absoluteString == "https://explore.kite.plus/auth/app/start?challenge=abc&client=ios&switch=1")
    }

    @Test func readsTheCode() throws {
        let scheme = try KitePlusSignIn.code(from: URL(string: "explore://app/auth/done?code=Xy-_1")!, expecting: .scheme)
        #expect(scheme == "Xy-_1")
        let https = try KitePlusSignIn.code(
            from: URL(string: "https://explore.kite.plus/app/auth/done?code=Xy-_1")!, expecting: .https(host: "explore.kite.plus")
        )
        #expect(https == "Xy-_1")
    }

    @Test(arguments: [
        ("login_expired", KitePlusSignInError.loginExpired),
        ("login_failed", .loginFailed),
        ("access_denied", .accessDenied),
        ("unavailable", .unavailable),
        ("account_disabled", .accountDisabled),
        ("email_in_use", .emailInUse),
        ("email_unverified", .emailUnverified),
        ("registration_closed", .registrationClosed),
        ("something_new", .loginFailed),
    ])
    func mapsTheServersErrors(code: String, error: KitePlusSignInError) {
        #expect(throws: error) {
            try KitePlusSignIn.code(from: URL(string: "explore://app/auth/done?error=\(code)")!, expecting: .scheme)
        }
    }

    @Test(arguments: [
        "explore://app/auth/done",
        "explore://app/auth/done?code=",
        "explore://blogs/example.com?code=abc",
        "https://explore.kite.plus/app/auth/done?code=abc",
    ])
    func refusesAddressesWithoutACodeForThisSignIn(address: String) {
        #expect(throws: KitePlusSignInError.loginFailed) {
            try KitePlusSignIn.code(from: URL(string: address)!, expecting: .scheme)
        }
    }

    @Test func refusesTheCallbackOfAnotherHost() {
        #expect(throws: KitePlusSignInError.loginFailed) {
            try KitePlusSignIn.code(
                from: URL(string: "https://evil.example/app/auth/done?code=abc")!, expecting: .https(host: "explore.kite.plus")
            )
        }
    }

    @Test func eachErrorSaysSomethingOfItsOwn() {
        let errors: [KitePlusSignInError] = [
            .loginExpired, .loginFailed, .accessDenied, .unavailable, .accountDisabled, .emailInUse, .emailUnverified,
            .registrationClosed,
        ]
        let messages = errors.map(\.readableMessage)
        #expect(messages.allSatisfy { !$0.isEmpty })
        #expect(Set(messages).count == errors.count)
    }
}

struct AuthOptionsTests {
    private let decoder = JSONDecoder()

    @Test func kitePlus() throws {
        let json = #"{"password":true,"oidc":{"name":"Kite Plus account","account_url":"https://id.kite.plus/ui/console/users/me"}}"#
        let options = try decoder.decode(AuthOptions.self, from: Data(json.utf8))
        #expect(options.password)
        #expect(options.kitePlus?.name == "Kite Plus account")
        #expect(options.kitePlus?.accountURL == "https://id.kite.plus/ui/console/users/me")
    }

    @Test func passwordOnly() throws {
        let options = try decoder.decode(AuthOptions.self, from: Data(#"{"password":true,"oidc":null}"#.utf8))
        #expect(options == .passwordOnly)
        #expect(try decoder.decode(AuthOptions.self, from: Data("{}".utf8)) == .passwordOnly)
    }
}

struct UserDecodingTests {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = RFC3339.decoding
        return decoder
    }()

    @Test func linkedToKitePlus() throws {
        let json = """
        {"id":"9f1","email":"a@example.com","display_name":"A","is_admin":false,"csrf_token":"abc",
        "password_login":false,"identity_linked_at":"2026-10-10T08:00:00.123456789Z"}
        """
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.passwordLogin == false)
        #expect(user.isLinkedToKitePlus)
    }

    @Test func notLinked() throws {
        let json = """
        {"id":"9f1","email":"a@example.com","display_name":"A","is_admin":false,"csrf_token":"abc",
        "password_login":true,"identity_linked_at":null}
        """
        let user = try decoder.decode(User.self, from: Data(json.utf8))
        #expect(user.passwordLogin == true)
        #expect(!user.isLinkedToKitePlus)
    }
}

@MainActor
struct SignInDeepLinkTests {
    @Test func leavesSignInCallbacksAlone() {
        let app = AppModel()
        app.tab = .me
        app.open(URL(string: "explore://app/auth/done?code=abc")!)
        app.open(URL(string: "https://explore.kite.plus/app/auth/done?code=abc")!)
        #expect(app.tab == .me)
        #expect(app.sheet == nil)
    }
}
