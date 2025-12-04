//
//  NotificationDelegate.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import Foundation
import UserNotifications

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    private override init() {
        super.init()
    }
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        // Extract recipe ID and step ID from notification
        if let recipeIdString = userInfo["recipeId"] as? String,
           let stepIdString = userInfo["stepId"] as? String,
           let recipeId = UUID(uuidString: recipeIdString),
           let stepId = UUID(uuidString: stepIdString) {
            
            // Store navigation info to be handled by the app
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToRecipe"),
                    object: nil,
                    userInfo: ["recipeId": recipeId, "stepId": stepId]
                )
            }
        }
        
        completionHandler()
    }
}

