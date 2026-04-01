//
//  ViperArchitectureApp.swift
//  ViperArchitecture
//
//  Created by Prana dhika on 04/03/25.
//

import SwiftUI

@main
struct ViperArchitectureApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 640)
        }
        .windowResizability(.contentMinSize)
    }
}
