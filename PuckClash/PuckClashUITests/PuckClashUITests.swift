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
    func testSkillGuideOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launch()

        let skillGuideButton = app.buttons["skill-guide-button"]
        XCTAssertTrue(skillGuideButton.waitForExistence(timeout: 5))
        skillGuideButton.tap()

        // The guide lists all three skills.
        XCTAssertTrue(app.staticTexts["skill-guide-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["skill-guide-boost"].exists)
        XCTAssertTrue(app.staticTexts["skill-guide-shot"].exists)
        XCTAssertTrue(app.staticTexts["skill-guide-block"].exists)

        let closeButton = app.buttons["close-skill-guide-button"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        closeButton.tap()

        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["skill-guide-screen"].exists)
    }

    @MainActor
    func testCPUPracticeFlowReachesMatch() throws {
        let app = XCUIApplication()
        app.launch()

        // Start -> Mode Select -> CPU Difficulty Select -> Map Select -> Match.
        let startButton = app.buttons["start-match-button"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        startButton.tap()

        let cpuCard = app.buttons["mode-cpu-practice"]
        XCTAssertTrue(cpuCard.waitForExistence(timeout: 5))
        cpuCard.tap()

        let normalDifficulty = app.buttons["cpu-difficulty-normal"]
        XCTAssertTrue(normalDifficulty.waitForExistence(timeout: 5))
        normalDifficulty.tap()

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
    func testAllSkillButtonsUsableInMatch() throws {
        let app = XCUIApplication()
        app.launch()

        // Start -> Mode Select -> CPU Difficulty Select -> Map Select -> Match.
        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        app.buttons["start-match-button"].tap()
        XCTAssertTrue(app.buttons["mode-cpu-practice"].waitForExistence(timeout: 5))
        app.buttons["mode-cpu-practice"].tap()
        XCTAssertTrue(app.buttons["cpu-difficulty-normal"].waitForExistence(timeout: 5))
        app.buttons["cpu-difficulty-normal"].tap()
        let classicMap = app.buttons["map-classic"]
        XCTAssertTrue(classicMap.waitForExistence(timeout: 5))
        classicMap.tap()

        // The opening countdown runs first; skills unlock once it ends.
        let countdown = app.staticTexts["match-countdown-overlay"]
        XCTAssertTrue(countdown.waitForExistence(timeout: 5))
        XCTAssertTrue(countdown.waitForNonExistence(timeout: 8))

        // Boost, Shot and Block are all now enabled and tappable.
        let boost = app.buttons["skill-boost-button"]
        XCTAssertTrue(boost.waitForExistence(timeout: 5))
        XCTAssertTrue(boost.isEnabled)
        let shot = app.buttons["skill-shot-button"]
        XCTAssertTrue(shot.exists)
        XCTAssertTrue(shot.isEnabled)
        let block = app.buttons["skill-block-button"]
        XCTAssertTrue(block.exists)
        XCTAssertTrue(block.isEnabled)

        boost.tap()
        shot.tap()
        block.tap()

        // The match keeps running: the joystick is still present after activating.
        XCTAssertTrue(app.otherElements["joystick-control"].exists)
    }

    @MainActor
    func testCPUDifficultyScreenShowsAllOptionsAndBackReturns() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        app.buttons["start-match-button"].tap()
        XCTAssertTrue(app.buttons["mode-cpu-practice"].waitForExistence(timeout: 5))
        app.buttons["mode-cpu-practice"].tap()

        // The difficulty screen offers all three presets.
        XCTAssertTrue(app.staticTexts["cpu-difficulty-screen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["cpu-difficulty-easy"].exists)
        XCTAssertTrue(app.buttons["cpu-difficulty-normal"].exists)
        XCTAssertTrue(app.buttons["cpu-difficulty-hard"].exists)

        // Back returns to mode selection without entering a match.
        app.buttons["cpu-difficulty-back"].tap()
        XCTAssertTrue(app.buttons["mode-cpu-practice"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["joystick-control"].exists)
    }

    @MainActor
    func testHardDifficultyAlsoReachesMatch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        app.buttons["start-match-button"].tap()
        XCTAssertTrue(app.buttons["mode-cpu-practice"].waitForExistence(timeout: 5))
        app.buttons["mode-cpu-practice"].tap()
        XCTAssertTrue(app.buttons["cpu-difficulty-hard"].waitForExistence(timeout: 5))
        app.buttons["cpu-difficulty-hard"].tap()
        XCTAssertTrue(app.buttons["map-classic"].waitForExistence(timeout: 5))
        app.buttons["map-classic"].tap()

        XCTAssertTrue(app.otherElements["joystick-control"].waitForExistence(timeout: 5))
    }

    // Shared navigation: Start -> CPU Practice -> Normal -> Classic -> Match.
    @MainActor
    private func enterMatch(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        app.buttons["start-match-button"].tap()
        XCTAssertTrue(app.buttons["mode-cpu-practice"].waitForExistence(timeout: 5))
        app.buttons["mode-cpu-practice"].tap()
        XCTAssertTrue(app.buttons["cpu-difficulty-normal"].waitForExistence(timeout: 5))
        app.buttons["cpu-difficulty-normal"].tap()
        XCTAssertTrue(app.buttons["map-classic"].waitForExistence(timeout: 5))
        app.buttons["map-classic"].tap()
        XCTAssertTrue(app.otherElements["joystick-control"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testMatchOpensWithCountdownThenUnlocksControls() throws {
        let app = XCUIApplication()
        app.launch()
        enterMatch(app)

        // Sampled immediately after the match screen appears (the joystick and the
        // countdown render together), so this lands inside the 3s countdown: skills
        // are locked and the overlay is up.
        let boost = app.buttons["skill-boost-button"]
        XCTAssertTrue(boost.waitForExistence(timeout: 5))
        XCTAssertFalse(boost.isEnabled)
        let countdown = app.staticTexts["match-countdown-overlay"]
        XCTAssertTrue(countdown.exists)

        // Countdown ends on its own; the match unlocks.
        XCTAssertTrue(countdown.waitForNonExistence(timeout: 8))
        XCTAssertTrue(boost.isEnabled)
        XCTAssertTrue(app.otherElements["joystick-control"].exists)
    }

    @MainActor
    func testPauseAndResumeKeepsMatch() throws {
        let app = XCUIApplication()
        app.launch()
        enterMatch(app)
        XCTAssertTrue(app.staticTexts["match-countdown-overlay"].waitForNonExistence(timeout: 8))

        let pauseButton = app.buttons["pause-match-button"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))
        pauseButton.tap()

        // Paused: overlay up, skills locked, board still visible.
        XCTAssertTrue(app.staticTexts["pause-overlay"].waitForExistence(timeout: 5))
        let boost = app.buttons["skill-boost-button"]
        XCTAssertTrue(boost.exists)
        XCTAssertFalse(boost.isEnabled)

        // Resume returns to the same match with controls unlocked.
        let resumeButton = app.buttons["resume-match-button"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 5))
        resumeButton.tap()
        XCTAssertTrue(app.staticTexts["pause-overlay"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(boost.isEnabled)
        XCTAssertTrue(app.otherElements["joystick-control"].exists)
    }

    @MainActor
    func testQuitFromPauseReturnsToTitleAfterConfirmation() throws {
        let app = XCUIApplication()
        app.launch()
        enterMatch(app)

        let pauseButton = app.buttons["pause-match-button"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 5))
        pauseButton.tap()

        let quitButton = app.buttons["quit-match-button"]
        XCTAssertTrue(quitButton.waitForExistence(timeout: 5))
        quitButton.tap()

        // A confirmation step guards the quit; cancel first, then really quit.
        let confirmButton = app.buttons["quit-confirm-button"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        app.buttons["quit-cancel-button"].tap()
        XCTAssertTrue(app.buttons["quit-match-button"].waitForExistence(timeout: 5))
        app.buttons["quit-match-button"].tap()
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        XCTAssertTrue(app.buttons["start-match-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["joystick-control"].exists)
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
