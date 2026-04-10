import SwiftUI
import Lottie

struct OnboardingHowItWorksView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                LottieView(animation: .named("mascot-writing"))
                    .playing(loopMode: .loop)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .padding(.vertical, 24)

                OnboardingTag(text: "Quick tip")
                    .padding(.bottom, 14)

                Text("Just write what you spent")
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("Type anything naturally. Notyfi reads it and fills in the details.")
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 24)

                LottieView(animation: .named("how-it-works"))
                    .playing(loopMode: .loop)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        OnboardingHowItWorksView()
    }
}
