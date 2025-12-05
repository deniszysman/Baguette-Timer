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
    
    private init() {
        loadCustomRecipes()
    }
    
    // MARK: - Public Methods
    
    /// Add a new custom recipe
    func addRecipe(_ recipe: BreadRecipe) {
        customRecipes.append(recipe)
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
        saveCustomRecipes()
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
            customIconName: iconName
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

/// Represents a step being edited
struct CustomStepData: Identifiable {
    let id = UUID()
    var name: String
    var notes: String
    var timerDuration: TimeInterval
    var isEndOfRecipe: Bool
    
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
    
    init(name: String = "", notes: String = "", timerDuration: TimeInterval = 30 * 60, isEndOfRecipe: Bool = false) {
        self.name = name
        self.notes = notes
        self.timerDuration = timerDuration
        self.isEndOfRecipe = isEndOfRecipe
    }
    
    private mutating func updateDuration(days: Int? = nil, hours: Int? = nil, minutes: Int? = nil) {
        let d = days ?? self.days
        let h = hours ?? self.hours
        let m = minutes ?? self.minutes
        timerDuration = TimeInterval(d * 86400 + h * 3600 + m * 60)
    }
}

