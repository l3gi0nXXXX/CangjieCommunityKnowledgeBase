package cangjie_community_knowledge_base

import std.time.*
import std.collection.ArrayList

public class CkbSchedulerLoopStartResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var intervalMillis: Int64 = 0
    public var readinessGate: String = ""
    public var firstTickDeferred: Bool = false
    public var tick: SchedulerExecutorResult = SchedulerExecutorResult()

    public init() {}
}

public func ckbSchedulerLoopIntervalMillis(config: CkbRuntimeConfig): Int64 {
    if (config.schedulerLoopIntervalMillis <= 0) {
        return 60000
    }
    config.schedulerLoopIntervalMillis
}

public func runCkbSchedulerTick(service: CkbCommandLoopService, limit: Int64): SchedulerExecutorResult {
    service.runScheduler(if (limit <= 0) { 1 } else { limit })
}

public func runCkbSchedulerTickWithLifecycleMetadata(service: CkbCommandLoopService, limit: Int64, tickKind: String, intervalMillis!: Int64 = 0): SchedulerExecutorResult {
    let effectiveLimit = if (limit <= 0) { 1 } else { limit }
    let result = runCkbSchedulerTick(service, effectiveLimit)
    service.saveSchedulerLoopMetadata("running", true, intervalMillis, tickKind, effectiveLimit, result.ran, result.taskNames, if (result.failed == 0) { "ok" } else { "scheduler_tick_failed" })
    result
}

public func startCkbSchedulerLoop(service: CkbCommandLoopService, config: CkbRuntimeConfig, afterHttpReady!: Bool = false, deferFirstTick!: Bool = false): CkbSchedulerLoopStartResult {
    let result = CkbSchedulerLoopStartResult()
    result.intervalMillis = ckbSchedulerLoopIntervalMillis(config)
    result.readinessGate = if (afterHttpReady) { "http_routes_registered" } else { "service_started" }
    result.firstTickDeferred = deferFirstTick
    if (!config.schedulerEnabled) {
        service.markSchedulerDisabled()
        service.saveSchedulerLoopMetadata("scheduler_disabled", false, result.intervalMillis, "disabled", 0, 0, ArrayList<String>(), "scheduler_disabled")
        result.status = "scheduler_disabled"
        return result
    }

    if (!deferFirstTick) {
        result.tick = runCkbSchedulerStartupTick(service, result.intervalMillis)
    } else {
        service.saveSchedulerLoopMetadata("running", true, result.intervalMillis, "startup_deferred", 0, 0, ArrayList<String>(), "first_tick_deferred")
    }
    result.ok = true
    result.status = if (afterHttpReady) { "scheduler_started_after_http_ready" } else { "scheduler_started" }
    let interval = result.intervalMillis
    spawn { =>
        if (deferFirstTick) {
            try {
                _ = runCkbSchedulerStartupTick(service, interval)
            } catch (_: Exception) {
                service.markSchedulerLoopFailure("scheduler_loop_startup_tick_failed")
                service.saveSchedulerLoopMetadata("failed", true, interval, "startup", 1, 0, ArrayList<String>(), "scheduler_loop_startup_tick_failed")
            }
        }
        while (true) {
            sleep(Duration.millisecond * interval)
            try {
                _ = runCkbSchedulerTickWithLifecycleMetadata(service, 1, "periodic", intervalMillis: interval)
            } catch (_: Exception) {
                service.markSchedulerLoopFailure("scheduler_loop_tick_failed")
                service.saveSchedulerLoopMetadata("failed", true, interval, "periodic", 1, 0, ArrayList<String>(), "scheduler_loop_tick_failed")
            }
        }
    }
    result
}

private func runCkbSchedulerStartupTick(service: CkbCommandLoopService, intervalMillis: Int64): SchedulerExecutorResult {
    var tick = runCkbSchedulerTickWithLifecycleMetadata(service, 1, "startup", intervalMillis: intervalMillis)
    if (tick.ran == 0) {
        let taskNames = ArrayList<String>()
        taskNames.add("community_repo_discovery_30d")
        tick = service.runSchedulerTasks(taskNames, true)
        service.saveSchedulerLoopMetadata("running", true, intervalMillis, "startup_forced_probe", 1, tick.ran, tick.taskNames, if (tick.failed == 0) { "ok" } else { "scheduler_startup_forced_probe_failed" })
    }
    tick
}
