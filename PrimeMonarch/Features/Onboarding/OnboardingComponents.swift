import SwiftUI

// MARK: - Step Header

struct OnboardingStepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: PMSpacing.xs) {
            Text(title)
                .font(.pmScreenTitle)
                .foregroundStyle(.pmTextPrimary)
            Text(subtitle)
                .font(.pmSecondaryBody)
                .foregroundStyle(.pmTextSecondary)
        }
    }
}

// MARK: - Toggle Chip

struct ToggleChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.pmCaptionMedium)
                .foregroundStyle(isSelected ? Color.pmAccentPurpleBright : Color.pmTextSecondary)
                .padding(.horizontal, PMSpacing.sm)
                .padding(.vertical, PMSpacing.xs)
                .background(
                    isSelected ? Color.pmAccentPurple.opacity(0.18) : Color.pmSurfacePrimary
                )
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(
                            isSelected ? Color.pmAccentPurple : Color.clear,
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Radio Row (single-select list item)

struct RadioRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    init(title: String, subtitle: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: PMSpacing.md) {
                VStack(alignment: .leading, spacing: PMSpacing.xxs) {
                    Text(title)
                        .font(.pmBodyMedium)
                        .foregroundStyle(.pmTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.pmCaption)
                            .foregroundStyle(.pmTextSecondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.pmAccentPurpleBright : Color.pmTextTertiary)
            }
            .padding(PMSpacing.sm)
            .background(isSelected ? Color.pmAccentPurple.opacity(0.12) : Color.pmSurfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Field Row

struct OnboardingFieldRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: PMSpacing.xxs) {
            Text(label)
                .font(.pmSecondaryBody)
                .foregroundStyle(.pmTextSecondary)
            HStack { content() }
                .padding(PMSpacing.sm)
                .background(Color.pmSurfacePrimary)
                .clipShape(RoundedRectangle(cornerRadius: PMSpacing.cardRadius))
        }
    }
}

// MARK: - Chip Grid (wrapping layout using simple VStack+HStack)

struct ChipGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let content: (Data.Element) -> Content

    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        // Simple wrap: row-by-row grouping for Phase 1
        let items = Array(data)
        let chunkSize = 3
        let rows = stride(from: 0, to: items.count, by: chunkSize).map {
            Array(items[$0..<min($0 + chunkSize, items.count)])
        }
        VStack(alignment: .leading, spacing: PMSpacing.xs) {
            ForEach(rows.indices, id: \.self) { rowIdx in
                HStack(spacing: PMSpacing.xs) {
                    ForEach(rows[rowIdx], id: \.self) { item in
                        content(item)
                    }
                    Spacer()
                }
            }
        }
    }
}
