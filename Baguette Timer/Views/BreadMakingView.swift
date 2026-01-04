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
    @State private var delayUpdateTrigger: Int = 0  // Forces view refresh when delays change
    @State private var stepToSkip: BreadStep?
    @State private var showSkipConfirmation = false
    @State private var selectedStepForNotes: BreadStep?
    @State private var showSchedulingSheet = false
    @State private var targetCompletionTime: Date = Date()
    @State private var scheduledStartTime: Date?
    @State private var showResetConfirmation = false
    @State private var isResetting = false
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var delayedSteps: [UUID: Date] = [:] // Track steps that are delayed with their scheduled start times
    @State private var selectedDelayedStepIndex: Int? // Track which delayed step's clock icon was tapped
    
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
        var currentTime = Date()
        
        // Check if current step is delayed
        if let delayedStart = delayedSteps[currentStep.id], delayedStart > currentTime {
            // Step is delayed, calculate from delayed start time
            let delay = delayedStart.timeIntervalSince(currentTime)
            total += delay + currentStep.timerDuration
            currentTime = delayedStart.addingTimeInterval(currentStep.timerDuration)
        } else if let currentRemaining = timerManager.getRemainingTime(for: currentStep.id),
           timerManager.isTimerActive(for: currentStep.id) {
            total += currentRemaining
            currentTime = Date().addingTimeInterval(currentRemaining)
        } else if !completedSteps.contains(currentStep.id) {
            // If current step not completed and timer not active, add its full duration
            total += currentStep.timerDuration
            currentTime = Date().addingTimeInterval(currentStep.timerDuration)
        }
        
        // Add all future steps' durations, accounting for delays
        for index in (currentStepIndex + 1)..<recipe.steps.count {
            let step = recipe.steps[index]
            if let delayedStart = delayedSteps[step.id], delayedStart > currentTime {
                // Step is delayed
                let delay = delayedStart.timeIntervalSince(currentTime)
                total += delay + step.timerDuration
                currentTime = delayedStart.addingTimeInterval(step.timerDuration)
            } else {
                total += step.timerDuration
                currentTime = currentTime.addingTimeInterval(step.timerDuration)
            }
        }
        
        return total
    }
    
    var estimatedCompletionTime: Date {
        var currentTime = Date()
        
        // Check if current step is delayed
        if let delayedStart = delayedSteps[currentStep.id], delayedStart > currentTime {
            currentTime = delayedStart.addingTimeInterval(currentStep.timerDuration)
        } else if let currentRemaining = timerManager.getRemainingTime(for: currentStep.id),
           timerManager.isTimerActive(for: currentStep.id) {
            currentTime = Date().addingTimeInterval(currentRemaining)
        } else if !completedSteps.contains(currentStep.id) {
            currentTime = Date().addingTimeInterval(currentStep.timerDuration)
        }
        
        // Add all future steps' durations, accounting for delays
        for index in (currentStepIndex + 1)..<recipe.steps.count {
            let step = recipe.steps[index]
            if let delayedStart = delayedSteps[step.id], delayedStart > currentTime {
                currentTime = delayedStart.addingTimeInterval(step.timerDuration)
            } else {
                currentTime = currentTime.addingTimeInterval(step.timerDuration)
            }
        }
        
        return currentTime
    }
    
    /// Calculate when a specific step will complete
    /// Returns when a step would START (not complete)
    /// - For current step not started: returns now
    /// - For current step with active timer: returns when timer completes (for display purposes)
    /// - For future steps: returns when they would start (after previous step completes, or delayed start)
    func getStepCompletionTime(for stepIndex: Int) -> Date? {
        guard stepIndex >= 0 && stepIndex < recipe.steps.count else { return nil }
        
        let step = recipe.steps[stepIndex]
        
        // If step is already completed, return nil (don't show time)
        if stepIndex < currentStepIndex || completedSteps.contains(step.id) {
            return nil
        }
        
        // For the current step
        if stepIndex == currentStepIndex {
            // If timer is active, show when it will complete
            if let currentRemaining = timerManager.getRemainingTime(for: step.id),
               timerManager.isTimerActive(for: step.id) {
                return Date().addingTimeInterval(currentRemaining)
            }
            // If delayed, show the delayed start time
            if let delayedStart = delayedSteps[step.id], delayedStart > Date() {
                return delayedStart
            }
            // Otherwise, show current time (user can start now)
            return Date()
        }
        
        // For future steps, calculate when they would START
        var nextStepStartTime = Date()
        
        // Start from current step
        let currentStepData = recipe.steps[currentStepIndex]
        if let delayedStart = delayedSteps[currentStepData.id], delayedStart > nextStepStartTime {
            nextStepStartTime = delayedStart.addingTimeInterval(currentStepData.timerDuration)
        } else if let currentRemaining = timerManager.getRemainingTime(for: currentStepData.id),
                  timerManager.isTimerActive(for: currentStepData.id) {
            nextStepStartTime = Date().addingTimeInterval(currentRemaining)
        } else if !completedSteps.contains(currentStepData.id) {
            nextStepStartTime = Date().addingTimeInterval(currentStepData.timerDuration)
        }
        
        // Work through intermediate steps
        for index in (currentStepIndex + 1)..<stepIndex {
            let intermediateStep = recipe.steps[index]
            if completedSteps.contains(intermediateStep.id) {
                continue
            }
            if let delayedStart = delayedSteps[intermediateStep.id], delayedStart > nextStepStartTime {
                nextStepStartTime = delayedStart.addingTimeInterval(intermediateStep.timerDuration)
            } else {
                nextStepStartTime = nextStepStartTime.addingTimeInterval(intermediateStep.timerDuration)
            }
        }
        
        // For the target step, check if it has a delayed start
        if let delayedStart = delayedSteps[step.id], delayedStart > nextStepStartTime {
            return delayedStart
        }
        
        return nextStepStartTime
    }
    
    var formattedCompletionTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        let now = Date()
        let completion = estimatedCompletionTime
        
        if calendar.isDate(completion, inSameDayAs: now) {
            return "\("time.today".localized) : \(formatter.string(from: completion))"
        } else if calendar.isDate(completion, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now) {
            return "\("time.tomorrow".localized) : \(formatter.string(from: completion))"
        } else {
            // For dates further out, include date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
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
                        // Filter to show only current and future steps (hide completed)
                        ForEach(Array(recipe.steps.enumerated()).filter { index, step in
                            // Show step if it's the current step or a future step that's not completed
                            index >= currentStepIndex && !completedSteps.contains(step.id)
                        }, id: \.element.id) { index, step in
                            let _ = delayUpdateTrigger  // Force view update when delays change
                            let stepIsDelayed = delayedSteps[step.id] != nil
                            StepRow(
                                step: step,
                                recipeKeyPrefix: recipe.recipeKeyPrefix,
                                isCurrent: step.id == currentStep.id,
                                isCompleted: false, // Never show as completed since we filter those out
                                isTimerActive: timerManager.isTimerActive(for: step.id),
                                remainingTime: timerManager.getRemainingTime(for: step.id),
                                completionTime: getStepCompletionTime(for: index),
                                isDelayed: stepIsDelayed,
                                onInfoTap: {
                                    selectedStepForNotes = step
                                },
                                onDelayTap: stepIsDelayed ? {
                                    selectedDelayedStepIndex = index
                                } : nil
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
            // Calculate delays for steps outside cooking window
            calculateProactiveDelays()
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
        .onChange(of: delayedSteps) {
            // Force view refresh when delays dictionary changes
            delayUpdateTrigger += 1
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
                    // Clear delays for skipped steps and recalculate for remaining steps
                    recalculateDelaysAfterSkip(toStepIndex: index)
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
                .presentationDetents([.height(650)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSchedulingSheet) {
            SchedulingView(
                remainingDuration: remainingDuration,
                onSchedule: { targetTime in
                    scheduleBreadMaking(targetTime: targetTime)
                }
            )
            .presentationDetents([.height(650)])
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
        .sheet(isPresented: Binding(
            get: { selectedDelayedStepIndex != nil },
            set: { if !$0 { selectedDelayedStepIndex = nil } }
        )) {
            if let stepIndex = selectedDelayedStepIndex,
               stepIndex < recipe.steps.count {
                let step = recipe.steps[stepIndex]
                let completionTime = getStepCompletionTime(for: stepIndex) ?? Date().addingTimeInterval(step.timerDuration)
                
                CookingTimeConflictView(
                    step: step,
                    estimatedCompletion: completionTime,
                    isFullRecipe: false,
                    onStartAnyway: {
                        // Remove the delay for this step
                        delayedSteps.removeValue(forKey: step.id)
                        // Recalculate subsequent steps without this delay
                        recalculateDelaysAfterRemoval(at: stepIndex)
                        selectedDelayedStepIndex = nil
                    },
                    onStartLater: {
                        // Keep the delay at earliest time
                        handleDelayFutureStepToEarliest(at: stepIndex)
                        selectedDelayedStepIndex = nil
                    },
                    onDelayStep: {
                        // Delay to next cooking start time
                        handleDelayFutureStep(at: stepIndex)
                        selectedDelayedStepIndex = nil
                    }
                )
            }
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
        
        // Check if any future step would START outside the cooking window
        // When current step's timer completes is when the next step would start
        var nextStepStartTime = Date().addingTimeInterval(currentStep.timerDuration)
        
        for index in (currentStepIndex + 1)..<recipe.steps.count {
            let step = recipe.steps[index]
            
            // Skip completed steps
            if completedSteps.contains(step.id) {
                continue
            }
            
            // Check if already delayed to a later time
            if let delayedStart = delayedSteps[step.id], delayedStart > nextStepStartTime {
                nextStepStartTime = delayedStart.addingTimeInterval(step.timerDuration)
                continue
            }
            
            // Check if this step would START outside the cooking window
            if !settingsManager.isWithinCookingTime(nextStepStartTime) {
                // Delay this step to the next cooking start time
                handleDelayFutureStep(at: index)
                // Update start time for subsequent steps
                if let delayedStart = delayedSteps[step.id] {
                    nextStepStartTime = delayedStart.addingTimeInterval(step.timerDuration)
                }
            } else {
                // Step starts within window, update time for next step
                nextStepStartTime = nextStepStartTime.addingTimeInterval(step.timerDuration)
            }
        }
        
        // Proceed with normal step completion
        proceedWithStepCompletion(step: currentStep, nextStep: nextStep)
    }
    
    private func proceedWithStepCompletion(step: BreadStep, nextStep: BreadStep?) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            completedSteps.insert(step.id)
            saveState() // Save immediately after completing step
            timerManager.startTimer(for: step, recipeId: recipe.id, nextStep: nextStep, recipeKeyPrefix: recipe.recipeKeyPrefix)
        }
    }
    
    /// Delay a specific future step to the next cooking start time
    private func handleDelayFutureStep(at stepIndex: Int) {
        guard stepIndex > currentStepIndex && stepIndex < recipe.steps.count else { return }
        
        let step = recipe.steps[stepIndex]
        
        // Calculate when this step would naturally start (after previous steps complete)
        let stepStartTime = calculateStepStartTime(for: stepIndex)
        
        // Delay this step to the next cooking start time
        let nextStartTime = settingsManager.getNextCookingStartTime(from: stepStartTime)
        delayedSteps[step.id] = nextStartTime
        
        // After delaying this step, check and auto-delay any subsequent steps
        autoDelayFutureSteps(startingFrom: stepIndex + 1, afterStepCompletion: nextStartTime.addingTimeInterval(step.timerDuration))
    }
    
    /// Delay a specific future step to the earliest time that allows completion within cooking window
    private func handleDelayFutureStepToEarliest(at stepIndex: Int) {
        guard stepIndex > currentStepIndex && stepIndex < recipe.steps.count else { return }
        
        let step = recipe.steps[stepIndex]
        
        // Calculate when this step would naturally start (after previous steps complete)
        let stepStartTime = calculateStepStartTime(for: stepIndex)
        
        // Calculate when this step would complete
        let stepCompletion = stepStartTime.addingTimeInterval(step.timerDuration)
        
        // Calculate the earliest start time that would allow completion within cooking window
        let earliestStart = settingsManager.calculateEarliestStartTime(for: stepCompletion, recipeDuration: step.timerDuration)
        
        // Only delay if the earliest start is later than the natural start
        if earliestStart > stepStartTime {
            delayedSteps[step.id] = earliestStart
            
            // After delaying this step, check and auto-delay any subsequent steps
            autoDelayFutureSteps(startingFrom: stepIndex + 1, afterStepCompletion: earliestStart.addingTimeInterval(step.timerDuration))
        }
    }
    
    /// Calculate when a specific step would start based on current state
    private func calculateStepStartTime(for stepIndex: Int) -> Date {
        var stepStartTime = Date()
        
        // Account for current step
        if let currentRemaining = timerManager.getRemainingTime(for: currentStep.id),
           timerManager.isTimerActive(for: currentStep.id) {
            stepStartTime = Date().addingTimeInterval(currentRemaining)
        } else if !completedSteps.contains(currentStep.id) {
            stepStartTime = Date().addingTimeInterval(currentStep.timerDuration)
        }
        
        // Add durations of steps between current and target
        for index in (currentStepIndex + 1)..<stepIndex {
            let intermediateStep = recipe.steps[index]
            if let delayedStart = delayedSteps[intermediateStep.id], delayedStart > stepStartTime {
                stepStartTime = delayedStart.addingTimeInterval(intermediateStep.timerDuration)
            } else {
                stepStartTime = stepStartTime.addingTimeInterval(intermediateStep.timerDuration)
            }
        }
        
        return stepStartTime
    }
    
    /// Proactively calculate delays for all steps that would START outside the cooking window
    /// This runs on view appear to show accurate completion times immediately
    private func calculateProactiveDelays() {
        // Calculate when the current step would complete (this is when the next step would start)
        var nextStepStartTime = Date()
        
        // If current step has an active timer, next step starts when timer completes
        if let remaining = timerManager.getRemainingTime(for: currentStep.id),
           timerManager.isTimerActive(for: currentStep.id) {
            nextStepStartTime = Date().addingTimeInterval(remaining)
        } else if !completedSteps.contains(currentStep.id) {
            // Current step not started yet - next step starts after current step's timer
            nextStepStartTime = Date().addingTimeInterval(currentStep.timerDuration)
        }
        
        // Current step is NOT delayed - user can start it any time
        // Remove any existing delay on current step
        delayedSteps.removeValue(forKey: currentStep.id)
        
        // Check all future steps - delay if they would START outside cooking window
        for index in (currentStepIndex + 1)..<recipe.steps.count {
            let step = recipe.steps[index]
            
            // Skip completed steps
            if completedSteps.contains(step.id) {
                continue
            }
            
            // Check if this step would START outside the cooking window
            if !settingsManager.isWithinCookingTime(nextStepStartTime) {
                // Delay this step to the next cooking start time
                let nextCookingStart = settingsManager.getNextCookingStartTime(from: nextStepStartTime)
                delayedSteps[step.id] = nextCookingStart
                // Next step would start after this delayed step completes
                nextStepStartTime = nextCookingStart.addingTimeInterval(step.timerDuration)
            } else {
                // Step starts within cooking window
                // But check if it would COMPLETE outside the window (affecting next step)
                let stepCompletion = nextStepStartTime.addingTimeInterval(step.timerDuration)
                // Remove any existing delay since this step can start on time
                delayedSteps.removeValue(forKey: step.id)
                nextStepStartTime = stepCompletion
            }
        }
        
        delayUpdateTrigger += 1
    }
    
    /// Recalculate delays for steps after skipping to a specific step
    private func recalculateDelaysAfterSkip(toStepIndex: Int) {
        // Clear all existing delays first
        delayedSteps.removeAll()
        
        // Calculate when the next step would start (after new current step's timer)
        var nextStepStartTime = Date().addingTimeInterval(recipe.steps[toStepIndex].timerDuration)
        
        for index in (toStepIndex + 1)..<recipe.steps.count {
            let step = recipe.steps[index]
            
            // Skip completed steps
            if completedSteps.contains(step.id) {
                continue
            }
            
            // Check if this step would START outside the cooking window
            if !settingsManager.isWithinCookingTime(nextStepStartTime) {
                // Delay this step to the next cooking start time
                let nextCookingStart = settingsManager.getNextCookingStartTime(from: nextStepStartTime)
                delayedSteps[step.id] = nextCookingStart
                nextStepStartTime = nextCookingStart.addingTimeInterval(step.timerDuration)
            } else {
                // Step starts within window, calculate when it completes for next step
                nextStepStartTime = nextStepStartTime.addingTimeInterval(step.timerDuration)
            }
        }
        
        delayUpdateTrigger += 1
    }
    
    /// Recalculate delays for steps after removing a delay
    private func recalculateDelaysAfterRemoval(at removedStepIndex: Int) {
        // After removing a delay, recalculate when subsequent steps would start
        var nextStepStartTime = calculateStepStartTime(for: removedStepIndex)
        let step = recipe.steps[removedStepIndex]
        nextStepStartTime = nextStepStartTime.addingTimeInterval(step.timerDuration)
        
        // Check subsequent steps - they may no longer need delays
        for index in (removedStepIndex + 1)..<recipe.steps.count {
            let futureStep = recipe.steps[index]
            
            // Skip completed steps
            if completedSteps.contains(futureStep.id) {
                continue
            }
            
            // Check if this step would START outside the cooking window
            if !settingsManager.isWithinCookingTime(nextStepStartTime) {
                // Need to delay this step
                let nextCookingStart = settingsManager.getNextCookingStartTime(from: nextStepStartTime)
                delayedSteps[futureStep.id] = nextCookingStart
                nextStepStartTime = nextCookingStart.addingTimeInterval(futureStep.timerDuration)
            } else {
                // Step can start within window, remove any existing delay
                delayedSteps.removeValue(forKey: futureStep.id)
                nextStepStartTime = nextStepStartTime.addingTimeInterval(futureStep.timerDuration)
            }
        }
        delayUpdateTrigger += 1
    }
    
    /// Automatically delay future steps that would complete outside the cooking window
    private func autoDelayFutureSteps(startingFrom stepIndex: Int, afterStepCompletion: Date) {
        var nextStepStartTime = afterStepCompletion
        
        for index in stepIndex..<recipe.steps.count {
            let step = recipe.steps[index]
            
            // Skip if step is already completed
            if index < currentStepIndex || completedSteps.contains(step.id) {
                continue
            }
            
            // Check if this step would START outside the cooking window
            if !settingsManager.isWithinCookingTime(nextStepStartTime) {
                // Delay this step to the next cooking start time
                let nextCookingStart = settingsManager.getNextCookingStartTime(from: nextStepStartTime)
                delayedSteps[step.id] = nextCookingStart
                // Next step starts after this delayed step completes
                nextStepStartTime = nextCookingStart.addingTimeInterval(step.timerDuration)
            } else {
                // Step starts within window, remove any existing delay
                delayedSteps.removeValue(forKey: step.id)
                // Next step starts after this step completes
                nextStepStartTime = nextStepStartTime.addingTimeInterval(step.timerDuration)
            }
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
    @State private var showLargeNotes = false
    
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
        
        return "step.next.at".localized(formatter.string(from: completionTime))
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
                
                // Notes display - tappable to show larger
                if !step.notes.isEmpty {
                    Button(action: { showLargeNotes = true }) {
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
                    .buttonStyle(PlainButtonStyle())
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
        .sheet(isPresented: $showLargeNotes) {
            LargeNotesView(
                stepNumber: step.stepNumber,
                instruction: step.localizedInstruction(recipeKeyPrefix: recipeKeyPrefix),
                notes: step.localizedNotes(recipeKeyPrefix: recipeKeyPrefix)
            )
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
    let completionTime: Date?
    let isDelayed: Bool
    let onInfoTap: () -> Void
    let onDelayTap: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 15) {
            stepNumberBadge
            instructionView
            Spacer()
            HStack(spacing: 8) {
                // Show delay clock icon if step is delayed
                if isDelayed, let delayAction = onDelayTap {
                    Button(action: delayAction) {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.orange)
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                    }
                }
                
                if !step.notes.isEmpty {
                    Button(action: onInfoTap) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 1)
                    }
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
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
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
                
                // Show completion time if available - more prominent with yellow
                if let completion = completionTime, !isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.yellow)
                        Text(formatCompletionTime(completion))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
            }
        }
    }
    
    private func formatCompletionTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(date, inSameDayAs: now) {
            return "\("time.today".localized) \(formatter.string(from: date))"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now) {
            return "\("time.tomorrow".localized) \(formatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: date)
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

// MARK: - Large Notes View
struct LargeNotesView: View {
    @Environment(\.dismiss) private var dismiss
    let stepNumber: Int
    let instruction: String
    let notes: String
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Step header
                    VStack(spacing: 12) {
                        Text("step.number".localized(stepNumber))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text(instruction)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
                    
                    Divider()
                    
                    // Notes content - large and readable
                    Text(notes)
                        .font(.system(size: 24, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                        .lineSpacing(10)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    NavigationStack {
        BreadMakingView(recipe: .frenchBaguette)
    }
}

