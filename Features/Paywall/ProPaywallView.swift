import RevenueCat
import SwiftUI

struct ProPaywallView: View {
    let onDismiss: () -> Void

    @State private var currentStep: PaywallStep = .features
    @State private var stepHistory: [PaywallStep] = []

    private enum Slot { case a, b }
    @State private var slotA: PaywallStep = .features
    @State private var slotB: PaywallStep = .features
    @State private var slotAOffset: CGFloat = 0
    @State private var slotBOffset: CGFloat = 1
    @State private var slotAZIndex: Double = 1
    @State private var slotBZIndex: Double = 0
    @State private var activeSlot: Slot = .a
    @State private var viewWidth: CGFloat = 390

    @State private var offering: Offering?
    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            NotyfiTheme.brandLight.ignoresSafeArea()

            GeometryReader { geo in
                ZStack {
                    stepContent(for: slotA)
                        .offset(x: slotAOffset * geo.size.width)
                        .zIndex(slotAZIndex)

                    stepContent(for: slotB)
                        .offset(x: slotBOffset * geo.size.width)
                        .zIndex(slotBZIndex)
                }
                .clipped()
                .onAppear { viewWidth = geo.size.width }
            }

            HStack {
                if currentStep != .features {
                    CircleChevronButton(direction: .left) { goBack() }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .task { await loadOffering() }
    }

    @ViewBuilder
    private func stepContent(for step: PaywallStep) -> some View {
        switch step {
        case .features:
            PaywallFeaturesPage(onContinue: { navigate(to: .howItWorks) })
        case .howItWorks:
            PaywallHowItWorksPage(onContinue: { navigate(to: .pricing) })
        case .pricing:
            PaywallPricingPage(
                offering: offering,
                selectedPackage: $selectedPackage,
                isPurchasing: isPurchasing,
                isRestoring: isRestoring,
                errorMessage: errorMessage,
                onSubscribe: { Task { await purchase() } },
                onRestore: { Task { await restore() } }
            )
        }
    }

    private func navigate(to step: PaywallStep) {
        stepHistory.append(currentStep)
        currentStep = step

        let outgoing = activeSlot
        let incoming: Slot = activeSlot == .a ? .b : .a

        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            switch incoming {
            case .a:
                slotA = step
                slotAOffset = 1
                slotAZIndex = 1
                slotBZIndex = 0
            case .b:
                slotB = step
                slotBOffset = 1
                slotBZIndex = 1
                slotAZIndex = 0
            }
        }

        activeSlot = incoming

        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            switch outgoing {
            case .a:
                slotAOffset = -1
                slotBOffset = 0
            case .b:
                slotBOffset = -1
                slotAOffset = 0
            }
        }
    }

    private func goBack() {
        guard let prev = stepHistory.popLast() else { return }
        currentStep = prev

        let outgoing = activeSlot
        let incoming: Slot = activeSlot == .a ? .b : .a

        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            switch incoming {
            case .a:
                slotA = prev
                slotAOffset = -1
                slotAZIndex = 0
                slotBZIndex = 1
            case .b:
                slotB = prev
                slotBOffset = -1
                slotBZIndex = 0
                slotAZIndex = 1
            }
        }

        activeSlot = incoming

        withAnimation(.spring(response: 0.38, dampingFraction: 0.96)) {
            switch outgoing {
            case .a:
                slotAOffset = 1
                slotBOffset = 0
            case .b:
                slotBOffset = 1
                slotAOffset = 0
            }
        }
    }

    private func loadOffering() async {
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.current
            selectedPackage = offering?.annual ?? offering?.availablePackages.first
        } catch {
            // Offerings unavailable — placeholder cards shown until products are configured
        }
    }

    private func purchase() async {
        guard let package = selectedPackage else { return }
        isPurchasing = true
        errorMessage = nil
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.customerInfo.entitlements["Notyfi Pro"]?.isActive == true {
                onDismiss()
            }
        } catch {
            let nsError = error as NSError
            // Code 2 is user-cancelled — no error message needed
            if nsError.code != 2 {
                errorMessage = error.localizedDescription
            }
        }
        isPurchasing = false
    }

    private func restore() async {
        isRestoring = true
        errorMessage = nil
        do {
            let info = try await Purchases.shared.restorePurchases()
            if info.entitlements["Notyfi Pro"]?.isActive == true {
                onDismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isRestoring = false
    }
}

// MARK: - Step

private enum PaywallStep: Hashable {
    case features
    case howItWorks
    case pricing
}

// MARK: - Page 1: Features

private struct PaywallFeaturesPage: View {
    let onContinue: () -> Void

    private let features: [(icon: String, text: String)] = [
        ("✨", "AI-powered expense parsing"),
        ("☁️", "Cloud sync across your devices"),
        ("📊", "Smart reports and insights"),
        ("📱", "Home and lock screen widgets"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SketchAnimatedImage(
                    frames: ["mascot-welcome-f1","mascot-welcome-f2","mascot-welcome-f3","mascot-welcome-f4"],
                    fps: 6
                )
                .frame(width: 346, height: 346)
                .padding(.top, 40)

                // Trial badge
                HStack(spacing: 6) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("3 days free, no commitment")
                        .font(.notyfi(.footnote, weight: .semibold))
                }
                .foregroundStyle(NotyfiTheme.brandPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(NotyfiTheme.brandPrimary.opacity(0.10), in: Capsule())
                .padding(.bottom, 20)

                Text("Good things ahead")
                    .font(.notyfi(.largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)

                VStack(spacing: 24) {
                    ForEach(features, id: \.text) { feature in
                        PaywallFeatureRow(icon: feature.icon, text: feature.text)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .contentMargins(.bottom, 120, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [NotyfiTheme.brandLight.opacity(0), NotyfiTheme.brandLight],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)

                OnboardingPrimaryButton(title: "See how it works".notyfiLocalized, action: onContinue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .background(NotyfiTheme.brandLight)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Page 2: How It Works

private struct PaywallHowItWorksPage: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                OnboardingIllustration(symbol: "gift.fill")
                    .padding(.top, 80)
                    .padding(.bottom, 36)

                Text("No commitment.\nJust try it.")
                    .font(.notyfi(.largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 48)

                VStack(spacing: 0) {
                    PaywallTimelineRow(
                        icon: "🚀",
                        title: "Today",
                        subtitle: "Start your free 3-day trial. No payment needed right now.",
                        isLast: false
                    )
                    PaywallTimelineRow(
                        icon: "🔔",
                        title: "Day 3",
                        subtitle: "We'll remind you before anything is charged.",
                        isLast: false
                    )
                    PaywallTimelineRow(
                        icon: "✅",
                        title: "After your trial",
                        subtitle: "Pick a plan that fits, or cancel anytime. No hard feelings.",
                        isLast: true
                    )
                }
                .padding(.horizontal, 24)
            }
        }
        .contentMargins(.bottom, 120, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [NotyfiTheme.brandLight.opacity(0), NotyfiTheme.brandLight],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)

                OnboardingPrimaryButton(title: "See pricing".notyfiLocalized, action: onContinue)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .background(NotyfiTheme.brandLight)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Page 3: Pricing

private struct PaywallPricingPage: View {
    let offering: Offering?
    @Binding var selectedPackage: Package?
    let isPurchasing: Bool
    let isRestoring: Bool
    let errorMessage: String?
    let onSubscribe: () -> Void
    let onRestore: () -> Void

    private let features: [(icon: String, text: String)] = [
        ("✨", "AI-powered expense parsing".notyfiLocalized),
        ("☁️", "Cloud sync across your devices".notyfiLocalized),
        ("📊", "Smart reports and insights".notyfiLocalized),
        ("📱", "Home and lock screen widgets".notyfiLocalized),
    ]

    private var annualPackage: Package? { offering?.annual }
    private var monthlyPackage: Package? { offering?.monthly }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                SketchAnimatedImage(
                    frames: ["mascot-welcome-f1","mascot-welcome-f2","mascot-welcome-f3","mascot-welcome-f4"],
                    fps: 6
                )
                .frame(width: 346, height: 346)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)

                Text("Access all of Notyfi".notyfiLocalized)
                    .font(.notyfi(.largeTitle, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(features, id: \.text) { feature in
                        HStack(spacing: 14) {
                            Text(feature.icon)
                                .font(.system(size: 20))
                                .frame(width: 28)
                            Text(feature.text)
                                .font(.notyfi(.subheadline))
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 36)

                HStack(spacing: 12) {
                    if let annual = annualPackage {
                        PlanCard(
                            package: annual,
                            isSelected: selectedPackage?.identifier == annual.identifier,
                            badge: "Best value".notyfiLocalized,
                            onTap: { selectedPackage = annual }
                        )
                    }
                    if let monthly = monthlyPackage {
                        PlanCard(
                            package: monthly,
                            isSelected: selectedPackage?.identifier == monthly.identifier,
                            badge: nil,
                            onTap: { selectedPackage = monthly }
                        )
                    }
                    if annualPackage == nil && monthlyPackage == nil {
                        PlaceholderPlanCard(label: "Yearly".notyfiLocalized, badge: "Best value".notyfiLocalized, isSelected: true)
                        PlaceholderPlanCard(label: "Monthly".notyfiLocalized, badge: nil, isSelected: false)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

                if let error = errorMessage {
                    Text(error)
                        .font(.notyfi(.caption))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 8)
                }
            }
        }
        .contentMargins(.bottom, 200, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .background(NotyfiTheme.brandLight)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                LinearGradient(
                    colors: [NotyfiTheme.brandLight.opacity(0), NotyfiTheme.brandLight],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)

                OnboardingPrimaryButton(title: "Start free trial".notyfiLocalized, isLoading: isPurchasing, action: onSubscribe)
                    .padding(.horizontal, 24)

                Button(action: onRestore) {
                    if isRestoring {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(NotyfiTheme.brandPrimary)
                            .frame(height: 20)
                    } else {
                        Text("Restore subscription".notyfiLocalized)
                            .font(.notyfi(.subheadline))
                            .foregroundStyle(NotyfiTheme.secondaryText)
                    }
                }

                Text("Apple shows the final billing terms before you confirm.".notyfiLocalized)
                    .font(.notyfi(.caption2))
                    .foregroundStyle(NotyfiTheme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
            .background(NotyfiTheme.brandLight)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Shared Components

private struct PaywallFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 32))
                .frame(width: 52, height: 52)
            Text(text)
                .font(.notyfi(.body, weight: .medium))
            Spacer()
        }
    }
}

private struct PaywallTimelineRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(spacing: 0) {
                Text(icon)
                    .font(.system(size: 28))
                    .frame(width: 52, height: 52)
                if !isLast {
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.notyfi(.body, weight: .semibold))
                Text(subtitle)
                    .font(.notyfi(.subheadline))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .lineSpacing(2)
            }
            .padding(.top, 14)
            .padding(.bottom, isLast ? 0 : 32)

            Spacer()
        }
    }
}

private struct PlanCard: View {
    let package: Package
    let isSelected: Bool
    let badge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(package.storeProduct.localizedTitle)
                        .font(.notyfi(.subheadline, weight: .semibold))
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(NotyfiTheme.brandPrimary)
                    }
                }
                Text(package.storeProduct.localizedPriceString)
                    .font(.notyfi(.title3, weight: .bold))
                Text(monthlyEquivalent)
                    .font(.notyfi(.caption))
                    .foregroundStyle(NotyfiTheme.secondaryText)
                    .frame(minHeight: 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                isSelected
                    ? NotyfiTheme.brandPrimary.opacity(0.07)
                    : Color(uiColor: .systemBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.10),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
            .overlay(alignment: .top) {
                if let badge {
                    Text(badge)
                        .font(.notyfi(.caption2, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(NotyfiTheme.brandPrimary)
                        .clipShape(Capsule())
                        .offset(y: -12)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    private var monthlyEquivalent: String {
        guard package.packageType == .annual else { return "" }
        let monthly = package.storeProduct.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        guard let formatted = formatter.string(from: monthly as NSDecimalNumber) else { return "" }
        return "\(formatted)/mo"
    }
}

private struct PlaceholderPlanCard: View {
    let label: String
    let badge: String?
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.notyfi(.subheadline, weight: .semibold))
            Text("--")
                .font(.notyfi(.title3, weight: .bold))
                .foregroundStyle(NotyfiTheme.tertiaryText)
            Text(" ")
                .font(.notyfi(.caption))
                .frame(minHeight: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            isSelected
                ? NotyfiTheme.brandPrimary.opacity(0.07)
                : Color(uiColor: .systemBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isSelected ? NotyfiTheme.brandPrimary : Color.primary.opacity(0.10),
                    lineWidth: isSelected ? 1.5 : 1
                )
        }
        .overlay(alignment: .top) {
            if let badge {
                Text(badge)
                    .font(.notyfi(.caption2, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(NotyfiTheme.brandPrimary)
                    .clipShape(Capsule())
                    .offset(y: -12)
            }
        }
    }
}

#Preview {
    ProPaywallView(onDismiss: {})
}
