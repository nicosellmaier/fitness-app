import Foundation
import HealthKit
import CoreLocation

final class HealthService {
    let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static let bpm = HKUnit.count().unitDivided(by: .minute())
    static let ms = HKUnit.secondUnit(with: .milli)

    var readTypes: Set<HKObjectType> {
        var s: Set<HKObjectType> = [HKCategoryType(.sleepAnalysis), HKObjectType.workoutType(), HKSeriesType.workoutRoute()]
        let ids: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN, .restingHeartRate, .heartRate, .respiratoryRate, .oxygenSaturation,
            .appleSleepingWristTemperature, .vo2Max, .activeEnergyBurned, .basalEnergyBurned,
            .distanceWalkingRunning, .stepCount, .bodyMass, .runningPower, .runningGroundContactTime,
            .runningVerticalOscillation, .runningStrideLength, .runningSpeed,
        ]
        for id in ids { s.insert(HKQuantityType(id)) }
        return s
    }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: readTypes)
    }

    func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, from: Date, to: Date = .now) async throws -> Double {
        let pred = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let d = HKStatisticsQueryDescriptor(predicate: .quantitySample(type: HKQuantityType(id), predicate: pred), options: .cumulativeSum)
        return try await d.result(for: store)?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    func latest(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int = 120) async throws -> Double? {
        try await quantity(id, from: Calendar.current.addDays(-days, to: .now)).last?.quantity.doubleValue(for: unit)
    }

    func quantity(_ id: HKQuantityTypeIdentifier, from: Date, to: Date = .now) async throws -> [HKQuantitySample] {
        let pred = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let d = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(id), predicate: pred)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await d.result(for: store)
    }

    func sleep(from: Date, to: Date = .now) async throws -> [HKCategorySample] {
        let pred = HKQuery.predicateForSamples(withStart: from, end: to, options: [])
        let d = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: pred)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await d.result(for: store)
    }

    func workouts(from: Date, limit: Int = 80) async throws -> [HKWorkout] {
        let pred = HKQuery.predicateForSamples(withStart: from, end: .now, options: [])
        let d = HKSampleQueryDescriptor(
            predicates: [.workout(pred)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: limit
        )
        return try await d.result(for: store)
    }

    func route(for workout: HKWorkout) async throws -> [CLLocation] {
        let pred = HKQuery.predicateForObjects(from: workout)
        let d = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKSeriesType.workoutRoute(), predicate: pred)],
            sortDescriptors: []
        )
        let routes = try await d.result(for: store).compactMap { $0 as? HKWorkoutRoute }
        var all: [CLLocation] = []
        for r in routes { all += try await locations(of: r) }
        return all.sorted { $0.timestamp < $1.timestamp }
    }

    private func locations(of route: HKWorkoutRoute) async throws -> [CLLocation] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[CLLocation], Error>) in
            let collector = LocationCollector()
            let query = HKWorkoutRouteQuery(route: route) { _, locs, done, error in
                if collector.finished { return }
                if let error {
                    collector.finished = true
                    cont.resume(throwing: error)
                    return
                }
                collector.items.append(contentsOf: locs ?? [])
                if done {
                    collector.finished = true
                    cont.resume(returning: collector.items)
                }
            }
            store.execute(query)
        }
    }

    // MARK: Umwandlung in WorkoutItem

    func item(from w: HKWorkout) -> WorkoutItem {
        let dist = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter())
        let kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie())
        let hr = w.statistics(for: HKQuantityType(.heartRate))
        let avg = hr?.averageQuantity()?.doubleValue(for: HealthService.bpm)
        let mx = hr?.maximumQuantity()?.doubleValue(for: HealthService.bpm)
        let elev = (w.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity)?.doubleValue(for: .meter())
        let indoor = (w.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false
        let t = w.workoutActivityType
        return WorkoutItem(
            id: w.uuid, workout: w, activity: t, kind: WorkoutItem.kind(for: t, distance: dist),
            name: WorkoutItem.name(for: t, start: w.startDate), start: w.startDate, end: w.endDate,
            duration: w.duration, distance: dist, energy: kcal, avgHR: avg, maxHR: mx, elevation: elev, indoor: indoor
        )
    }

    func detail(for item: WorkoutItem, maxHR: Double) async -> WorkoutDetail {
        guard let w = item.workout else { return DemoData.detail(for: item, maxHR: maxHR) }
        var det = WorkoutDetail()
        det.route = (try? await route(for: w)) ?? []
        if let hr = try? await quantity(.heartRate, from: w.startDate, to: w.endDate) {
            det.hr = hr.map { HRPoint(date: $0.startDate, bpm: $0.quantity.doubleValue(for: HealthService.bpm)) }
        }
        func avg(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? {
            w.statistics(for: HKQuantityType(id))?.averageQuantity()?.doubleValue(for: unit)
        }
        det.power = avg(.runningPower, .watt())
        det.groundContact = avg(.runningGroundContactTime, HealthService.ms)
        det.verticalOsc = avg(.runningVerticalOscillation, .meterUnit(with: .centi))
        det.stride = avg(.runningStrideLength, .meter())
        if let steps = w.statistics(for: HKQuantityType(.stepCount))?.sumQuantity()?.doubleValue(for: .count()), w.duration > 60 {
            det.cadence = steps / (w.duration / 60)
        }
        Analytics.fill(&det, item: item, maxHR: maxHR)
        return det
    }
}

private final class LocationCollector {
    var items: [CLLocation] = []
    var finished = false
}
