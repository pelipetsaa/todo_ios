import XCTest
import UIKit

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
        XCTAssertTrue(app.staticTexts["Welcome back! Sign in to see your todos."].exists)
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
        pastePassword("password123", into: password, in: app)
        let confirm = app.secureTextFields["confirmationField"]
        pastePassword("password123", into: confirm, in: app)
        app.buttons["submitAuth"].tap()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 10))
    }

    private func pastePassword(_ text: String, into field: XCUIElement, in app: XCUIApplication) {
        let savedClipboard = UIPasteboard.general.items
        defer { UIPasteboard.general.items = savedClipboard }
        UIPasteboard.general.string = text
        // Paste as one edit so the system password suggestion cannot consume individual keystrokes.
        field.press(forDuration: 1.1)
        let pasteButton = app.buttons["Paste"]
        if pasteButton.waitForExistence(timeout: 2) { pasteButton.tap() }
        else { app.menuItems["Paste"].tap() }
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
        app.segmentedControls["statusPicker"].buttons["Done"].tap()
        app.buttons["saveTask"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Done"))
        row.tap()
        app.buttons["deleteTask"].tap()
        app.alerts["Delete this todo?"].buttons["Delete"].tap()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 5))
        XCTAssertFalse(row.exists)
    }

    func testPeriodsBackAndSignOut() {
        let app = launch()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 10))
        app.segmentedControls["periodPicker"].buttons["This week"].tap()
        XCTAssertTrue(app.buttons["todoRow-00000000-0000-0000-0000-000000000001"].waitForExistence(timeout: 5))
        app.segmentedControls["periodPicker"].buttons["This month"].tap()
        app.buttons["addTask"].tap()
        let title = app.descendants(matching: .any)["taskTitle"].firstMatch
        title.tap(); title.typeText("Unsaved task")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["addTask"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unsaved task"].exists)
        app.buttons["logoutButton"].tap()
        XCTAssertTrue(app.buttons["submitAuth"].waitForExistence(timeout: 5))
    }
}
