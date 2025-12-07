//
//  CookingTimeConflictView.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/7/25.
//

import SwiftUI

struct CookingTimeConflictView: View {
    let step: BreadStep
    let estimatedCompletion: Date
    let isFullRecipe: Bool
    let onStartAnyway: () -> Void
    let onStartLater: () -> Void
    let onDelayStep: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    private var formattedCompletionTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: estimatedCompletion)
    }
    
    private var earliestStartTime: Date {
        if isFullRecipe {
            // For full recipe, calculate earliest start time based on full recipe completion
            // We need to estimate the total recipe duration - this should be passed from caller
            // For now, use the estimated completion time
            return settingsManager.calculateEarliestStartTime(for: estimatedCompletion, recipeDuration: estimatedCompletion.timeIntervalSinceNow)
        } else {
            return settingsManager.calculateEarliestStartTime(for: estimatedCompletion, recipeDuration: step.timerDuration)
        }
    }
    
    private var nextCookingStartTime: Date {
        settingsManager.getNextCookingStartTime(from: Date())
    }
    
    private var formattedEarliestStart: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: earliestStartTime)
    }
    
    private var formattedNextStart: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: nextCookingStartTime)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Semi-transparent ultrathin material background
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
                            Image(systemName: "clock.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            Text("cooking.time.conflict.title".localized)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                        }
                        .padding(.top, 20)
                        
                        // Warning message
                        VStack(alignment: .leading, spacing: 12) {
                            if isFullRecipe {
                                Text("cooking.time.conflict.recipe.message".localized(formattedCompletionTime))
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.primary)
                            } else {
                                Text("cooking.time.conflict.message".localized(formattedCompletionTime))
                                    .font(.system(size: 16, weight: .regular, design: .rounded))
                                    .foregroundColor(.primary)
                            }
                            
                            Text("cooking.time.conflict.description".localized)
                                .font(.system(size: 14, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.orange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // Options
                        VStack(spacing: 16) {
                            // Option 1: Start Anyway
                            Button(action: {
                                onStartAnyway()
                                dismiss()
                            }) {
                                optionButton(
                                    title: "cooking.time.option.start.anyway".localized,
                                    subtitle: "cooking.time.option.start.anyway.subtitle".localized,
                                    color: .orange
                                )
                            }
                            
                            // Option 2: Start Later
                            Button(action: {
                                onStartLater()
                                dismiss()
                            }) {
                                let subtitle = isFullRecipe 
                                    ? "cooking.time.option.start.later.recipe.subtitle".localized(formattedEarliestStart)
                                    : "cooking.time.option.start.later.subtitle".localized(formattedEarliestStart)
                                optionButton(
                                    title: "cooking.time.option.start.later".localized,
                                    subtitle: subtitle,
                                    color: .blue
                                )
                            }
                            
                            // Option 3: Delay Step
                            Button(action: {
                                onDelayStep()
                                dismiss()
                            }) {
                                optionButton(
                                    title: "cooking.time.option.delay.step".localized,
                                    subtitle: "cooking.time.option.delay.step.subtitle".localized(formattedNextStart),
                                    color: .green
                                )
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("cooking.time.conflict.title".localized)
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
        }
    }
    
    private func optionButton(title: String, subtitle: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(color)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

#Preview {
    CookingTimeConflictView(
        step: BreadStep(stepNumber: 5, instruction: "Stretch the dough", timerDuration: 12 * 3600, notes: ""),
        estimatedCompletion: Date().addingTimeInterval(12 * 3600),
        isFullRecipe: false,
        onStartAnyway: {},
        onStartLater: {},
        onDelayStep: {}
    )
}

