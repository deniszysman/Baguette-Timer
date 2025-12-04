//
//  NavigationManager.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import Foundation
import SwiftUI
import Combine

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    // Use a simple notification-based approach to avoid @Published property updates during view updates
    private let navigationSubject = PassthroughSubject<(recipeId: UUID, stepId: UUID), Never>()
    
    var navigationPublisher: AnyPublisher<(recipeId: UUID, stepId: UUID), Never> {
        navigationSubject.eraseToAnyPublisher()
    }
    
    private init() {}
    
    func navigateToRecipe(recipeId: UUID, stepId: UUID) {
        // Always dispatch to main queue to avoid view update issues
        DispatchQueue.main.async { [weak self] in
            self?.navigationSubject.send((recipeId: recipeId, stepId: stepId))
        }
    }
}

