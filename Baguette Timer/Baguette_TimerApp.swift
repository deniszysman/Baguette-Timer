//
//  Baguette_TimerApp.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import SwiftUI

@main
struct Baguette_TimerApp: App {
    init() {
        // Request notification permissions on app launch
        NotificationManager.shared.requestAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            BreadSelectionView()
        }
    }
}
