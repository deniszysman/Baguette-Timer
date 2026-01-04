//
//  CustomRecipeManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/5/25.
//

import Foundation
import SwiftUI
import Combine

/// Manages persistence of custom user-created recipes
class CustomRecipeManager: ObservableObject {
    static let shared = CustomRecipeManager()
    
    @Published private(set) var customRecipes: [BreadRecipe] = []
    
    private let customRecipesKey = "CustomRecipes"
    private let customImagesDirectory = "CustomRecipeImages"
    private let creationDatesKey = "CustomRecipeCreationDates"
    private let draftRecipeKey = "DraftRecipe"
    private let draftImageKey = "DraftRecipeImage"
    
    /// Stores creation dates for custom recipes
    private var creationDates: [String: Date] = [:]
    
    private init() {
        loadCreationDates()
        loadCustomRecipes()
    }
    
    // MARK: - Draft Management
    
    /// Check if a draft exists
    var hasDraft: Bool {
        UserDefaults.standard.data(forKey: draftRecipeKey) != nil
    }
    
    /// Save draft recipe data
    func saveDraft(name: String, icon: String, steps: [CustomStepData]) {
        let draftData = DraftRecipeData(name: name, iconName: icon, steps: steps.map { DraftStepData(from: $0) })
        
        do {
            let data = try JSONEncoder().encode(draftData)
            UserDefaults.standard.set(data, forKey: draftRecipeKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving draft: \(error)")
        }
    }
    
    /// Save draft image separately (not in JSON)
    func saveDraftImage(_ image: UIImage?) {
        if let image = image, let data = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: draftImageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: draftImageKey)
        }
        UserDefaults.standard.synchronize()
    }
    
    /// Load draft recipe data
    func loadDraft() -> (name: String, icon: String, steps: [CustomStepData], image: UIImage?)? {
        guard let data = UserDefaults.standard.data(forKey: draftRecipeKey) else {
            return nil
        }
        
        do {
            let draftData = try JSONDecoder().decode(DraftRecipeData.self, from: data)
            let steps = draftData.steps.map { $0.toCustomStepData() }
            
            // Load draft image
            var image: UIImage?
            if let imageData = UserDefaults.standard.data(forKey: draftImageKey) {
                image = UIImage(data: imageData)
            }
            
            return (draftData.name, draftData.iconName, steps, image)
        } catch {
            print("Error loading draft: \(error)")
            return nil
        }
    }
    
    /// Clear the draft
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftRecipeKey)
        UserDefaults.standard.removeObject(forKey: draftImageKey)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Public Methods
    
    /// Add a new custom recipe
    func addRecipe(_ recipe: BreadRecipe) {
        customRecipes.append(recipe)
        // Track creation date
        creationDates[recipe.id.uuidString] = Date()
        saveCreationDates()
        saveCustomRecipes()
    }
    
    /// Update an existing custom recipe
    func updateRecipe(_ recipe: BreadRecipe) {
        if let index = customRecipes.firstIndex(where: { $0.id == recipe.id }) {
            customRecipes[index] = recipe
            saveCustomRecipes()
        }
    }
    
    /// Delete a custom recipe
    func deleteRecipe(_ recipe: BreadRecipe) {
        customRecipes.removeAll { $0.id == recipe.id }
        // Also delete the custom image if it exists
        deleteCustomImage(for: recipe.id)
        // Remove creation date
        creationDates.removeValue(forKey: recipe.id.uuidString)
        saveCreationDates()
        saveCustomRecipes()
    }
    
    /// Get the creation date for a custom recipe
    func getCreationDate(for recipeId: UUID) -> Date? {
        return creationDates[recipeId.uuidString]
    }
    
    /// Save a custom image for a recipe
    func saveCustomImage(_ image: UIImage, for recipeId: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileName = "\(recipeId.uuidString).jpg"
        let fileURL = getCustomImagesDirectory().appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("Error saving custom image: \(error)")
            return nil
        }
    }
    
    /// Load a custom image for a recipe
    func loadCustomImage(for recipeId: UUID) -> UIImage? {
        let fileName = "\(recipeId.uuidString).jpg"
        let fileURL = getCustomImagesDirectory().appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        
        return UIImage(contentsOfFile: fileURL.path)
    }
    
    /// Delete a custom image
    func deleteCustomImage(for recipeId: UUID) {
        let fileName = "\(recipeId.uuidString).jpg"
        let fileURL = getCustomImagesDirectory().appendingPathComponent(fileName)
        
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Private Methods
    
    private func getCustomImagesDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagesDirectory = documentsDirectory.appendingPathComponent(customImagesDirectory)
        
        if !FileManager.default.fileExists(atPath: imagesDirectory.path) {
            try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        }
        
        return imagesDirectory
    }
    
    private func loadCustomRecipes() {
        guard let data = UserDefaults.standard.data(forKey: customRecipesKey) else { return }
        
        do {
            let recipes = try JSONDecoder().decode([BreadRecipe].self, from: data)
            customRecipes = recipes
        } catch {
            print("Error loading custom recipes: \(error)")
        }
    }
    
    private func saveCustomRecipes() {
        do {
            let data = try JSONEncoder().encode(customRecipes)
            UserDefaults.standard.set(data, forKey: customRecipesKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving custom recipes: \(error)")
        }
    }
    
    private func loadCreationDates() {
        guard let data = UserDefaults.standard.data(forKey: creationDatesKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            creationDates = try decoder.decode([String: Date].self, from: data)
        } catch {
            print("Error loading creation dates: \(error)")
        }
    }
    
    private func saveCreationDates() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(creationDates)
            UserDefaults.standard.set(data, forKey: creationDatesKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("Error saving creation dates: \(error)")
        }
    }
}

/// Represents a custom recipe being edited (mutable version)
struct CustomRecipeData {
    var id: UUID
    var name: String
    var steps: [CustomStepData]
    var customImage: UIImage?
    var iconName: String
    
    init(id: UUID = UUID(), name: String = "", steps: [CustomStepData] = [], customImage: UIImage? = nil, iconName: String = "birthday.cake.fill") {
        self.id = id
        self.name = name
        self.steps = steps
        self.customImage = customImage
        self.iconName = iconName
    }
    
    /// Convert to BreadRecipe
    func toBreadRecipe() -> BreadRecipe {
        let breadSteps = steps.enumerated().map { index, step in
            BreadStep(
                stepNumber: index + 1,
                instruction: step.name,
                timerDuration: step.isEndOfRecipe ? 0 : step.timerDuration,
                notes: step.notes
            )
        }
        
        return BreadRecipe(
            id: id,
            name: name,
            steps: breadSteps,
            isCustom: true,
            customIconName: iconName,
            category: nil // Custom recipes can have category set later if needed
        )
    }
    
    /// Create from existing BreadRecipe
    static func from(_ recipe: BreadRecipe) -> CustomRecipeData {
        CustomRecipeData(
            id: recipe.id,
            name: recipe.name,
            steps: recipe.steps.map { step in
                CustomStepData(
                    name: step.instruction,
                    notes: step.notes,
                    timerDuration: step.timerDuration,
                    isEndOfRecipe: step.timerDuration == 0
                )
            },
            iconName: recipe.customIconName ?? "birthday.cake.fill"
        )
    }
}

/// Codable structure for persisting draft recipes
struct DraftRecipeData: Codable {
    let name: String
    let iconName: String
    let steps: [DraftStepData]
}

/// Codable structure for persisting draft steps
struct DraftStepData: Codable {
    let id: UUID
    let name: String
    let notes: String
    let timerDuration: TimeInterval
    let isEndOfRecipe: Bool
    
    init(from step: CustomStepData) {
        self.id = step.id
        self.name = step.name
        self.notes = step.notes
        self.timerDuration = step.timerDuration
        self.isEndOfRecipe = step.isEndOfRecipe
    }
    
    func toCustomStepData() -> CustomStepData {
        return CustomStepData(id: id, name: name, notes: notes, timerDuration: timerDuration, isEndOfRecipe: isEndOfRecipe)
    }
}

/// Represents a step being edited
struct CustomStepData: Identifiable {
    let id: UUID
    var name: String
    var notes: String
    var timerDuration: TimeInterval
    var isEndOfRecipe: Bool
    
    init(id: UUID = UUID(), name: String = "", notes: String = "", timerDuration: TimeInterval = 30 * 60, isEndOfRecipe: Bool = false) {
        self.id = id
        self.name = name
        self.notes = notes
        self.timerDuration = timerDuration
        self.isEndOfRecipe = isEndOfRecipe
    }
    
    // Timer components for picker
    var days: Int {
        get { Int(timerDuration) / 86400 }
        set { updateDuration(days: newValue) }
    }
    
    var hours: Int {
        get { (Int(timerDuration) % 86400) / 3600 }
        set { updateDuration(hours: newValue) }
    }
    
    var minutes: Int {
        get { (Int(timerDuration) % 3600) / 60 }
        set { updateDuration(minutes: newValue) }
    }
    
    private mutating func updateDuration(days: Int? = nil, hours: Int? = nil, minutes: Int? = nil) {
        let d = days ?? self.days
        let h = hours ?? self.hours
        let m = minutes ?? self.minutes
        timerDuration = TimeInterval(d * 86400 + h * 3600 + m * 60)
    }
}

