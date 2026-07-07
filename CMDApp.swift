import SwiftUI

@main
struct CMDApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(store)
                .preferredColorScheme(settings.resolvedColorScheme)
                .tint(.primary)
        }
    }
}
