import XCTest

@MainActor
final class ToDoUITests: XCTestCase {
    private func launch(_ mode: String = "--demo") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [mode, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    func testLoginValidationAndRegistration() {
        let app = launch("--demo-auth")
        XCTAssertTrue(app.buttons["submitAuth"].waitForExistence(timeout: 10))
        app.buttons["submitAuth"].tap()
        XCTAssertTrue(app.staticTexts["Enter your email."].exists)
        XCTAssertTrue(app.staticTexts["Enter your password."].exists)
        app.swipeUp()
        app.buttons["registerLink"].tap()
        app.buttons["submitAuth"].tap()
        XCTAssertTrue(app.staticTexts["Enter your email."].exists)
        let email = app.textFields["emailField"]
        email.tap(); email.typeText("ios@example.com")
        let password = app.secureTextFields["passwordField"]
        password.tap(); password.typeText("password123")
        let confirm = app.secureTextFields["confirmationField"]
        confirm.tap(); confirm.typeText("password123\n")
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 10))
    }

    func testCreateEditAndDeleteTask() {
        let app = launch()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 10))
        app.buttons["addTask"].tap()
        let title = app.descendants(matching: .any)["taskTitle"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap(); title.typeText("Native SwiftUI task")
        app.buttons["saveTask"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'todoRow-' AND label CONTAINS 'Native SwiftUI task'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["status-DONE"].tap()
        app.buttons["saveTask"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Done"))
        row.tap()
        app.swipeUp()
        app.buttons["deleteTask"].tap()
        app.buttons.matching(NSPredicate(format: "label == 'Delete task' AND identifier != 'deleteTask'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
    }

    func testPeriodsDiscardAndSignOut() {
        let app = launch()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 10))
        app.segmentedControls["periodPicker"].buttons["Week"].tap()
        XCTAssertTrue(app.buttons["todoRow-00000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 5))
        app.segmentedControls["periodPicker"].buttons["Month"].tap()
        app.buttons["addTask"].tap()
        let title = app.descendants(matching: .any)["taskTitle"].firstMatch
        title.tap(); title.typeText("Unsaved task")
        app.buttons["cancelEditor"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unsaved task"].exists)
        app.buttons["accountMenu"].tap()
        app.buttons["Sign out"].tap()
        app.buttons["Sign out"].tap()
        XCTAssertTrue(app.buttons["submitAuth"].waitForExistence(timeout: 5))
    }
}
