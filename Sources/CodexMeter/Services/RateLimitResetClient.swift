import Foundation

struct RateLimitResetClient: Sendable {
    private let endpoint = URL(string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchCredits(credentials: CodexAuthCredentials) async throws -> RateLimitResetResponse {
        let request = CodexBackendRequest.make(url: endpoint, credentials: credentials)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
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
                    recognizedKeys: EndpointResponseDecoder.recognizedKeys(from: data, endpoint: .resetCredits),
                    message: L10n.text("endpointError.resetCredits.negativeCount"),
                    recoverySuggestion: L10n.text("endpointError.recovery.copyDiagnostics")
                )
            )
        }

        return decoded
    }
}
