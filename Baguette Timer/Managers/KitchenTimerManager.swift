//
//  KitchenTimerManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/5/25.
//

import Foundation
import SwiftUI
import Combine
import UserNotifications

/// Represents a single kitchen timer
struct KitchenTimer: Identifiable, Codable {
    let id: UUID
    var name: String
    var totalDuration: TimeInterval // in seconds
    var startTime: Date
    var isRunning: Bool
    
    var endTime: Date {
        startTime.addingTimeInterval(totalDuration)
    }
    
    var remainingTime: TimeInterval {
        guard isRunning else { return totalDuration }
        let remaining = endTime.timeIntervalSinceNow
        return max(0, remaining)
    }
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let elapsed = totalDuration - remainingTime
        return min(1.0, elapsed / totalDuration)
    }
    
    var isComplete: Bool {
        remainingTime <= 0
    }
    
    init(id: UUID = UUID(), name: String = "", totalDuration: TimeInterval, startTime: Date = Date(), isRunning: Bool = true) {
        self.id = id
        self.name = name
        self.totalDuration = totalDuration
        self.startTime = startTime
        self.isRunning = isRunning
    }
}

/// Manages multiple kitchen timers
class KitchenTimerManager: ObservableObject {
    static let shared = KitchenTimerManager()
    
    @Published var timers: [KitchenTimer] = []
    @Published var updateTrigger: Int = 0
    
    private let storageKey = "KitchenTimers"
    private let timerCounterKey = "KitchenTimerCounter"
    private var updateTimer: Timer?
    private var notificationUpdateTimers: [UUID: Timer] = [:]
    
    private init() {
        loadTimers()
        startUpdateTimer()
        startNotificationUpdates()
    }
    
    // MARK: - Timer Operations
    
    /// Get next timer number for auto-naming
    private func getNextTimerNumber() -> Int {
        var counter = UserDefaults.standard.integer(forKey: timerCounterKey)
        counter += 1
        UserDefaults.standard.set(counter, forKey: timerCounterKey)
        return counter
    }
    
    /// Create and start a new timer
    func createTimer(minutes: Int) -> KitchenTimer {
        let duration = TimeInterval(minutes * 60)
        let timerNumber = getNextTimerNumber()
        let timerName = "\("timer.default.name".localized) \(timerNumber)"
        let timer = KitchenTimer(name: timerName, totalDuration: duration)
        
        timers.insert(timer, at: 0)
        saveTimers()
        scheduleNotification(for: timer)
        updateNotificationSummary(for: timer)
        startNotificationUpdateTimer(for: timer)
        
        return timer
    }
    
    /// Remove a timer
    func removeTimer(_ timer: KitchenTimer) {
        cancelNotification(for: timer)
        stopNotificationUpdateTimer(for: timer)
        timers.removeAll { $0.id == timer.id }
        saveTimers()
    }
    
    /// Remove a timer by ID
    func removeTimer(id: UUID) {
        if let timer = timers.first(where: { $0.id == id }) {
            removeTimer(timer)
        }
    }
    
    /// Clear all completed timers
    func clearCompletedTimers() {
        let completedTimers = timers.filter { $0.isComplete }
        for timer in completedTimers {
            cancelNotification(for: timer)
            stopNotificationUpdateTimer(for: timer)
        }
        timers.removeAll { $0.isComplete }
        saveTimers()
    }
    
    /// Clear all timers
    func clearAllTimers() {
        for timer in timers {
            cancelNotification(for: timer)
            stopNotificationUpdateTimer(for: timer)
        }
        timers.removeAll()
        saveTimers()
    }
    
    // MARK: - Notifications
    
    private func scheduleNotification(for timer: KitchenTimer) {
        guard timer.totalDuration > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "timer.complete.title".localized
        content.body = String(format: "timer.complete.body".localized, timer.name)
        content.sound = UNNotificationSound(named: UNNotificationSoundName("BreadTimerSound.caf"))
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timer.totalDuration,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "kitchenTimer-\(timer.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelNotification(for timer: KitchenTimer) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["kitchenTimer-\(timer.id.uuidString)", "kitchenTimerSummary-\(timer.id.uuidString)"]
        )
        // Also remove delivered notifications
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["kitchenTimerSummary-\(timer.id.uuidString)"]
        )
    }
    
    // MARK: - Notification Summary Updates
    
    /// Update the notification summary with current timer status
    private func updateNotificationSummary(for timer: KitchenTimer) {
        guard timer.isRunning && !timer.isComplete else {
            return
        }
        
        let remainingTime = timer.remainingTime
        let formattedTime = formatTimeInterval(remainingTime)
        let totalDuration = formatTimeInterval(timer.totalDuration)
        
        let content = UNMutableNotificationContent()
        content.title = timer.name
        content.body = String(format: "timer.summary.body".localized, formattedTime, totalDuration)
        content.sound = nil // Silent for summary updates
        content.categoryIdentifier = "KITCHEN_TIMER_SUMMARY"
        
        // Use immediate delivery for summary updates (0.1 second delay ensures it's delivered)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "kitchenTimerSummary-\(timer.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error updating notification summary: \(error.localizedDescription)")
            }
        }
    }
    
    /// Start periodic updates for a timer's notification summary
    private func startNotificationUpdateTimer(for timer: KitchenTimer) {
        // Cancel any existing update timer for this timer
        stopNotificationUpdateTimer(for: timer)
        
        // Update immediately
        updateNotificationSummary(for: timer)
        
        // Schedule periodic updates every minute
        let updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Find the current state of the timer
            if let currentTimer = self.timers.first(where: { $0.id == timer.id }),
               currentTimer.isRunning && !currentTimer.isComplete {
                self.updateNotificationSummary(for: currentTimer)
            } else {
                // Timer is no longer running, stop updates
                self.stopNotificationUpdateTimer(for: timer)
            }
        }
        
        notificationUpdateTimers[timer.id] = updateTimer
    }
    
    /// Stop notification updates for a timer
    private func stopNotificationUpdateTimer(for timer: KitchenTimer) {
        notificationUpdateTimers[timer.id]?.invalidate()
        notificationUpdateTimers.removeValue(forKey: timer.id)
    }
    
    /// Start notification updates for all running timers (called on init and when app becomes active)
    private func startNotificationUpdates() {
        for timer in timers where timer.isRunning && !timer.isComplete {
            startNotificationUpdateTimer(for: timer)
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
    
    // MARK: - Persistence
    
    private func saveTimers() {
        if let encoded = try? JSONEncoder().encode(timers) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadTimers() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([KitchenTimer].self, from: data) {
            timers = decoded
        }
    }
    
    // MARK: - Update Timer
    
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTrigger += 1
                // Stop notification updates for completed timers
                self?.cleanupCompletedTimerNotifications()
            }
        }
    }
    
    /// Stop notification updates for timers that have completed
    private func cleanupCompletedTimerNotifications() {
        for timer in timers where timer.isComplete {
            stopNotificationUpdateTimer(for: timer)
        }
    }
    
    func reloadTimers() {
        loadTimers()
        // Restart notification updates for all running timers
        startNotificationUpdates()
        objectWillChange.send()
    }
}

