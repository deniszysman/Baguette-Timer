//
//  Common.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import Foundation

/// Common settings for the app
struct Common {
    
    // MARK: - Test Mode Setting
    // ============================================
    // TO ENABLE TEST MODE: Change .disabled to .enabled
    // TO DISABLE TEST MODE: Change .enabled to .disabled
    // ============================================
    // When test mode is enabled, all timers will complete after 5 seconds
    // instead of their normal duration. This is useful for testing the app flow.
    static let testMode: TestMode = .disabled //.enabled or .disabled
    
    // MARK: - Test Mode Configuration
    /// Duration for test timers (in seconds) - timers will complete after this duration when test mode is enabled
    static let testTimerDuration: TimeInterval = 15.0
    
    // MARK: - Test Mode Enum
    enum TestMode: String {
        case enabled
        case disabled
        
        var isEnabled: Bool {
            self == .enabled
        }
    }
}

