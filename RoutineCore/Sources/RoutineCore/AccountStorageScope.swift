import Foundation

/// Storage routing only: a scope never authenticates a user or authorizes server requests.
public enum AccountStorageScope: Equatable, Sendable {
    case guest
    case account(String)

    public var defaultsSuiteName: String? {
        switch self {
        case .guest: return nil // Preserve the existing local-only install's defaults.
        case .account(let userID):
            let encoded = Data(userID.utf8).base64EncodedString()
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
            return "bloomward.account.\(encoded)"
        }
    }
}
