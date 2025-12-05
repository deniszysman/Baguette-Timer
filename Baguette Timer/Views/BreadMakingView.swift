//
//  BreadMakingView.swift
//  Baguette Timer
//
//  Created by Denis Zysman x`xn 12/2/25.
//

import SwiftUI
import UIKit

struct BreadMakingView: View {
    let recipe: BreadRecipe
    @ObservedObject private var timerManager = TimerManager.shared
    
    private var stateKey: String {
        "BreadTimer.\(recipe.id.uuidString)"
    }
    
    // Initialize state from UserDefaults to prevent overwriting saved state
    @State private var currentStepIndex: Int
    @State private var completedSteps: Set<UUID>
    @State private var timerValue: TimeInterval = 0
    @State private var timer: Timer?
    @State private var timerUpdateTrigger: Int = 0
    @State private var stepToSkip: BreadStep?
    @State private var showSkipConfirmation = false
    @State private var selectedStepForNotes: BreadStep?
    @State private var showSchedulingSheet = false
    @State private var targetCompletionTime: Date = Date()
    @State private var scheduledStartTime: Date?
    @State private var showResetConfirmation = false
    @State private var isResetting = false
    
    init(recipe: BreadRecipe) {
        self.recipe = recipe
        let stateKey = "BreadTimer.\(recipe.id.uuidString)"
        
        // Load saved state immediately - restore if state exists or if there are active timers for this recipe
        let timerManager = TimerManager.shared
        let hasActiveTimers = recipe.steps.contains { step in
            timerManager.isTimerActive(for: step.id)
        }
        
        var initialStepIndex = 0
        var initialCompletedSteps: Set<UUID> = []
        
        if let state = UserDefaults.standard.dictionary(forKey: stateKey),
           let savedIndex = state["currentStepIndex"] as? Int,
           let savedSteps = state["completedSteps"] as? [String],
           (UserDefaults.standard.bool(forKey: "\(stateKey).hasStarted") || hasActiveTimers) {
            // Restore saved state
            initialCompletedSteps = Set(savedSteps.compactMap { UUID(uuidString: $0) })
            
            // Calculate correct step index based on active timers (priority) or saved index
            // Find the HIGHEST step with an active timer (most recent step)
            // This matches the logic in BreadSelectionView.getRecipeProgress()
            var foundActiveTimerStep: Int? = nil
            for (index, step) in recipe.steps.enumerated() {
                if timerManager.isTimerActive(for: step.id) {
                    // Always take the higher step index (don't break on first match)
                    // This handles cases where multiple steps have running timers
                    foundActiveTimerStep = index
                }
            }
            
            if let activeStepIndex = foundActiveTimerStep {
                // Use the step with active timer
                initialStepIndex = activeStepIndex
            } else {
                // No active timer, use saved index as fallback
                initialStepIndex = savedIndex
            }
        } else {
            // First time or no saved state - start fresh
            initialStepIndex = 0
            initialCompletedSteps = []
        }
        
        _currentStepIndex = State(initialValue: initialStepIndex)
        _completedSteps = State(initialValue: initialCompletedSteps)
    }
    
    var currentStep: BreadStep {
        recipe.steps[currentStepIndex]
    }
    
    var totalDuration: TimeInterval {
        // Calculate total time needed for all steps
        recipe.steps.reduce(0) { $0 + $1.timerDuration }
    }
    
    var elapsedDuration: TimeInterval {
        // Calculate elapsed time
        var total: TimeInterval = 0
        
        // Add all completed steps' full durations
        for (index, step) in recipe.steps.enumerated() {
            if index < currentStepIndex {
                // Previous steps are fully completed
                total += step.timerDuration
            } else if index == currentStepIndex {
                // Current step - calculate elapsed time
                if let remaining = timerManager.getRemainingTime(for: step.id),
                   timerManager.isTimerActive(for: step.id) {
                    // Timer is running - elapsed = duration - remaining
                    total += step.timerDuration - remaining
                } else if completedSteps.contains(step.id) {
                    // Step is completed - full duration elapsed
                    total += step.timerDuration
                }
                // If step not started, no time elapsed
            }
            // Future steps haven't started, so no time elapsed
        }
        
        return total
    }
    
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        let progressValue = elapsedDuration / totalDuration
        // Clamp between 0 and 1
        return min(max(progressValue, 0), 1)
    }
    
    var remainingDuration: TimeInterval {
        // Calculate remaining time for current step if timer is active
        var total: TimeInterval = 0
        
        if let currentRemaining = timerManager.getRemainingTime(for: currentStep.id),
           timerManager.isTimerActive(for: currentStep.id) {
            total += currentRemaining
        } else if !completedSteps.contains(currentStep.id) {
            // If current step not completed and timer not active, add its full duration
            total += currentStep.timerDuration
        }
        
        // Add all future steps' durations
        for index in (currentStepIndex + 1)..<recipe.steps.count {
            total += recipe.steps[index].timerDuration
        }
        
        return total
    }
    
    var estimatedCompletionTime: Date {
        Date().addingTimeInterval(remainingDuration)
    }
    
    var formattedCompletionTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        let now = Date()
        let completion = estimatedCompletionTime
        
        if calendar.isDate(completion, inSameDayAs: now) {
            return "Today : \(formatter.string(from: completion))"
        } else if calendar.isDate(completion, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now) {
            return "Tomorrow : \(formatter.string(from: completion))"
        } else {
            // For dates further out, include date
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "MMM d, h:mm a"
            return dateFormatter.string(from: completion)
        }
    }
    
    var body: some View {
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
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(recipe.localizedName)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            .multilineTextAlignment(.center)
                        
                        Text("step.current".localized(currentStep.stepNumber, recipe.steps.count))
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, 16)
                    
                    // Progress bar
                    ProgressBar(progress: progress)
                        .padding(.horizontal, 16)
                        .frame(height: 20)
                    
                    // Estimated completion time
                    Text(formattedCompletionTime)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    
                    // Current step card
                    StepCard(
                        step: currentStep,
                        recipeKeyPrefix: recipe.recipeKeyPrefix,
                        isCompleted: completedSteps.contains(currentStep.id),
                        isTimerActive: timerManager.isTimerActive(for: currentStep.id),
                        remainingTime: timerManager.getRemainingTime(for: currentStep.id),
                        onComplete: {
                            completeStep()
                        },
                        onInfoTap: {
                            selectedStepForNotes = currentStep
                        },
                        onSkip: {
                            // Find the next step
                            if currentStepIndex + 1 < recipe.steps.count {
                                let nextStep = recipe.steps[currentStepIndex + 1]
                                stepToSkip = nextStep
                                showSkipConfirmation = true
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    
                    // Steps list
                    VStack(spacing: 12) {
                        ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                            StepRow(
                                step: step,
                                recipeKeyPrefix: recipe.recipeKeyPrefix,
                                isCurrent: step.id == currentStep.id,
                                isCompleted: index < currentStepIndex || completedSteps.contains(step.id),
                                isTimerActive: timerManager.isTimerActive(for: step.id),
                                remainingTime: timerManager.getRemainingTime(for: step.id),
                                onInfoTap: {
                                    selectedStepForNotes = step
                                }
                            )
                            .onTapGesture {
                                if step.id == currentStep.id {
                                    // Already on this step, no action needed
                                    return
                                }
                                // Show confirmation before skipping
                                stepToSkip = step
                                showSkipConfirmation = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // Share button
                    ShareButton(recipe: recipe)
                    
                    // Reset button
                    Button(action: {
                        showResetConfirmation = true
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    // Schedule button
                    Button(action: {
                        showSchedulingSheet = true
                    }) {
                        Image(systemName: "clock")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            // Style navigation bar
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().tintColor = .white
        }
        .onAppear {
            // First check timers and recalculate correct step (this must happen first)
            checkAllTimersAndAdvance()
            // Then start timer updates
            startTimerUpdates()
        }
        .onDisappear {
            timer?.invalidate()
            saveState()
            // Force save to disk immediately when navigating away
            UserDefaults.standard.synchronize()
        }
        .onChange(of: timerUpdateTrigger) {
            checkAndAdvanceStep()
        }
        .onChange(of: currentStepIndex) {
            saveState()
        }
        .onChange(of: completedSteps) {
            saveState()
        }
        .alert("alert.skip.title".localized, isPresented: $showSkipConfirmation) {
            Button("alert.skip.cancel".localized, role: .cancel) {
                stepToSkip = nil
            }
            Button("alert.skip.confirm".localized, role: .destructive) {
                if let step = stepToSkip,
                   let index = recipe.steps.firstIndex(where: { $0.id == step.id }) {
                    withAnimation {
                        currentStepIndex = index
                    }
                    saveState() // Save immediately after skipping
                }
                stepToSkip = nil
            }
        } message: {
            if let step = stepToSkip {
                Text("alert.skip.message.step".localized(step.stepNumber, step.localizedInstruction(recipeKeyPrefix: recipe.recipeKeyPrefix)))
            } else {
                Text("alert.skip.message.generic".localized)
            }
        }
        .sheet(item: $selectedStepForNotes) { step in
            StepNotesView(step: step, recipeKeyPrefix: recipe.recipeKeyPrefix)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSchedulingSheet) {
            SchedulingView(
                remainingDuration: remainingDuration,
                onSchedule: { targetTime in
                    scheduleBreadMaking(targetTime: targetTime)
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .alert("alert.reset.title".localized, isPresented: $showResetConfirmation) {
            Button("alert.reset.cancel".localized, role: .cancel) { }
            Button("alert.reset.confirm".localized, role: .destructive) {
                resetRecipe()
            }
        } message: {
            Text("alert.reset.message".localized)
        }
    }
    
    private func scheduleBreadMaking(targetTime: Date) {
        // Calculate start time
        let startTime = targetTime.addingTimeInterval(-remainingDuration)
        scheduledStartTime = startTime
        
        // Save scheduled time to UserDefaults for persistence
        let scheduleKey = "BreadTimer.\(recipe.id.uuidString).scheduledStart"
        UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: scheduleKey)
        UserDefaults.standard.set(targetTime.timeIntervalSince1970, forKey: "\(scheduleKey).target")
        UserDefaults.standard.synchronize()
        
        // Schedule notification for start time
        let timeUntilStart = startTime.timeIntervalSinceNow
        
        if timeUntilStart > 0 {
            NotificationManager.shared.scheduleNotification(
                identifier: "bread-start-\(recipe.id.uuidString)",
                title: "notification.start.title".localized,
                body: "notification.start.body".localized(recipe.localizedName, formatTime(targetTime)),
                timeInterval: timeUntilStart
            )
        }
    }
    
    /// Clears the scheduled start time (called when recipe is reset or started)
    private func clearScheduledTime() {
        let scheduleKey = "BreadTimer.\(recipe.id.uuidString).scheduledStart"
        UserDefaults.standard.removeObject(forKey: scheduleKey)
        UserDefaults.standard.removeObject(forKey: "\(scheduleKey).target")
        UserDefaults.standard.synchronize()
        scheduledStartTime = nil
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    private func completeStep() {
        // Don't allow completion if timer is still running
        if timerManager.isTimerActive(for: currentStep.id) {
            return
        }
        
        // Get the next step (if there is one) for the notification
        let nextStep: BreadStep? = (currentStepIndex + 1 < recipe.steps.count) 
            ? recipe.steps[currentStepIndex + 1] 
            : nil
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            completedSteps.insert(currentStep.id)
            saveState() // Save immediately after completing step
            timerManager.startTimer(for: currentStep, recipeId: recipe.id, nextStep: nextStep, recipeKeyPrefix: recipe.recipeKeyPrefix)
        }
    }
    
    private func startTimerUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // Cleanup expired timers first (this defers state updates properly)
            TimerManager.shared.cleanupExpiredTimers()
            // Update timer displays by triggering a state change
            timerUpdateTrigger += 1
        }
    }
    
    private func checkAndAdvanceStep() {
        // Check if current step timer is finished and advance if needed
        if !timerManager.isTimerActive(for: currentStep.id) &&
           completedSteps.contains(currentStep.id) {
            // Timer finished, move to next step
            if currentStepIndex < recipe.steps.count - 1 {
                // Defer state update to avoid publishing during view updates
                DispatchQueue.main.async {
                    withAnimation {
                        currentStepIndex += 1
                    }
                    saveState() // Save immediately after advancing
                }
            }
        }
    }
    
    private func checkAllTimersAndAdvance() {
        // First cleanup any expired timers
        timerManager.cleanupExpiredTimers()
        
        // Defer the rest to next run loop to avoid view update conflicts
        DispatchQueue.main.async {
            // Recalculate the correct current step based on completed steps and timer states
            // This is critical when app reopens - we need to find the actual active step
            
            // First pass: Find the HIGHEST step with an active timer (most recent step)
            // This matches the logic in BreadSelectionView.getRecipeProgress()
            var stepWithActiveTimer: Int? = nil
            for (index, step) in recipe.steps.enumerated() {
                if timerManager.isTimerActive(for: step.id) {
                    // Always take the higher step index (don't break on first match)
                    // This handles cases where multiple steps have running timers
                    stepWithActiveTimer = index
                }
            }
            
            // If we found a step with an active timer, use that
            if let activeStepIndex = stepWithActiveTimer {
                if activeStepIndex != currentStepIndex {
                    currentStepIndex = activeStepIndex
                    saveState()
                }
                checkAndAdvanceStep()
                return
            }
            
            // Second pass: Find the first incomplete step or first completed step with finished timer
            var targetStepIndex = 0
            for (index, step) in recipe.steps.enumerated() {
                if !completedSteps.contains(step.id) {
                    // Found a step that hasn't been completed - this is the current step
                    targetStepIndex = index
                    break
                } else if completedSteps.contains(step.id) {
                    // Step is completed - check if timer finished
                    if !timerManager.isTimerActive(for: step.id) {
                        // Timer finished - move to next step if available
                        if index < recipe.steps.count - 1 {
                            // Continue to next step
                            continue
                        } else {
                            // Last step completed
                            targetStepIndex = index
                            break
                        }
                    }
                }
            }
            
            // Update current step if it's different from what we calculated
            if targetStepIndex != currentStepIndex {
                currentStepIndex = targetStepIndex
                saveState()
            }
            
            // Also check if current step timer finished (for real-time updates)
            checkAndAdvanceStep()
        }
    }
    
    private func saveState() {
        // Don't save state if we're in the middle of resetting
        guard !isResetting else { return }
        
        let state: [String: Any] = [
            "currentStepIndex": currentStepIndex,
            "completedSteps": completedSteps.map { $0.uuidString }
        ]
        UserDefaults.standard.set(state, forKey: stateKey)
        // Also save a flag to indicate that a process has started
        UserDefaults.standard.set(true, forKey: "\(stateKey).hasStarted")
        UserDefaults.standard.synchronize() // Force immediate write to disk
    }
    
    private func loadState() {
        // State is already loaded in init, but we can refresh it here if needed
        // This is mainly for checking timer states
    }
    
    private func resetRecipe() {
        // Set flag to prevent saving state during reset
        isResetting = true
        
        // Cancel all timers for this recipe
        for step in recipe.steps {
            timerManager.cancelTimer(for: step.id)
        }
        
        // Clear scheduled start time
        clearScheduledTime()
        
        // Clear saved state
        UserDefaults.standard.removeObject(forKey: stateKey)
        UserDefaults.standard.removeObject(forKey: "\(stateKey).hasStarted")
        UserDefaults.standard.synchronize()
        
        // Reset local state
        withAnimation {
            currentStepIndex = 0
            completedSteps = []
        }
        
        // Clear flag after a brief delay to ensure onChange handlers don't save
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isResetting = false
            // Ensure state is still cleared
            UserDefaults.standard.removeObject(forKey: self.stateKey)
            UserDefaults.standard.removeObject(forKey: "\(self.stateKey).hasStarted")
            UserDefaults.standard.synchronize()
        }
    }
}

struct StepCard: View {
    let step: BreadStep
    let recipeKeyPrefix: String
    let isCompleted: Bool
    let isTimerActive: Bool
    let remainingTime: TimeInterval?
    let onComplete: () -> Void
    let onInfoTap: () -> Void
    let onSkip: (() -> Void)?
    
    @State private var isPressed = false
    
    init(step: BreadStep, recipeKeyPrefix: String, isCompleted: Bool, isTimerActive: Bool, remainingTime: TimeInterval?, onComplete: @escaping () -> Void, onInfoTap: @escaping () -> Void, onSkip: (() -> Void)? = nil) {
        self.step = step
        self.recipeKeyPrefix = recipeKeyPrefix
        self.isCompleted = isCompleted
        self.isTimerActive = isTimerActive
        self.remainingTime = remainingTime
        self.onComplete = onComplete
        self.onInfoTap = onInfoTap
        self.onSkip = onSkip
    }
    
    var nextStepTimeText: String {
        guard let remaining = remainingTime, remaining > 0 else {
            return "Waiting for Timer..."
        }
        
        let completionTime = Date().addingTimeInterval(remaining)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        
        return "Next step at \(formatter.string(from: completionTime))"
    }
    
    var body: some View {
        ZStack {
            // Liquid Glass card - less transparent for active step
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            Color.white.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.orange.opacity(0.5),
                                    Color.red.opacity(0.5)
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
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                .shadow(color: .white.opacity(0.2), radius: 5, x: 0, y: -5)
            
            VStack(spacing: 16) {
                // Step number badge
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                        )
                    
                    Text("step.number".localized(step.stepNumber))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Instruction with info button
                HStack(spacing: 8) {
                    Text(step.localizedInstruction(recipeKeyPrefix: recipeKeyPrefix))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if !step.notes.isEmpty {
                        Button(action: onInfoTap) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                        }
                    }
                }
                .padding(.horizontal, 8)
                
                // Notes display
                if !step.notes.isEmpty {
                    Text(step.localizedNotes(recipeKeyPrefix: recipeKeyPrefix))
                        .font(.system(size: 18, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(0.3))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Timer display - more prominent when running
                if let remaining = remainingTime, isTimerActive {
                    VStack(spacing: 8) {
                        Text("step.timer.running".localized)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .textCase(.uppercase)
                            .tracking(1)
                        
                        TimerDisplay(timeInterval: remaining)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 15)
                                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                    )
                            )
                    }
                } else if isCompleted {
                    Text("step.timer.duration".localized(step.formattedDuration))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                } else {
                    Text("step.timer.duration".localized(step.formattedDuration))
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                // Complete button
                completeButton
            }
            .padding(20)
        }
    }
    
    @ViewBuilder
    private var completeButton: some View {
        if isTimerActive {
            // Timer is running - show next step time button that triggers skip
            Button(action: {
                onSkip?()
            }) {
                completeButtonContent(opacity: 0.6, text: nextStepTimeText)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        } else if isCompleted {
            // Step completed and timer finished
            completeButtonContent(opacity: 0.4, text: "Completed")
        } else {
            // Step not completed - show Done button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    onComplete()
                }
            }) {
                completeButtonContent(opacity: 0.6, text: "step.done".localized)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
    }
    
    private func completeButtonContent(opacity: Double, text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.green.opacity(opacity),
                            Color.green.opacity(opacity * 0.67)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            HStack(spacing: 10) {
                if !text.contains("Next step") {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                }
                Text(text)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .foregroundColor(.white)
        }
        .frame(height: 56)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

struct StepRow: View {
    let step: BreadStep
    let recipeKeyPrefix: String
    let isCurrent: Bool
    let isCompleted: Bool
    let isTimerActive: Bool
    let remainingTime: TimeInterval?
    let onInfoTap: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            stepNumberBadge
            instructionView
            Spacer()
            if !step.notes.isEmpty {
                Button(action: onInfoTap) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                }
            }
        }
        .padding()
        .background(backgroundView)
    }
    
    private var stepNumberBadge: some View {
        ZStack {
            Circle()
                .fill(
                    isCurrent ? 
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.4),
                                Color.green.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ) :
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(
                            isCurrent ? Color.green.opacity(0.7) : Color.white.opacity(0.3),
                            lineWidth: isCurrent ? 2.5 : 2
                        )
                )
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text("\(step.stepNumber)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var instructionView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(step.localizedInstruction(recipeKeyPrefix: recipeKeyPrefix))
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            
            if let remaining = remainingTime, isTimerActive {
                Text(TimerDisplay.formatTime(remaining))
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            } else {
                Text(step.formattedDuration)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
    
    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(
                isCurrent ?
                    LinearGradient(
                        colors: [
                            Color.green.opacity(0.3),
                            Color.green.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ) :
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isCurrent ? Color.green.opacity(0.6) : Color.white.opacity(0.2),
                        lineWidth: isCurrent ? 2.5 : 1
                    )
            )
            .shadow(
                color: isCurrent ? Color.green.opacity(0.3) : Color.clear,
                radius: isCurrent ? 8 : 0,
                x: 0,
                y: 2
            )
    }
}

struct ProgressBar: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 20)
                
                // Progress
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(0.8),
                                Color.green.opacity(0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 20)
    }
}

struct TimerDisplay: View {
    let timeInterval: TimeInterval
    
    var body: some View {
        Text(TimerDisplay.formatTime(timeInterval))
            .font(.system(size: 26, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
    }
    
    static func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        } else if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct StepNotesView: View {
    let step: BreadStep
    let recipeKeyPrefix: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Solid background for readability
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Step header
                    HStack {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("step.number".localized(step.stepNumber))
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text(step.localizedInstruction(recipeKeyPrefix: recipeKeyPrefix))
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 16)
                    
                    // Notes section with card design
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: "note.text")
                                .font(.system(size: 22))
                                .foregroundColor(.orange)
                            Text("step.notes".localized)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        
                        Text(step.localizedNotes(recipeKeyPrefix: recipeKeyPrefix))
                            .font(.system(size: 18, weight: .regular, design: .rounded))
                            .foregroundColor(.primary.opacity(0.85))
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 5)
                    
                    // Timer info card if step has a timer
                    if step.timerDuration > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "timer")
                                    .font(.system(size: 22))
                                    .foregroundColor(.green)
                                Text("step.timer".localized)
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            Text("step.timer.duration.label".localized(step.formattedDuration))
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .green.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
    }
}

struct SchedulingView: View {
    let remainingDuration: TimeInterval
    let onSchedule: (Date) -> Void
    
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @Environment(\.dismiss) private var dismiss
    
    var targetTime: Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)
        
        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        
        return calendar.date(from: components) ?? Date()
    }
    
    var startTime: Date {
        targetTime.addingTimeInterval(-remainingDuration)
    }
    
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: startTime)
    }
    
    var formattedTargetTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: targetTime)
    }
    
    var body: some View {
        ZStack {
            // Solid light background for better readability
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text("schedule.title".localized)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)
                    
                    // Target completion time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("schedule.question".localized)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        DatePicker(
                            "Date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .tint(.orange)
                        
                        DatePicker(
                            "Time",
                            selection: $selectedTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .tint(.orange)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(UIColor.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    
                    // Calculated start time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("schedule.start.time".localized)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "clock.badge.checkmark")
                                    .font(.system(size: 20))
                                    .foregroundColor(.green)
                                Text("schedule.start.at".localized)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(formattedStartTime)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Text("schedule.finish.at".localized(formattedTargetTime))
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.green.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.green.opacity(0.4), lineWidth: 1.5)
                            )
                    )
                    .shadow(color: .green.opacity(0.15), radius: 8, x: 0, y: 4)
                    
                    // Schedule button
                    Button(action: {
                        onSchedule(targetTime)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18))
                            Text("schedule.alert.button".localized)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.green,
                                            Color.green.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: .green.opacity(0.4), radius: 10, x: 0, y: 5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Share Button

struct ShareButton: View {
    let recipe: BreadRecipe
    @State private var showShareSheet = false
    
    var body: some View {
        Button(action: {
            showShareSheet = true
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(recipe: recipe)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let recipe: BreadRecipe
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let shareText = ShareManager.shared.generateShareMessage(for: recipe)
        let shareLink = ShareManager.shared.generateShareLink(for: recipe)
        
        let items: [Any] = [shareText, shareLink]
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    NavigationStack {
        BreadMakingView(recipe: .frenchBaguette)
    }
}

