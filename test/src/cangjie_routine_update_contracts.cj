package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CkbRoutineUpdatePolicies {
    public static let PROBE_ONLY: String = "probe_only_no_active_mutation"
    public static let CHECKPOINT_ONLY: String = "checkpoint_only_no_active_mutation"
    public static let REVIEW_QUEUE_ONLY: String = "review_queue_only_no_active_mutation"
    public static let CANDIDATE_PROMOTE: String = "candidate_validate_promote"
    public static let MANIFEST_CANDIDATE: String = "manifest_candidate_validate_promote"
    public static let CURATED_CANDIDATE: String = "curated_candidate_validate_promote"
    public static let REBUILD_PROMOTE: String = "rebuild_candidate_then_promote"
}

public class CkbRoutineUpdateContract {
    public var updateMechanismId: String = ""
    public var name: String = ""
    public var activeMutationPolicy: String = ""
    public var requiredFreshnessFields: ArrayList<String> = ArrayList<String>()
    public var requiredArtifacts: ArrayList<String> = ArrayList<String>()
    public var schedulerTasks: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbSchedulerTaskContract {
    public var taskName: String = ""
    public var updateMechanismId: String = ""
    public var profile: String = ""
    public var candidateMode: String = ""
    public var activeMutationPolicy: String = ""
    public var expectedUpdatedDataKinds: ArrayList<String> = ArrayList<String>()
    public var requiredArtifacts: ArrayList<String> = ArrayList<String>()
    public var requiredValidationGates: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CkbRoutineActiveInvariant {
    public var activeKnowledgeVersion: String = ""
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var indexCount: Int64 = 0
    public var vectorState: String = ""
    public var graphState: String = ""
    public var evidenceHash: String = ""

    public init() {}
}

public class CkbRoutineContractValidation {
    public var ok: Bool = false
    public var status: String = "failed"
    public var taskName: String = ""
    public var updateMechanismId: String = ""
    public var diagnostic: String = ""
    public var evidenceHash: String = ""
    public var missingArtifacts: ArrayList<String> = ArrayList<String>()
    public var artifactEvidenceHash: String = ""

    public init() {}
}

public class CkbRoutineArtifactStatus {
    public var ok: Bool = true
    public var presentArtifacts: ArrayList<String> = ArrayList<String>()
    public var missingArtifacts: ArrayList<String> = ArrayList<String>()
    public var evidenceHash: String = ""

    public init() {}
}

public func cangjieRoutineUpdateContracts(): ArrayList<CkbRoutineUpdateContract> {
    let out = ArrayList<CkbRoutineUpdateContract>()
    out.add(ckbRoutineContract("KU-06", "freshness contract", CkbRoutineUpdatePolicies.PROBE_ONLY, ["metadata/cangjie-freshness.ckb"], ["sourceSet", "targetVersion", "sourceRepo", "sourceRef", "resolvedCommit", "contentHash", "crawlAt", "indexedAt", "staleness"], ["docs_probe_30d", "cangjie_freshness_daily"]))
    out.add(ckbRoutineContract("KU-07", "official docs incremental sync", CkbRoutineUpdatePolicies.CANDIDATE_PROMOTE, ["normalized/candidate"], [], ["cangjie_docs_full_weekly"]))
    out.add(ckbRoutineContract("KU-08", "official docs weekly full rebuild", CkbRoutineUpdatePolicies.CANDIDATE_PROMOTE, ["index/active.ckb"], [], ["cangjie_docs_full_weekly", "weekly_full_rebuild"]))
    out.add(ckbRoutineContract("KU-09", "release full sync", CkbRoutineUpdatePolicies.CANDIDATE_PROMOTE, ["metadata/cangjie-version-manifest.ckb"], [], ["cangjie_release_full_sync"]))
    out.add(ckbRoutineContract("KU-10", "source repository event sync", CkbRoutineUpdatePolicies.CANDIDATE_PROMOTE, ["metadata/repository-event-latest.ckb"], [], ["cangjie_source_event_sync"]))
    out.add(ckbRoutineContract("KU-11", "benchmark gap curation", CkbRoutineUpdatePolicies.CURATED_CANDIDATE, ["gap-curation-input.jsonl"], [], ["cangjie_benchmark_gap_curation"]))
    out.add(ckbRoutineContract("KU-12", "reviewed negative and diagnose rules", CkbRoutineUpdatePolicies.CURATED_CANDIDATE, ["gap-curation-input.jsonl"], [], ["cangjie_benchmark_gap_curation"]))
    out.add(ckbRoutineContract("KU-13", "version branch mapping refresh", CkbRoutineUpdatePolicies.MANIFEST_CANDIDATE, ["metadata/cangjie-version-manifest.ckb"], [], ["cangjie_version_branch_refresh"]))
    out
}

public func cangjieSchedulerTaskContracts(): ArrayList<CkbSchedulerTaskContract> {
    let out = ArrayList<CkbSchedulerTaskContract>()
    out.add(ckbSchedulerTaskContract("community_repo_discovery_30d", "repo-catalog", "community_repo_discovery", "none", CkbRoutineUpdatePolicies.CHECKPOINT_ONLY, ["repo_catalog"], ["metadata/repo-list.ckb"], []))
    out.add(ckbSchedulerTaskContract("docs_probe_30d", "KU-06", "docs_probe", "none", CkbRoutineUpdatePolicies.PROBE_ONLY, ["docs"], ["metadata/cangjie-freshness.ckb"], []))
    out.add(ckbSchedulerTaskContract("website_probe_weekly", "website-freshness", "website_probe", "none", CkbRoutineUpdatePolicies.PROBE_ONLY, ["website"], [], []))
    out.add(ckbSchedulerTaskContract("website_full_weekly", "website-full-sync", "website_full", "none", CkbRoutineUpdatePolicies.REVIEW_QUEUE_ONLY, ["website"], [], []))
    out.add(ckbSchedulerTaskContract("web_candidate_weekly", "web-candidate-discovery", "web_candidate_discovery", "none", CkbRoutineUpdatePolicies.REVIEW_QUEUE_ONLY, ["web_candidates"], [], []))
    out.add(ckbSchedulerTaskContract("web_candidate_recrawl_30d", "web-candidate-recrawl", "web_candidate_recrawl", "none", CkbRoutineUpdatePolicies.REVIEW_QUEUE_ONLY, ["web_candidates"], [], []))
    out.add(ckbSchedulerTaskContract("weekly_full_rebuild", "KU-08", "full_rebuild", "rebuild_candidate_then_promote", CkbRoutineUpdatePolicies.REBUILD_PROMOTE, ["index"], ["index/active.ckb"], []))
    out.add(ckbSchedulerTaskContract("cangjie_freshness_daily", "KU-06", "cangjie_freshness_probe", "probe_only", CkbRoutineUpdatePolicies.PROBE_ONLY, ["freshness", "version_manifest"], ["metadata/cangjie-freshness.ckb"], []))
    out.add(ckbSchedulerTaskContract("cangjie_docs_full_weekly", "KU-07", "cangjie_docs_full_sync", "candidate_validate_promote", CkbRoutineUpdatePolicies.CANDIDATE_PROMOTE, ["docs", "serving_feed"], ["normalized/candidate"], ["candidate_validation_passed"]))
    out.add(ckbSchedulerTaskContract("cangjie_release_full_sync", "KU-09", "cangjie_release_full_sync", "candidate_validate_promote", CkbRoutineUpdatePolicies.CANDIDATE_PROMOTE, ["release", "version_manifest"], ["metadata/cangjie-version-manifest.ckb"], ["candidate_validation_passed"]))
    out.add(ckbSchedulerTaskContract("cangjie_source_event_sync", "KU-10", "cangjie_source_event_sync", "candidate_validate_promote", CkbRoutineUpdatePolicies.CANDIDATE_PROMOTE, ["repo_source", "serving_feed"], ["metadata/repository-event-latest.ckb"], ["candidate_validation_passed"]))
    out.add(ckbSchedulerTaskContract("cangjie_version_branch_refresh", "KU-13", "cangjie_version_branch_refresh", "manifest_candidate", CkbRoutineUpdatePolicies.MANIFEST_CANDIDATE, ["version_manifest"], ["metadata/cangjie-version-manifest.ckb"], ["version_manifest_write_verified"]))
    out.add(ckbSchedulerTaskContract("cangjie_benchmark_gap_curation", "KU-11/KU-12", "cangjie_benchmark_gap_curation", "curated_candidate_validate_promote", CkbRoutineUpdatePolicies.CURATED_CANDIDATE, ["benchmark_gap_curation", "negative_rules"], ["gap-curation-input.jsonl"], ["candidate_validation_passed", "query_proof"]))
    out
}

public func ckbRoutineActiveInvariantFromStatus(status: KnowledgeStatus): CkbRoutineActiveInvariant {
    let invariant = CkbRoutineActiveInvariant()
    invariant.activeKnowledgeVersion = status.activeKnowledgeVersion
    invariant.rawCount = status.storage.rawCount
    invariant.normalizedCount = status.storage.normalizedCount
    invariant.indexCount = status.storage.indexCount
    invariant.vectorState = status.storage.vectorState
    invariant.graphState = status.storage.graphState
    invariant.evidenceHash = stableSummaryHash("${invariant.activeKnowledgeVersion}:${invariant.rawCount}:${invariant.normalizedCount}:${invariant.indexCount}:${invariant.vectorState}:${invariant.graphState}")
    invariant
}

public func validateSchedulerTaskResultAgainstContract(taskName: String, task: SchedulerTaskResult, before: CkbRoutineActiveInvariant, after: CkbRoutineActiveInvariant): CkbRoutineContractValidation {
    validateSchedulerTaskResultAgainstContractWithArtifacts(taskName, task, before, after, CkbRoutineArtifactStatus())
}

public func validateSchedulerTaskResultAgainstContractWithArtifacts(taskName: String, task: SchedulerTaskResult, before: CkbRoutineActiveInvariant, after: CkbRoutineActiveInvariant, artifactStatus: CkbRoutineArtifactStatus): CkbRoutineContractValidation {
    let validation = CkbRoutineContractValidation()
    validation.taskName = taskName
    let contract = ckbSchedulerTaskContractByName(taskName)
    validation.updateMechanismId = contract.updateMechanismId
    validation.artifactEvidenceHash = artifactStatus.evidenceHash
    for (artifact in artifactStatus.missingArtifacts) {
        validation.missingArtifacts.add(artifact)
    }
    if (contract.taskName == "") {
        ckbRoutineValidationFail(validation, "routine_task_contract_missing")
        return validation
    }
    if (!task.ok) {
        ckbRoutineValidationFail(validation, "task_not_ok:${task.status}")
        return validation
    }
    for (kind in contract.expectedUpdatedDataKinds) {
        if (!task.updatedDataKinds.contains(kind)) {
            ckbRoutineValidationFail(validation, "updated_kind_missing:${kind}")
            return validation
        }
    }
    if (ckbRoutinePolicyRequiresNoActiveMutation(contract.activeMutationPolicy) && before.activeKnowledgeVersion != after.activeKnowledgeVersion) {
        ckbRoutineValidationFail(validation, "active_mutation_forbidden:${before.activeKnowledgeVersion}->${after.activeKnowledgeVersion}")
        return validation
    }
    if (ckbRoutinePolicyRequiresManifestWriteGate(contract.activeMutationPolicy) && task.validationStatus != "version_manifest_write_verified") {
        ckbRoutineValidationFail(validation, "manifest_write_gate_missing:${task.validationStatus}")
        return validation
    }
    if (ckbRoutinePolicyRequiresCandidateValidation(contract.activeMutationPolicy) && task.validationStatus != "candidate_validation_passed") {
        ckbRoutineValidationFail(validation, "candidate_validation_missing:${task.validationStatus}")
        return validation
    }
    if (ckbRoutinePolicyRequiresCandidateValidation(contract.activeMutationPolicy) && (task.candidateVersion == "" || task.activeVersion == "")) {
        ckbRoutineValidationFail(validation, "candidate_or_active_version_missing")
        return validation
    }
    if (contract.activeMutationPolicy == CkbRoutineUpdatePolicies.REBUILD_PROMOTE && task.activeVersion == "") {
        ckbRoutineValidationFail(validation, "rebuild_active_version_missing")
        return validation
    }
    if (contract.requiredArtifacts.size > 0 && !artifactStatus.ok) {
        ckbRoutineValidationFail(validation, "required_artifact_missing:${ckbRoutineJoinStrings(artifactStatus.missingArtifacts, ",")}")
        return validation
    }
    validation.ok = true
    validation.status = "passed"
    validation.diagnostic = "routine_contract_passed"
    validation.evidenceHash = stableSummaryHash(ckbRoutineValidationEvidence(validation, contract, before, after, task))
    validation
}

public func renderCkbRoutineContractValidationJson(validation: CkbRoutineContractValidation): String {
    "{\"taskName\":\"${ckbRoutineJsonEscape(validation.taskName)}\",\"updateMechanismId\":\"${ckbRoutineJsonEscape(validation.updateMechanismId)}\",\"ok\":${validation.ok},\"status\":\"${ckbRoutineJsonEscape(validation.status)}\",\"diagnostic\":\"${ckbRoutineJsonEscape(validation.diagnostic)}\",\"evidenceHash\":\"${ckbRoutineJsonEscape(validation.evidenceHash)}\",\"missingArtifacts\":${ckbRoutineStringArrayJson(validation.missingArtifacts)},\"artifactEvidenceHash\":\"${ckbRoutineJsonEscape(validation.artifactEvidenceHash)}\"}"
}

public func renderCkbRoutineUpdateContractsJsonl(): String {
    var out = ""
    for (contract in cangjieRoutineUpdateContracts()) {
        out += "{\"type\":\"ku\",\"id\":\"${ckbRoutineJsonEscape(contract.updateMechanismId)}\",\"name\":\"${ckbRoutineJsonEscape(contract.name)}\",\"activeMutationPolicy\":\"${ckbRoutineJsonEscape(contract.activeMutationPolicy)}\",\"requiredArtifacts\":${ckbRoutineStringArrayJson(contract.requiredArtifacts)},\"schedulerTasks\":${ckbRoutineStringArrayJson(contract.schedulerTasks)}}\n"
    }
    for (contract in cangjieSchedulerTaskContracts()) {
        out += "{\"type\":\"task\",\"name\":\"${ckbRoutineJsonEscape(contract.taskName)}\",\"updateMechanismId\":\"${ckbRoutineJsonEscape(contract.updateMechanismId)}\",\"profile\":\"${ckbRoutineJsonEscape(contract.profile)}\",\"candidateMode\":\"${ckbRoutineJsonEscape(contract.candidateMode)}\",\"activeMutationPolicy\":\"${ckbRoutineJsonEscape(contract.activeMutationPolicy)}\",\"expectedUpdatedDataKinds\":${ckbRoutineStringArrayJson(contract.expectedUpdatedDataKinds)},\"requiredArtifacts\":${ckbRoutineStringArrayJson(contract.requiredArtifacts)},\"requiredValidationGates\":${ckbRoutineStringArrayJson(contract.requiredValidationGates)}}\n"
    }
    out
}

public func renderCkbRoutineUpdateStatusJson(status: KnowledgeStatus): String {
    let contracts = cangjieSchedulerTaskContracts()
    var passed: Int64 = 0
    var failed: Int64 = 0
    var missing: Int64 = 0
    for (contract in contracts) {
        let entry = ckbRoutineFindSchedule(status, contract.taskName)
        if (entry.name == "") {
            missing += 1
        } else if (entry.lastSuccessAt > 0 && !entry.degraded) {
            passed += 1
        } else if (entry.lastFailureAt > 0 || entry.degraded) {
            failed += 1
        } else {
            missing += 1
        }
    }
    let state = if (passed == contracts.size && failed == 0 && missing == 0) { "landed" } else if (passed > 0) { "partial" } else { "missing" }
    "{\"status\":\"${state}\",\"passedTasks\":${passed},\"failedTasks\":${failed},\"missingTasks\":${missing},\"totalTasks\":${contracts.size},\"requiredKuCount\":${cangjieRoutineUpdateContracts().size}}"
}

public func ckbSchedulerTaskContractForName(name: String): CkbSchedulerTaskContract {
    ckbSchedulerTaskContractByName(name)
}

private func ckbRoutineContract(id: String, name: String, policy: String, artifacts: Array<String>, freshnessFields: Array<String>, tasks: Array<String>): CkbRoutineUpdateContract {
    let contract = CkbRoutineUpdateContract()
    contract.updateMechanismId = id
    contract.name = name
    contract.activeMutationPolicy = policy
    for (artifact in artifacts) {
        contract.requiredArtifacts.add(artifact)
    }
    for (field in freshnessFields) {
        contract.requiredFreshnessFields.add(field)
    }
    for (task in tasks) {
        contract.schedulerTasks.add(task)
    }
    contract
}

private func ckbSchedulerTaskContract(taskName: String, updateMechanismId: String, profile: String, candidateMode: String, policy: String, kinds: Array<String>, artifacts: Array<String>, gates: Array<String>): CkbSchedulerTaskContract {
    let contract = CkbSchedulerTaskContract()
    contract.taskName = taskName
    contract.updateMechanismId = updateMechanismId
    contract.profile = profile
    contract.candidateMode = candidateMode
    contract.activeMutationPolicy = policy
    for (kind in kinds) {
        contract.expectedUpdatedDataKinds.add(kind)
    }
    for (artifact in artifacts) {
        contract.requiredArtifacts.add(artifact)
    }
    for (gate in gates) {
        contract.requiredValidationGates.add(gate)
    }
    contract
}

private func ckbSchedulerTaskContractByName(name: String): CkbSchedulerTaskContract {
    for (contract in cangjieSchedulerTaskContracts()) {
        if (contract.taskName == name) {
            return contract
        }
    }
    CkbSchedulerTaskContract()
}

private func ckbRoutinePolicyRequiresNoActiveMutation(policy: String): Bool {
    policy == CkbRoutineUpdatePolicies.PROBE_ONLY || policy == CkbRoutineUpdatePolicies.CHECKPOINT_ONLY || policy == CkbRoutineUpdatePolicies.REVIEW_QUEUE_ONLY || policy == CkbRoutineUpdatePolicies.MANIFEST_CANDIDATE
}

private func ckbRoutinePolicyRequiresCandidateValidation(policy: String): Bool {
    policy == CkbRoutineUpdatePolicies.CANDIDATE_PROMOTE || policy == CkbRoutineUpdatePolicies.CURATED_CANDIDATE
}

private func ckbRoutinePolicyRequiresManifestWriteGate(policy: String): Bool {
    policy == CkbRoutineUpdatePolicies.MANIFEST_CANDIDATE
}

private func ckbRoutineValidationFail(validation: CkbRoutineContractValidation, diagnostic: String): Unit {
    validation.ok = false
    validation.status = "failed"
    validation.diagnostic = diagnostic
    validation.evidenceHash = stableSummaryHash("${validation.taskName}:${validation.updateMechanismId}:${diagnostic}:${ckbRoutineJoinStrings(validation.missingArtifacts, ",")}:${validation.artifactEvidenceHash}")
}

private func ckbRoutineValidationEvidence(validation: CkbRoutineContractValidation, contract: CkbSchedulerTaskContract, before: CkbRoutineActiveInvariant, after: CkbRoutineActiveInvariant, task: SchedulerTaskResult): String {
    "${validation.taskName}:${contract.updateMechanismId}:${contract.activeMutationPolicy}:${before.evidenceHash}:${after.evidenceHash}:${task.status}:${task.validationStatus}:${ckbRoutineJoinStrings(task.updatedDataKinds, ",")}:${ckbRoutineJoinStrings(validation.missingArtifacts, ",")}:${validation.artifactEvidenceHash}"
}

private func ckbRoutineFindSchedule(status: KnowledgeStatus, name: String): ScheduleEntry {
    for (entry in status.schedules) {
        if (entry.name == name) {
            return entry
        }
    }
    ScheduleEntry()
}

private func ckbRoutineStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${ckbRoutineJsonEscape(values[i])}\""
    }
    out + "]"
}

private func ckbRoutineJoinStrings(values: ArrayList<String>, separator: String): String {
    var out = ""
    for (i in 0..values.size) {
        if (i > 0) {
            out += separator
        }
        out += values[i]
    }
    out
}

private func ckbRoutineJsonEscape(raw: String): String {
    redactSensitive(raw).replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t")
}
