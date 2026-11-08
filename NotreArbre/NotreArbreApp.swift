import SwiftUI
import ArbreCore

@main
struct NotreArbreApp: App {
    var body: some Scene {
        WindowGroup { Text("Notre arbre \(ArbreCore.version)") }
    }
}
