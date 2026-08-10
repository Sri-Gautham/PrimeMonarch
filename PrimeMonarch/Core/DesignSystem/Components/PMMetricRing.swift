import SwiftUI

// Custom ring visualization. Must NOT look like Apple Activity rings.
struct PMMetricRing: View {
    let progress: Double       // 0.0 – 1.0+
    let color: Color
    let lineWidth: CGFloat
    var size: CGFloat = 80
    var accessibilityLabel: String = ""

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Fill arc — allow over 100% by capping display at 1.0 visually
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Three-Ring Cluster

struct PMThreeRingCluster: View {
    let energyProgress: Double
    let hydrationProgress: Double
    let movementProgress: Double

    var energyLabel: String = "Energy ring"
    var hydrationLabel: String = "Hydration ring"
    var movementLabel: String = "Movement ring"

    private let outerSize: CGFloat  = 160
    private let middleSize: CGFloat = 120
    private let innerSize: CGFloat  = 80
    private let lineWidth: CGFloat  = 14

    var body: some View {
        ZStack {
            PMMetricRing(progress: energyProgress,   color: .pmRingEnergy,
                         lineWidth: lineWidth, size: outerSize,
                         accessibilityLabel: energyLabel)
            PMMetricRing(progress: hydrationProgress, color: .pmRingHydration,
                         lineWidth: lineWidth, size: middleSize,
                         accessibilityLabel: hydrationLabel)
            PMMetricRing(progress: movementProgress, color: .pmRingMovement,
                         lineWidth: lineWidth, size: innerSize,
                         accessibilityLabel: movementLabel)
        }
        .frame(width: outerSize + lineWidth, height: outerSize + lineWidth)
    }
}

// MARK: - Rank Badge

struct PMRankBadge: View {
    let rank: RankTier
    let level: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: PMSpacing.xxs) {
            Image(systemName: "crown.fill")
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .foregroundStyle(.pmAccentPurpleBright)

            Text(rank.displayName.uppercased())
                .font(.pmRankLabel)
                .foregroundStyle(.pmAccentPurpleBright)

            if !compact {
                Text("·")
                    .foregroundStyle(.pmTextTertiary)
                Text("Lv.\(level)")
                    .font(.pmRankLabel)
                    .foregroundStyle(.pmTextSecondary)
            }
        }
        .padding(.horizontal, PMSpacing.sm)
        .padding(.vertical, PMSpacing.xxs)
        .background(Color.pmAccentPurple.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - XP Bar

struct PMXPBar: View {
    let progress: Double  // 0.0 – 1.0
    let currentXP: Int
    let nextLevelXP: Int

    var body: some View {
        VStack(alignment: .leading, spacing: PMSpacing.xxs) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: PMSpacing.pillRadius)
                        .fill(Color.pmAccentPurple.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: PMSpacing.pillRadius)
                        .fill(LinearGradient.pmPurpleGradient)
                        .frame(width: geo.size.width * max(0, min(progress, 1.0)), height: 6)
                        .animation(.spring(response: 0.5), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(currentXP) XP")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextSecondary)
                Spacer()
                Text("\(nextLevelXP) XP")
                    .font(.pmCaption)
                    .foregroundStyle(.pmTextTertiary)
            }
        }
    }
}
