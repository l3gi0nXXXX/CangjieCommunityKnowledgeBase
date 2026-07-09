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

    @TestCase
    public func p7Neg02ContractFailsWhenRequiredArtifactIsMissing(): Unit {
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "candidate_validated_promoted"
        task.activeVersion = "active-v2"
        task.candidateVersion = "candidate-v2"
        task.validationStatus = "candidate_validation_passed"
        task.updatedDataKinds.add("release")
        task.updatedDataKinds.add("version_manifest")
        let artifacts = CkbRoutineArtifactStatus()
        artifacts.ok = false
        artifacts.missingArtifacts.add("metadata/cangjie-version-manifest.ckb")
        artifacts.evidenceHash = "artifact-missing"

        let validation = validateSchedulerTaskResultAgainstContractWithArtifacts("cangjie_release_full_sync", task, p7Invariant("active-v1"), p7Invariant("active-v2"), artifacts)
        let rendered = renderCkbRoutineContractValidationJson(validation)

        @Expect(validation.ok, false)
        @Expect(validation.diagnostic.contains("required_artifact_missing"), true)
        @Expect(validation.missingArtifacts.contains("metadata/cangjie-version-manifest.ckb"), true)
        @Expect(rendered.contains("\"missingArtifacts\""), true)
        @Expect(rendered.contains("metadata/cangjie-version-manifest.ckb"), true)
    }

    @TestCase
    public func p2Ut001ManifestCandidateContractAcceptsManifestWriteGate(): Unit {
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "version_manifest_refreshed_with_content_warnings"
        task.validationStatus = "version_manifest_write_verified"
        task.validationDiagnostics.add("version_manifest_write_verified:sources=5:evidence=manifest-hash")
        task.updatedDataKinds.add("version_manifest")
        let artifacts = CkbRoutineArtifactStatus()
        artifacts.ok = true
        artifacts.presentArtifacts.add("metadata/cangjie-version-manifest.ckb")
        artifacts.evidenceHash = "artifact-ok"

        let validation = validateSchedulerTaskResultAgainstContractWithArtifacts("cangjie_version_branch_refresh", task, p7Invariant("active-v1"), p7Invariant("active-v1"), artifacts)

        @Expect(validation.ok, true)
        @Expect(validation.diagnostic, "routine_contract_passed")
    }

    @TestCase
    public func p2Neg001ManifestCandidateContractRejectsMissingManifestWriteGate(): Unit {
        let task = SchedulerTaskResult()
        task.ok = true
        task.status = "version_manifest_refreshed_with_content_warnings"
        task.validationStatus = "not_run"
        task.updatedDataKinds.add("version_manifest")
        let artifacts = CkbRoutineArtifactStatus()
        artifacts.ok = true
        artifacts.presentArtifacts.add("metadata/cangjie-version-manifest.ckb")

        let validation = validateSchedulerTaskResultAgainstContractWithArtifacts("cangjie_version_branch_refresh", task, p7Invariant("active-v1"), p7Invariant("active-v1"), artifacts)

        @Expect(validation.ok, false)
        @Expect(validation.diagnostic.contains("manifest_write_gate_missing"), true)
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
