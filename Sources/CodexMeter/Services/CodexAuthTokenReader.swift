import Foundation

struct CodexAuthCredentials {
    let accessToken: String
    let accountID: String
}

struct CodexAuthTokenReader {
    private let authURL: URL

    init(authURL: URL = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/auth.json")) {
        self.authURL = authURL
    }

    func credentials() throws -> CodexAuthCredentials {
        guard FileManager.default.fileExists(atPath: authURL.path) else {
            throw CodexAuthError.missingAuthFile
        }

        let data = try Data(contentsOf: authURL)
        let authFile = try JSONDecoder().decode(CodexAuthFile.self, from: data)
        let token = authFile.tokens.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !token.isEmpty else {
            throw CodexAuthError.missingAccessToken
        }

        let accountID = authFile.tokens.accountID?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !accountID.isEmpty else {
            throw CodexAuthError.missingAccountID
        }

        return CodexAuthCredentials(accessToken: token, accountID: accountID)
    }
}

private struct CodexAuthFile: Decodable {
    let tokens: CodexTokens
}

private struct CodexTokens: Decodable {
    let accessToken: String
    let accountID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case accountID = "account_id"
    }
}

enum CodexAuthError: LocalizedError, Equatable {
    case missingAuthFile
    case missingAccessToken
    case missingAccountID

    var errorDescription: String? {
        switch self {
        case .missingAuthFile:
            return L10n.text("auth.error.missingFile")
        case .missingAccessToken:
            return L10n.text("auth.error.missingAccessToken")
        case .missingAccountID:
            return L10n.text("auth.error.missingAccountID")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingAuthFile:
            return L10n.text("failure.detail.missingAuth")
        case .missingAccessToken:
            return L10n.text("auth.recovery.refreshSignIn")
        case .missingAccountID:
            return L10n.text("auth.recovery.selectAccount")
        }
    }
}
