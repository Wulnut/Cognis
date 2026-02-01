//
//  CognisApp.swift
//  CognisApp
//
//  App Entry Point
//

import SwiftUI

@main
struct CognisApp: App {
    var body: some Scene {
        WindowGroup {
            MainWindowView()
                .preferredColorScheme(.dark) // Default to dark for terminal vibe
        }
        .windowStyle(.hiddenTitleBar) // Modern macOS look
    }
}
