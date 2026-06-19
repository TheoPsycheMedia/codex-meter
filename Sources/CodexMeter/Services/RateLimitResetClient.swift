import Foundation

struct RateLimitResetClient: Sendable {
    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!

    func fetchCredits(accessToken: String) async throws -> RateLimitResetResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw EndpointClientError.transportFailure(error, endpoint: .resetCredits)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EndpointClientError.invalidResponse(endpoint: .resetCredits)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw EndpointClientError.httpFailure(statusCode: httpResponse.statusCode, endpoint: .resetCredits)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(CreditDateDecoder.decode)
        let decoded = try EndpointResponseDecoder.decode(
            RateLimitResetResponse.self,
            from: data,
            endpoint: .resetCredits,
            decoder: decoder
        )

        guard decoded.availableCount >= 0 else {
            throw EndpointClientError.validationFailure(
                EndpointFailure(
                    endpoint: .resetCredits,
                    category: .schemaMismatch,
                    recognizedKeys: EndpointResponseDecoder.topLevelKeys(from: data),
                    message: "Reset-credit response contained a negative available count.",
                    recoverySuggestion: "Copy diagnostics and report the endpoint shape."
                )
            )
        }

        return decoded
    }
}
