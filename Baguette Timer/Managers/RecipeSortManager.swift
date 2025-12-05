//
//  RecipeSortManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/5/25.
//

import Foundation
import Combine

/// Manages recipe sorting based on timer status, last used date, and creation date
class RecipeSortManager: ObservableObject {
    static let shared = RecipeSortManager()
    
    @Published private(set) var sortTrigger: Int = 0
    
    private let lastUsedKey = "RecipeLastUsedDates"
    private var lastUsedDates: [String: Date] = [:]
    
    private init() {
        loadLastUsedDates()
    }
    
    // MARK: - Last Used Tracking
    
    /// Mark a recipe as used (called when user opens a recipe)
    func markRecipeAsUsed(_ recipeId: UUID) {
        lastUsedDates[recipeId.uuidString] = Date()
        saveLastUsedDates()
        triggerSort()
    }
    
    /// Get the last used date for a recipe
    func getLastUsedDate(for recipeId: UUID) -> Date? {
        return lastUsedDates[recipeId.uuidString]
    }
    
    /// Trigger a sort refresh
    func triggerSort() {
        sortTrigger += 1
    }
    
    // MARK: - Sorting Logic
    
    /// Sort recipes based on:
    /// 1. Timer running → sorted by next timer to complete
    /// 2. Otherwise → sorted by last used date
    /// 3. Otherwise → sorted by creation date (custom) or static order (built-in)
    func sortRecipes(_ recipes: [BreadRecipe], timerManager: TimerManager, customRecipeManager: CustomRecipeManager) -> [BreadRecipe] {
        return recipes.sorted { recipe1, recipe2 in
            // Get next timer end time for each recipe (if any timer is active)
            let timer1EndTime = getNextTimerEndTime(for: recipe1, timerManager: timerManager)
            let timer2EndTime = getNextTimerEndTime(for: recipe2, timerManager: timerManager)
            
            // Priority 1: Recipes with active timers come first, sorted by soonest end time
            if let end1 = timer1EndTime, let end2 = timer2EndTime {
                // Both have active timers - sort by soonest end time
                return end1 < end2
            } else if timer1EndTime != nil {
                // Only recipe1 has active timer - it comes first
                return true
            } else if timer2EndTime != nil {
                // Only recipe2 has active timer - it comes first
                return false
            }
            
            // Priority 2: Sort by last used date
            let lastUsed1 = getLastUsedDate(for: recipe1.id)
            let lastUsed2 = getLastUsedDate(for: recipe2.id)
            
            if let used1 = lastUsed1, let used2 = lastUsed2 {
                // Both have been used - sort by most recent
                return used1 > used2
            } else if lastUsed1 != nil {
                // Only recipe1 has been used - it comes first
                return true
            } else if lastUsed2 != nil {
                // Only recipe2 has been used - it comes first
                return false
            }
            
            // Priority 3: Sort by creation date for custom recipes, or preserve order for built-in
            let creation1 = getCreationDate(for: recipe1, customRecipeManager: customRecipeManager)
            let creation2 = getCreationDate(for: recipe2, customRecipeManager: customRecipeManager)
            
            if let create1 = creation1, let create2 = creation2 {
                // Both have creation dates - sort by most recent first
                return create1 > create2
            } else if creation1 != nil {
                // Custom recipe with creation date comes after built-in
                return false
            } else if creation2 != nil {
                // Built-in recipes come before custom recipes without interaction
                return true
            }
            
            // Fallback: preserve original order (built-in recipes maintain their default order)
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    /// Get the next timer end time for a recipe (soonest ending timer among all steps)
    private func getNextTimerEndTime(for recipe: BreadRecipe, timerManager: TimerManager) -> Date? {
        var earliestEndTime: Date?
        
        for step in recipe.steps {
            if let timerState = timerManager.activeTimers[step.id],
               timerState.isActive,
               timerState.endTime > Date() {
                if earliestEndTime == nil || timerState.endTime < earliestEndTime! {
                    earliestEndTime = timerState.endTime
                }
            }
        }
        
        return earliestEndTime
    }
    
    /// Get the creation date for a custom recipe
    private func getCreationDate(for recipe: BreadRecipe, customRecipeManager: CustomRecipeManager) -> Date? {
        guard recipe.isCustom else { return nil }
        return customRecipeManager.getCreationDate(for: recipe.id)
    }
    
    // MARK: - Persistence
    
    private func loadLastUsedDates() {
        guard let data = UserDefaults.standard.data(forKey: lastUsedKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970
            lastUsedDates = try decoder.decode([String: Date].self, from: data)
        } catch {
            print("RecipeSortManager: Failed to load last used dates: \(error)")
        }
    }
    
    private func saveLastUsedDates() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .secondsSince1970
            let data = try encoder.encode(lastUsedDates)
            UserDefaults.standard.set(data, forKey: lastUsedKey)
            UserDefaults.standard.synchronize()
        } catch {
            print("RecipeSortManager: Failed to save last used dates: \(error)")
        }
    }
}

