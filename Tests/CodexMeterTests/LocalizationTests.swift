import Foundation
import XCTest
@testable import CodexMeter

final class LocalizationTests: XCTestCase {
    func testLoadsSupportedCJKLocalizations() {
        XCTAssertEqual(L10n.text("settings.smartAlerts", languageCode: "zh-Hans"), "智能提醒")
        XCTAssertEqual(L10n.text("settings.smartAlerts", languageCode: "ja"), "スマート通知")
        XCTAssertEqual(L10n.text("settings.smartAlerts", languageCode: "ko"), "스마트 알림")
    }

    func testFormatsLocalizedStringsWithArguments() {
        XCTAssertEqual(L10n.text("notification.threshold.title", languageCode: "zh-Hans", 20), "Codex 容量低于 20%")
        XCTAssertEqual(L10n.text("statusItem.remaining.hoursMinutes", languageCode: "ja", 2, 14), "2時間14分")
        XCTAssertEqual(L10n.text("usage.percentRemaining", languageCode: "ko", 67), "67% 남음")
    }

    func testStaticPercentStringsUseSinglePercentSigns() {
        XCTAssertEqual(L10n.text("settings.warnBelow20", languageCode: "en"), "Warn below 20%")
        XCTAssertEqual(L10n.text("statusItem.preview.primaryAndWeekly", languageCode: "zh-Hans"), "5小时 83% · 周 71%")
    }

    func testMissingLocalizationFallsBackToKey() {
        XCTAssertEqual(L10n.text("missing.localization.key", languageCode: "zh-Hans"), "missing.localization.key")
    }

    func testSupportedLocalizationsShareEnglishKeySet() throws {
        let englishKeys = try Self.localizationKeys(for: "en")
        XCTAssertFalse(englishKeys.isEmpty)

        for languageCode in Self.supportedLanguageCodes where languageCode != "en" {
            XCTAssertEqual(
                try Self.localizationKeys(for: languageCode),
                englishKeys,
                "\(languageCode) Localizable.strings must match the English key set."
            )
        }
    }

    private static let supportedLanguageCodes = ["en", "zh-Hans", "ja", "ko"]

    private static func localizationKeys(for languageCode: String) throws -> Set<String> {
        let url = resourceRoot
            .appendingPathComponent("\(languageCode).lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)

        guard let dictionary = plist as? [String: String] else {
            throw NSError(
                domain: "CodexMeter.LocalizationTests",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(languageCode) Localizable.strings did not parse as a string dictionary."]
            )
        }

        return Set(dictionary.keys)
    }

    private static var resourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/CodexMeter/Resources")
    }
}
