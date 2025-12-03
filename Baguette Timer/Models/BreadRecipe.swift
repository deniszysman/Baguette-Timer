//
//  BreadRecipe.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import Foundation

struct BreadRecipe: Identifiable, Codable {
    let id: UUID
    let name: String
    let steps: [BreadStep]

    init(id: UUID = UUID(), name: String, steps: [BreadStep]) {
        self.id = id
        self.name = name
        self.steps = steps
    }
}

struct BreadStep: Identifiable, Codable {
    let id: UUID
    let stepNumber: Int
    let instruction: String
    let timerDuration: TimeInterval // in seconds
    let notes: String

    init(id: UUID = UUID(), stepNumber: Int, instruction: String, timerDuration: TimeInterval, notes: String = "") {
        self.id = id
        self.stepNumber = stepNumber
        self.instruction = instruction
        self.timerDuration = timerDuration
        self.notes = notes
    }

    var formattedDuration: String {
        let hours = Int(timerDuration) / 3600
        let minutes = (Int(timerDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)hr \(minutes)min"
        } else {
            return "\(minutes)min"
        }
    }
}

extension BreadRecipe {
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
        ]
    )

    static let availableRecipes: [BreadRecipe] = [
        frenchBaguette
    ]
}
