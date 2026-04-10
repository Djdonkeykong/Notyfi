import SwiftUI

struct OnboardingWidgetView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Add the Notyfi widget")
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("People who add the widget are far more consistent. Your spending is always one glance away.")
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 28)

                mockWidget
                    .padding(.bottom, 28)

                VStack(spacing: 14) {
                    WidgetStep(number: 1, text: "Long press anywhere on your Home Screen")
                    WidgetStep(number: 2, text: "Tap the \"+\" button in the top left corner")
                    WidgetStep(number: 3, text: "Search for \"Notyfi\" and choose a size")
                    WidgetStep(number: 4, text: "Tap the widget any time to open the app")
                }
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

    private var mockWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image("WelcomeLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text("Notyfi")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("This month")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            Text("$1,240")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .padding(.bottom, 2)

            Text("spent of $2,000 budget")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            GeometryReader { geo in
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(NotyfiTheme.brandPrimary)
                            .frame(width: geo.size.width * 0.62)
                    }
            }
            .frame(height: 5)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 6)
    }
}

private struct WidgetStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(NotyfiTheme.brandPrimary)
                    .frame(width: 30, height: 30)
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.notyfi(.body))
                .foregroundStyle(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 5)
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingWidgetView()
    }
}
