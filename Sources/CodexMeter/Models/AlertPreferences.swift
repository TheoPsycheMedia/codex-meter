import Foundation

struct SmartAlertPreferences {
    var enabled: Bool
    var capacityThresholdsEnabled: Bool
    var threshold20Percent: Bool
    var threshold10Percent: Bool
    var threshold5Percent: Bool
    var projectedRunoutEnabled: Bool
    var creditsExpireSoonEnabled: Bool
    var resetCreditReturnedEnabled: Bool

    func enabledPercentages() -> [Int] {
        var percentages: [Int] = []
        if threshold20Percent { percentages.append(20) }
        if threshold10Percent { percentages.append(10) }
        if threshold5Percent { percentages.append(5) }
        return percentages
    }
}
