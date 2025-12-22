import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    let pages = [
        OnboardingPage(
            title: "Welcome to DueTrack",
            description: "Never miss a bill payment again. Track all your recurring bills in one place.",
            imageName: "calendar.badge.clock",
            color: Color.primaryBlue
        ),
        OnboardingPage(
            title: "Create Your Bills",
            description: "Add bills with custom frequencies - monthly, weekly, quarterly, or annual. Set due dates and categories.",
            imageName: "plus.circle.fill",
            color: Color.accentGreen
        ),
        OnboardingPage(
            title: "Smart Calendar View",
            description: "See all your bills on a calendar with color-coded status. Green for paid, yellow for upcoming, red for overdue.",
            imageName: "calendar",
            color: Color.upcomingYellow
        ),
        OnboardingPage(
            title: "Payment Tracking",
            description: "Mark bills as paid with a tap. Keep a complete payment history and track your spending patterns.",
            imageName: "checkmark.circle.fill",
            color: Color.accentGreen
        ),
        OnboardingPage(
            title: "Smart Reminders",
            description: "Get notified 1, 3, and 7 days before bills are due. Never miss a payment again!",
            imageName: "bell.fill",
            color: Color.primaryBlue
        ),
        OnboardingPage(
            title: "Financial Insights",
            description: "View your monthly spending breakdown by category. Understand where your money goes.",
            imageName: "chart.bar.fill",
            color: Color.primaryBlue
        )
    ]
    
    var body: some View {
        ZStack {
            Color.adaptiveBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button(action: {
                        skipOnboarding()
                    }) {
                        Text("Skip")
                            .foregroundColor(.primaryBlue)
                            .fontWeight(.medium)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                }
                .padding()
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page)
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .foregroundColor(.primaryBlue)
                            .fontWeight(.medium)
                            .padding()
                        }
                    }
                    
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                            .padding()
                            .background(Color.primaryBlue)
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: {
                            skipOnboarding()
                        }) {
                            Text("Get Started")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.primaryBlue)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
    }
    
    private func skipOnboarding() {
        OnboardingManager.shared.completeOnboarding()
        withAnimation {
            isPresented = false
        }
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Icon
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .padding()
            
            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(.adaptiveText)
                .padding(.horizontal)
            
            // Description
            Text(page.description)
                .font(.system(size: 18))
                .multilineTextAlignment(.center)
                .foregroundColor(.adaptiveSecondaryText)
                .padding(.horizontal, 40)
                .lineSpacing(4)
            
            Spacer()
            Spacer()
        }
    }
}

