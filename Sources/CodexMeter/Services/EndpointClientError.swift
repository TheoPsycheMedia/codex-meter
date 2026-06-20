import Foundation

enum EndpointClientError: Error {
    case invalidResponse(endpoint: WidgetEndpoint)
    case httpFailure(statusCode: Int, endpoint: WidgetEndpoint)
    case decodeFailure(EndpointFailure)
    case validationFailure(EndpointFailure)
    case transportFailure(Error, endpoint: WidgetEndpoint)

    var failure: EndpointFailure {
        switch self {
        case .invalidResponse(let endpoint):
            return EndpointFailure(
                endpoint: endpoint,
                category: .invalidResponse,
                message: "The \(endpoint.title.lowercased()) service returned an invalid response.",
                recoverySuggestion: "Try refreshing again."
            )
        case .httpFailure(let statusCode, let endpoint):
            if statusCode == 401 || statusCode == 403 {
                return EndpointFailure(
                    endpoint: endpoint,
                    category: .expiredSession,
                    statusCode: statusCode,
                    message: "Codex sign-in is not authorized for \(endpoint.title.lowercased()) lookup.",
                    recoverySuggestion: "Sign in to Codex again, then refresh."
                )
            }

            return EndpointFailure(
                endpoint: endpoint,
                category: .httpFailure,
                statusCode: statusCode,
                message: "The \(endpoint.title.lowercased()) service returned HTTP \(statusCode).",
                recoverySuggestion: "Try again in a moment."
            )
        case .decodeFailure(let failure), .validationFailure(let failure):
            return failure
        case .transportFailure(let error, let endpoint):
            return EndpointFailure(
                endpoint: endpoint,
                category: .networkFailure,
                message: sanitizedTransportMessage(error),
                recoverySuggestion: "Check your connection, then refresh."
            )
        }
    }

    private func sanitizedTransportMessage(_ error: Error) -> String {
        if let urlError = error as? URLError {
            return "Network error: \(urlError.code)"
        }

        return "Network error while loading endpoint data."
    }
}

enum EndpointResponseDecoder {
    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        endpoint: WidgetEndpoint,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw EndpointClientError.decodeFailure(
                failure(from: error, data: data, endpoint: endpoint)
            )
        }
    }

    static func topLevelKeys(from data: Data) -> [String] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let dictionary = object as? [String: Any]
        else {
            return []
        }

        return dictionary.keys.sorted()
    }

    /// Privacy-preserving view of the response shape: reports only the keys this
    /// app already knows about by name, and collapses any unexpected, server-
    /// controlled keys into a redacted count. This prevents "Copy Diagnostics"
    /// from ever placing an unknown key name (e.g. a future `account_id`) on the
    /// user's clipboard.
    static func recognizedKeys(from data: Data, endpoint: WidgetEndpoint) -> [String] {
        let keys = topLevelKeys(from: data)
        guard !keys.isEmpty else {
            return []
        }

        let known = keys.filter { endpoint.knownTopLevelKeys.contains($0) }
        let unrecognizedCount = keys.count - known.count

        guard unrecognizedCount > 0 else {
            return known
        }

        return known + ["+\(unrecognizedCount) unrecognized"]
    }

    private static func failure(from error: Error, data: Data, endpoint: WidgetEndpoint) -> EndpointFailure {
        let keys = recognizedKeys(from: data, endpoint: endpoint)
        let category: EndpointFailureCategory = topLevelKeys(from: data).isEmpty ? .malformedPayload : .schemaMismatch
        let path = decoderPath(from: error)
        let expectedType = String(describing: endpoint.title)

        return EndpointFailure(
            endpoint: endpoint,
            category: category,
            decoderPath: path,
            recognizedKeys: keys,
            message: "Could not decode \(expectedType) response.",
            recoverySuggestion: "Copy diagnostics and report the endpoint shape."
        )
    }

    private static func decoderPath(from error: Error) -> String? {
        guard let decodingError = error as? DecodingError else {
            return nil
        }

        let path: [CodingKey]
        switch decodingError {
        case .typeMismatch(_, let context),
             .valueNotFound(_, let context),
             .keyNotFound(_, let context),
             .dataCorrupted(let context):
            path = context.codingPath
        @unknown default:
            return nil
        }

        guard !path.isEmpty else {
            return "$"
        }

        return path.map { key in
            if let index = key.intValue {
                return String(index)
            }

            return key.stringValue
        }
        .joined(separator: ".")
    }
}
