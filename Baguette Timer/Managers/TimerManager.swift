//
//  TimerManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import Foundation
import Combine

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
    
    private let timersKey = "BreadTimer.activeTimers.v2"  // New key to avoid migration issues
    
    private init() {
        loadTimers()
        // Don't cleanup on init - let the views handle cleanup to preserve state
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
    
    func startTimer(for step: BreadStep, recipeId: UUID, nextStep: BreadStep? = nil) {
        // Use test duration if test mode is enabled, otherwise use actual step duration
        let timerDuration = Common.testMode.isEnabled ? Common.testTimerDuration : step.timerDuration
        
        let endTime = Date().addingTimeInterval(timerDuration)
        let timerState = TimerState(
            stepId: step.id,
            endTime: endTime,
            duration: timerDuration
        )
        
        activeTimers[step.id] = timerState
        
        // Build notification message - show NEXT step if available
        let notificationTitle: String
        let notificationBody: String
        
        if let next = nextStep {
            notificationTitle = "Ready for Step \(next.stepNumber)! 🍞"
            notificationBody = "Next: \(next.instruction)"
        } else {
            // Last step - bread is done!
            notificationTitle = "Your bread is ready! 🥖"
            notificationBody = "\(step.instruction) complete - Enjoy!"
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
        NotificationManager.shared.cancelNotification(identifier: stepId.uuidString)
    }
    
    func clearAllTimers() {
        activeTimers.removeAll()
        UserDefaults.standard.removeObject(forKey: timersKey)
    }
}

