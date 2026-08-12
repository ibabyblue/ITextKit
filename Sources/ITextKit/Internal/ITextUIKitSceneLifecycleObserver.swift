import UIKit

/// Converts UIKit application and window-scene lifecycle into one active-state callback.
///
/// A window scene is authoritative when available. Application state remains the fallback for
/// applications that do not adopt the scene lifecycle.
@MainActor
final class _ITextUIKitSceneLifecycleObserver {
    /// Receives active-state transitions only when the resolved value changes.
    private let onActiveChanged: (Bool) -> Void

    /// Notification source retained for symmetric cleanup.
    private let notificationCenter: NotificationCenter

    /// Supplies legacy application state when the current window has no scene.
    private let applicationStateProvider: @MainActor () -> UIApplication.State

    /// The window whose scene controls the owning view's timing eligibility.
    private weak var window: UIWindow?

    /// Last delivered state, used to keep repeated lifecycle notifications idempotent.
    private var lastIsActive: Bool?

    /// Creates a scene-aware lifecycle observer.
    ///
    /// - Parameters:
    ///   - notificationCenter: Lifecycle notification source.
    ///   - applicationStateProvider: Legacy state used only when a window has no scene.
    ///   - onActiveChanged: Action invoked after the resolved active state changes.
    init(
        notificationCenter: NotificationCenter = .default,
        applicationStateProvider: @escaping @MainActor () -> UIApplication.State = {
            UIApplication.shared.applicationState
        },
        onActiveChanged: @escaping (Bool) -> Void
    ) {
        self.notificationCenter = notificationCenter
        self.applicationStateProvider = applicationStateProvider
        self.onActiveChanged = onActiveChanged

        notificationCenter.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(sceneDidActivate(_:)),
            name: UIScene.didActivateNotification,
            object: nil
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(sceneWillDeactivate(_:)),
            name: UIScene.willDeactivateNotification,
            object: nil
        )
    }

    /// Removes lifecycle notification observation.
    deinit {
        notificationCenter.removeObserver(self)
    }

    /// Replaces the current window and immediately publishes its resolved active state.
    ///
    /// - Parameter window: The owning view's current window, or `nil` after detachment.
    func updateWindow(_ window: UIWindow?) {
        self.window = window
        refresh()
    }

    /// Resolves timing eligibility from hierarchy, scene, and legacy application state.
    ///
    /// A scene value always takes precedence over application state so one inactive window does
    /// not keep advancing merely because another scene leaves the application active.
    static func resolveIsActive(
        isInWindow: Bool,
        sceneActivationState: UIScene.ActivationState?,
        applicationState: UIApplication.State
    ) -> Bool {
        guard isInWindow else { return false }
        if let sceneActivationState {
            return sceneActivationState == .foregroundActive
        }
        return applicationState == .active
    }

    /// Re-evaluates an attached scene, or the legacy application fallback.
    private func refresh() {
        publish(Self.resolveIsActive(
            isInWindow: window != nil,
            sceneActivationState: window?.windowScene?.activationState,
            applicationState: applicationStateProvider()
        ))
    }

    /// Delivers an actual active-state transition once.
    private func publish(_ isActive: Bool) {
        guard isActive != lastIsActive else { return }
        lastIsActive = isActive
        onActiveChanged(isActive)
    }

    /// Uses application activation only for windows without a scene.
    @objc private func applicationDidBecomeActive() {
        refresh()
    }

    /// Suspends legacy windows before application state changes become observable.
    @objc private func applicationWillResignActive() {
        guard window?.windowScene == nil else { return }
        publish(false)
    }

    /// Resumes only when the notification belongs to the owning window scene.
    @objc private func sceneDidActivate(_ notification: Notification) {
        guard notificationBelongsToCurrentScene(notification) else { return }
        publish(true)
    }

    /// Suspends before the owning scene leaves its active foreground state.
    @objc private func sceneWillDeactivate(_ notification: Notification) {
        guard notificationBelongsToCurrentScene(notification) else { return }
        publish(false)
    }

    /// Prevents lifecycle changes in another window scene from affecting this observer.
    private func notificationBelongsToCurrentScene(_ notification: Notification) -> Bool {
        guard let currentScene = window?.windowScene,
              let notificationScene = notification.object as? UIScene else {
            return false
        }
        return notificationScene === currentScene
    }
}
