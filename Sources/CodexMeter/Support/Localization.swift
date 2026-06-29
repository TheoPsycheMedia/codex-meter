import Foundation

enum L10n {
    /// Reads localized strings from the SwiftPM resource bundle, falling back to the key when missing.
    static func text(_ key: String) -> String {
        localizedString(for: key)
    }

    /// Reads formatted localized strings. Callers must pass arguments that match the string placeholders.
    static func text(_ key: String, _ arguments: CVarArg...) -> String {
        format(key, arguments: arguments)
    }

    static func text(_ key: String, languageCode: String) -> String {
        localizedString(for: key, languageCode: languageCode)
    }

    static func text(_ key: String, languageCode: String, _ arguments: CVarArg...) -> String {
        format(key, languageCode: languageCode, arguments: arguments)
    }

    private static func format(_ key: String, languageCode: String? = nil, arguments: [CVarArg]) -> String {
        let template = localizedString(for: key, languageCode: languageCode)
        return String(format: template, locale: Locale.current, arguments: arguments)
    }

    private static func localizedString(for key: String, languageCode: String? = nil) -> String {
        let bundle = languageBundle(for: languageCode)
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    private static func languageBundle(for languageCode: String?) -> Bundle {
        let resourceBundle = appResourceBundle ?? Bundle.module

        guard let languageCode else {
            return resourceBundle
        }

        for candidate in [languageCode, languageCode.lowercased()] {
            if let path = resourceBundle.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }

        return resourceBundle
    }

    private static let appResourceBundle: Bundle? = {
        let bundleName = "CodexMeter_CodexMeter"
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL
        ]

        for baseURL in candidates.compactMap({ $0 }) {
            let url = baseURL.appendingPathComponent(bundleName).appendingPathExtension("bundle")
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }

        return nil
    }()
}
