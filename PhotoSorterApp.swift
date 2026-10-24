import SwiftUI

@main
struct PhotoSorterApp: App {
    @StateObject private var model = SorterModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}
