//
//  BreadSelectionView.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import SwiftUI
import Combine

struct BreadSelectionView: View {
    @EnvironmentObject var navigationManager: NavigationManager
    @ObservedObject private var timerManager = TimerManager.shared
    @State private var selectedRecipe: BreadRecipe?
    @State private var showBreadMaking = false
    @State private var scale: CGFloat = 1.0
    @State private var navigationSubscription: AnyCancellable?
    @State private var timerUpdateTrigger: Int = 0
    @State private var updateTimer: Timer?
    
    let recipes = BreadRecipe.availableRecipes
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background image
                GeometryReader { geometry in
                    Image("Background")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .overlay(
                            // Dark overlay for better text readability
                            Color.black.opacity(0.3)
                        )
                }
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Title
                    VStack(spacing: 10) {
                        Text("BreadOClock")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Text("Select your bread recipe")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 20)
                    
                    // Bread selection cards
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(recipes) { recipe in
                                let progress = getRecipeProgress(for: recipe)
                                let scheduled = getScheduledTime(for: recipe)
                                BreadCard(
                                    recipe: recipe,
                                    currentStep: progress.currentStep,
                                    remainingTime: progress.remainingTime,
                                    scheduledStartTime: scheduled.startTime,
                                    timerUpdateTrigger: timerUpdateTrigger
                                ) {
                                    selectedRecipe = recipe
                                    showBreadMaking = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationDestination(isPresented: $showBreadMaking) {
                if let recipe = selectedRecipe {
                    BreadMakingView(recipe: recipe)
                } else {
                    // Fallback view if recipe is nil (shouldn't happen, but prevents blank screen)
                    Text("Loading...")
                        .foregroundColor(.white)
                }
            }
            .onAppear {
                // Start timer updates for displaying remaining time
                startTimerUpdates()
                
                // Subscribe to navigation events using Combine to avoid view update issues
                navigationSubscription = navigationManager.navigationPublisher
                    .receive(on: DispatchQueue.main)
                    .sink { recipeId, stepId in
                        if let recipe = self.recipes.first(where: { $0.id == recipeId }) {
                            // Use a small delay to ensure we're not in a view update cycle
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.selectedRecipe = recipe
                                self.showBreadMaking = true
                            }
                        }
                    }
            }
            .onDisappear {
                updateTimer?.invalidate()
                navigationSubscription?.cancel()
            }
        }
    }
    
    private func startTimerUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            TimerManager.shared.cleanupExpiredTimers()
            timerUpdateTrigger += 1
        }
    }
    
    /// Get current progress for a recipe (current step and remaining time if timer active)
    private func getRecipeProgress(for recipe: BreadRecipe) -> (currentStep: Int?, remainingTime: TimeInterval?) {
        let stateKey = "BreadTimer.\(recipe.id.uuidString)"
        
        // Check if recipe has been started
        guard UserDefaults.standard.bool(forKey: "\(stateKey).hasStarted") else {
            return (nil, nil)
        }
        
        // Load saved state
        guard let state = UserDefaults.standard.dictionary(forKey: stateKey),
              let savedIndex = state["currentStepIndex"] as? Int,
              let savedSteps = state["completedSteps"] as? [String] else {
            return (nil, nil)
        }
        
        // If step is 0 and no steps completed and no active timers, treat as not started (reset state)
        let completedStepsCount = savedSteps.count
        var hasActiveTimer = false
        for step in recipe.steps {
            if timerManager.isTimerActive(for: step.id) {
                hasActiveTimer = true
                break
            }
        }
        
        if savedIndex == 0 && completedStepsCount == 0 && !hasActiveTimer {
            // This is a reset state - treat as not started
            return (nil, nil)
        }
        
        // Find the HIGHEST step with an active timer (most recent step)
        // This handles cases where multiple steps have running timers
        var activeTimerStep: Int? = nil
        var remainingTime: TimeInterval? = nil
        
        for (index, step) in recipe.steps.enumerated() {
            if timerManager.isTimerActive(for: step.id) {
                // Always take the higher step index (don't break on first match)
                activeTimerStep = index
                remainingTime = timerManager.getRemainingTime(for: step.id)
            }
        }
        
        // Return the active timer step if found, otherwise the saved step
        let currentStep = activeTimerStep ?? savedIndex
        return (currentStep + 1, remainingTime) // +1 for 1-based step display
    }
    
    /// Get scheduled start time for a recipe (if user has scheduled when to start)
    private func getScheduledTime(for recipe: BreadRecipe) -> (startTime: Date?, targetTime: Date?) {
        let scheduleKey = "BreadTimer.\(recipe.id.uuidString).scheduledStart"
        
        guard let startTimestamp = UserDefaults.standard.object(forKey: scheduleKey) as? TimeInterval else {
            return (nil, nil)
        }
        
        let startTime = Date(timeIntervalSince1970: startTimestamp)
        
        // Only return if the scheduled time is in the future
        if startTime > Date() {
            let targetTimestamp = UserDefaults.standard.double(forKey: "\(scheduleKey).target")
            let targetTime = targetTimestamp > 0 ? Date(timeIntervalSince1970: targetTimestamp) : nil
            return (startTime, targetTime)
        }
        
        // Scheduled time has passed - clear it
        UserDefaults.standard.removeObject(forKey: scheduleKey)
        UserDefaults.standard.removeObject(forKey: "\(scheduleKey).target")
        return (nil, nil)
    }
}

struct BreadCard: View {
    let recipe: BreadRecipe
    let currentStep: Int?
    let remainingTime: TimeInterval?
    let scheduledStartTime: Date?
    let timerUpdateTrigger: Int
    let action: () -> Void
    
    @State private var isPressed = false
    
    /// Whether this recipe has been started (has progress)
    private var isInProgress: Bool {
        currentStep != nil
    }
    
    /// Whether there's an active timer running
    private var hasActiveTimer: Bool {
        if let time = remainingTime, time > 0 {
            return true
        }
        return false
    }
    
    /// Whether there's a scheduled start time
    private var hasScheduledTime: Bool {
        scheduledStartTime != nil
    }
    
    /// Formatted scheduled start time
    private var formattedScheduledTime: String? {
        guard let startTime = scheduledStartTime else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        let calendar = Calendar.current
        if calendar.isDateInToday(startTime) {
            formatter.dateFormat = "'Today' h:mm a"
        } else if calendar.isDateInTomorrow(startTime) {
            formatter.dateFormat = "'Tomorrow' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: startTime)
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            ZStack {
                // Liquid Glass effect - green tint if in progress
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: isInProgress ? [
                                        Color.green.opacity(0.4),
                                        Color.green.opacity(0.2)
                                    ] : hasScheduledTime ? [
                                        Color.orange.opacity(0.35),
                                        Color.orange.opacity(0.15)
                                    ] : [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: isInProgress ? [
                                        Color.green.opacity(0.8),
                                        Color.green.opacity(0.4)
                                    ] : hasScheduledTime ? [
                                        Color.orange.opacity(0.8),
                                        Color.orange.opacity(0.4)
                                    ] : [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: (isInProgress || hasScheduledTime) ? 2.5 : 2
                            )
                    )
                    .shadow(color: isInProgress ? .green.opacity(0.3) : hasScheduledTime ? .orange.opacity(0.3) : .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .shadow(color: .white.opacity(0.1), radius: 5, x: 0, y: -5)
                
                HStack(spacing: 16) {
                    // Recipe image with liquid glass dome effect
                    ZStack {
                        // The actual recipe image
                        Image(recipe.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                        
                        // Glass dome overlay - centered subtle gradient
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.12),
                                        Color.clear,
                                        Color.black.opacity(0.05)
                                    ],
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                        
                        // Top highlight arc (centered light reflection on dome)
                        Circle()
                            .trim(from: 0.0, to: 0.3)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.0),
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                        
                        // Glass border/rim
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.4)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 60, height: 60)
                        
                        // Active timer indicator
                        if hasActiveTimer {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .offset(x: 22, y: -22)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(recipe.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        
                        if let step = currentStep {
                            // Show current step progress and timer on same line
                            HStack(spacing: 10) {
                                Text("Step \(step)/\(recipe.steps.count)")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                
                                // Timer if active
                                if let time = remainingTime, time > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "timer")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text(formatTime(time))
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .lineLimit(1)
                                    }
                                    .fixedSize()
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(Color.green.opacity(0.7))
                                    )
                                    .shadow(color: .green.opacity(0.4), radius: 4, x: 0, y: 2)
                                }
                            }
                        } else if let scheduledTime = formattedScheduledTime {
                            // Show scheduled start time with orange badge
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 14, weight: .semibold))
                                Text(scheduledTime)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .fixedSize()
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.85))
                            )
                            .shadow(color: .orange.opacity(0.4), radius: 4, x: 0, y: 2)
                        } else {
                            Text("\(recipe.steps.count) steps")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    // Progress indicator, scheduled indicator, or nothing
                    if isInProgress {
                        VStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.green.opacity(0.9))
                        }
                    } else if hasScheduledTime {
                        VStack {
                            Image(systemName: "bell.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.orange.opacity(0.9))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(minHeight: 100)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        // Show only days for timers longer than 24 hours
        if days >= 1 {
            return days == 1 ? "1 day" : "\(days) days"
        } else if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

#Preview {
    BreadSelectionView()
        .environmentObject(NavigationManager.shared)
}

#Preview("BreadCard - Not Started") {
    ZStack {
        Color.black
        BreadCard(
            recipe: .frenchBaguette,
            currentStep: nil,
            remainingTime: nil,
            scheduledStartTime: nil,
            timerUpdateTrigger: 0
        ) {}
        .padding()
    }
}

#Preview("BreadCard - In Progress with Timer") {
    ZStack {
        Color.black
        BreadCard(
            recipe: .frenchBaguette,
            currentStep: 3,
            remainingTime: 3600,
            scheduledStartTime: nil,
            timerUpdateTrigger: 0
        ) {}
        .padding()
    }
}

#Preview("BreadCard - Scheduled") {
    ZStack {
        Color.black
        BreadCard(
            recipe: .frenchBaguette,
            currentStep: nil,
            remainingTime: nil,
            scheduledStartTime: Date().addingTimeInterval(3600 * 5), // 5 hours from now
            timerUpdateTrigger: 0
        ) {}
        .padding()
    }
}

