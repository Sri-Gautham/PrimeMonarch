import SwiftUI

struct PMCard<Content: View>: View {
    var elevated: Bool = false
    let content: () -> Content

    var body: some View {
        content()
            .background(elevated ? Color.pmSurfaceElevated : Color.pmSurfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
            .shadow(
                color: Color(red: 0.180, green: 0.169, blue: 0.145).opacity(0.14),
                radius: 8, x: 0, y: 3
            )
    }
}

// MARK: - Section Header

struct PMSectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "See all"

    var body: some View {
        HStack {
            Text(title)
                .font(.pmSectionTitle)
                .foregroundStyle(.pmTextPrimary)
            Spacer()
            if let action {
                Button(actionLabel, action: action)
                    .font(.pmCaptionMedium)
                    .foregroundStyle(.pmAccentPurpleBright)
            }
        }
    }
}

// MARK: - Empty State

struct PMEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var action: (() -> Void)? = nil
    var actionLabel: String = "Get started"

    var body: some View {
        VStack(spacing: PMSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.pmTextTertiary)

            VStack(spacing: PMSpacing.xs) {
                Text(title)
                    .font(.pmCardTitle)
                    .foregroundStyle(.pmTextPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.pmSecondaryBody)
                    .foregroundStyle(.pmTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let action {
                Button(actionLabel, action: action)
                    .pmPrimaryStyle(fullWidth: false)
                    .padding(.top, PMSpacing.xs)
            }
        }
        .padding(PMSpacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Loading State

struct PMLoadingState: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: PMSpacing.md) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.pmAccentPurpleBright)
                .scaleEffect(1.3)

            Text(message)
                .font(.pmSecondaryBody)
                .foregroundStyle(.pmTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Divider

struct PMDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.pmDivider)
            .frame(height: 1)
    }
}
