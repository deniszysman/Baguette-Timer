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
    }
    
    private let timersKey = "BreadTimer.activeTimers"
    
    private init() {
        loadTimers()
        cleanupExpiredTimers()
    }
    
    private func saveTimers() {
        if let encoded = try? JSONEncoder().encode(activeTimers) {
            UserDefaults.standard.set(encoded, forKey: timersKey)
        }
    }
    
    private func loadTimers() {
        if let data = UserDefaults.standard.data(forKey: timersKey),
           let decoded = try? JSONDecoder().decode([UUID: TimerState].self, from: data) {
            activeTimers = decoded
        }
    }
    
    private func cleanupExpiredTimers() {
        let now = Date()
        for (stepId, timerState) in activeTimers {
            if timerState.endTime <= now && timerState.isActive {
                var updatedState = timerState
                updatedState.isActive = false
                activeTimers[stepId] = updatedState
            }
        }
    }
    
    func startTimer(for step: BreadStep) {
        let endTime = Date().addingTimeInterval(step.timerDuration)
        let timerState = TimerState(
            stepId: step.id,
            endTime: endTime,
            duration: step.timerDuration
        )
        
        activeTimers[step.id] = timerState
        
        // Schedule notification
        NotificationManager.shared.scheduleNotification(
            identifier: step.id.uuidString,
            title: "Bread Making Timer",
            body: "Step \(step.stepNumber): \(step.instruction) - Time's up!",
            timeInterval: step.timerDuration
        )
    }
    
    func getRemainingTime(for stepId: UUID) -> TimeInterval? {
        guard var timerState = activeTimers[stepId],
              timerState.isActive else {
            return nil
        }
        
        let remaining = timerState.endTime.timeIntervalSinceNow
        if remaining <= 0 {
            // Timer finished - mark as inactive
            timerState.isActive = false
            activeTimers[stepId] = timerState
            return 0
        }
        return remaining
    }
    
    func isTimerActive(for stepId: UUID) -> Bool {
        guard var timerState = activeTimers[stepId] else {
            return false
        }
        
        if timerState.endTime <= Date() {
            timerState.isActive = false
            activeTimers[stepId] = timerState
            return false
        }
        
        return timerState.isActive
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

