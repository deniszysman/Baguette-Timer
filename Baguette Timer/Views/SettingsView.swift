//
//  SettingsView.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/5/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    @State private var earliestHours: Int = 6
    @State private var latestHours: Int = 22
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Semi-transparent ultrathin material background (50% opacity)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.5)
                    .ignoresSafeArea()
                
                // Subtle accent overlay
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.05),
                        Color.clear,
                        Color.orange.opacity(0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("settings.title".localized)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 20)
                        
                        // Cooking Time Section
                        cookingTimeSection
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }
    
    // MARK: - Cooking Time Section
    
    private var cookingTimeSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("settings.cooking.time.title".localized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.leading, 4)
            
            Text("settings.cooking.time.description".localized)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            // Range Slider Container
            VStack(spacing: 16) {
                // Labels and time displays
                HStack(spacing: 20) {
                    // Earliest Time
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.earliest.time".localized)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(hours: earliestHours))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Latest Time
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("settings.latest.time".localized)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(hours: latestHours))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // Range Slider (0-24 hours with two thumbs)
                RangeSlider(
                    earliestHours: $earliestHours,
                    latestHours: $latestHours,
                    onValueChanged: {
                        saveSettings()
                    }
                )
                .frame(height: 60)
                
                // Scale labels (0 and 24)
                HStack {
                    Text("0:00")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("24:00")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
        )
    }
    
    
    // MARK: - Helper Functions
    
    private func loadCurrentSettings() {
        let (earliestH, _) = settingsManager.minutesToTime(settingsManager.earliestCookingTime)
        let (latestH, _) = settingsManager.minutesToTime(settingsManager.latestCookingTime)
        
        // Clamp to valid range (0-24)
        earliestHours = max(0, min(24, earliestH))
        latestHours = max(0, min(24, latestH))
        
        // Ensure latest is after earliest
        if latestHours <= earliestHours {
            if earliestHours < 24 {
                latestHours = min(24, earliestHours + 1)
            } else {
                latestHours = 24
                earliestHours = 23
            }
        }
    }
    
    private func saveSettings() {
        // Ensure values are in valid range
        earliestHours = max(0, min(24, earliestHours))
        latestHours = max(0, min(24, latestHours))
        
        // Ensure latest is not before earliest (with at least 1 hour difference)
        if latestHours <= earliestHours {
            // Adjust latest to be at least 1 hour after earliest
            if earliestHours < 24 {
                latestHours = min(24, earliestHours + 1)
            } else {
                latestHours = 24
                earliestHours = 23
            }
        }
        
        // Save with 0 minutes (on the hour)
        let earliestTotalMinutes = settingsManager.timeToMinutes(hours: earliestHours, minutes: 0)
        let latestTotalMinutes = settingsManager.timeToMinutes(hours: latestHours, minutes: 0)
        
        settingsManager.earliestCookingTime = earliestTotalMinutes
        settingsManager.latestCookingTime = latestTotalMinutes
    }
    
    private func formatTime(hours: Int) -> String {
        // Handle 24:00 as 12:00 AM (midnight)
        if hours == 24 {
            return "12:00 AM"
        }
        let hour12 = hours % 12 == 0 ? 12 : hours % 12
        let amPm = hours < 12 ? "AM" : "PM"
        return String(format: "%d:00 %@", hour12, amPm)
    }
}

// MARK: - Range Slider Component

struct RangeSlider: View {
    @Binding var earliestHours: Int
    @Binding var latestHours: Int
    let onValueChanged: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingEarliest: Bool = false
    @State private var isDraggingLatest: Bool = false
    
    private let minValue: Double = 0
    private let maxValue: Double = 24
    
    var body: some View {
        GeometryReader { geometry in
            let trackWidth = geometry.size.width
            let trackHeight: CGFloat = 6
            let thumbSize: CGFloat = 24
            
            // Calculate positions
            let earliestPosition = positionForValue(Double(earliestHours), in: trackWidth, thumbSize: thumbSize)
            let latestPosition = positionForValue(Double(latestHours), in: trackWidth, thumbSize: thumbSize)
            
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: trackHeight)
                    .offset(y: (geometry.size.height - trackHeight) / 2)
                
                // Selected range track (between thumbs)
                RoundedRectangle(cornerRadius: trackHeight / 2)
                    .fill(Color.orange.opacity(0.5))
                    .frame(width: max(0, latestPosition - earliestPosition), height: trackHeight)
                    .offset(x: earliestPosition, y: (geometry.size.height - trackHeight) / 2)
                
                // Earliest thumb
                thumbView(isEarliest: true)
                    .position(x: earliestPosition, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDraggingEarliest && !isDraggingLatest {
                                    isDraggingEarliest = true
                                }
                                if isDraggingEarliest {
                                    let newPosition = max(0, min(trackWidth, value.location.x))
                                    let newValue = valueForPosition(newPosition, in: trackWidth, thumbSize: thumbSize)
                                    let newHours = Int(newValue.rounded())
                                    
                                    // Constrain to valid range and ensure it's before latest
                                    if newHours >= 0 && newHours <= 24 && newHours < latestHours {
                                        earliestHours = newHours
                                        onValueChanged()
                                    } else if newHours >= latestHours {
                                        // Don't allow earliest to pass latest
                                        earliestHours = max(0, latestHours - 1)
                                        onValueChanged()
                                    }
                                }
                            }
                            .onEnded { _ in
                                isDraggingEarliest = false
                            }
                    )
                
                // Latest thumb
                thumbView(isEarliest: false)
                    .position(x: latestPosition, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDraggingEarliest && !isDraggingLatest {
                                    isDraggingLatest = true
                                }
                                if isDraggingLatest {
                                    let newPosition = max(0, min(trackWidth, value.location.x))
                                    let newValue = valueForPosition(newPosition, in: trackWidth, thumbSize: thumbSize)
                                    let newHours = Int(newValue.rounded())
                                    
                                    // Constrain to valid range and ensure it's after earliest
                                    if newHours >= 0 && newHours <= 24 && newHours > earliestHours {
                                        latestHours = newHours
                                        onValueChanged()
                                    } else if newHours <= earliestHours {
                                        // Don't allow latest to pass earliest
                                        latestHours = min(24, earliestHours + 1)
                                        onValueChanged()
                                    }
                                }
                            }
                            .onEnded { _ in
                                isDraggingLatest = false
                            }
                    )
            }
        }
    }
    
    private func thumbView(isEarliest: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color.orange)
                .frame(width: 24, height: 24)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
        }
    }
    
    private func positionForValue(_ value: Double, in width: CGFloat, thumbSize: CGFloat) -> CGFloat {
        let availableWidth = width - thumbSize
        let normalizedValue = (value - minValue) / (maxValue - minValue)
        return thumbSize / 2 + normalizedValue * availableWidth
    }
    
    private func valueForPosition(_ position: CGFloat, in width: CGFloat, thumbSize: CGFloat) -> Double {
        let availableWidth = width - thumbSize
        let normalizedPosition = (position - thumbSize / 2) / availableWidth
        return minValue + normalizedPosition * (maxValue - minValue)
    }
}

#Preview {
    SettingsView()
}

