import Foundation
import HealthKit
import SwiftData

@Observable @MainActor
final class HealthKitService {

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else { return }
        try? await store.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Refresh

    /// Fetches today's steps, active kcal, and latest body mass from HealthKit.
    /// Writes steps/kcal into DailyTarget and auto-inserts a WeightEntry when
    /// HealthKit has a newer measurement than the last logged one.
    func refreshTodayMetrics(in context: ModelContext) async {
        guard isAvailable else { return }

        async let steps      = fetchTodaySteps()
        async let activeKcal = fetchTodayActiveCalories()
        async let bodyMassKg = fetchLatestBodyMass()
        async let sleepMins  = fetchLastNightSleep()
        let (s, k, w, sl) = await (steps, activeKcal, bodyMassKg, sleepMins)

        let today    = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let desc = FetchDescriptor<DailyTarget>(
            predicate: #Predicate { $0.date >= today && $0.date < tomorrow }
        )
        if let target = (try? context.fetch(desc))?.first {
            target.healthKitStepsToday             = s
            target.healthKitActiveKcalToday        = k
            target.healthKitSleepMinutesLastNight  = sl
        }

        // Auto-sync body mass: only insert once per calendar day from HealthKit.
        if let kg = w, kg > 0 {
            let source = "healthkit"
            let existingToday = FetchDescriptor<WeightEntry>(
                predicate: #Predicate { $0.loggedAt >= today && $0.loggedAt < tomorrow && $0.source == source }
            )
            if (try? context.fetch(existingToday))?.isEmpty == true {
                let entry = WeightEntry(weightKilograms: kg)
                entry.source = "healthkit"
                context.insert(entry)
            }
        }

        try? context.save()
    }

    // MARK: - Fetch helpers

    func fetchTodaySteps() async -> Int {
        let value = await fetchSum(
            identifier: .stepCount,
            unit: .count(),
            start: Calendar.current.startOfDay(for: Date()),
            end: Date()
        )
        return Int(value)
    }

    func fetchTodayActiveCalories() async -> Double {
        await fetchSum(
            identifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            start: Calendar.current.startOfDay(for: Date()),
            end: Date()
        )
    }

    /// Returns the most recent body mass sample in kilograms, or nil if none.
    func fetchLatestBodyMass() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return nil }
        return await withCheckedContinuation { continuation in
            let desc = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [desc]) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            store.execute(query)
        }
    }

    /// Returns today's resting heart rate in BPM, or nil if unavailable.
    func fetchRestingHeartRate() async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let predicate = HKQuery.predicateForSamples(withStart: today, end: end)
        return await withCheckedContinuation { continuation in
            let desc  = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [desc]) { _, samples, _ in
                let bpm = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    /// Returns total asleep minutes from last night (yesterday 6pm → today noon).
    /// Sums all asleep-stage samples; returns 0 if HealthKit has no data.
    func fetchLastNightSleep() async -> Int {
        guard isAvailable,
              let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let windowStart = cal.date(byAdding: .hour, value: -18, to: today)!  // yesterday ~6pm
        let windowEnd   = cal.date(byAdding: .hour, value:  12, to: today)!  // today noon

        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: Int(totalSeconds / 60))
            }
            store.execute(query)
        }
    }

    private func fetchSum(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
