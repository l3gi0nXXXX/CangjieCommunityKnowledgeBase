package cangjie_community_knowledge_base_test

import std.time.*
import std.collection.ArrayList

public class CkbSchedulerLoopStartResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var intervalMillis: Int64 = 0
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

public func startCkbSchedulerLoop(service: CkbCommandLoopService, config: CkbRuntimeConfig): CkbSchedulerLoopStartResult {
    let result = CkbSchedulerLoopStartResult()
    result.intervalMillis = ckbSchedulerLoopIntervalMillis(config)
    if (!config.schedulerEnabled) {
        service.markSchedulerDisabled()
        result.status = "scheduler_disabled"
        return result
    }

    result.tick = runCkbSchedulerTick(service, 1)
    if (result.tick.ran == 0) {
        let taskNames = ArrayList<String>()
        taskNames.add("community_repo_discovery_30d")
        result.tick = service.runSchedulerTasks(taskNames, true)
    }
    result.ok = true
    result.status = "scheduler_started"
    let interval = result.intervalMillis
    spawn { =>
        while (true) {
            sleep(Duration.millisecond * interval)
            try {
                _ = runCkbSchedulerTick(service, 1)
            } catch (_: Exception) {
                service.markSchedulerLoopFailure("scheduler_loop_tick_failed")
            }
        }
    }
    result
}
