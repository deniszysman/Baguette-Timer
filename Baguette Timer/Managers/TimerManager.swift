//
//  TimerManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import Foundation
import Combine
import UserNotifications

class TimerManager: ObservableObject {
    static let shared = TimerManager()
    
    @Published var activeTimers: [UUID: TimerState] = [:] {
        didSet {
            saveTimers()
        }
    }
    
    struct TimerState: Codable {
        let stepId: UUID
        let endTime: Date
        let duration: TimeInterval
        var isActive: Bool = true
        
        // Custom coding keys to ensure proper serialization
        enum CodingKeys: String, CodingKey {
            case stepId, endTime, duration, isActive
        }
    }
    
    // Store step information for notifications (stepId -> (stepInstruction, recipeName, stepNumber))
    private var stepInfo: [UUID: (instruction: String, recipeName: String, stepNumber: Int)] = [:]
    private var notificationUpdateTimers: [UUID: Timer] = [:]
    
    private let timersKey = "BreadTimer.activeTimers.v2"  // New key to avoid migration issues
    
    private init() {
        loadTimers()
        // Don't cleanup on init - let the views handle cleanup to preserve state
        startNotificationUpdates()
    }
    
    private func saveTimers() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970  // More reliable date encoding
            let encoded = try encoder.encode(activeTimers)
            UserDefaults.standard.set(encoded, forKey: timersKey)
            UserDefaults.standard.synchronize()  // Force immediate write
            print("TimerManager: Saved \(activeTimers.count) timers")
        } catch {
            print("TimerManager: Failed to save timers: \(error)")
        }
    }
    
    private func loadTimers() {
        guard let data = UserDefaults.standard.data(forKey: timersKey) else {
            print("TimerManager: No saved timers found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970  // Match encoding strategy
            let decoded = try decoder.decode([UUID: TimerState].self, from: data)
            
            // Filter to only keep timers that are still active (not expired or cancelled)
            var validTimers: [UUID: TimerState] = [:]
            let now = Date()
            
            for (key, timer) in decoded {
                // Keep timer if it's marked active AND hasn't expired yet
                if timer.isActive && timer.endTime > now {
                    validTimers[key] = timer
                    print("TimerManager: Restored timer for step \(timer.stepId), ends at \(timer.endTime)")
                } else if timer.isActive && timer.endTime <= now {
                    // Timer expired while app was closed - keep it but mark for notification
                    var expiredTimer = timer
                    expiredTimer.isActive = false
                    validTimers[key] = expiredTimer
                    print("TimerManager: Timer for step \(timer.stepId) expired while app was closed")
                }
            }
            
            // Set without triggering didSet to avoid save loop
            activeTimers = validTimers
            print("TimerManager: Loaded \(validTimers.count) valid timers")
        } catch {
            print("TimerManager: Failed to load timers: \(error)")
        }
    }
    
    /// Force reload timers from storage - useful after app becomes active
    func reloadTimers() {
        loadTimers()
    }
    
    /// Cleans up expired timers - call this explicitly, NOT during view body evaluation
    func cleanupExpiredTimers() {
        let now = Date()
        var hasChanges = false
        var updatedTimers = activeTimers
        
        for (stepId, timerState) in activeTimers {
            if timerState.endTime <= now && timerState.isActive {
                var updatedState = timerState
                updatedState.isActive = false
                updatedTimers[stepId] = updatedState
                // Stop notification updates for expired timers
                stopNotificationUpdateTimer(for: stepId)
                hasChanges = true
            }
        }
        
        if hasChanges {
            // Defer state update to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                self?.activeTimers = updatedTimers
            }
        }
    }
    
    func startTimer(for step: BreadStep, recipeId: UUID, nextStep: BreadStep? = nil, recipeKeyPrefix: String? = nil) {
        // Use test duration if test mode is enabled, otherwise use actual step duration
        let timerDuration = Common.testMode.isEnabled ? Common.testTimerDuration : step.timerDuration
        
        let endTime = Date().addingTimeInterval(timerDuration)
        let timerState = TimerState(
            stepId: step.id,
            endTime: endTime,
            duration: timerDuration
        )
        
        activeTimers[step.id] = timerState
        
        // Store step information for notifications
        let stepInstruction: String
        let recipeName: String
        
        if let prefix = recipeKeyPrefix {
            stepInstruction = step.localizedInstruction(recipeKeyPrefix: prefix)
            // Get recipe name from prefix
            recipeName = getRecipeName(from: prefix)
        } else {
            stepInstruction = step.instruction
            recipeName = "Recipe"
        }
        
        stepInfo[step.id] = (instruction: stepInstruction, recipeName: recipeName, stepNumber: step.stepNumber)
        
        // Build notification message - show NEXT step if available
        let notificationTitle: String
        let notificationBody: String
        
        if let next = nextStep, let prefix = recipeKeyPrefix {
            notificationTitle = String(format: NSLocalizedString("notification.ready.step", comment: ""), next.stepNumber)
            notificationBody = String(format: NSLocalizedString("notification.next", comment: ""), next.localizedInstruction(recipeKeyPrefix: prefix))
        } else if let next = nextStep {
            notificationTitle = String(format: NSLocalizedString("notification.ready.step", comment: ""), next.stepNumber)
            notificationBody = String(format: NSLocalizedString("notification.next", comment: ""), next.instruction)
        } else if let prefix = recipeKeyPrefix {
            // Last step - bread is done!
            notificationTitle = NSLocalizedString("notification.bread.ready", comment: "")
            notificationBody = String(format: NSLocalizedString("notification.complete.enjoy", comment: ""), step.localizedInstruction(recipeKeyPrefix: prefix))
        } else {
            // Last step - bread is done!
            notificationTitle = NSLocalizedString("notification.bread.ready", comment: "")
            notificationBody = String(format: NSLocalizedString("notification.complete.enjoy", comment: ""), step.instruction)
        }
        
        // Schedule notification with recipe and step IDs for deep linking
        NotificationManager.shared.scheduleNotification(
            identifier: step.id.uuidString,
            title: notificationTitle,
            body: notificationBody,
            timeInterval: timerDuration,
            recipeId: recipeId,
            stepId: step.id
        )
        
        // Post immediate summary notification and start periodic updates
        updateNotificationSummary(for: step.id)
        startNotificationUpdateTimer(for: step.id)
    }
    
    /// Get recipe name from recipe key prefix
    private func getRecipeName(from prefix: String) -> String {
        // Try to get localized recipe name from prefix
        // For built-in recipes: "recipe.french.baguette" -> "recipe.french.baguette.name"
        if prefix.hasPrefix("recipe.") {
            let nameKey = "\(prefix).name"
            let localized = nameKey.localized
            // If localization exists and is different from the key, use it
            if localized != nameKey {
                return localized
            }
        }
        
        // For custom recipes: "custom.{uuid}" - we can't get the name easily
        // Fall back to extracting from prefix or return generic name
        if prefix.hasPrefix("custom.") {
            return "Custom Recipe"
        }
        
        // Fallback: extract recipe name from prefix like "recipe.french.baguette"
        let components = prefix.components(separatedBy: ".")
        if components.count >= 2 && components[0] == "recipe" {
            // Convert "french.baguette" to "French Baguette"
            let nameParts = components.dropFirst().map { $0.capitalized }
            return nameParts.joined(separator: " ")
        }
        
        return "Recipe"
    }
    
    /// Pure read method - returns remaining time without modifying state
    /// Call cleanupExpiredTimers() separately to update expired timer states
    func getRemainingTime(for stepId: UUID) -> TimeInterval? {
        guard let timerState = activeTimers[stepId],
              timerState.isActive else {
            return nil
        }
        
        let remaining = timerState.endTime.timeIntervalSinceNow
        if remaining <= 0 {
            // Timer has expired - return 0 but don't modify state here
            // The cleanup will be handled by cleanupExpiredTimers()
            return 0
        }
        return remaining
    }
    
    /// Pure read method - checks if timer is active without modifying state
    /// Call cleanupExpiredTimers() separately to update expired timer states
    func isTimerActive(for stepId: UUID) -> Bool {
        guard let timerState = activeTimers[stepId] else {
            return false
        }
        
        // Check both the stored isActive flag and whether the timer has expired
        return timerState.isActive && timerState.endTime > Date()
    }
    
    func cancelTimer(for stepId: UUID) {
        activeTimers.removeValue(forKey: stepId)
        stepInfo.removeValue(forKey: stepId)
        stopNotificationUpdateTimer(for: stepId)
        NotificationManager.shared.cancelNotification(identifier: stepId.uuidString)
        // Also cancel summary notification
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["recipeTimerSummary-\(stepId.uuidString)"]
        )
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["recipeTimerSummary-\(stepId.uuidString)"]
        )
    }
    
    func clearAllTimers() {
        // Stop all notification update timers
        for stepId in activeTimers.keys {
            stopNotificationUpdateTimer(for: stepId)
        }
        activeTimers.removeAll()
        stepInfo.removeAll()
        UserDefaults.standard.removeObject(forKey: timersKey)
    }
    
    // MARK: - Notification Summary Updates
    
    /// Update the notification summary with current timer status
    private func updateNotificationSummary(for stepId: UUID) {
        guard let timerState = activeTimers[stepId],
              timerState.isActive,
              let info = stepInfo[stepId] else {
            return
        }
        
        let remaining = timerState.endTime.timeIntervalSinceNow
        guard remaining > 0 else {
            return
        }
        
        let formattedTime = formatTimeInterval(remaining)
        let totalDuration = formatTimeInterval(timerState.duration)
        
        let content = UNMutableNotificationContent()
        content.title = "\(info.recipeName) - Step \(info.stepNumber)"
        content.body = String(format: "%@\n%@ remaining (Total: %@)", info.instruction, formattedTime, totalDuration)
        content.sound = nil // Silent for summary updates
        content.categoryIdentifier = "RECIPE_TIMER_SUMMARY"
        
        // Add userInfo for potential deep linking
        content.userInfo = [
            "stepId": stepId.uuidString,
            "type": "recipeTimerSummary"
        ]
        
        // Use immediate delivery for summary updates
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "recipeTimerSummary-\(stepId.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error updating recipe timer notification summary: \(error.localizedDescription)")
            }
        }
    }
    
    /// Start periodic updates for a timer's notification summary
    private func startNotificationUpdateTimer(for stepId: UUID) {
        // Cancel any existing update timer for this timer
        stopNotificationUpdateTimer(for: stepId)
        
        // Update immediately
        updateNotificationSummary(for: stepId)
        
        // Schedule periodic updates every minute
        let updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Check if timer is still active
            if let timerState = self.activeTimers[stepId],
               timerState.isActive,
               timerState.endTime > Date() {
                self.updateNotificationSummary(for: stepId)
            } else {
                // Timer is no longer active, stop updates
                self.stopNotificationUpdateTimer(for: stepId)
            }
        }
        
        notificationUpdateTimers[stepId] = updateTimer
    }
    
    /// Stop notification updates for a timer
    private func stopNotificationUpdateTimer(for stepId: UUID) {
        notificationUpdateTimers[stepId]?.invalidate()
        notificationUpdateTimers.removeValue(forKey: stepId)
    }
    
    /// Start notification updates for all running timers (called on init)
    private func startNotificationUpdates() {
        let now = Date()
        for (stepId, timerState) in activeTimers where timerState.isActive && timerState.endTime > now {
            startNotificationUpdateTimer(for: stepId)
        }
    }
    
    /// Format time interval as "Xm Ys" or "Xh Ym" or "Xm"
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            if minutes > 0 {
                return String(format: "%dh %dm", hours, minutes)
            } else {
                return String(format: "%dh", hours)
            }
        } else if minutes > 0 {
            if seconds > 0 {
                return String(format: "%dm %ds", minutes, seconds)
            } else {
                return String(format: "%dm", minutes)
            }
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

