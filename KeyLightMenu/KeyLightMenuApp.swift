//
//  KeyLightMenuApp.swift
//  KeyLightMenu
//
//  Created by Cai Williamson on 27/04/2026.
//

import SwiftUI

@main
struct KeyLightMenuApp: App {
    @State private var service = KeyLightService()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(service)
        } label: {
            Image(systemName: service.isOn ? "lightbulb.fill" : "lightbulb")
        }
        .menuBarExtraStyle(.window)
    }
}
