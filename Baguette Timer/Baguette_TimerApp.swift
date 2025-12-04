//
//  Baguette_TimerApp.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import SwiftUI
import UserNotifications

@main
struct Baguette_TimerApp: App {
    @StateObject private var navigationManager = NavigationManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Request notification permissions on app launch
        NotificationManager.shared.requestAuthorization()
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Initialize TimerManager to load persisted timers
        _ = TimerManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            BreadSelectionView()
                .environmentObject(navigationManager)
                .onAppear {
                    // Listen for notification navigation events
                    NotificationCenter.default.addObserver(
                        forName: NSNotification.Name("NavigateToRecipe"),
                        object: nil,
                        queue: .main
                    ) { notification in
                        if let userInfo = notification.userInfo,
                           let recipeId = userInfo["recipeId"] as? UUID,
                           let stepId = userInfo["stepId"] as? UUID {
                            // Defer the state update to avoid publishing during view updates
                            DispatchQueue.main.async {
                                navigationManager.navigateToRecipe(recipeId: recipeId, stepId: stepId)
                            }
                        }
                    }
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                // App became active - reload timers to sync state
                print("App became active - reloading timers")
                TimerManager.shared.reloadTimers()
            case .background:
                // App going to background - ensure timers are saved
                print("App going to background - saving state")
                UserDefaults.standard.synchronize()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
