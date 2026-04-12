import SwiftUI

struct OnboardingBeDetailedView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .center, spacing: 0) {
                Text("Quick tip".notyfiLocalized)
                    .font(.notyfi(.footnote, weight: .semibold))
                    .foregroundStyle(NotyfiTheme.brandPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(NotyfiTheme.brandLight)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(NotyfiTheme.brandPrimary.opacity(0.25), lineWidth: 1))
                    .padding(.bottom, 20)

                Text("The more detail,\nthe better it tracks".notyfiLocalized)
                    .font(.notyfi(.title2, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 12)

                Text("Specific entries get categorized more accurately and make your spending history actually useful.".notyfiLocalized)
                    .font(.notyfi(.body))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 32)

                VStack(spacing: 10) {
                    DetailComparisonRow(
                        vagueText: "example.food.vague".notyfiLocalized,
                        specificText: "example.food.specific".notyfiLocalized,
                        categoryText: "Food & Drink".notyfiLocalized
                    )
                    DetailComparisonRow(
                        vagueText: "example.drinks.vague".notyfiLocalized,
                        specificText: "example.drinks.specific".notyfiLocalized,
                        categoryText: "Coffee".notyfiLocalized
                    )
                    DetailComparisonRow(
                        vagueText: "example.sub.vague".notyfiLocalized,
                        specificText: "example.sub.specific".notyfiLocalized,
                        categoryText: "Entertainment".notyfiLocalized
                    )
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
}

private struct DetailComparisonRow: View {
    let vagueText: String
    let specificText: String
    let categoryText: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\"\(vagueText)\"")
                    .font(.notyfi(.subheadline, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.72))

                HStack(spacing: 5) {
                    Circle()
                        .stroke(Color.orange.opacity(0.8), lineWidth: 1.5)
                        .frame(width: 10, height: 10)
                    Text("Unclear".notyfiLocalized)
                        .font(.notyfi(.caption2, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.35))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 6) {
                Text("\"\(specificText)\"")
                    .font(.notyfi(.caption, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text(categoryText)
                        .font(.notyfi(.caption2, weight: .medium))
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.green.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingBeDetailedView()
    }
}
