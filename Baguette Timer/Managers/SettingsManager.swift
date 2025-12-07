//
//  SettingsManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/5/25.
//

import Foundation
import Combine

/// Manages app settings and preferences
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    private let earliestCookingTimeKey = "Settings.earliestCookingTime"
    private let latestCookingTimeKey = "Settings.latestCookingTime"
    
    /// Earliest cooking time in minutes from midnight (0-1440)
    @Published var earliestCookingTime: Int {
        didSet {
            UserDefaults.standard.set(earliestCookingTime, forKey: earliestCookingTimeKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    /// Latest cooking time in minutes from midnight (0-1440)
    @Published var latestCookingTime: Int {
        didSet {
            UserDefaults.standard.set(latestCookingTime, forKey: latestCookingTimeKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private init() {
        // Default: 6 AM to 10 PM (360 to 1320 minutes)
        self.earliestCookingTime = UserDefaults.standard.object(forKey: earliestCookingTimeKey) as? Int ?? 360
        self.latestCookingTime = UserDefaults.standard.object(forKey: latestCookingTimeKey) as? Int ?? 1320
    }
    
    /// Convert minutes from midnight to hours and minutes
    func minutesToTime(_ minutes: Int) -> (hours: Int, minutes: Int) {
        let hours = minutes / 60
        let mins = minutes % 60
        return (hours, mins)
    }
    
    /// Convert hours and minutes to minutes from midnight
    func timeToMinutes(hours: Int, minutes: Int) -> Int {
        return hours * 60 + minutes
    }
    
    /// Format minutes from midnight to time string (e.g., "6:00 AM")
    func formatTime(_ minutes: Int) -> String {
        let (hours, mins) = minutesToTime(minutes)
        let hour12 = hours % 12 == 0 ? 12 : hours % 12
        let amPm = hours < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", hour12, mins, amPm)
    }
    
    /// Check if a given date/time falls within the cooking time window
    func isWithinCookingTime(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else {
            return true // Default to allowing if we can't determine time
        }
        
        let timeInMinutes = timeToMinutes(hours: hour, minutes: minute)
        
        // Handle case where latest time is 24:00 (1440 minutes)
        if latestCookingTime >= 1440 {
            // 24:00 means until midnight (end of day), so any time >= earliest is valid
            return timeInMinutes >= earliestCookingTime
        }
        
        return timeInMinutes >= earliestCookingTime && timeInMinutes <= latestCookingTime
    }
    
    /// Get the next cooking start time (earliest time) from a given date
    func getNextCookingStartTime(from date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return date
        }
        
        let (earliestHours, earliestMinutes) = minutesToTime(earliestCookingTime)
        
        // Create date for today's earliest cooking time
        var startComponents = DateComponents(year: year, month: month, day: day, hour: earliestHours, minute: earliestMinutes)
        var startTime = calendar.date(from: startComponents) ?? date
        
        // If the earliest time has already passed today, use tomorrow's earliest time
        if startTime <= date {
            startComponents = calendar.dateComponents([.year, .month, .day], from: date)
            startComponents.hour = earliestHours
            startComponents.minute = earliestMinutes
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
                let tomorrowComponents = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                startComponents.year = tomorrowComponents.year
                startComponents.month = tomorrowComponents.month
                startComponents.day = tomorrowComponents.day
                startTime = calendar.date(from: startComponents) ?? date
            }
        }
        
        return startTime
    }
    
    /// Calculate the earliest start time for a recipe to complete within cooking window
    func calculateEarliestStartTime(for completionTime: Date, recipeDuration: TimeInterval) -> Date {
        // If completion time is already within window, can start now
        if isWithinCookingTime(completionTime) {
            return Date()
        }
        
        // Calculate how much earlier we need to start
        let (latestHours, latestMinutes) = minutesToTime(latestCookingTime)
        let calendar = Calendar.current
        let completionComponents = calendar.dateComponents([.year, .month, .day], from: completionTime)
        
        // Create date for latest cooking time on completion day
        var latestTimeComponents = DateComponents(
            year: completionComponents.year,
            month: completionComponents.month,
            day: completionComponents.day
        )
        
        // If latest is 24:00, use 23:59:59
        if latestCookingTime >= 1440 {
            latestTimeComponents.hour = 23
            latestTimeComponents.minute = 59
            latestTimeComponents.second = 59
        } else {
            latestTimeComponents.hour = latestHours
            latestTimeComponents.minute = latestMinutes
        }
        
        guard let latestTime = calendar.date(from: latestTimeComponents) else {
            return getNextCookingStartTime(from: Date())
        }
        
        // Calculate start time: latest time minus recipe duration
        let earliestStart = latestTime.addingTimeInterval(-recipeDuration)
        
        // Ensure it's not in the past and is within cooking time
        let nextStart = getNextCookingStartTime(from: Date())
        return max(earliestStart, nextStart)
    }
}

