//
//  NotificationManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleNotification(
        identifier: String,
        title: String,
        body: String,
        timeInterval: TimeInterval,
        recipeId: UUID? = nil,
        stepId: UUID? = nil
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Use custom bread timer sound (pleasant chime)
        content.sound = UNNotificationSound(named: UNNotificationSoundName("BreadTimerSound.caf"))
        content.badge = 1
        
        // Add userInfo for deep linking
        if let recipeId = recipeId, let stepId = stepId {
            content.userInfo = [
                "recipeId": recipeId.uuidString,
                "stepId": stepId.uuidString
            ]
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

