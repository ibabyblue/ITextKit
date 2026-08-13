import SwiftUI

struct ExampleRootView: View {
    var body: some View {
        TabView {
            NavigationView {
                SwiftUICatalogView()
            }
            .navigationViewStyle(.stack)
            .tabItem {
                Label("SwiftUI", systemImage: "swift")
            }

            UIKitExampleContainer()
            .tabItem {
                Label("UIKit", systemImage: "rectangle.3.group")
            }
        }
    }
}
