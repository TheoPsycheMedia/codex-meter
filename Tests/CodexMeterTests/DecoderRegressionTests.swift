import XCTest
@testable import CodexMeter

final class DecoderRegressionTests: XCTestCase {
    func testUsageDecoderAcceptsExpectedPayload() throws {
        let response = try decodeFixture("usage-success", as: UsageResponse.self)

        XCTAssertEqual(response.planType, "plus")
        XCTAssertEqual(response.rateLimit?.primaryWindow?.remainingPercent, 87)
        XCTAssertEqual(response.rateLimit?.secondaryWindow?.remainingPercent, 58)
        XCTAssertEqual(response.additionalRateLimits.first?.displayName, "Codex-Spark")
        XCTAssertEqual(response.rateLimitResetCredits?.availableCount, 2)
    }

    func testUsageDecoderToleratesMissingOptionalAndExtraFields() throws {
        let response = try decodeFixture("usage-missing-optional-extra", as: UsageResponse.self)

        XCTAssertNil(response.planType)
        XCTAssertEqual(response.rateLimit?.primaryWindow?.usedPercent, 25)
        XCTAssertEqual(response.rateLimit?.primaryWindow?.limitWindowSeconds, 0)
        XCTAssertEqual(response.additionalRateLimits.first?.meteredFeature, "unknown_meter")
        XCTAssertEqual(response.additionalRateLimits.first?.rateLimit.secondaryWindow?.remainingPercent, 25)
    }

    func testUsageSchemaShiftKeepsRecognizedKeysOnly() throws {
        let data = try fixtureData("usage-schema-shift")

        XCTAssertThrowsError(
            try EndpointResponseDecoder.decode(UsageResponse.self, from: data, endpoint: .usage)
        ) { error in
            let failure = (error as? EndpointClientError)?.failure
            XCTAssertEqual(failure?.category, .schemaMismatch)
            XCTAssertEqual(failure?.recognizedKeys, ["additional_rate_limits", "rate_limit"])
            XCTAssertEqual(failure?.decoderPath, "rate_limit.primary_window")
        }
    }

    func testResetCreditDecoderAcceptsExpectedPayload() throws {
        let response = try decodeResetFixture("reset-success")

        XCTAssertEqual(response.availableCount, 2)
        XCTAssertEqual(response.credits.count, 2)
        XCTAssertTrue(response.credits[0].isAvailable)
        XCTAssertEqual(response.credits[1].resetType, "rate_limit_reset")
    }

    func testResetCreditDecoderDerivesMissingAvailableCount() throws {
        let response = try decodeResetFixture("reset-missing-count")

        XCTAssertEqual(response.availableCount, 1)
        XCTAssertEqual(response.credits.count, 2)
    }

    func testResetCreditMalformedDateIsSchemaMismatch() throws {
        let data = try fixtureData("reset-malformed-date")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(CreditDateDecoder.decode)

        XCTAssertThrowsError(
            try EndpointResponseDecoder.decode(
                RateLimitResetResponse.self,
                from: data,
                endpoint: .resetCredits,
                decoder: decoder
            )
        ) { error in
            let failure = (error as? EndpointClientError)?.failure
            XCTAssertEqual(failure?.category, .schemaMismatch)
            XCTAssertEqual(failure?.decoderPath, "credits.0.granted_at")
            XCTAssertEqual(failure?.recognizedKeys, ["available_count", "credits"])
        }
    }

    private func decodeResetFixture(_ name: String) throws -> RateLimitResetResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(CreditDateDecoder.decode)
        return try decodeFixture(name, as: RateLimitResetResponse.self, decoder: decoder)
    }

    private func decodeFixture<T: Decodable>(
        _ name: String,
        as type: T.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        try decoder.decode(type, from: fixtureData(name))
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json")
        )
        return try Data(contentsOf: url)
    }
}
