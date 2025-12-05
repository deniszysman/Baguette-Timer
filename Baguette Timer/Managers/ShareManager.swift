//
//  ShareManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/5/25.
//

import Foundation
import SwiftUI
import UIKit

class ShareManager {
    static let shared = ShareManager()
    
    private let appStoreURL = "https://apps.apple.com/us/app/breadoclock/id6756032998"
    private let urlScheme = "breadoclock"
    
    private init() {}
    
    /// Generate a shareable link for a recipe
    func generateShareLink(for recipe: BreadRecipe) -> URL {
        // Use a web URL that will redirect to the app if installed, or App Store if not
        // Format: https://breadoclock.app/recipe/{recipeId}
        // For now, we'll use a simple URL scheme that iOS will handle
        let recipeId = recipe.id.uuidString
        let urlString = "\(urlScheme)://recipe/\(recipeId)"
        return URL(string: urlString) ?? URL(string: appStoreURL)!
    }
    
    /// Generate a shareable message with the recipe link
    func generateShareMessage(for recipe: BreadRecipe) -> String {
        let recipeName = recipe.localizedName
        let deepLink = generateShareLink(for: recipe)
        return "Check out this recipe: \(recipeName)\n\nOpen in BreadOClock: \(deepLink.absoluteString)\n\nDownload the app: \(appStoreURL)"
    }
    
    /// Present share sheet
    func shareRecipe(_ recipe: BreadRecipe, from viewController: UIViewController) {
        let shareText = generateShareMessage(for: recipe)
        let shareLink = generateShareLink(for: recipe)
        
        var items: [Any] = [shareText]
        
        // Add the URL as a separate item for better handling
        items.append(shareLink)
        
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // For iPad
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityViewController, animated: true)
    }
    
    /// Handle incoming URL (deep link)
    func handleURL(_ url: URL) -> (recipeId: UUID, stepId: UUID?)? {
        guard url.scheme == urlScheme else { return nil }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count >= 2, pathComponents[1] == "recipe" else { return nil }
        
        guard pathComponents.count >= 3,
              let recipeId = UUID(uuidString: pathComponents[2]) else {
            return nil
        }
        
        // Optional step ID
        var stepId: UUID? = nil
        if pathComponents.count >= 4 {
            stepId = UUID(uuidString: pathComponents[3])
        }
        
        return (recipeId, stepId)
    }
}

