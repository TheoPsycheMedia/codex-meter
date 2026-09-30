import Foundation
import XCTest
@testable import CodexMeter

final class UsageClientTests: XCTestCase, @unchecked Sendable {
    private let credentials = CodexAuthCredentials(accessToken: "test-token", accountID: "test-account")

    func testUsageRequestMatchesOfficialAccountAndPricingContext() async throws {
        UsageProtocol.stub.set { request in
            XCTAssertEqual(request.url?.absoluteString, "https://chatgpt.com/backend-api/wham/usage")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "test-account")
            XCTAssertEqual(request.value(forHTTPHeaderField: "OAI-App-Brand"), "chatgpt")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-openai-codex-pricing-chooser"), "1")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            return (200, Data(Self.weeklyUsage.utf8))
        }
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let usage = try await UsageClient(session: session).fetchUsage(credentials: credentials)
        let weekly = try XCTUnwrap(usage.rateLimit?.weeklyWindow)
        XCTAssertEqual(weekly.usedPercent, 23)
        XCTAssertEqual(weekly.remainingPercent, 77)
        XCTAssertEqual(weekly.durationTitle, "Weekly")
        XCTAssertEqual(weekly.resetAt, Date(timeIntervalSince1970: 1_735_693_200))
        XCTAssertNil(usage.rateLimit?.secondaryWindow)
        XCTAssertTrue(usage.additionalRateLimits.isEmpty)
    }

    func testResetCreditsUseTheSameSelectedAccount() async throws {
        UsageProtocol.stub.set { request in
            XCTAssertEqual(request.url?.path, "/backend-api/wham/rate-limit-reset-credits")
            XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-Id"), "test-account")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            return (200, Data(#"{"available_count":4,"credits":[]}"#.utf8))
        }
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let credits = try await RateLimitResetClient(session: session).fetchCredits(credentials: credentials)
        XCTAssertEqual(credits.availableCount, 4)
    }

    func testUnauthorizedUsageDoesNotBecomeAnAvailablePercentage() async throws {
        UsageProtocol.stub.set { _ in (401, Data("{}".utf8)) }
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        do {
            _ = try await UsageClient(session: session).fetchUsage(credentials: credentials)
            XCTFail("Unauthorized usage must fail instead of producing a meter reading.")
        } catch let error as EndpointClientError {
            XCTAssertEqual(error.failure.statusCode, 401)
        }
    }

    func testWeeklyWindowCanAppearInEitherBackendSlot() throws {
        let data = Data(Self.weeklyUsage.utf8)
        let primaryWeekly = try JSONDecoder().decode(UsageResponse.self, from: data)
        XCTAssertEqual(primaryWeekly.rateLimit?.weeklyWindow, primaryWeekly.rateLimit?.primaryWindow)

        let secondaryData = Data(Self.weeklyUsage.replacingOccurrences(
            of: "\"secondary_window\":null",
            with: "\"secondary_window\":{\"used_percent\":10,\"limit_window_seconds\":604800,\"reset_after_seconds\":3600,\"reset_at\":1735696800}"
        ).replacingOccurrences(of: "\"limit_window_seconds\":604800,\"reset_after_seconds\":7200", with: "\"limit_window_seconds\":18000,\"reset_after_seconds\":7200").utf8)
        let secondaryWeekly = try JSONDecoder().decode(UsageResponse.self, from: secondaryData)
        XCTAssertEqual(secondaryWeekly.rateLimit?.weeklyWindow, secondaryWeekly.rateLimit?.secondaryWindow)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UsageProtocol.self]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }

    // Synthetic payload: preserves the weekly-primary/null-secondary shape only.
    private static let weeklyUsage = #"{"plan_type":"pro","rate_limit":{"allowed":true,"limit_reached":false,"primary_window":{"used_percent":23,"limit_window_seconds":604800,"reset_after_seconds":7200,"reset_at":1735693200},"secondary_window":null},"additional_rate_limits":null}"#
}

private final class UsageProtocol: URLProtocol, @unchecked Sendable {
    static let stub = LockedUsageStub()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (status, data) = try Self.stub.get()(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class LockedUsageStub: @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (Int, Data)
    private let lock = NSLock()
    private var handler: Handler = { _ in throw URLError(.badServerResponse) }

    func set(_ handler: @escaping Handler) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
    }

    func get() -> Handler {
        lock.lock()
        defer { lock.unlock() }
        return handler
    }
}
