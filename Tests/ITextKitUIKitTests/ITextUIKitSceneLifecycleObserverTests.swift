import UIKit
import XCTest
@testable import ITextKit

@MainActor
final class ITextUIKitSceneLifecycleObserverTests: XCTestCase {
    func testWindowSceneActivationTakesPrecedenceOverApplicationState() {
        XCTAssertTrue(_ITextUIKitSceneLifecycleObserver.resolveIsActive(
            isInWindow: true,
            sceneActivationState: .foregroundActive,
            applicationState: .inactive
        ))
        XCTAssertFalse(_ITextUIKitSceneLifecycleObserver.resolveIsActive(
            isInWindow: true,
            sceneActivationState: .foregroundInactive,
            applicationState: .active
        ))
        XCTAssertFalse(_ITextUIKitSceneLifecycleObserver.resolveIsActive(
            isInWindow: true,
            sceneActivationState: .background,
            applicationState: .active
        ))
    }

    func testApplicationStateIsUsedForAWindowWithoutAScene() {
        XCTAssertTrue(_ITextUIKitSceneLifecycleObserver.resolveIsActive(
            isInWindow: true,
            sceneActivationState: nil,
            applicationState: .active
        ))
        XCTAssertFalse(_ITextUIKitSceneLifecycleObserver.resolveIsActive(
            isInWindow: true,
            sceneActivationState: nil,
            applicationState: .inactive
        ))
    }

    func testDetachedViewIsInactiveRegardlessOfSceneOrApplicationState() {
        XCTAssertFalse(_ITextUIKitSceneLifecycleObserver.resolveIsActive(
            isInWindow: false,
            sceneActivationState: .foregroundActive,
            applicationState: .active
        ))
    }
}
