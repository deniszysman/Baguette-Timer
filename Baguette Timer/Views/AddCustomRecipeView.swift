//
//  AddCustomRecipeView.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/5/25.
//

import SwiftUI
import PhotosUI

struct AddCustomRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customRecipeManager = CustomRecipeManager.shared
    
    @State private var recipeName: String = ""
    @State private var selectedIcon: String = "birthday.cake.fill"
    @State private var selectedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var steps: [CustomStepData] = [CustomStepData()]
    @State private var showIconPicker = false
    @State private var showDeleteConfirmation = false
    @State private var showDiscardDraftConfirmation = false
    @State private var hasLoadedDraft = false
    @State private var autoSaveTimer: Timer?
    
    // For editing existing recipe
    let existingRecipe: BreadRecipe?
    
    /// Whether this is a new recipe (not editing existing)
    private var isNewRecipe: Bool {
        existingRecipe == nil
    }
    
    private let availableIcons = [
        "birthday.cake.fill", "leaf.fill", "star.fill", "moon.fill",
        "circle.fill", "square.fill", "triangle.fill", "heart.fill",
        "flame.fill", "drop.fill", "snowflake", "sun.max.fill",
        "cloud.fill", "bolt.fill", "sparkles", "wand.and.stars",
        "cup.and.saucer.fill", "fork.knife", "takeoutbag.and.cup.and.straw.fill",
        "carrot.fill", "fish.fill", "pawprint.fill"
    ]
    
    init(existingRecipe: BreadRecipe? = nil) {
        self.existingRecipe = existingRecipe
        
        if let recipe = existingRecipe {
            _recipeName = State(initialValue: recipe.name)
            _selectedIcon = State(initialValue: recipe.customIconName ?? "birthday.cake.fill")
            _steps = State(initialValue: recipe.steps.map { step in
                CustomStepData(
                    name: step.instruction,
                    notes: step.notes,
                    timerDuration: step.timerDuration,
                    isEndOfRecipe: step.timerDuration == 0
                )
            })
        }
        
        // Configure navigation bar appearance for proper contrast in light/dark mode
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var isFormValid: Bool {
        !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !steps.isEmpty &&
        steps.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Recipe Header Section
                        recipeHeaderSection
                        
                        // Steps Section
                        stepsSection
                        
                        // Add Step Button
                        addStepButton
                        
                        // Save Button
                        saveButton
                        
                        // Delete Button (only for editing)
                        if existingRecipe != nil {
                            deleteButton
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle(existingRecipe != nil ? "custom.recipe.edit.title".localized : "custom.recipe.new.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("custom.recipe.cancel".localized) {
                        handleCancel()
                    }
                    .foregroundColor(.orange)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                iconPickerSheet
            }
            .onAppear {
                loadDraftIfNeeded()
                startAutoSave()
            }
            .onDisappear {
                stopAutoSave()
                // Save one final time when leaving
                saveDraft()
            }
            .onChange(of: photoPickerItem) {
                loadSelectedPhoto()
            }
            .onChange(of: recipeName) { _, _ in scheduleDraftSave() }
            .onChange(of: selectedIcon) { _, _ in scheduleDraftSave() }
            .onChange(of: selectedImage) { _, _ in saveDraftWithImage() }
            .alert("custom.recipe.delete.title".localized, isPresented: $showDeleteConfirmation) {
                Button("custom.recipe.cancel".localized, role: .cancel) { }
                Button("custom.recipe.delete".localized, role: .destructive) {
                    if let recipe = existingRecipe {
                        customRecipeManager.deleteRecipe(recipe)
                        dismiss()
                    }
                }
            } message: {
                Text("custom.recipe.delete.message".localized)
            }
            .alert("custom.recipe.discard.draft.title".localized, isPresented: $showDiscardDraftConfirmation) {
                Button("custom.recipe.keep.editing".localized, role: .cancel) { }
                Button("custom.recipe.discard".localized, role: .destructive) {
                    customRecipeManager.clearDraft()
                    dismiss()
                }
            } message: {
                Text("custom.recipe.discard.draft.message".localized)
            }
        }
    }
    
    // MARK: - Draft Management
    
    private func loadDraftIfNeeded() {
        // Only load draft for new recipes, not when editing
        guard isNewRecipe && !hasLoadedDraft else { return }
        hasLoadedDraft = true
        
        if let draft = customRecipeManager.loadDraft() {
            recipeName = draft.name
            selectedIcon = draft.icon
            steps = draft.steps.isEmpty ? [CustomStepData()] : draft.steps
            selectedImage = draft.image
        }
    }
    
    private func startAutoSave() {
        guard isNewRecipe else { return }
        // Auto-save every 2 seconds to catch step content changes
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            saveDraft()
        }
    }
    
    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }
    
    private func scheduleDraftSave() {
        // Immediate save for main fields
        saveDraft()
    }
    
    private func saveDraft() {
        // Only save draft for new recipes
        guard isNewRecipe else { return }
        customRecipeManager.saveDraft(name: recipeName, icon: selectedIcon, steps: steps)
    }
    
    private func saveDraftWithImage() {
        // Only save draft for new recipes
        guard isNewRecipe else { return }
        customRecipeManager.saveDraftImage(selectedImage)
        saveDraft()
    }
    
    private func handleCancel() {
        // For new recipes, check if there's data to save
        if isNewRecipe && hasUnsavedData() {
            showDiscardDraftConfirmation = true
        } else {
            dismiss()
        }
    }
    
    private func hasUnsavedData() -> Bool {
        // Check if user has entered any data
        let hasName = !recipeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasStepData = steps.contains { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let hasImage = selectedImage != nil
        return hasName || hasStepData || hasImage
    }
    
    // MARK: - Recipe Header Section
    
    private var recipeHeaderSection: some View {
        VStack(spacing: 16) {
            // Icon and Photo Selection
            HStack(spacing: 20) {
                // Icon/Photo Display
                ZStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 32))
                                    .foregroundColor(.orange)
                            )
                    }
                    
                    Circle()
                        .stroke(Color.orange.opacity(0.5), lineWidth: 3)
                        .frame(width: 80, height: 80)
                }
                
                // Photo/Icon Selection Buttons
                VStack(alignment: .leading, spacing: 12) {
                    PhotosPicker(selection: $photoPickerItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 16))
                            Text("custom.recipe.choose.photo".localized)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.orange)
                    }
                    
                    Button(action: { showIconPicker = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                            Text("custom.recipe.choose.icon".localized)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            
            // Recipe Name
            VStack(alignment: .leading, spacing: 8) {
                Text("custom.recipe.name".localized)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                TextField("custom.recipe.name.placeholder".localized, text: $recipeName)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - Steps Section
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("custom.recipe.steps".localized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            ForEach(steps) { step in
                if let index = steps.firstIndex(where: { $0.id == step.id }) {
                    StepEditorCard(
                        stepNumber: index + 1,
                        step: Binding(
                            get: { steps[index] },
                            set: { steps[index] = $0 }
                        ),
                        onDelete: steps.count > 1 ? { deleteStep(id: step.id) } : nil
                    )
                }
            }
        }
    }
    
    private func deleteStep(id: UUID) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            steps.removeAll { $0.id == id }
        }
    }
    
    // MARK: - Add Step Button
    
    private var addStepButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                steps.append(CustomStepData())
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                Text("custom.recipe.add.step".localized)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveRecipe) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                Text(existingRecipe != nil ? "custom.recipe.save.changes".localized : "custom.recipe.create".localized)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: isFormValid 
                                ? [Color.green, Color.green.opacity(0.8)]
                                : [Color.gray, Color.gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: isFormValid ? .green.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .disabled(!isFormValid)
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button(action: { showDeleteConfirmation = true }) {
            HStack(spacing: 10) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18))
                Text("custom.recipe.delete.button".localized)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Icon Picker Sheet
    
    private var iconPickerSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 16) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            selectedImage = nil // Clear photo when icon is selected
                            showIconPicker = false
                        }) {
                            ZStack {
                                Circle()
                                    .fill(
                                        selectedIcon == icon
                                            ? LinearGradient(colors: [.orange, .orange.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                            : LinearGradient(colors: [Color(UIColor.tertiarySystemGroupedBackground), Color(UIColor.tertiarySystemGroupedBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: icon)
                                    .font(.system(size: 26))
                                    .foregroundColor(selectedIcon == icon ? .white : .primary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("custom.recipe.choose.icon".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("custom.recipe.done".localized) {
                        showIconPicker = false
                    }
                    .foregroundColor(.orange)
                }
            }
        }
        .presentationDetents([.height(500)])
    }
    
    // MARK: - Helper Methods
    
    private func loadSelectedPhoto() {
        Task {
            if let data = try? await photoPickerItem?.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImage = image
                }
            }
        }
    }
    
    private func saveRecipe() {
        let recipeId = existingRecipe?.id ?? UUID()
        
        let recipeData = CustomRecipeData(
            id: recipeId,
            name: recipeName.trimmingCharacters(in: .whitespacesAndNewlines),
            steps: steps,
            customImage: selectedImage,
            iconName: selectedIcon
        )
        
        // Save custom image if provided
        if let image = selectedImage {
            _ = customRecipeManager.saveCustomImage(image, for: recipeId)
        }
        
        let recipe = recipeData.toBreadRecipe()
        
        if existingRecipe != nil {
            customRecipeManager.updateRecipe(recipe)
        } else {
            customRecipeManager.addRecipe(recipe)
            // Clear draft after successful save
            customRecipeManager.clearDraft()
        }
        
        dismiss()
    }
}

// MARK: - Step Editor Card

struct StepEditorCard: View {
    let stepNumber: Int
    @Binding var step: CustomStepData
    let onDelete: (() -> Void)?
    
    @State private var showTimerPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with step number and delete button
            HStack {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Text("\(stepNumber)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                }
                
                Text("custom.recipe.step".localized(stepNumber))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
            }
            
            // Step Name
            VStack(alignment: .leading, spacing: 6) {
                Text("custom.recipe.step.name".localized)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                TextField("custom.recipe.step.name.placeholder".localized, text: $step.name)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 6) {
                Text("custom.recipe.step.notes".localized)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                TextField("custom.recipe.step.notes.placeholder".localized, text: $step.notes, axis: .vertical)
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .lineLimit(3...6)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(UIColor.tertiarySystemGroupedBackground))
                    )
            }
            
            // Timer Duration
            VStack(alignment: .leading, spacing: 10) {
                Text("custom.recipe.step.duration".localized)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                
                // End of Recipe Toggle
                Toggle(isOn: $step.isEndOfRecipe) {
                    HStack(spacing: 8) {
                        Image(systemName: "flag.checkered")
                            .foregroundColor(.orange)
                        Text("custom.recipe.end.of.recipe".localized)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                    }
                }
                .tint(.orange)
                
                if !step.isEndOfRecipe {
                    // Timer Picker
                    Button(action: { showTimerPicker.toggle() }) {
                        HStack {
                            Image(systemName: "timer")
                                .font(.system(size: 18))
                                .foregroundColor(.green)
                            
                            Text(formatDuration(step.timerDuration))
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(showTimerPicker ? 180 : 0))
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.tertiarySystemGroupedBackground))
                        )
                    }
                    
                    if showTimerPicker {
                        TimerDurationPicker(step: $step)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: step.isEndOfRecipe)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showTimerPicker)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        if minutes > 0 { parts.append("\(minutes)m") }
        
        return parts.isEmpty ? "0m" : parts.joined(separator: " ")
    }
}

// MARK: - Timer Duration Picker

struct TimerDurationPicker: View {
    @Binding var step: CustomStepData
    
    @State private var days: Int
    @State private var hours: Int
    @State private var minutes: Int
    
    init(step: Binding<CustomStepData>) {
        self._step = step
        let totalSeconds = Int(step.wrappedValue.timerDuration)
        _days = State(initialValue: totalSeconds / 86400)
        _hours = State(initialValue: (totalSeconds % 86400) / 3600)
        _minutes = State(initialValue: (totalSeconds % 3600) / 60)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Days
            VStack(spacing: 4) {
                Text("custom.recipe.days".localized)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Picker("custom.recipe.days".localized, selection: $days) {
                    ForEach(0..<31) { day in
                        Text("\(day)").tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 100)
                .clipped()
            }
            
            // Hours
            VStack(spacing: 4) {
                Text("custom.recipe.hours".localized)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Picker("custom.recipe.hours".localized, selection: $hours) {
                    ForEach(0..<24) { hour in
                        Text("\(hour)").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 100)
                .clipped()
            }
            
            // Minutes
            VStack(spacing: 4) {
                Text("custom.recipe.minutes".localized)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                
                Picker("custom.recipe.minutes".localized, selection: $minutes) {
                    ForEach(0..<60) { minute in
                        Text("\(minute)").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 70, height: 100)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
        .onChange(of: days) { updateDuration() }
        .onChange(of: hours) { updateDuration() }
        .onChange(of: minutes) { updateDuration() }
    }
    
    private func updateDuration() {
        step.timerDuration = TimeInterval(days * 86400 + hours * 3600 + minutes * 60)
    }
}

#Preview {
    AddCustomRecipeView()
}

