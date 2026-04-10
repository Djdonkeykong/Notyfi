import SwiftUI

struct OnboardingBeDetailedView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                OnboardingTag(text: "Quick tip")
                    .padding(.bottom, 14)

                Text("The more detail,\nthe better it tracks")
                    .font(.notyfi(.title2, weight: .bold))
                    .padding(.bottom, 10)

                Text("Specific entries get categorized more accurately and make your spending history actually useful.")
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(3)
                    .padding(.bottom, 28)

                VStack(spacing: 12) {
                    DetailComparisonCard(
                        vagueText: "food",
                        specificText: "Chipotle burrito bowl 12.50",
                        specificCategory: "Food & Drink"
                    )
                    DetailComparisonCard(
                        vagueText: "drinks",
                        specificText: "Starbucks oat milk latte 5.80",
                        specificCategory: "Coffee"
                    )
                    DetailComparisonCard(
                        vagueText: "subscription",
                        specificText: "Spotify monthly 9.99",
                        specificCategory: "Subscriptions"
                    )
                }
            }
            .padding(.horizontal, 24)
        }
        .contentMargins(.top, 72, for: .scrollContent)
        .contentMargins(.bottom, 160, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct DetailComparisonCard: View {
    let vagueText: String
    let specificText: String
    let specificCategory: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Vague side
            VStack(alignment: .leading, spacing: 8) {
                Text("\"\(vagueText)\"")
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Circle()
                        .stroke(Color.orange.opacity(0.8), lineWidth: 2)
                        .frame(width: 13, height: 13)
                    Text("Unclear")
                        .font(.notyfi(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.4))
                .frame(width: 32)
                .padding(.top, 20)

            // Specific side
            VStack(alignment: .leading, spacing: 8) {
                Text("\"\(specificText)\"")
                    .font(.notyfi(.caption, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.green)
                    Text(specificCategory)
                        .font(.notyfi(.caption))
                        .foregroundStyle(.green)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(4)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    NavigationStack {
        OnboardingBeDetailedView()
    }
}
