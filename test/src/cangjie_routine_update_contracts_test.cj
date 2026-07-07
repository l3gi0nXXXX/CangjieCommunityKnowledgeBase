package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieRoutineUpdateContractsTest {
    @TestCase
    public func p7Ut01RoutineContractsCoverKu06ToKu13(): Unit {
        let contracts = cangjieRoutineUpdateContracts()

        @Expect(contracts.size, 8)
        @Expect(p7HasKu(contracts, "KU-06"), true)
        @Expect(p7HasKu(contracts, "KU-13"), true)
    }

    @TestCase
    public func p7Ut02SchedulerTaskContractsMatchAllowlist(): Unit {
        let allowlist = ckbSchedulerAllowlistTaskNames()
        let contracts = cangjieSchedulerTaskContracts()

        @Expect(contracts.size, allowlist.size)
        for (name in allowlist) {
            @Expect(p7HasTask(contracts, name), true)
        }
    }

    @TestCase
    public func p7Bnd01UnknownTaskFailsContractValidationWithoutPanic(): Unit {
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "ok"
        let before = CkbRoutineActiveInvariant()
        let after = CkbRoutineActiveInvariant()

        let validation = validateSchedulerTaskResultAgainstContract("unknown_task", task, before, after)

        @Expect(validation.ok, false)
        @Expect(validation.diagnostic, "routine_task_contract_missing")
    }

    @TestCase
    public func p7Pos01ProbeOnlyContractPassesWhenActiveInvariantIsStable(): Unit {
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "freshness_probe_ok"
        task.activeVersion = "active-v1"
        task.updatedDataKinds.add("freshness")
        task.updatedDataKinds.add("version_manifest")
        let before = p7Invariant("active-v1")
        let after = p7Invariant("active-v1")

        let validation = validateSchedulerTaskResultAgainstContract("cangjie_freshness_daily", task, before, after)

        @Expect(validation.ok, true)
        @Expect(validation.diagnostic, "routine_contract_passed")
    }

    @TestCase
    public func p7Neg01ProbeOnlyContractFailsWhenActiveMutates(): Unit {
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "freshness_probe_ok"
        task.activeVersion = "active-v2"
        task.updatedDataKinds.add("freshness")
        task.updatedDataKinds.add("version_manifest")
        let before = p7Invariant("active-v1")
        let after = p7Invariant("active-v2")

        let validation = validateSchedulerTaskResultAgainstContract("cangjie_freshness_daily", task, before, after)

        @Expect(validation.ok, false)
        @Expect(validation.diagnostic.contains("active_mutation_forbidden"), true)
    }
}

private func p7HasKu(contracts: ArrayList<CkbRoutineUpdateContract>, id: String): Bool {
    for (contract in contracts) {
        if (contract.updateMechanismId == id) {
            return true
        }
    }
    false
}

private func p7HasTask(contracts: ArrayList<CkbSchedulerTaskContract>, name: String): Bool {
    for (contract in contracts) {
        if (contract.taskName == name) {
            return true
        }
    }
    false
}

private func p7Invariant(activeVersion: String): CkbRoutineActiveInvariant {
    let invariant = CkbRoutineActiveInvariant()
    invariant.activeKnowledgeVersion = activeVersion
    invariant.rawCount = 1
    invariant.normalizedCount = 1
    invariant.indexCount = 1
    invariant.vectorState = "ready"
    invariant.graphState = "ready"
    invariant.evidenceHash = stableSummaryHash(activeVersion)
    invariant
}
