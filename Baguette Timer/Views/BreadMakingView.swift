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
    @State private var showCookingTimeConflict = false
    @State private var pendingStepCompletion: (step: BreadStep, nextStep: BreadStep?)?
    @State private var conflictStepIndex: Int? // Track which step index has the conflict
    @ObservedObject private var settingsManager = SettingsManager.shared
    @State private var delayedSteps: [UUID: Date] = [:] // Track steps that are delayed with their scheduled start times
    
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
    func getStepCompletionTime(for stepIndex: Int) -> Date? {
        guard stepIndex >= 0 && stepIndex < recipe.steps.count else { return nil }
        
        var currentTime = Date()
        
        // If step is already completed, return nil (don't show time)
        if stepIndex < currentStepIndex || completedSteps.contains(recipe.steps[stepIndex].id) {
            return nil
        }
        
        // Work forward from current step to the target step
        for index in currentStepIndex...stepIndex {
            let step = recipe.steps[index]
            
            if index == currentStepIndex {
                // Current step
                if let delayedStart = delayedSteps[step.id], delayedStart > currentTime {
                    currentTime = delayedStart.addingTimeInterval(step.timerDuration)
                } else if let currentRemaining = timerManager.getRemainingTime(for: step.id),
                   timerManager.isTimerActive(for: step.id) {
                    currentTime = Date().addingTimeInterval(currentRemaining)
                } else if !completedSteps.contains(step.id) {
                    currentTime = currentTime.addingTimeInterval(step.timerDuration)
                }
            } else {
                // Future step
                if let delayedStart = delayedSteps[step.id], delayedStart > currentTime {
                    currentTime = delayedStart.addingTimeInterval(step.timerDuration)
                } else {
                    currentTime = currentTime.addingTimeInterval(step.timerDuration)
                }
            }
        }
        
        return currentTime
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
                            let _ = delayUpdateTrigger  // Force view update when delays change
                            StepRow(
                                step: step,
                                recipeKeyPrefix: recipe.recipeKeyPrefix,
                                isCurrent: step.id == currentStep.id,
                                isCompleted: index < currentStepIndex || completedSteps.contains(step.id),
                                isTimerActive: timerManager.isTimerActive(for: step.id),
                                remainingTime: timerManager.getRemainingTime(for: step.id),
                                completionTime: getStepCompletionTime(for: index),
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
        .sheet(isPresented: $showCookingTimeConflict) {
            if let pending = pendingStepCompletion {
                let completionTime = getConflictCompletionTime(for: pending.step)
                
                CookingTimeConflictView(
                    step: pending.step,
                    estimatedCompletion: completionTime,
                    isFullRecipe: false, // Always show step-specific message since we identify the specific conflicting step
                    onStartAnyway: {
                        // If conflict is for a future step, just proceed with current step
                        // The future step will be handled when we get to it
                        if let conflictIdx = conflictStepIndex, conflictIdx != currentStepIndex {
                            // Conflict is for a future step, proceed with current step
                            let nextStep: BreadStep? = (currentStepIndex + 1 < recipe.steps.count) 
                                ? recipe.steps[currentStepIndex + 1] 
                                : nil
                            proceedWithStepCompletion(step: currentStep, nextStep: nextStep)
                        } else {
                            proceedWithStepCompletion(step: pending.step, nextStep: pending.nextStep)
                        }
                        pendingStepCompletion = nil
                        conflictStepIndex = nil
                    },
                    onStartLater: {
                        // Delay the conflicting step to earliest time within cooking window
                        if let conflictIdx = conflictStepIndex, conflictIdx != currentStepIndex {
                            // Conflict is for a future step, delay that step and proceed with current
                            handleDelayFutureStepToEarliest(at: conflictIdx)
                            let nextStep: BreadStep? = (currentStepIndex + 1 < recipe.steps.count) 
                                ? recipe.steps[currentStepIndex + 1] 
                                : nil
                            proceedWithStepCompletion(step: currentStep, nextStep: nextStep)
                        } else {
                            handleStartLater(step: pending.step, nextStep: pending.nextStep)
                        }
                        pendingStepCompletion = nil
                        conflictStepIndex = nil
                    },
                    onDelayStep: {
                        // Delay the conflicting step to next cooking start time
                        if let conflictIdx = conflictStepIndex, conflictIdx != currentStepIndex {
                            // Conflict is for a future step, delay that step and proceed with current
                            handleDelayFutureStep(at: conflictIdx)
                            let nextStep: BreadStep? = (currentStepIndex + 1 < recipe.steps.count) 
                                ? recipe.steps[currentStepIndex + 1] 
                                : nil
                            proceedWithStepCompletion(step: currentStep, nextStep: nextStep)
                        } else {
                            handleDelayStep(step: pending.step, nextStep: pending.nextStep)
                        }
                        pendingStepCompletion = nil
                        conflictStepIndex = nil
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
        
        // Check if starting this timer would cause completion outside cooking time
        let estimatedCompletion = Date().addingTimeInterval(currentStep.timerDuration)
        
        // Check if completion would be outside cooking window
        if !settingsManager.isWithinCookingTime(estimatedCompletion) {
            // Store pending step completion and show conflict alert
            pendingStepCompletion = (currentStep, nextStep)
            showCookingTimeConflict = true
            return
        }
        
        // Check if any step (current or future) would complete outside cooking window
        // For the first step, we scan all steps to find the first conflict
        // For later steps, we only check remaining steps
        let isFirstStep = currentStepIndex == 0 && completedSteps.isEmpty
        
        if isFirstStep {
            // Walk through all steps to find the first one that would complete outside the cooking window
            var currentTime = Date().addingTimeInterval(currentStep.timerDuration) // After first step completes
            var conflictIndex: Int? = nil
            
            for index in 1..<recipe.steps.count {
                let step = recipe.steps[index]
                
                // Check if already delayed
                if let delayedStart = delayedSteps[step.id], delayedStart > currentTime {
                    currentTime = delayedStart.addingTimeInterval(step.timerDuration)
                    continue
                }
                
                let stepCompletion = currentTime.addingTimeInterval(step.timerDuration)
                
                if !settingsManager.isWithinCookingTime(stepCompletion) {
                    conflictIndex = index
                    break
                }
                currentTime = stepCompletion
            }
            
            if let conflictIdx = conflictIndex {
                // Found a future step that would complete outside window
                let conflictStep = recipe.steps[conflictIdx]
                let conflictNextStep: BreadStep? = (conflictIdx + 1 < recipe.steps.count) 
                    ? recipe.steps[conflictIdx + 1] 
                    : nil
                pendingStepCompletion = (conflictStep, conflictNextStep)
                conflictStepIndex = conflictIdx
                showCookingTimeConflict = true
                return
            }
        } else {
            // For later steps, check if any remaining steps would be outside window
            // This check happens before completing the current step
            var futureTime = estimatedCompletion
            var conflictIndex: Int? = nil
            
            for index in (currentStepIndex + 1)..<recipe.steps.count {
                let step = recipe.steps[index]
                
                // Check if step is already delayed
                if let delayedStart = delayedSteps[step.id], delayedStart > futureTime {
                    futureTime = delayedStart.addingTimeInterval(step.timerDuration)
                } else {
                    futureTime = futureTime.addingTimeInterval(step.timerDuration)
                }
                
                if !settingsManager.isWithinCookingTime(futureTime) {
                    // Found a step that would complete outside window
                    conflictIndex = index
                    break
                }
            }
            
            if let conflictIdx = conflictIndex {
                // Store the step that has the conflict (not the current step)
                let conflictStep = recipe.steps[conflictIdx]
                let conflictNextStep: BreadStep? = (conflictIdx + 1 < recipe.steps.count) 
                    ? recipe.steps[conflictIdx + 1] 
                    : nil
                pendingStepCompletion = (conflictStep, conflictNextStep)
                conflictStepIndex = conflictIdx
                showCookingTimeConflict = true
                return
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
    
    private func handleStartLater(step: BreadStep, nextStep: BreadStep?) {
        // Calculate earliest start time to complete within cooking window
        let estimatedCompletion = Date().addingTimeInterval(step.timerDuration)
        let earliestStart = settingsManager.calculateEarliestStartTime(for: estimatedCompletion, recipeDuration: step.timerDuration)
        
        // Schedule the step to start at the earliest time
        let delay = earliestStart.timeIntervalSinceNow
        if delay > 0 {
            // Store the delayed start time
            delayedSteps[step.id] = earliestStart
            
            // After delaying this step, check and auto-delay any subsequent steps that would complete outside cooking window
            autoDelayFutureSteps(startingFrom: currentStepIndex + 1, afterStepCompletion: earliestStart.addingTimeInterval(step.timerDuration))
            
            // Schedule notification to start the step later
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.delayedSteps.removeValue(forKey: step.id)
                self.proceedWithStepCompletion(step: step, nextStep: nextStep)
            }
        } else {
            // If delay is 0 or negative, start immediately
            proceedWithStepCompletion(step: step, nextStep: nextStep)
        }
    }
    
    private func handleDelayStep(step: BreadStep, nextStep: BreadStep?) {
        // Delay the step to the next cooking start time
        let nextStartTime = settingsManager.getNextCookingStartTime(from: Date())
        let delay = nextStartTime.timeIntervalSinceNow
        
        if delay > 0 {
            // Store the delayed start time
            delayedSteps[step.id] = nextStartTime
            
            // After delaying this step, check and auto-delay any subsequent steps that would complete outside cooking window
            autoDelayFutureSteps(startingFrom: currentStepIndex + 1, afterStepCompletion: nextStartTime.addingTimeInterval(step.timerDuration))
            
            // Schedule notification to start the step at next cooking time
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.delayedSteps.removeValue(forKey: step.id)
                self.proceedWithStepCompletion(step: step, nextStep: nextStep)
            }
        } else {
            // If delay is 0 or negative, start immediately
            proceedWithStepCompletion(step: step, nextStep: nextStep)
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
    
    /// Get the completion time for the conflicting step shown in the conflict dialog
    private func getConflictCompletionTime(for step: BreadStep) -> Date {
        if let conflictIdx = conflictStepIndex {
            // Use the calculated step completion time
            return getStepCompletionTime(for: conflictIdx) ?? Date().addingTimeInterval(step.timerDuration)
        } else {
            return Date().addingTimeInterval(step.timerDuration)
        }
    }
    
    /// Automatically delay future steps that would complete outside the cooking window
    private func autoDelayFutureSteps(startingFrom stepIndex: Int, afterStepCompletion: Date) {
        var currentTime = afterStepCompletion
        
        for index in stepIndex..<recipe.steps.count {
            let step = recipe.steps[index]
            
            // Skip if step is already completed
            if index < currentStepIndex || completedSteps.contains(step.id) {
                continue
            }
            
            // Calculate when this step would complete if started at currentTime
            let stepCompletion = currentTime.addingTimeInterval(step.timerDuration)
            
            // Check if completion would be outside cooking window
            if !settingsManager.isWithinCookingTime(stepCompletion) {
                // Delay this step to the next cooking start time
                let nextStartTime = settingsManager.getNextCookingStartTime(from: currentTime)
                delayedSteps[step.id] = nextStartTime
                // Update currentTime to be after this delayed step completes
                currentTime = nextStartTime.addingTimeInterval(step.timerDuration)
            } else {
                // Step is within window, proceed normally
                currentTime = stepCompletion
            }
        }
    }
    
    private func handleStartRecipeLater() {
        // Calculate earliest start time for the entire recipe to complete within cooking window
        let fullRecipeCompletion = estimatedCompletionTime
        let earliestStart = settingsManager.calculateEarliestStartTime(for: fullRecipeCompletion, recipeDuration: remainingDuration)
        
        // Delay the first step to start at the earliest time
        let delay = earliestStart.timeIntervalSinceNow
        if delay > 0 {
            // Store the delayed start time for the first step
            delayedSteps[currentStep.id] = earliestStart
            
            // Schedule notification to start the step later
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.delayedSteps.removeValue(forKey: self.currentStep.id)
                let nextStep: BreadStep? = (self.currentStepIndex + 1 < self.recipe.steps.count) 
                    ? self.recipe.steps[self.currentStepIndex + 1] 
                    : nil
                self.proceedWithStepCompletion(step: self.currentStep, nextStep: nextStep)
            }
        } else {
            // If delay is 0 or negative, start immediately
            let nextStep: BreadStep? = (currentStepIndex + 1 < recipe.steps.count) 
                ? recipe.steps[currentStepIndex + 1] 
                : nil
            proceedWithStepCompletion(step: currentStep, nextStep: nextStep)
        }
    }
    
    private func handleDelayRecipeStart() {
        // Delay the entire recipe to start at the next cooking start time
        let nextStartTime = settingsManager.getNextCookingStartTime(from: Date())
        let delay = nextStartTime.timeIntervalSinceNow
        
        if delay > 0 {
            // Store the delayed start time for the first step
            delayedSteps[currentStep.id] = nextStartTime
            
            // Schedule notification to start the recipe at next cooking time
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.delayedSteps.removeValue(forKey: self.currentStep.id)
                let nextStep: BreadStep? = (self.currentStepIndex + 1 < self.recipe.steps.count) 
                    ? self.recipe.steps[self.currentStepIndex + 1] 
                    : nil
                self.proceedWithStepCompletion(step: self.currentStep, nextStep: nextStep)
            }
        } else {
            // If delay is 0 or negative, start immediately
            let nextStep: BreadStep? = (currentStepIndex + 1 < recipe.steps.count) 
                ? recipe.steps[currentStepIndex + 1] 
                : nil
            proceedWithStepCompletion(step: currentStep, nextStep: nextStep)
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
    let completionTime: Date?
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
            return "Today \(formatter.string(from: date))"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: now) ?? now) {
            return "Tomorrow \(formatter.string(from: date))"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "MMM d, h:mm a"
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

#Preview {
    NavigationStack {
        BreadMakingView(recipe: .frenchBaguette)
    }
}

