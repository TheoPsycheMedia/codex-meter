import Foundation

struct UsageClient: Sendable {
    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage(credentials: CodexAuthCredentials) async throws -> UsageResponse {
        let request = CodexBackendRequest.make(
            url: endpoint,
            credentials: credentials,
            usesPricingChooser: true
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw EndpointClientError.transportFailure(error, endpoint: .usage)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EndpointClientError.invalidResponse(endpoint: .usage)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw EndpointClientError.httpFailure(statusCode: httpResponse.statusCode, endpoint: .usage)
        }

        let decoded = try EndpointResponseDecoder.decode(UsageResponse.self, from: data, endpoint: .usage)
        guard decoded.hasUsableUsageWindow else {
            throw EndpointClientError.validationFailure(
                EndpointFailure(
                    endpoint: .usage,
                    category: .schemaMismatch,
                    recognizedKeys: EndpointResponseDecoder.recognizedKeys(from: data, endpoint: .usage),
                    message: L10n.text("endpointError.usage.noUsableWindow"),
                    recoverySuggestion: L10n.text("endpointError.recovery.copyDiagnostics")
                )
            )
        }

        return decoded
    }
}

private extension UsageResponse {
    var hasUsableUsageWindow: Bool {
        rateLimit?.primaryWindow != nil
            || rateLimit?.secondaryWindow != nil
            || additionalRateLimits.contains { $0.rateLimit.primaryWindow != nil || $0.rateLimit.secondaryWindow != nil }
    }
}
