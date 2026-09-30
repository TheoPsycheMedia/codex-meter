import Foundation

enum CodexBackendRequest {
    static func make(
        url: URL,
        credentials: CodexAuthCredentials,
        usesPricingChooser: Bool = false
    ) -> URLRequest {
        // Usage depends on account and pricing context, not only the bearer token.
        // Bypass cached responses from an older account or request configuration.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountID, forHTTPHeaderField: "ChatGPT-Account-Id")
        request.setValue("chatgpt", forHTTPHeaderField: "OAI-App-Brand")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if usesPricingChooser {
            request.setValue("1", forHTTPHeaderField: "x-openai-codex-pricing-chooser")
        }
        return request
    }
}
