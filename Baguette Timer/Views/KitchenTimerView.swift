//
//  KitchenTimerView.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/5/25.
//

import SwiftUI

struct KitchenTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var timerManager = KitchenTimerManager.shared
    
    @State private var inputMinutes: String = ""
    @FocusState private var isInputFocused: Bool
    
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
                        // Input Section
                        inputSection
                        
                        // Active Timers
                        if !timerManager.timers.isEmpty {
                            activeTimersSection
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("timer.title".localized)
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
                
                if !timerManager.timers.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button(role: .destructive, action: {
                                timerManager.clearCompletedTimers()
                            }) {
                                Label("timer.clear.completed".localized, systemImage: "checkmark.circle")
                            }
                            
                            Button(role: .destructive, action: {
                                timerManager.clearAllTimers()
                            }) {
                                Label("timer.clear.all".localized, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle.fill")
                                .font(.system(size: 24))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(spacing: 20) {
            // Minutes Input
            HStack(spacing: 16) {
                // Input Field
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 24))
                    
                    TextField("0", text: $inputMinutes)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .focused($isInputFocused)
                        .frame(width: 100)
                    
                    Text("timer.minutes".localized)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                )
                
                // Start Button
                Button(action: startTimer) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, Color.orange.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70, height: 70)
                            .shadow(color: .orange.opacity(0.4), radius: 12, x: 0, y: 6)
                        
                        Image(systemName: "play.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(inputMinutes.isEmpty || Int(inputMinutes) == 0)
                .opacity(inputMinutes.isEmpty || Int(inputMinutes) == 0 ? 0.5 : 1)
            }
            
            // Quick preset buttons
            HStack(spacing: 10) {
                ForEach([1, 5, 10, 15, 30], id: \.self) { minutes in
                    Button(action: {
                        inputMinutes = "\(minutes)"
                    }) {
                        Text("\(minutes)")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: gradientColors(for: minutes),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: gradientColors(for: minutes).first?.opacity(0.3) ?? .clear, radius: 6, x: 0, y: 3)
                            )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.thinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
        )
    }
    
    // MARK: - Active Timers Section
    
    private var activeTimersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("timer.active".localized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.leading, 4)
            
            // Force update when timer changes
            let _ = timerManager.updateTrigger
            
            ForEach(timerManager.timers) { timer in
                TimerCard(timer: timer) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        timerManager.removeTimer(timer)
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Returns gradient colors for preset timer buttons based on duration
    /// Light orange for 1 min, dark orange for 30 min
    private func gradientColors(for minutes: Int) -> [Color] {
        // Normalize minutes to 0.0 (1 min) to 1.0 (30 min)
        let normalized = min(max((Double(minutes) - 1.0) / (30.0 - 1.0), 0.0), 1.0)
        
        // Interpolate between light orange (1 min) and dark orange (30 min)
        // Light orange: RGB(255, 218, 185) = (1.0, 0.85, 0.73)
        // Dark orange: RGB(204, 85, 0) = (0.8, 0.33, 0.0)
        let red = 1.0 - (0.2 * normalized)
        let green = 0.85 - (0.52 * normalized)
        let blue = 0.73 - (0.73 * normalized)
        
        let baseColor = Color(red: red, green: green, blue: blue)
        let darkerColor = Color(red: max(0, red - 0.1), green: max(0, green - 0.1), blue: max(0, blue - 0.1))
        
        return [baseColor, darkerColor]
    }
    
    // MARK: - Actions
    
    private func startTimer() {
        guard let minutes = Int(inputMinutes), minutes > 0 else { return }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            _ = timerManager.createTimer(minutes: minutes)
        }
        
        // Reset input
        inputMinutes = ""
        isInputFocused = false
    }
}

// MARK: - Timer Card

struct TimerCard: View {
    let timer: KitchenTimer
    let onDelete: () -> Void
    
    @State private var showDeleteConfirm = false
    
    private var progressColors: [Color] {
        timer.isComplete ? [.green, .green.opacity(0.8)] : [.orange, .yellow, .orange]
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(timer.isComplete ? Color.green.opacity(0.1) : Color.clear)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.thinMaterial)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Circular Progress
            circularProgress
            
            // Timer Info
            timerInfo
            
            Spacer()
            
            // Delete button
            deleteButton
        }
        .padding(16)
        .background(cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(timer.isComplete ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .confirmationDialog("timer.delete.confirm".localized, isPresented: $showDeleteConfirm) {
            Button("timer.delete".localized, role: .destructive) {
                onDelete()
            }
            Button("custom.recipe.cancel".localized, role: .cancel) {}
        }
    }
    
    private var circularProgress: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 6)
                .frame(width: 70, height: 70)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(
                    AngularGradient(colors: progressColors, center: .center),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 70, height: 70)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: timer.progress)
            
            // Center icon or checkmark
            centerIcon
        }
    }
    
    @ViewBuilder
    private var centerIcon: some View {
        if timer.isComplete {
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.green)
        } else {
            Circle()
                .fill(Color.orange)
                .frame(width: 10, height: 10)
                .shadow(color: .orange.opacity(0.6), radius: 6)
        }
    }
    
    private var timerInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timer.name)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            timerDisplay
            
            // Total duration
            Text(String(format: "timer.total".localized, formatDuration(timer.totalDuration)))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
    
    @ViewBuilder
    private var timerDisplay: some View {
        if timer.isComplete {
            Text("timer.done".localized)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.green)
        } else {
            Text(formatTime(timer.remainingTime))
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
    
    private var deleteButton: some View {
        Button(action: { showDeleteConfirm = true }) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 26))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Preview

#Preview {
    KitchenTimerView()
}
