//
//  BreadSelectionView.swift
//  Baguette Timer
//
//  Created by Denis Zysman on 12/2/25.
//

import SwiftUI

struct BreadSelectionView: View {
    @State private var selectedRecipe: BreadRecipe?
    @State private var showBreadMaking = false
    @State private var scale: CGFloat = 1.0
    
    let recipes = BreadRecipe.availableRecipes
    
    var body: some View {
        NavigationStack {
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
                
                VStack(spacing: 20) {
                    // Title
                    VStack(spacing: 10) {
                        Text("Bread Timer")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Text("Select your bread recipe")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.top, 20)
                    
                    // Bread selection cards
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(recipes) { recipe in
                                BreadCard(recipe: recipe) {
                                    selectedRecipe = recipe
                                    showBreadMaking = true
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationDestination(isPresented: $showBreadMaking) {
                if let recipe = selectedRecipe {
                    BreadMakingView(recipe: recipe)
                }
            }
        }
    }
}

struct BreadCard: View {
    let recipe: BreadRecipe
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            ZStack {
                // Liquid Glass effect
                RoundedRectangle(cornerRadius: 30)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.white.opacity(0.1)
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
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.3)
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
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    .shadow(color: .white.opacity(0.1), radius: 5, x: 0, y: -5)
                
                HStack(spacing: 20) {
                    Image(systemName: recipe.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                        .frame(width: 50)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        
                        Text("\(recipe.steps.count) steps")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(height: 100)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    BreadSelectionView()
}

