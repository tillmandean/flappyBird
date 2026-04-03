//
//  flappyBirdUITests.swift
//  flappyBirdUITests
//
//  Created by Tillman Dean on 4/2/26.
//

import XCTest

final class flappyBirdUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // Sends a touch at the centre of the screen, bypassing the accessibility tree.
    // app.tap() routes to the Application container and never reaches the Canvas TapGesture.
    private func tapGame() {
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    // MARK: - Start Screen

    @MainActor
    func testStartScreen_showsTitle() throws {
        XCTAssertTrue(app.staticTexts["Flappy Bird"].exists)
    }

    @MainActor
    func testStartScreen_showsTapToStart() throws {
        XCTAssertTrue(app.staticTexts["Tap to Start"].exists)
    }

    @MainActor
    func testStartScreen_doesNotShowGameOver() throws {
        XCTAssertFalse(app.staticTexts["Game Over"].exists)
    }

    // MARK: - Gameplay

    @MainActor
    func testTap_dismissesStartScreen() throws {
        tapGame()
        XCTAssertTrue(app.staticTexts["Tap to Start"].waitForNonExistence(timeout: 2))
    }

    @MainActor
    func testTap_showsScoreLabel() throws {
        tapGame()
        XCTAssertTrue(app.staticTexts["0"].exists)
    }

    // MARK: - Game Over

    @MainActor
    func testGameOver_appearsAfterBirdFalls() throws {
        tapGame() // start the game; without further input the bird falls to the ground
        XCTAssertTrue(app.staticTexts["Game Over"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testGameOver_showsRetryButton() throws {
        tapGame()
        guard app.staticTexts["Game Over"].waitForExistence(timeout: 8) else {
            XCTFail("Game Over screen did not appear")
            return
        }
        XCTAssertTrue(app.buttons["Tap to Retry"].exists)
    }

    @MainActor
    func testRetryButton_returnsToStartScreen() throws {
        tapGame()
        guard app.staticTexts["Game Over"].waitForExistence(timeout: 8) else {
            XCTFail("Game Over screen did not appear")
            return
        }
        app.buttons["Tap to Retry"].tap()
        XCTAssertTrue(app.staticTexts["Flappy Bird"].waitForExistence(timeout: 3))
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
