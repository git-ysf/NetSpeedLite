import SwiftUI

@main
struct NetSpeedLiteApp: App {
    @StateObject private var monitor = NetworkSpeedMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView(monitor: monitor)
                .preferredColorScheme(monitor.theme.colorScheme)
                .onAppear {
                    monitor.start()
                }
        }
    }
}
