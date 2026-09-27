import XCTest
@testable import planora

@MainActor
final class HelpCenterTests: XCTestCase {
    func testEveryArticleHasJapaneseCopyAndStableUniqueID() {
        let articles = PlanoraHelpContent.categories.flatMap(\.articles)
        XCTAssertEqual(Set(articles.map(\.id)).count, articles.count)
        for category in PlanoraHelpContent.categories {
            XCTAssertNotNil(category.title.ja, category.id)
            for article in category.articles {
                XCTAssertFalse(article.title.ja?.isEmpty ?? true, article.id)
                XCTAssertFalse(article.body.ja?.isEmpty ?? true, article.id)
            }
        }
    }

    func testSearchUsesSelectedLanguageAndTrimsWhitespace() {
        for (locale, query) in [("en", " attendance "), ("zh-Hans", " 出勤 "), ("ja", " 出席 ")] {
            XCTAssertFalse(PlanoraHelpContent.search(query, locale: Locale(identifier: locale)).isEmpty)
        }
        XCTAssertTrue(PlanoraHelpContent.search("no-such-help-article", locale: .current).isEmpty)
        XCTAssertEqual(PlanoraHelpContent.search(" \n", locale: .current, categoryID: "results").map(\.id), ["results"])
    }
}
