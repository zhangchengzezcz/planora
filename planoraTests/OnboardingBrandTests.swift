import SwiftUI
import XCTest
@testable import planora

@MainActor
final class OnboardingBrandTests: XCTestCase {
    func testBothIconAppearancesAreBundled() {
        for name in ["PlanoraBrandLight", "PlanoraBrandDark"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "png"))
        }
    }

    func testIntroCopyCoversCurrentFeaturesInThreeLanguages() {
        let chinese = OnboardingCopy(locale: Locale(identifier: "zh-Hans"))
        XCTAssertTrue(chinese.coursesDetail.contains("成绩"))
        XCTAssertTrue(chinese.attendanceDetail.contains("七天"))
        let english = OnboardingCopy(locale: Locale(identifier: "en"))
        XCTAssertTrue(english.coursesDetail.contains("grades"))
        let japanese = OnboardingCopy(locale: Locale(identifier: "ja"))
        XCTAssertTrue(japanese.attendanceDetail.contains("7日間"))
        XCTAssertEqual(OnboardingCopy(locale: Locale(identifier: "fr")).subtitle, english.subtitle)
    }
}
