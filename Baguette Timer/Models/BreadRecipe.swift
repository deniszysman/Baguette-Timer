//
//  BreadRecipe.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import Foundation
import CryptoKit

enum RecipeCategory: String, Codable, CaseIterable {
    case yeasted = "Yeasted"
    case artisan = "Artisan"
    case enriched = "Enriched"
    case flatbread = "Flatbread"
    case rye = "Rye"
    case mediterranean = "Mediterranean"
    
    var localizedName: String {
        return "recipe.category.\(rawValue.lowercased())".localized
    }
}

struct BreadRecipe: Identifiable, Codable {
    let id: UUID
    let name: String
    let steps: [BreadStep]
    let isCustom: Bool
    let customIconName: String?
    let category: RecipeCategory?

    init(id: UUID? = nil, name: String, steps: [BreadStep], isCustom: Bool = false, customIconName: String? = nil, category: RecipeCategory? = nil) {
        // Use deterministic UUID based on recipe name for persistence (unless custom or ID provided)
        if let providedId = id {
            self.id = providedId
        } else if isCustom {
            self.id = UUID() // Custom recipes get random UUIDs
        } else {
            self.id = UUID.deterministic(from: "recipe.\(name)")
        }
        self.name = name
        self.isCustom = isCustom
        self.customIconName = customIconName
        self.category = category
        
        // Assign deterministic IDs to steps based on recipe name + step number
        self.steps = steps.map { step in
            BreadStep(
                id: isCustom ? UUID() : UUID.deterministic(from: "step.\(name).\(step.stepNumber)"),
                stepNumber: step.stepNumber,
                instruction: step.instruction,
                timerDuration: step.timerDuration,
                notes: step.notes
            )
        }
    }
}

struct BreadStep: Identifiable, Codable {
    let id: UUID
    let stepNumber: Int
    let instruction: String
    let timerDuration: TimeInterval // in seconds
    let notes: String

    init(id: UUID? = nil, stepNumber: Int, instruction: String, timerDuration: TimeInterval, notes: String = "") {
        self.id = id ?? UUID()  // Will be overwritten by BreadRecipe init
        self.stepNumber = stepNumber
        self.instruction = instruction
        self.timerDuration = timerDuration
        self.notes = notes
    }
}

// Extension to create deterministic UUIDs from strings
extension UUID {
    /// Creates a deterministic UUID from a string using SHA256 hash
    /// The same input string will always produce the same UUID
    static func deterministic(from string: String) -> UUID {
        let hash = SHA256.hash(data: Data(string.utf8))
        let hashBytes = Array(hash)
        
        // Use first 16 bytes of hash to create UUID
        return UUID(uuid: (
            hashBytes[0], hashBytes[1], hashBytes[2], hashBytes[3],
            hashBytes[4], hashBytes[5], hashBytes[6], hashBytes[7],
            hashBytes[8], hashBytes[9], hashBytes[10], hashBytes[11],
            hashBytes[12], hashBytes[13], hashBytes[14], hashBytes[15]
        ))
    }
}

extension BreadStep {
    var formattedDuration: String {
        let totalSeconds = Int(timerDuration)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if days >= 7 && days % 7 == 0 {
            let weeks = days / 7
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        } else if days > 0 {
        if hours > 0 {
                return "\(days)d \(hours)hr"
            }
            return days == 1 ? "1 day" : "\(days) days"
        } else if hours > 0 {
            if minutes > 0 {
            return "\(hours)hr \(minutes)min"
            }
            return "\(hours)hr"
        } else {
            return "\(minutes)min"
        }
    }
    
    /// Localized instruction for this step, given a recipe key prefix
    func localizedInstruction(recipeKeyPrefix: String) -> String {
        let key = "\(recipeKeyPrefix).step.\(stepNumber).instruction"
        let localized = key.localized
        // If localization key doesn't exist, fall back to original
        return localized == key ? instruction : localized
    }
    
    /// Localized notes for this step, given a recipe key prefix
    func localizedNotes(recipeKeyPrefix: String) -> String {
        let key = "\(recipeKeyPrefix).step.\(stepNumber).notes"
        let localized = key.localized
        // If localization key doesn't exist, fall back to original
        return localized == key ? notes : localized
    }
}

extension BreadRecipe {
    var iconName: String {
        // Custom recipes use their custom icon name
        if isCustom, let customIcon = customIconName {
            return customIcon
        }
        
        switch name {
        case "French Baguette":
            return "leaf.fill"
        case "Starter refresh":
            return "arrow.triangle.2.circlepath"
        case "Bread Ball", "Sourdough Bread Ball":
            return "circle.fill"
        case "Croissant", "Croissants":
            return "moon.fill"
        case "Brioche":
            return "star.fill"
        case "Pain au Chocolat":
            return "square.fill"
        case "Bagels":
            return "circle.dotted"
        case "English Muffins":
            return "circle.grid.2x2.fill"
        // Yeasted
        case "White Sandwich Bread":
            return "rectangle.fill"
        case "Whole Wheat Bread":
            return "square.stack.fill"
        case "Multigrain Bread":
            return "square.grid.2x2.fill"
        case "Country Loaf":
            return "circle.circle.fill"
        case "Farmhouse Bread":
            return "house.fill"
        case "Pullman Loaf":
            return "rectangle.portrait.fill"
        case "Milk Bread (Hokkaido)":
            return "drop.fill"
        case "Potato Bread":
            return "circle.hexagongrid.fill"
        case "Oat Bread":
            return "circle.grid.cross.fill"
        case "Spelt Bread":
            return "circle.grid.3x3.fill"
        // Artisan
        case "Levain Bread":
            return "sparkles"
        case "Ciabatta":
            return "rectangle.fill"
        case "Pain de Campagne":
            return "mountain.2.fill"
        case "Rustic Boule":
            return "circle.fill"
        case "No-Knead Bread":
            return "hand.raised.fill"
        case "Poolish Bread":
            return "drop.fill"
        case "Biga Bread":
            return "drop.triangle.fill"
        case "Autolyse Bread":
            return "hourglass"
        // Enriched
        case "Challah":
            return "star.fill"
        case "Babka":
            return "star.circle.fill"
        case "Panettone":
            return "star.circle.fill"
        case "Pandoro":
            return "star.square.fill"
        case "Milk Rolls":
            return "circle.grid.3x3.fill"
        case "Sweet Rolls":
            return "circle.grid.cross.fill"
        case "Cinnamon Rolls":
            return "circle.grid.hex.fill"
        case "Raisin Bread":
            return "circle.grid.2x2.fill"
        // Flatbread
        case "Naan":
            return "circle.fill"
        case "Pita":
            return "circle.circle.fill"
        case "Roti":
            return "circlebadge.fill"
        case "Chapati":
            return "circlebadge.fill"
        case "Paratha":
            return "layers.fill"
        case "Kulcha":
            return "circle.fill"
        case "Lavash":
            return "rectangle.portrait.fill"
        case "Yufka":
            return "rectangle.portrait.fill"
        case "Bazlama":
            return "circle.rectangle.fill"
        // Rye
        case "Rye Bread":
            return "circle.hexagongrid.fill"
        case "Pumpernickel":
            return "circle.grid.3x3.fill"
        case "Black Bread":
            return "circle.fill"
        case "Vollkornbrot":
            return "circle.grid.cross.fill"
        case "Borodinsky Bread":
            return "circle.grid.hex.fill"
        case "Mixed Rye-Wheat Bread":
            return "circle.grid.2x2.fill"
        // Mediterranean
        case "Focaccia":
            return "square.grid.3x3.fill"
        case "Pizza Dough":
            return "circle.grid.3x3.fill"
        case "Schiacciata":
            return "square.stack.3d.up.fill"
        case "Ligurian Flatbread":
            return "square.stack.3d.down.fill"
        case "Olive Bread":
            return "circle.circle.fill"
        default:
            return "birthday.cake.fill"
        }
    }
    
    var imageName: String? {
        // Custom recipes don't use asset catalog images
        if isCustom {
            return nil
        }
        
        switch name {
        case "French Baguette":
            return "FrenchBaguetteImage"
        case "Starter refresh":
            return "RefreshStarterImage"
        case "Bread Ball", "Sourdough Bread Ball":
            return "SourdoughBreadBallImage"
        case "Croissant", "Croissants":
            return "CroissantsImage"
        case "Brioche":
            return "BriocheImage"
        case "Pain au Chocolat":
            return "PainAuChocolatImage"
        case "Bagels":
            return "BagelsImage"
        case "English Muffins":
            return "EnglishMuffinsImage"
        // Yeasted
        case "White Sandwich Bread":
            return "WhiteSandwichBreadImage"
        case "Whole Wheat Bread":
            return "WholeWheatBreadImage"
        case "Multigrain Bread":
            return "MultigrainBreadImage"
        case "Country Loaf":
            return "CountryLoafImage"
        case "Farmhouse Bread":
            return "FarmhouseBreadImage"
        case "Pullman Loaf":
            return "PullmanLoafImage"
        case "Milk Bread (Hokkaido)":
            return "MilkBreadHokkaidoImage"
        case "Potato Bread":
            return "PotatoBreadImage"
        case "Oat Bread":
            return "OatBreadImage"
        case "Spelt Bread":
            return "SpeltBreadImage"
        // Artisan
        case "Levain Bread":
            return "LevainBreadImage"
        case "Ciabatta":
            return "CiabattaImage"
        case "Pain de Campagne":
            return "PainDeCampagneImage"
        case "Rustic Boule":
            return "RusticBouleImage"
        case "No-Knead Bread":
            return "NoKneadBreadImage"
        case "Poolish Bread":
            return "PoolishBreadImage"
        case "Biga Bread":
            return "BigaBreadImage"
        case "Autolyse Bread":
            return "AutolyseBreadImage"
        // Enriched
        case "Challah":
            return "ChallahImage"
        case "Babka":
            return "BabkaImage"
        case "Panettone":
            return "PanettoneImage"
        case "Pandoro":
            return "PandoroImage"
        case "Milk Rolls":
            return "MilkRollsImage"
        case "Sweet Rolls":
            return "SweetRollsImage"
        case "Cinnamon Rolls":
            return "CinnamonRollsImage"
        case "Raisin Bread":
            return "RaisinBreadImage"
        // Flatbread
        case "Naan":
            return "NaanImage"
        case "Pita":
            return "PitaImage"
        case "Roti":
            return "RotiImage"
        case "Chapati":
            return "ChapatiImage"
        case "Paratha":
            return "ParathaImage"
        case "Kulcha":
            return "KulchaImage"
        case "Lavash":
            return "LavashImage"
        case "Yufka":
            return "YufkaImage"
        case "Bazlama":
            return "BazlamaImage"
        // Rye
        case "Rye Bread":
            return "RyeBreadImage"
        case "Pumpernickel":
            return "PumpernickelImage"
        case "Black Bread":
            return "BlackBreadImage"
        case "Vollkornbrot":
            return "VollkornbrotImage"
        case "Borodinsky Bread":
            return "BorodinskyBreadImage"
        case "Mixed Rye-Wheat Bread":
            return "MixedRyeWheatBreadImage"
        // Mediterranean
        case "Focaccia":
            return "FocacciaImage"
        case "Pizza Dough":
            return "PizzaDoughImage"
        case "Schiacciata":
            return "SchiacciataImage"
        case "Ligurian Flatbread":
            return "LigurianFlatbreadImage"
        case "Olive Bread":
            return "OliveBreadImage"
        default:
            return nil
        }
    }
    
    /// Localized recipe name
    var localizedName: String {
        // Custom recipes use their name directly (not localized)
        if isCustom {
            return name
        }
        
        // For new recipes, use the recipeKeyPrefix to get the localized name
        let key = "\(recipeKeyPrefix).name"
        let localized = key.localized
        // If localization key doesn't exist, fall back to original name
        return localized == key ? name : localized
    }
    
    /// Recipe key prefix for localization (e.g., "recipe.french.baguette")
    var recipeKeyPrefix: String {
        // Custom recipes use a unique prefix based on ID
        if isCustom {
            return "custom.\(id.uuidString)"
        }
        
        switch name {
        case "French Baguette":
            return "recipe.french.baguette"
        case "Starter refresh":
            return "recipe.refresh.starter"
        case "Bread Ball", "Sourdough Bread Ball":
            return "recipe.sourdough.bread.ball"
        case "Croissant", "Croissants":
            return "recipe.croissants"
        case "Brioche":
            return "recipe.brioche"
        case "Pain au Chocolat":
            return "recipe.pain.au.chocolat"
        case "Bagels":
            return "recipe.bagels"
        case "English Muffins":
            return "recipe.english.muffins"
        // New recipes - use name as key prefix (will be localized)
        default:
            // Convert name to key format (e.g., "White Sandwich Bread" -> "recipe.white.sandwich.bread")
            let keyName = name.lowercased().replacingOccurrences(of: " ", with: ".").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").replacingOccurrences(of: "-", with: ".")
            return "recipe.\(keyName)"
        }
    }
    
    static let frenchBaguette = BreadRecipe(
        name: "French Baguette",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Feed starter", timerDuration: 8 * 3600, notes: "50gr. of Water and 50 gr. of Flour for 2 baguettes"), // 8 hours
            BreadStep(stepNumber: 2, instruction: "Prepare the dough", timerDuration: 30 * 60, notes: "325gr. Water\n10gr. Salt\n100gr. Starter\n450gr. Bread Flower\nRest with Towel on top"), // 30 minutes
            BreadStep(stepNumber: 3, instruction: "Stretch the dough", timerDuration: 30 * 60, notes: "Stretch and fold 4 sides\nRest with towel on top"), // 30 minutes
            BreadStep(stepNumber: 4, instruction: "Stretch the dough", timerDuration: 30 * 60, notes: "Stretch and fold 4 sides\nRest with towel on top"), // 30 minutes
            BreadStep(stepNumber: 5, instruction: "Stretch the dough", timerDuration: 12 * 3600, notes: "Stretch and fold 4 sides\nRest with towel on top"), // 12 hours
            BreadStep(stepNumber: 6, instruction: "Prepare for baking", timerDuration: 15 * 60, notes: "Take half out of the bowl (keep other half for the next day)\nSplit in 2 balls and let it rest"), // 15 minutes
            BreadStep(stepNumber: 7, instruction: "Shape the baguettes", timerDuration: 30 * 60, notes: "Shape the 2 balls in baguettes\nBread flower on top\nPlace on Parchment paper on tray\nCover with towel"), // 30 minutes
            BreadStep(stepNumber: 8, instruction: "Place in oven", timerDuration: 20 * 60, notes: "Score the bread (3 slashes)\nAdd 1cup water for steam\nPlace tray in oven\nPre-heat oven to 500 degrees"), // 20 minutes
            BreadStep(stepNumber: 9, instruction: "Turn the tray", timerDuration: 7 * 60, notes: "Turn the tray in the oven and if needed turn the baguettes upside down"), // 7 minutes
            BreadStep(stepNumber: 10, instruction: "Take out of the oven", timerDuration: 10 * 60, notes: "Cover with a cloth") // 10 minutes
        ],
        category: .artisan
    )

    static let refreshStarter = BreadRecipe(
        name: "Starter refresh",
        steps: [
            BreadStep(
                stepNumber: 1,
                instruction: "Feed the starter",
                timerDuration: 12 * 3600, // 12 hours
                notes: "Remove the starter from the fridge and discard 2 tablespoons of starter.\n\nAdd 2 tablespoons of fresh flour and 2 tablespoons of filtered or spring water.\n\nMix well, cover with a breathable cloth & rubber band.\n\nLet rest at room temperature for 12 hours."
            ),
            BreadStep(
                stepNumber: 2,
                instruction: "Return to fridge",
                timerDuration: 7 * 24 * 3600, // 1 week
                notes: "Cover with a closed lid and return to the fridge.\n\nReminder set for 1 week to refresh the starter again."
            )
        ],
        category: .artisan
    )
    
    static let breadBall = BreadRecipe(
        name: "Sourdough Bread Ball",
        steps: [
            BreadStep(
                stepNumber: 1,
                instruction: "Prepare the dough",
                timerDuration: 60 * 60, // 60 minutes
                notes: "• 325 g water\n• 10 g salt\n• 100 g starter\n• 450 g bread flour\n• Mix until combined\n• Cover with towel"
            ),
            BreadStep(
                stepNumber: 2,
                instruction: "Stretch & Fold #1",
                timerDuration: 30 * 60, // 30 minutes
                notes: "• Wet hands\n• Lift one side of the dough and fold over\n• Rotate bowl ¼ turn and repeat 3–4 times\n• Cover with towel"
            ),
            BreadStep(
                stepNumber: 3,
                instruction: "Stretch & Fold #2",
                timerDuration: 30 * 60, // 30 minutes
                notes: "• Repeat stretch-and-fold process\n• Keep dough covered"
            ),
            BreadStep(
                stepNumber: 4,
                instruction: "Stretch & Fold #3",
                timerDuration: 30 * 60, // 30 minutes
                notes: "• Repeat stretch-and-fold process\n• Keep dough covered"
            ),
            BreadStep(
                stepNumber: 5,
                instruction: "Stretch & Fold #4",
                timerDuration: 60 * 60, // 60 minutes
                notes: "• Final stretch-and-fold\n• Dough should feel tighter and smoother\n• Cover with towel"
            ),
            BreadStep(
                stepNumber: 6,
                instruction: "Shape the dough ball",
                timerDuration: 60 * 60, // 60 minutes
                notes: "• Lightly flour the counter\n• Shape into a tight round ball (boule)\n• Place seam-side up in a floured bowl/banneton\n• Cover with towel"
            ),
            BreadStep(
                stepNumber: 7,
                instruction: "Final Proof (Cold Fermentation)",
                timerDuration: 14 * 3600, // 14 hours (middle of 12-16 hour range)
                notes: "• Place dough in refrigerator\n• Proof overnight (12–16 hours)\n• Dough will rise slowly and develop flavor"
            ),
            BreadStep(
                stepNumber: 8,
                instruction: "Preheat the oven",
                timerDuration: 30 * 60, // 30 minutes
                notes: "• Preheat oven to 475°F (245°C)\n• Put Dutch oven inside to heat\n• Allow at least 30 minutes of preheating"
            ),
            BreadStep(
                stepNumber: 9,
                instruction: "Score & Bake",
                timerDuration: 30 * 60, // 30 minutes
                notes: "• Remove dough from fridge\n• Flip onto parchment\n• Score the top\n• Bake in Dutch oven:\n• 20 min lid ON\n• 20–25 min lid OFF\n• Cool 1 hour before slicing"
            ),
            BreadStep(
                stepNumber: 10,
                instruction: "Your bread is ready!",
                timerDuration: 0, // End of recipe - no timer needed
                notes: "• Slice and enjoy\n\nEnd of the recipe"
            )
        ],
        category: .artisan
    )
    
    static let brioche = BreadRecipe(
        name: "Brioche",
        steps: [
            BreadStep(
                stepNumber: 1,
                instruction: "Prepare and knead the dough",
                timerDuration: 2 * 3600, // 2 hours first rise
                notes: "• 250 g milk (lukewarm)\n• 10 g dry yeast\n• 60 g sugar\n• 3 eggs\n• Mix until combined\n• Add 500 g flour and 10 g salt\n• Mix until dough starts forming\n• Add 150 g softened butter, piece by piece\n• Knead until dough is smooth, elastic, and shiny\n• Dough will be sticky — this is normal\n\nFirst Rise:\n• Cover the bowl\n• Leave in warm room\n• Dough should double in size"
            ),
            BreadStep(
                stepNumber: 2,
                instruction: "Shape the Brioche",
                timerDuration: 1 * 3600, // 1 hour proofing
                notes: "• Gently press down dough to remove excess air\n• Do not over-knead\n\nChoose one shape:\n• Brioche loaf → divide into 3–4 balls, place in loaf pan\n• Brioche balls → form tight round balls, place in mold\n• Cover with towel\n\nSecond Rise (Proofing):\n• Dough should rise until almost doubled\n• Very important for softness"
            ),
            BreadStep(
                stepNumber: 3,
                instruction: "Egg wash and Bake",
                timerDuration: 27 * 60, // ~27 minutes baking
                notes: "• Preheat oven to 350°F (175°C)\n• Mix 1 egg + a splash of milk\n• Brush gently on top\n• Bake 25–30 minutes (loaf)\n• Or 18–22 minutes (individual balls)\n• Golden brown on top\n• Let cool slightly before serving"
            )
        ],
        category: .enriched
    )
    
    static let croissant = BreadRecipe(
        name: "Croissants",
        steps: [
            BreadStep(
                stepNumber: 1,
                instruction: "Prepare the dough (Détrempe)",
                timerDuration: 1 * 3600, // 1 hour refrigeration
                notes: "• 500 g flour\n• 10 g salt\n• 60 g sugar\n• 10 g dry yeast\n• 300 g cold milk\n• Mix until dough forms\n• Knead gently 2–3 minutes until smooth\n• Shape into rectangle, wrap and refrigerate\n\nDuring this time, prepare the butter block:\n• 250 g cold butter\n• Shape into 15×15 cm flat square\n• Wrap and refrigerate"
            ),
            BreadStep(
                stepNumber: 2,
                instruction: "Encase the butter",
                timerDuration: 30 * 60, // 30 minutes chilling
                notes: "• Place butter block in center of dough\n• Fold dough over butter (envelope shape)\n• Seal edges tightly\n• Wrap and refrigerate"
            ),
            BreadStep(
                stepNumber: 3,
                instruction: "First Fold (Lamination)",
                timerDuration: 30 * 60, // 30 minutes chilling
                notes: "• Roll dough into a long rectangle\n• Fold in thirds (like a letter)\n• Wrap and chill"
            ),
            BreadStep(
                stepNumber: 4,
                instruction: "Second Fold (Lamination)",
                timerDuration: 30 * 60, // 30 minutes chilling
                notes: "• Roll out again into long rectangle\n• Fold in thirds again\n• Wrap and chill"
            ),
            BreadStep(
                stepNumber: 5,
                instruction: "Third Fold (Final Lamination)",
                timerDuration: 1 * 3600, // 1 hour chilling
                notes: "• Roll and fold in thirds one last time\n• This completes 3 folds\n• Wrap and chill"
            ),
            BreadStep(
                stepNumber: 6,
                instruction: "Shape the croissants",
                timerDuration: 2 * 3600, // 2 hours proofing
                notes: "• Roll dough to ~4 mm thickness\n• Cut long isosceles triangles (base ~8–10 cm)\n• Make small slit at base, stretch gently\n• Roll from base to tip, place tip underneath\n• Arrange on baking tray\n\nProofing:\n• Cover and let rise at 77–80°F (25–27°C)\n• Should become puffy and slightly jiggly\n• Do NOT let butter melt"
            ),
            BreadStep(
                stepNumber: 7,
                instruction: "Egg wash and Bake",
                timerDuration: 12 * 60, // 12 minutes first bake
                notes: "• Preheat oven to 400°F (200°C)\n• Mix 1 egg + splash of milk\n• Brush gently on top of croissants\n• Place in oven and bake at 400°F"
            ),
            BreadStep(
                stepNumber: 8,
                instruction: "Lower temperature and finish baking",
                timerDuration: 10 * 60, // 8-10 minutes second bake
                notes: "• Lower oven to 375°F (190°C)\n• Continue baking 8–10 more minutes\n• Should be golden with flaky, crispy layers\n• Let cool slightly before serving"
            )
        ],
        category: .enriched
    )
    
    static let painAuChocolat = BreadRecipe(
        name: "Pain au Chocolat",
        steps: [
            BreadStep(
                stepNumber: 1,
                instruction: "Prepare the dough (Détrempe)",
                timerDuration: 1 * 3600, // 1 hour refrigeration
                notes: "• 500 g flour\n• 10 g salt\n• 60 g sugar\n• 10 g dry yeast\n• 300 g cold milk\n• Mix until dough forms\n• Knead gently 2–3 minutes until smooth\n• Shape into rectangle, wrap and refrigerate\n\nDuring this time, prepare the butter block:\n• 250 g cold butter\n• Shape into 15×15 cm flat square\n• Wrap and refrigerate"
            ),
            BreadStep(
                stepNumber: 2,
                instruction: "Encase the butter",
                timerDuration: 30 * 60, // 30 minutes chilling
                notes: "• Place butter block in the center of dough\n• Fold dough over butter (envelope shape)\n• Seal edges tightly\n• Wrap and refrigerate"
            ),
            BreadStep(
                stepNumber: 3,
                instruction: "First Fold (Lamination)",
                timerDuration: 30 * 60, // 30 minutes chilling
                notes: "• Roll dough into a long rectangle\n• Fold in thirds (like a letter)\n• Wrap and chill"
            ),
            BreadStep(
                stepNumber: 4,
                instruction: "Second Fold (Lamination)",
                timerDuration: 30 * 60, // 30 minutes chilling
                notes: "• Roll out again into long rectangle\n• Fold in thirds again\n• Wrap and chill"
            ),
            BreadStep(
                stepNumber: 5,
                instruction: "Third Fold (Final Lamination)",
                timerDuration: 1 * 3600, // 1 hour chilling
                notes: "• Roll and fold in thirds one last time\n• This completes 3 folds\n• Wrap and chill"
            ),
            BreadStep(
                stepNumber: 6,
                instruction: "Shape the pain au chocolat",
                timerDuration: 2 * 3600, // 2 hours proofing
                notes: "• Roll dough to ~4 mm thickness\n• Cut rectangles about 8×12 cm\n• Place one chocolate baton near the short edge\n• Roll once, add second baton\n• Finish rolling, seam underneath\n• Place on baking tray\n\nProofing:\n• Cover and let rise at 77–80°F (25–27°C)\n• Should become puffy and aerated\n• Butter must not melt"
            ),
            BreadStep(
                stepNumber: 7,
                instruction: "Egg wash and Bake",
                timerDuration: 12 * 60, // 12 minutes first bake
                notes: "• Preheat oven to 400°F (200°C)\n• Mix 1 egg + splash of milk\n• Brush lightly on top\n• Place in oven and bake at 400°F"
            ),
            BreadStep(
                stepNumber: 8,
                instruction: "Lower temperature and finish baking",
                timerDuration: 10 * 60, // 8-10 minutes second bake
                notes: "• Lower oven to 375°F (190°C)\n• Continue baking 8–10 more minutes\n• Should be golden and flaky\n• Let cool slightly before serving"
            )
        ],
        category: .enriched
    )
    
    static let bagels = BreadRecipe(
        name: "Bagels",
        steps: [
            BreadStep(
                stepNumber: 1,
                instruction: "Prepare and knead the dough",
                timerDuration: 1 * 3600, // 1 hour first rise
                notes: "• 500 g bread flour\n• 10 g salt\n• 10 g sugar\n• 7 g dry yeast\n• 300 g warm water\n• Mix until dough comes together\n• Knead 8–10 minutes until smooth and firm\n• Dough should be stiffer than bread dough\n• Form into a ball\n\nFirst Rise:\n• Place dough in lightly oiled bowl\n• Cover\n• Let rise until doubled"
            ),
            BreadStep(
                stepNumber: 2,
                instruction: "Shape the bagels",
                timerDuration: 20 * 60, // 20 minutes second rise
                notes: "• Cut dough into 8 equal pieces\n• Roll each into a tight ball\n\nUse one of two methods:\n• Method A: Poke hole in center, stretch to 3–4 cm\n• Method B: Roll rope & seal ends together\n• Place on tray\n\nSecond Rise:\n• Cover shaped bagels with towel\n• Let rest before boiling"
            ),
            BreadStep(
                stepNumber: 3,
                instruction: "Boil, add toppings, and Bake",
                timerDuration: 20 * 60, // ~20 minutes baking
                notes: "• Preheat oven to 425°F (220°C)\n• Bring water to boil\n• Add 1 tbsp sugar or honey (optional)\n• Boil bagels 30–45 sec per side\n• Remove and drain\n\nChoose toppings:\n• Sesame, Poppy, Everything mix, Onion flakes, or plain\n• Press gently onto wet dough\n\nBake:\n• Place on baking sheet\n• Bake 18–22 minutes\n• Should be golden and shiny"
            )
        ],
        category: .yeasted
    )
    
    static let englishMuffins = BreadRecipe(
        name: "English Muffins",
        steps: [
            BreadStep(
                stepNumber: 1,
                instruction: "Prepare and knead the dough",
                timerDuration: 1 * 3600, // 1 hour first rise
                notes: "• 350 g milk (warm)\n• 30 g butter (melted)\n• 20 g sugar\n• 7 g dry yeast\n• Mix until dissolved\n• Add 500 g flour and 10 g salt\n• Mix until dough forms\n• Dough should be soft and slightly sticky\n• Knead 5–7 minutes until smooth\n• Avoid adding too much flour\n\nFirst Rise:\n• Place dough in lightly oiled bowl\n• Cover with towel\n• Allow to double in size"
            ),
            BreadStep(
                stepNumber: 2,
                instruction: "Shape the muffins",
                timerDuration: 20 * 60, // 20 minutes second rise
                notes: "• Turn dough onto floured surface\n• Roll to ~2 cm thickness\n• Dust surface with flour or semolina\n• Use a 7–8 cm cutter\n• Transfer rounds onto semolina-covered tray\n• Dust tops with semolina as well\n\nSecond Rise:\n• Cover muffins lightly\n• Let puff up slightly\n• Do not overproof"
            ),
            BreadStep(
                stepNumber: 3,
                instruction: "Cook on skillet (First Side)",
                timerDuration: 7 * 60, // 7 minutes
                notes: "• Preheat skillet on low-medium heat\n• No oil or butter\n• Cook muffins 6–7 minutes on first side\n• Should brown gently"
            ),
            BreadStep(
                stepNumber: 4,
                instruction: "Flip and cook (Second Side)",
                timerDuration: 7 * 60, // 7 minutes
                notes: "• Flip muffins\n• Cook another 6–7 minutes\n• They should rise and firm up"
            ),
            BreadStep(
                stepNumber: 5,
                instruction: "Finish in oven",
                timerDuration: 6 * 60, // 6 minutes
                notes: "• Preheat oven to 350°F (175°C)\n• Bake 5–7 minutes to finish interior crumb\n• Helps form iconic \"nooks & crannies\"\n• Let cool before splitting with a fork"
            )
        ],
        category: .yeasted
    )

    // MARK: - New Recipes from CSV Data
    
    // Yeasted Breads
    static let whiteSandwichBread = BreadRecipe(
        name: "White Sandwich Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 60 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Water\n• 7g Yeast\n• 20g Sugar\n• 10g Salt\n• 30g Butter\n\nAction: Mix until smooth dough forms"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Degas and shape loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 35 * 60, notes: "Bake at 180C for 35 min")
        ],
        category: .yeasted
    )
    
    static let wholeWheatBread = BreadRecipe(
        name: "Whole Wheat Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Whole wheat flour\n• 340ml Water\n• 7g Yeast\n• 20g Honey\n• 10g Salt\n• 30g Oil\n\nAction: Mix until elastic"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 40 * 60, notes: "Bake at 185C for 40 min")
        ],
        category: .yeasted
    )
    
    static let multigrainBread = BreadRecipe(
        name: "Multigrain Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Soak Grains", timerDuration: 30 * 60, notes: "Ingredients:\n• 80g Multigrain mix\n• 120ml Hot water\n\nAction: Soak grains"),
            BreadStep(stepNumber: 2, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 420g Flour\n• Soaked grains\n• 220ml Water\n• 7g Yeast\n• 10g Salt\n• 20g Honey\n\nAction: Mix dough"),
            BreadStep(stepNumber: 3, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 4, instruction: "Bake", timerDuration: 40 * 60, notes: "Bake at 190C for 40 min")
        ],
        category: .yeasted
    )
    
    static let countryLoaf = BreadRecipe(
        name: "Country Loaf",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 500g Flour\n• 350ml Water\n• 3g Yeast\n• 10g Salt\n\nAction: Mix rough dough"),
            BreadStep(stepNumber: 2, instruction: "Fold", timerDuration: 45 * 60, notes: "Stretch and fold"),
            BreadStep(stepNumber: 3, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape boule"),
            BreadStep(stepNumber: 4, instruction: "Bake", timerDuration: 40 * 60, notes: "Bake at 240C then 220C for 40 min")
        ],
        category: .yeasted
    )
    
    static let farmhouseBread = BreadRecipe(
        name: "Farmhouse Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 75 * 60, notes: "Ingredients:\n• 500g Flour\n• 320ml Water\n• 7g Yeast\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape round loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 40 * 60, notes: "Bake at 200C for 40 min")
        ],
        category: .yeasted
    )
    
    static let pullmanLoaf = BreadRecipe(
        name: "Pullman Loaf",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 60 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Milk\n• 7g Yeast\n• 30g Sugar\n• 10g Salt\n• 40g Butter\n\nAction: Mix enriched dough"),
            BreadStep(stepNumber: 2, instruction: "Pan", timerDuration: 45 * 60, notes: "Place in Pullman pan and close lid"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 35 * 60, notes: "Bake at 180C for 35 min")
        ],
        category: .yeasted
    )
    
    static let milkBreadHokkaido = BreadRecipe(
        name: "Milk Bread (Hokkaido)",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Tangzhong", timerDuration: 10 * 60, notes: "Ingredients:\n• 25g Flour\n• 125ml Milk\n\nAction: Cook paste until thick"),
            BreadStep(stepNumber: 2, instruction: "Mix", timerDuration: 75 * 60, notes: "Ingredients:\n• 475g Flour\n• 150ml Milk\n• 7g Yeast\n• 50g Sugar\n• 10g Salt\n• 50g Butter\n• All Tangzhong\n\nAction: Mix smooth dough"),
            BreadStep(stepNumber: 3, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 4, instruction: "Bake", timerDuration: 35 * 60, notes: "Bake at 175C for 35 min")
        ],
        category: .yeasted
    )
    
    static let potatoBread = BreadRecipe(
        name: "Potato Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 450g Flour\n• 150g Mashed potato\n• 250ml Water\n• 7g Yeast\n• 10g Salt\n• 30g Butter\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2400, notes: "Bake at 190C for 40 min")
        ],
        category: .yeasted
    )
    
    static let oatBread = BreadRecipe(
        name: "Oat Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Soak Oats", timerDuration: 20 * 60, notes: "Ingredients:\n• 80g Oats\n• 120ml Hot water\n\nAction: Soak oats"),
            BreadStep(stepNumber: 2, instruction: "Mix", timerDuration: 75 * 60, notes: "Ingredients:\n• 420g Flour\n• Soaked oats\n• 200ml Water\n• 7g Yeast\n• 10g Salt\n• 30g Honey\n\nAction: Mix dough"),
            BreadStep(stepNumber: 3, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 4, instruction: "Bake", timerDuration: 40 * 60, notes: "Bake at 190C for 40 min")
        ],
        category: .yeasted
    )
    
    static let speltBread = BreadRecipe(
        name: "Spelt Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 60 * 60, notes: "Ingredients:\n• 500g Spelt flour\n• 320ml Water\n• 7g Yeast\n• 10g Salt\n\nAction: Mix gently"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 40 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 35 * 60, notes: "Bake at 200C for 35 min")
        ],
        category: .yeasted
    )
    
    // Artisan Breads
    static let levainBread = BreadRecipe(
        name: "Levain Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Autolyse", timerDuration: 45 * 60, notes: "Ingredients:\n• 500g Flour\n• 350ml Water\n\nAction: Mix roughly"),
            BreadStep(stepNumber: 2, instruction: "Mix Levain", timerDuration: 240 * 60, notes: "Ingredients:\n• 100g Levain\n• 10g Salt\n\nAction: Fold into dough"),
            BreadStep(stepNumber: 3, instruction: "Shape", timerDuration: 60 * 60, notes: "Shape boule"),
            BreadStep(stepNumber: 4, instruction: "Bake", timerDuration: 2400, notes: "Bake at 240C for 40 min")
        ],
        category: .artisan
    )
    
    static let ciabatta = BreadRecipe(
        name: "Ciabatta",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 180 * 60, notes: "Ingredients:\n• 500g Flour\n• 400ml Water\n• 3g Yeast\n• 10g Salt\n\nAction: Mix wet dough"),
            BreadStep(stepNumber: 2, instruction: "Divide", timerDuration: 30 * 60, notes: "Divide gently"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 1080, notes: "Bake at 240C for 18 min")
        ],
        category: .artisan
    )
    
    static let painDeCampagne = BreadRecipe(
        name: "Pain de Campagne",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 350g White flour\n• 150g Whole wheat flour\n• 350ml Water\n• 3g Yeast\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 60 * 60, notes: "Shape boule"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2400, notes: "Bake at 230C for 40 min")
        ],
        category: .artisan
    )
    
    static let rusticBoule = BreadRecipe(
        name: "Rustic Boule",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 150 * 60, notes: "Ingredients:\n• 500g Flour\n• 370ml Water\n• 3g Yeast\n• 10g Salt\n\nAction: Mix high hydration dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 60 * 60, notes: "Shape boule"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2400, notes: "Bake at 240C for 40 min")
        ],
        category: .artisan
    )
    
    static let noKneadBread = BreadRecipe(
        name: "No-Knead Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 960 * 60, notes: "Ingredients:\n• 500g Flour\n• 375ml Water\n• 1g Yeast\n• 10g Salt\n\nAction: Mix shaggy dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2400, notes: "Bake at 240C for 40 min")
        ],
        category: .artisan
    )
    
    static let poolishBread = BreadRecipe(
        name: "Poolish Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Poolish", timerDuration: 720 * 60, notes: "Ingredients:\n• 250g Flour\n• 250ml Water\n• 1g Yeast\n\nAction: Mix poolish"),
            BreadStep(stepNumber: 2, instruction: "Final Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 250g Flour\n• 100ml Water\n• 10g Salt\n\nAction: Mix final dough"),
            BreadStep(stepNumber: 3, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 4, instruction: "Bake", timerDuration: 2100, notes: "Bake at 240C for 35 min")
        ],
        category: .artisan
    )
    
    static let bigaBread = BreadRecipe(
        name: "Biga Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Biga", timerDuration: 720 * 60, notes: "Ingredients:\n• 250g Flour\n• 150ml Water\n• 1g Yeast\n\nAction: Mix stiff biga"),
            BreadStep(stepNumber: 2, instruction: "Final Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 250g Flour\n• 200ml Water\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 3, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 4, instruction: "Bake", timerDuration: 2100, notes: "Bake at 230C for 35 min")
        ],
        category: .artisan
    )
    
    static let autolyseBread = BreadRecipe(
        name: "Autolyse Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Autolyse", timerDuration: 45 * 60, notes: "Ingredients:\n• 500g Flour\n• 350ml Water\n\nAction: Mix and rest"),
            BreadStep(stepNumber: 2, instruction: "Mix Yeast", timerDuration: 120 * 60, notes: "Ingredients:\n• 3g Yeast\n• 10g Salt\n\nAction: Mix fully"),
            BreadStep(stepNumber: 3, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 4, instruction: "Bake", timerDuration: 2400, notes: "Bake at 240C for 40 min")
        ],
        category: .artisan
    )
    
    // Enriched Breads
    static let challah = BreadRecipe(
        name: "Challah",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 2 Eggs\n• 180ml Water\n• 60g Oil\n• 50g Sugar\n• 7g Yeast\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Braid", timerDuration: 45 * 60, notes: "Braid loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2100, notes: "Bake at 180C for 35 min")
        ],
        category: .enriched
    )
    
    static let babka = BreadRecipe(
        name: "Babka",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 200ml Milk\n• 2 Eggs\n• 80g Butter\n• 80g Sugar\n• 7g Yeast\n\nAction: Mix rich dough"),
            BreadStep(stepNumber: 2, instruction: "Fill & Roll", timerDuration: 45 * 60, notes: "Ingredients:\n• 150g Chocolate filling\n• 40g Butter\n\nAction: Fill and roll dough"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2400, notes: "Bake at 180C for 40 min")
        ],
        category: .enriched
    )
    
    static let panettone = BreadRecipe(
        name: "Panettone",
        steps: [
            BreadStep(stepNumber: 1, instruction: "First Dough", timerDuration: 600 * 60, notes: "Ingredients:\n• 300g Flour\n• 150ml Water\n• 5g Yeast\n\nAction: Mix starter dough"),
            BreadStep(stepNumber: 2, instruction: "Final Dough", timerDuration: 180 * 60, notes: "Ingredients:\n• 200g Flour\n• 4 Eggs\n• 120g Butter\n• 120g Sugar\n\nAction: Mix enriched dough"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2700, notes: "Bake at 170C for 45 min")
        ],
        category: .enriched
    )
    
    static let pandoro = BreadRecipe(
        name: "Pandoro",
        steps: [
            BreadStep(stepNumber: 1, instruction: "First Dough", timerDuration: 600 * 60, notes: "Ingredients:\n• 300g Flour\n• 150ml Water\n• 5g Yeast\n\nAction: Mix starter dough"),
            BreadStep(stepNumber: 2, instruction: "Final Dough", timerDuration: 180 * 60, notes: "Ingredients:\n• 200g Flour\n• 4 Eggs\n• 180g Butter\n• 120g Sugar\n\nAction: Mix dough"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2700, notes: "Bake at 170C for 45 min")
        ],
        category: .enriched
    )
    
    static let milkRolls = BreadRecipe(
        name: "Milk Rolls",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 75 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Milk\n• 40g Sugar\n• 50g Butter\n• 7g Yeast\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape balls"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 1500, notes: "Bake at 175C for 25 min")
        ],
        category: .enriched
    )
    
    static let sweetRolls = BreadRecipe(
        name: "Sweet Rolls",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Milk\n• 80g Sugar\n• 80g Butter\n• 7g Yeast\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape rolls"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 1800, notes: "Bake at 180C for 30 min")
        ],
        category: .enriched
    )
    
    static let cinnamonRolls = BreadRecipe(
        name: "Cinnamon Rolls",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Milk\n• 80g Sugar\n• 80g Butter\n• 7g Yeast\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Fill", timerDuration: 45 * 60, notes: "Ingredients:\n• 10g Cinnamon\n• 80g Sugar\n• 40g Butter\n\nAction: Fill and roll"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 1800, notes: "Bake at 180C for 30 min")
        ],
        category: .enriched
    )
    
    static let raisinBread = BreadRecipe(
        name: "Raisin Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Milk\n• 60g Sugar\n• 60g Butter\n• 7g Yeast\n• 120g Raisins\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2100, notes: "Bake at 180C for 35 min")
        ],
        category: .enriched
    )
    
    // Flatbread
    static let naan = BreadRecipe(
        name: "Naan",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 120g Yogurt\n• 180ml Water\n• 5g Yeast\n• 30g Oil\n\nAction: Mix soft dough"),
            BreadStep(stepNumber: 2, instruction: "Rest Portions", timerDuration: 20 * 60, notes: "Rest balls"),
            BreadStep(stepNumber: 3, instruction: "Cook", timerDuration: 4 * 60, notes: "Cook on hot pan 2 min per side")
        ],
        category: .flatbread
    )
    
    static let pita = BreadRecipe(
        name: "Pita",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Water\n• 7g Yeast\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Rest Disks", timerDuration: 20 * 60, notes: "Rest disks"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 360, notes: "Bake at 260C for 6 min")
        ],
        category: .flatbread
    )
    
    static let roti = BreadRecipe(
        name: "Roti",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 30 * 60, notes: "Ingredients:\n• 500g Whole wheat flour\n• 300ml Water\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Cook", timerDuration: 5 * 60, notes: "Cook on dry pan")
        ],
        category: .flatbread
    )
    
    static let chapati = BreadRecipe(
        name: "Chapati",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 30 * 60, notes: "Ingredients:\n• 500g Whole wheat flour\n• 300ml Water\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Cook", timerDuration: 5 * 60, notes: "Cook on hot pan")
        ],
        category: .flatbread
    )
    
    static let paratha = BreadRecipe(
        name: "Paratha",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 30 * 60, notes: "Ingredients:\n• 500g Whole wheat flour\n• 280ml Water\n• 50g Butter\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Fold", timerDuration: 15 * 60, notes: "Layer with butter"),
            BreadStep(stepNumber: 3, instruction: "Cook", timerDuration: 10 * 60, notes: "Cook on pan until flaky")
        ],
        category: .flatbread
    )
    
    static let kulcha = BreadRecipe(
        name: "Kulcha",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 120g Yogurt\n• 200ml Water\n• 5g Yeast\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Cook", timerDuration: 5 * 60, notes: "Cook on hot surface")
        ],
        category: .flatbread
    )
    
    static let lavash = BreadRecipe(
        name: "Lavash",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 30 * 60, notes: "Ingredients:\n• 500g Flour\n• 280ml Water\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Bake", timerDuration: 10 * 60, notes: "Bake thin sheets at 250C")
        ],
        category: .flatbread
    )
    
    static let yufka = BreadRecipe(
        name: "Yufka",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 30 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Water\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Roll", timerDuration: 15 * 60, notes: "Roll very thin"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 5 * 60, notes: "Bake briefly on hot surface")
        ],
        category: .flatbread
    )
    
    static let bazlama = BreadRecipe(
        name: "Bazlama",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 300ml Water\n• 7g Yeast\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Cook", timerDuration: 10 * 60, notes: "Cook thick flatbread on pan")
        ],
        category: .flatbread
    )
    
    // Rye Breads
    static let ryeBread = BreadRecipe(
        name: "Rye Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 500g Rye flour\n• 400ml Water\n• 5g Yeast\n• 10g Salt\n\nAction: Mix sticky dough"),
            BreadStep(stepNumber: 2, instruction: "Proof", timerDuration: 60 * 60, notes: "Proof in pan"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 3000, notes: "Bake at 200C for 50 min")
        ],
        category: .rye
    )
    
    static let pumpernickel = BreadRecipe(
        name: "Pumpernickel",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 500g Rye flour\n• 450ml Water\n• 10g Salt\n\nAction: Mix very wet dough"),
            BreadStep(stepNumber: 2, instruction: "Bake", timerDuration: 18000, notes: "Bake at 160C for 300 min")
        ],
        category: .rye
    )
    
    static let blackBread = BreadRecipe(
        name: "Black Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 500g Rye flour\n• 420ml Water\n• 40g Molasses\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Bake", timerDuration: 3600, notes: "Bake at 180C for 60 min")
        ],
        category: .rye
    )
    
    static let vollkornbrot = BreadRecipe(
        name: "Vollkornbrot",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 500g Rye flour\n• 120g Seeds\n• 420ml Water\n• 10g Salt\n\nAction: Mix dense dough"),
            BreadStep(stepNumber: 2, instruction: "Bake", timerDuration: 3600, notes: "Bake at 180C for 60 min")
        ],
        category: .rye
    )
    
    static let borodinskyBread = BreadRecipe(
        name: "Borodinsky Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 500g Rye flour\n• 420ml Water\n• 40g Molasses\n• 5g Coriander\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Bake", timerDuration: 3600, notes: "Bake at 180C for 60 min")
        ],
        category: .rye
    )
    
    static let mixedRyeWheatBread = BreadRecipe(
        name: "Mixed Rye-Wheat Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 120 * 60, notes: "Ingredients:\n• 250g Rye flour\n• 250g Wheat flour\n• 380ml Water\n• 5g Yeast\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Proof", timerDuration: 60 * 60, notes: "Proof loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2700, notes: "Bake at 200C for 45 min")
        ],
        category: .rye
    )
    
    // Mediterranean Breads
    static let focaccia = BreadRecipe(
        name: "Focaccia",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 380ml Water\n• 7g Yeast\n• 60g Olive oil\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Pan Rest", timerDuration: 45 * 60, notes: "Stretch in pan"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 1500, notes: "Bake at 220C for 25 min")
        ],
        category: .mediterranean
    )
    
    static let pizzaDough = BreadRecipe(
        name: "Pizza Dough",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 2880 * 60, notes: "Ingredients:\n• 500g Flour\n• 325ml Water\n• 3g Yeast\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 30 * 60, notes: "Stretch dough"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 5 * 60, notes: "Bake at highest oven temp 2–5 min")
        ],
        category: .mediterranean
    )
    
    static let schiacciata = BreadRecipe(
        name: "Schiacciata",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 380ml Water\n• 7g Yeast\n• 60g Olive oil\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Pan Rest", timerDuration: 45 * 60, notes: "Stretch in pan"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 1500, notes: "Bake at 220C for 25 min")
        ],
        category: .mediterranean
    )
    
    static let ligurianFlatbread = BreadRecipe(
        name: "Ligurian Flatbread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 370ml Water\n• 7g Yeast\n• 70g Olive oil\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Bake", timerDuration: 1200, notes: "Bake at 220C for 20 min")
        ],
        category: .mediterranean
    )
    
    static let oliveBread = BreadRecipe(
        name: "Olive Bread",
        steps: [
            BreadStep(stepNumber: 1, instruction: "Mix", timerDuration: 90 * 60, notes: "Ingredients:\n• 500g Flour\n• 330ml Water\n• 7g Yeast\n• 120g Olives\n• 10g Salt\n\nAction: Mix dough"),
            BreadStep(stepNumber: 2, instruction: "Shape", timerDuration: 45 * 60, notes: "Shape loaf"),
            BreadStep(stepNumber: 3, instruction: "Bake", timerDuration: 2400, notes: "Bake at 210C for 40 min")
        ],
        category: .mediterranean
    )

    static let availableRecipes: [BreadRecipe] = [
        refreshStarter,
        frenchBaguette,
        breadBall,
        brioche,
        croissant,
        painAuChocolat,
        bagels,
        englishMuffins,
        // Yeasted
        whiteSandwichBread,
        wholeWheatBread,
        multigrainBread,
        countryLoaf,
        farmhouseBread,
        pullmanLoaf,
        milkBreadHokkaido,
        potatoBread,
        oatBread,
        speltBread,
        // Artisan
        levainBread,
        ciabatta,
        painDeCampagne,
        rusticBoule,
        noKneadBread,
        poolishBread,
        bigaBread,
        autolyseBread,
        // Enriched
        challah,
        babka,
        panettone,
        pandoro,
        milkRolls,
        sweetRolls,
        cinnamonRolls,
        raisinBread,
        // Flatbread
        naan,
        pita,
        roti,
        chapati,
        paratha,
        kulcha,
        lavash,
        yufka,
        bazlama,
        // Rye
        ryeBread,
        pumpernickel,
        blackBread,
        vollkornbrot,
        borodinskyBread,
        mixedRyeWheatBread,
        // Mediterranean
        focaccia,
        pizzaDough,
        schiacciata,
        ligurianFlatbread,
        oliveBread
    ]
}
