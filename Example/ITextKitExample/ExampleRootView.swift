import SwiftUI

struct ExampleRootView: View {
    var body: some View {
        TabView {
            NavigationView {
                SwiftUIExampleView()
                    .navigationTitle("SwiftUI")
            }
            .tabItem {
                Label("SwiftUI", systemImage: "swift")
            }

            NavigationView {
                UIKitExampleContainer()
                    .navigationTitle("UIKit")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem {
                Label("UIKit", systemImage: "rectangle.3.group")
            }
        }
    }
}
