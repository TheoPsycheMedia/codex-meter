import Foundation

struct UsageClient: Sendable {
    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func fetchUsage(accessToken: String) async throws -> UsageResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
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
                    recognizedKeys: EndpointResponseDecoder.topLevelKeys(from: data),
                    message: "Usage response did not contain a usable Codex window.",
                    recoverySuggestion: "Copy diagnostics and report the endpoint shape."
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
