//
//  SpatialNotesApp.swift
//  spatial-notes
//

import SwiftUI

@main
struct SpatialNotesApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .background {
                // Save world map when going to background
                NotificationCenter.default.post(name: .saveWorldMap, object: nil)
            }
        }
    }
}
