import XCTest

final class NazlahUITests: XCTestCase {
    func testLaunchAndReachHomeAfterOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitesting"]
        app.launch()
        if app.buttons["ابدأ"].exists {
            if app.buttons["التالي"].exists {
                app.buttons["التالي"].tap()
                app.buttons["التالي"].tap()
            }
            app.buttons["ابدأ"].tap()
        }
        XCTAssertTrue(app.tabBars.buttons.count >= 1)
    }
}
