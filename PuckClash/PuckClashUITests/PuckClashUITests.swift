//
//  PuckClashUITests.swift
//  PuckClashUITests
//
//  Created by yuuki kounishi on 2026/06/24.
//

import XCTest

final class PuckClashUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testStartButtonExistsOnLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // The start screen is the entry point; its Start button must be present,
        // along with the Settings and How to Play entries.
        let startButton = app.buttons["start-match-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings-button"].exists)
        XCTAssertTrue(app.buttons["how-to-play-button"].exists)
    }

    @MainActor
    func testSettingsScreenOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsButton = app.buttons["settings-button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["settings-screen"].waitForExistence(timeout: 5))

        let closeButton = app.buttons["close-settings-button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        // Back on the home screen; the settings screen is gone.
        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["settings-screen"].exists)
    }

    @MainActor
    func testHowToPlayScreenOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launch()

        let howToPlayButton = app.buttons["how-to-play-button"]
        XCTAssertTrue(howToPlayButton.waitForExistence(timeout: 5))
        howToPlayButton.tap()

        XCTAssertTrue(app.staticTexts["how-to-play-screen"].waitForExistence(timeout: 5))

        let closeButton = app.buttons["close-how-to-play-button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["how-to-play-screen"].exists)
    }

    @MainActor
    func testCPUPracticeFlowReachesMatch() throws {
        let app = XCUIApplication()
        app.launch()

        // Start -> Mode Select -> Map Select -> Match.
        let startButton = app.buttons["start-match-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let cpuCard = app.buttons["mode-cpu-practice"]
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5))
        cpuCard.tap()

        let classicMap = app.buttons["map-classic"]
        XCTAssertTrue(classicMap.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["map-wide"].exists)
        XCTAssertTrue(app.buttons["map-speed"].exists)
        classicMap.tap()

        // The match screen shows the fixed virtual joystick.
        let joystick = app.otherElements["joystick-control"]
        XCTAssertTrue(joystick.waitForExistence(timeout: 5))
    }

    @MainActor
    func testBoostAndShotUsableInMatchAndBlockLocked() throws {
        let app = XCUIApplication()
        app.launch()

        // Start -> Mode Select -> Map Select -> Match.
        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        app.buttons["start-match-button"].tap()
        XCTAssertTrue(app.buttons["mode-cpu-practice"].waitForExistence(timeout: 5))
        app.buttons["mode-cpu-practice"].tap()
        let classicMap = app.buttons["map-classic"]
        XCTAssertTrue(classicMap.waitForExistence(timeout: 5))
        classicMap.tap()

        // Boost and Shot are enabled and tappable; only Block remains locked (disabled).
        let boost = app.buttons["skill-boost-button"]
        XCTAssertTrue(boost.waitForExistence(timeout: 5))
        XCTAssertTrue(boost.isEnabled)
        let shot = app.buttons["skill-shot-button"]
        XCTAssertTrue(shot.exists)
        XCTAssertTrue(shot.isEnabled)
        let block = app.buttons["skill-block-button"]
        XCTAssertTrue(block.exists)
        XCTAssertFalse(block.isEnabled)
        // Block announces its not-yet-available state.
        XCTAssertEqual(block.value as? String, "準備中")

        boost.tap()
        shot.tap()

        // The match keeps running: the joystick is still present after activating.
        XCTAssertTrue(app.otherElements["joystick-control"].exists)
    }

    @MainActor
    func testOnlineMatchShowsComingSoon() throws {
        let app = XCUIApplication()
        app.launch()

        let startButton = app.buttons["start-match-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let onlineCard = app.buttons["mode-online-match"]
        XCTAssertTrue(onlineCard.waitForExistence(timeout: 5))
        onlineCard.tap()

        // The online entry only shows a placeholder; it must not enter a match.
        let comingSoon = app.staticTexts["online-coming-soon"]
        XCTAssertTrue(comingSoon.waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["joystick-control"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
