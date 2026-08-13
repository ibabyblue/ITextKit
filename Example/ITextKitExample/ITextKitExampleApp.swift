import SwiftUI

@main
struct ITextKitExampleApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains(
                "-ITextStyledPerformance"
            ) {
                StyledTextPerformanceView()
            } else {
                ExampleRootView()
            }
        }
    }
}
