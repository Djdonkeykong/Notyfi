import SwiftUI
import UIKit

// MARK: - Primary CTA Button

struct OnboardingPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            ZStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.notyfi(.body, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(NotyfiTheme.brandPrimary)
            .clipShape(Capsule())
        }
        .disabled(isLoading)
    }
}

// MARK: - Back Button

struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.regularMaterial, in: Circle())
        }
    }
}

// MARK: - Progress Bar

struct OnboardingProgressBar: View {
    let current: Int
    let total: Int

    private var progress: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current) / CGFloat(total)
    }

    var body: some View {
        GeometryReader { geo in
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
        }
        .frame(height: 4)
    }
}

// MARK: - Illustration Container

struct OnboardingIllustration: View {
    let symbol: String
    var size: CGFloat = 80

    var body: some View {
        ZStack {
            Circle()
                .fill(NotyfiTheme.brandLight)
                .frame(width: 200, height: 200)

            Circle()
                .stroke(NotyfiTheme.brandPrimary.opacity(0.12), lineWidth: 1)
                .frame(width: 200, height: 200)

            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(NotyfiTheme.brandPrimary)
        }
        .shadow(color: NotyfiTheme.brandPrimary.opacity(0.12), radius: 32, x: 0, y: 8)
    }
}

// MARK: - Step Tag

struct OnboardingTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.notyfi(.caption, weight: .semibold))
            .foregroundStyle(NotyfiTheme.brandPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(NotyfiTheme.brandLight)
            .clipShape(Capsule())
    }
}

// MARK: - Selection Card

struct OnboardingSelectionCard<Content: View>: View {
    var isSelected: Bool
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                content()
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(NotyfiTheme.brandPrimary)
                }
            }
            .padding(18)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Skip Button

struct OnboardingSkipButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text("Skip for now")
                .font(.notyfi(.subheadline))
                .foregroundStyle(NotyfiTheme.secondaryText)
        }
    }
}

