import Foundation
import WorkoutKit
import HealthKit

/// Wandelt geplante Läufe in Trainings für die Trainings-App der Apple Watch um
enum WatchExport {
    static func workout(for run: PlannedRun, paces: Paces) -> CustomWorkout {
        let warmup = run.structure.warmup.map { WorkoutStep(goal: goal($0, paces), alert: alert($0, paces)) }
        let cooldown = run.structure.cooldown.map { WorkoutStep(goal: goal($0, paces), alert: alert($0, paces)) }
        var blocks: [IntervalBlock] = []
        for b in run.structure.blocks {
            var steps: [IntervalStep] = [IntervalStep(.work, goal: goal(b.work, paces), alert: alert(b.work, paces))]
            if let rec = b.recovery, b.repeats > 1 {
                steps.append(IntervalStep(.recovery, goal: goal(rec, paces), alert: alert(rec, paces)))
            }
            blocks.append(IntervalBlock(steps: steps, iterations: max(1, b.repeats)))
        }
        let activity: HKWorkoutActivityType = run.type == .cross ? .cycling : .running
        return CustomWorkout(activity: activity, location: .outdoor, displayName: run.title,
                             warmup: warmup, blocks: blocks, cooldown: cooldown)
    }

    static func workoutPlan(for run: PlannedRun, paces: Paces) -> WorkoutPlan {
        WorkoutPlan(.custom(workout(for: run, paces: paces)), id: run.id)
    }

    private static func goal(_ s: Segment, _ p: Paces) -> WorkoutGoal {
        if let m = s.meters { return .distance(m, .meters) }
        if let t = s.seconds { return .time(t, .seconds) }
        return .open
    }

    private static func alert(_ s: Segment, _ p: Paces) -> (any WorkoutAlert)? {
        guard s.zone.isQuality, s.zone != .repetition else { return nil }
        let pace = p.sec(s.zone)
        let tol: Double = s.zone == .marathon || s.zone == .half || s.zone == .race ? 6 : 5
        let slow = 1000 / (pace + tol)
        let fast = 1000 / max(60, pace - tol)
        let lo = Measurement(value: slow, unit: UnitSpeed.metersPerSecond)
        let hi = Measurement(value: fast, unit: UnitSpeed.metersPerSecond)
        return SpeedRangeAlert(target: lo...hi, metric: .current)
    }

    static var isSupported: Bool { WorkoutScheduler.isSupported }

    static func authorize() async -> Bool {
        let state = await WorkoutScheduler.shared.requestAuthorization()
        return state == .authorized
    }

    /// Die nächsten 7 Tage auf die Uhr legen
    static func scheduleWeek(_ plan: TrainingPlan) async -> Int {
        guard await authorize() else { return 0 }
        await WorkoutScheduler.shared.removeAllWorkouts()
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.addDays(7, to: start)
        let paces = plan.paces
        var count = 0
        for r in plan.runs where r.date >= start && r.date < end && r.status == .planned && ![.rest].contains(r.type) && !r.structure.isEmpty {
            var comps = cal.dateComponents([.year, .month, .day], from: r.date)
            comps.hour = 7
            comps.minute = 0
            await WorkoutScheduler.shared.schedule(workoutPlan(for: r, paces: paces), at: comps)
            count += 1
            if count >= WorkoutScheduler.maxAllowedScheduledWorkoutCount { break }
        }
        return count
    }
}
