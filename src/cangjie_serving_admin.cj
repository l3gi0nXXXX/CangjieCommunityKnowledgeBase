package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.time.DateTime
import stdx.crypto.digest.SHA256

public class CangjieCandidateValidationResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var candidateVersion: String = ""
    public var activeVersion: String = ""
    public var servingDocumentCount: Int64 = 0
    public var exactSymbolHits: Int64 = 0
    public var docSectionHits: Int64 = 0
    public var toolManualHits: Int64 = 0
    public var negativeRuleHits: Int64 = 0
    public var moduleHits: Int64 = 0
    public var availabilityHits: Int64 = 0
    public var coveragePass: Bool = false
    public var taskPackCoveragePass: Bool = false
    public var transportParityPass: Bool = false
    public var performancePass: Bool = false
    public var vectorHealthPass: Bool = false
    public var vectorState: String = ""
    public var vectorDimension: Int64 = 0
    public var vectorDegradedReason: String = ""
    public var performanceP95Cost: Int64 = 0
    public var legacyVersionGapCount: Int64 = 0
    public var evidenceHash: String = ""
    public var servingIndexDiagnostic: String = ""
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieServingPerformanceProbe {
    public var pass: Bool = false
    public var queryCount: Int64 = 0
    public var p95Cost: Int64 = 0
    public var threshold: Int64 = 0
    public var evidenceHash: String = ""
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieCandidatePromotionResult {
    public var ok: Bool = false
    public var candidateWritten: Bool = false
    public var activePromoted: Bool = false
    public var candidateVersion: String = ""
    public var activeVersion: String = ""
    public var snapshotTxId: String = ""
    public var snapshotPointerCommitted: Bool = false
    public var snapshotLiveShadowConsistent: Bool = false
    public var validation: CangjieCandidateValidationResult = CangjieCandidateValidationResult()

    public init() {}
}

public class CangjieCandidatePromotionBudgetPlan {
    public var segmented: Bool = false
    public var vectorBudgetMillis: Int64 = 0
    public var validationBudgetMillis: Int64 = 0
    public var activeCommitBudgetMillis: Int64 = 0
    public var snapshotBudgetMillis: Int64 = 0
    public var workerSoftDeadlineAtMillis: Int64 = 0
    public var deadlineClock: CkbMillisClock = SystemCkbMillisClock()

    public init() {}
}

public func cangjieLiveSyncCandidateVersion(): String {
    "ckb-20260519-000100-candidate"
}

public func cangjieActiveVersionForCandidate(candidateVersion: String): String {
    if (candidateVersion.endsWith("-candidate")) {
        return candidateVersion.replace("-candidate", "-active")
    }
    "${candidateVersion}-active"
}

public func validateCandidateServingIndex(records: ArrayList<NormalizedRecord>, candidateVersion: String, forceFailure!: Bool = false): CangjieCandidateValidationResult {
    validateCandidateServingIndexWithVectorStatus(records, candidateVersion, cangjieCandidateImplicitVectorStatus(records), forceFailure: forceFailure)
}

public func validateCandidateServingIndexWithVectorStatus(records: ArrayList<NormalizedRecord>, candidateVersion: String, vectorStatus: VectorStoreStatus, forceFailure!: Bool = false, deadlineAtMillis!: Int64 = 0, validationScope!: String = "full"): CangjieCandidateValidationResult {
    let result = CangjieCandidateValidationResult()
    result.candidateVersion = candidateVersion
    result.activeVersion = cangjieActiveVersionForCandidate(candidateVersion)
    if (candidateVersion.trimAscii() == "") {
        result.status = "candidate_version_missing"
        result.diagnostics.add("candidate_version_missing")
        return result
    }
    if (forceFailure) {
        result.status = "candidate_validation_forced_failure"
        result.diagnostics.add("candidate_validation_forced_failure")
        return result
    }
    if (cangjieCandidateValidationDeadline(result, validationScope, "doc_loop_before", deadlineAtMillis, 0, records.size)) {
        return result
    }
    let index = buildCangjieServingIndex(records, activeKnowledgeVersion: result.activeVersion, deadlineAtMillis: deadlineAtMillis)
    result.servingDocumentCount = index.documents.size
    let servingDeadline = cangjieServingIndexDeadlineDiagnostic(index)
    if (servingDeadline != "") {
        result.ok = false
        result.status = "candidate_validation_timeout"
        result.diagnostics.add("${servingDeadline}:scope=${validationScope}:completed=0:total=${records.size}")
        cangjieReleaseServingIndex(index)
        return result
    }
    if (cangjieCandidateValidationDeadline(result, validationScope, "doc_loop_before", deadlineAtMillis, 0, index.documents.size)) {
        cangjieReleaseServingIndex(index)
        return result
    }
    let completedDocs = cangjieCandidateAccumulateCoverage(index, result, validationScope, deadlineAtMillis)
    if (result.status == "candidate_validation_timeout") {
        cangjieReleaseServingIndex(index)
        return result
    }
    result.taskPackCoveragePass = result.exactSymbolHits > 0 &&
        result.docSectionHits > 0 &&
        result.toolManualHits > 0 &&
        result.negativeRuleHits > 0
    result.coveragePass = result.exactSymbolHits > 0 && result.docSectionHits > 0 && result.negativeRuleHits > 0
    if (cangjieCandidateValidationDeadline(result, validationScope, "parity_probe_before", deadlineAtMillis, completedDocs, index.documents.size)) {
        cangjieReleaseServingIndex(index)
        return result
    }
    result.transportParityPass = cangjieCandidateRestMcpParityPass(index)
    if (cangjieCandidateValidationDeadline(result, validationScope, "performance_probe_before", deadlineAtMillis, completedDocs, index.documents.size)) {
        cangjieReleaseServingIndex(index)
        return result
    }
    let performance = cangjieServingPerformanceProbe(index, cangjieCandidatePerformanceQueries(index), budget: 5, p95Threshold: 10000000)
    result.performancePass = performance.pass
    result.performanceP95Cost = performance.p95Cost
    result.vectorState = vectorStatus.state
    result.vectorDimension = vectorStatus.dimension
    result.vectorDegradedReason = vectorStatus.degradedReason
    result.vectorHealthPass = cangjieCandidateVectorHealthPass(vectorStatus)
    result.evidenceHash = cangjieServingDocumentEvidenceHash(index.documents)
    result.servingIndexDiagnostic = cangjieServingIndexDiagnostics(index)
    if (index.documents.size == 0) {
        result.diagnostics.add("serving_index_not_ready")
    }
    if (!result.coveragePass) {
        result.diagnostics.add("candidate_coverage_regression")
    }
    if (result.exactSymbolHits == 0) {
        result.diagnostics.add("exact_symbol_coverage_missing")
    }
    if (result.docSectionHits == 0) {
        result.diagnostics.add("doc_section_coverage_missing")
    }
    if (result.toolManualHits == 0) {
        result.diagnostics.add("tool_manual_coverage_missing")
    }
    if (result.negativeRuleHits == 0) {
        result.diagnostics.add("negative_rule_coverage_missing")
    }
    if (!result.taskPackCoveragePass) {
        result.diagnostics.add("task_pack_coverage_missing")
    }
    if (!result.transportParityPass) {
        result.diagnostics.add("rest_mcp_parity_failed")
    } else {
        result.diagnostics.add("rest_mcp_parity_passed")
    }
    if (!result.vectorHealthPass) {
        result.diagnostics.add("vector_health_failed:${cangjieCandidateVectorDiagnostic(vectorStatus)}")
    } else {
        result.diagnostics.add("vector_health_passed")
    }
    if (!result.performancePass) {
        result.diagnostics.add("performance_threshold_failed")
    } else {
        result.diagnostics.add("performance_threshold_passed")
    }
    result.ok = index.documents.size > 0 && result.coveragePass && result.transportParityPass && result.vectorHealthPass && result.performancePass
    result.status = if (result.ok) { "candidate_validation_passed" } else { "candidate_validation_failed" }
    cangjieReleaseServingIndex(index)
    result
}

private func cangjieReleaseServingIndex(index: CangjieServingIndex): Unit {
    index.records.clear()
    index.documents.clear()
    index.exactEntries.clear()
}

private func cangjieCandidateValidationDeadline(result: CangjieCandidateValidationResult, validationScope: String, stage: String, deadlineAtMillis: Int64, completed: Int64, total: Int64): Bool {
    let deadline = ckbDeadlineGuard("candidate_validation_${stage}", deadlineAtMillis)
    if (!deadline.exceeded) {
        return false
    }
    result.ok = false
    result.status = "candidate_validation_timeout"
    result.diagnostics.add("${deadline.diagnostic}:scope=${validationScope}:completed=${completed}:total=${total}")
    true
}

private func cangjieCandidateAccumulateCoverage(index: CangjieServingIndex, result: CangjieCandidateValidationResult, validationScope: String, deadlineAtMillis: Int64): Int64 {
    var completedDocs: Int64 = 0
    for (doc in index.documents) {
        if (completedDocs % 512 == 0 && cangjieCandidateValidationDeadline(result, validationScope, "doc_loop", deadlineAtMillis, completedDocs, index.documents.size)) {
            return completedDocs
        }
        if (doc.rejected) {
            completedDocs += 1
            continue
        }
        if (doc.versionResolutionId == "") {
            result.legacyVersionGapCount += 1
        }
        if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD && doc.symbolKey.trimAscii() != "") {
            result.exactSymbolHits += 1
        } else if (doc.recordKind == CangjieServingRecordKinds.DOC_SECTION && cangjieCandidateDocSectionCovered(doc)) {
            result.docSectionHits += 1
        } else if (doc.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL && cangjieCandidateToolSelector(doc).trimAscii() != "") {
            result.toolManualHits += 1
        } else if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE && cangjieCandidateNegativeRuleCovered(doc)) {
            result.negativeRuleHits += 1
        }
        if (doc.module.trimAscii() != "") {
            result.moduleHits += 1
        }
        if ((doc.recordKind == CangjieTypedRecordKinds.AVAILABILITY || doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) && cangjieCandidateAvailabilitySelector(doc) != "") {
            result.availabilityHits += 1
        }
        completedDocs += 1
    }
    completedDocs
}

private func cangjieCandidateDocSectionCovered(doc: CangjieServingDocument): Bool {
    doc.sourceId.trimAscii() != "" || doc.title.trimAscii() != "" || doc.citation.trimAscii() != ""
}

private func cangjieCandidateNegativeRuleCovered(doc: CangjieServingDocument): Bool {
    doc.title.trimAscii() != "" || doc.text.trimAscii() != ""
}

private func cangjieCandidateAvailabilitySelector(doc: CangjieServingDocument): String {
    let symbol = doc.symbolKey.trimAscii()
    if (symbol != "") {
        return symbol
    }
    doc.title.trimAscii()
}

public func cangjiePromoteCandidateAfterValidation(kb: KnowledgeBase, store: FileKnowledgeStore, forceFailure!: Bool = false): CangjieCandidatePromotionResult {
    cangjiePromoteCandidateAfterValidationWithVersion(kb, store, cangjieLiveSyncCandidateVersion(), forceFailure: forceFailure)
}

public func cangjiePromoteCandidateAfterValidationWithVersion(kb: KnowledgeBase, store: FileKnowledgeStore, candidateVersion: String, forceFailure!: Bool = false, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), stageSink!: CkbStagedRebuildStageSink = NoopCkbStagedRebuildStageSink(), deadlineAtMillis!: Int64 = 0, budgetPlan!: CangjieCandidatePromotionBudgetPlan = CangjieCandidatePromotionBudgetPlan()): CangjieCandidatePromotionResult {
    let stagedCandidateVersion = kb.stageCandidateIndex(candidateVersion)
    cangjiePromoteStagedCandidateAfterValidation(kb, store, stagedCandidateVersion, forceFailure: forceFailure, progressSink: progressSink, stageSink: stageSink, deadlineAtMillis: deadlineAtMillis, budgetPlan: budgetPlan)
}

public func cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb: KnowledgeBase, store: FileKnowledgeStore, candidateVersion: String, records: ArrayList<NormalizedRecord>, forceFailure!: Bool = false, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), stageSink!: CkbStagedRebuildStageSink = NoopCkbStagedRebuildStageSink(), deadlineAtMillis!: Int64 = 0, budgetPlan!: CangjieCandidatePromotionBudgetPlan = CangjieCandidatePromotionBudgetPlan(), acquisitionContext!: CkbCandidateAcquisitionContext = CkbCandidateAcquisitionContext(), releaseBundle!: CkbReleaseCommitBundle = CkbReleaseCommitBundle(), repositoryEventIdentity!: String = "", snapshotFaultInjector!: CkbActiveSnapshotFaultInjector = NoopCkbActiveSnapshotFaultInjector()): CangjieCandidatePromotionResult {
    let stagedCandidateVersion = kb.stageCandidateRecords(candidateVersion, records)
    cangjiePromoteStagedCandidateAfterValidation(kb, store, stagedCandidateVersion, forceFailure: forceFailure, progressSink: progressSink, stageSink: stageSink, deadlineAtMillis: deadlineAtMillis, budgetPlan: budgetPlan, acquisitionContext: acquisitionContext, releaseBundle: releaseBundle, repositoryEventIdentity: repositoryEventIdentity, snapshotFaultInjector: snapshotFaultInjector)
}

private func cangjiePromoteStagedCandidateAfterValidation(kb: KnowledgeBase, store: FileKnowledgeStore, stagedCandidateVersion: String, forceFailure!: Bool = false, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), stageSink!: CkbStagedRebuildStageSink = NoopCkbStagedRebuildStageSink(), deadlineAtMillis!: Int64 = 0, budgetPlan!: CangjieCandidatePromotionBudgetPlan = CangjieCandidatePromotionBudgetPlan(), acquisitionContext!: CkbCandidateAcquisitionContext = CkbCandidateAcquisitionContext(), releaseBundle!: CkbReleaseCommitBundle = CkbReleaseCommitBundle(), repositoryEventIdentity!: String = "", snapshotFaultInjector!: CkbActiveSnapshotFaultInjector = NoopCkbActiveSnapshotFaultInjector()): CangjieCandidatePromotionResult {
    let result = CangjieCandidatePromotionResult()
    result.candidateVersion = stagedCandidateVersion
    let vectorDeadlineAtMillis = cangjieCandidateStageDeadline(budgetPlan, budgetPlan.vectorBudgetMillis, deadlineAtMillis)
    cangjieCandidateEmitStage(stageSink, "candidate_materialization_started", "running", vectorDeadlineAtMillis, "candidate=${stagedCandidateVersion}", candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
    try {
        kb.persistCandidateSnapshot(store, deadlineAtMillis: vectorDeadlineAtMillis)
        result.candidateWritten = true
    } catch (e: Exception) {
        result.validation.ok = false
        result.validation.status = if (e.message.startsWith("deadline_exceeded:")) { cangjieCandidateTimeoutStatus(budgetPlan, "candidate_materialization_deadline_exceeded") } else { "candidate_materialization_failed" }
        result.validation.candidateVersion = stagedCandidateVersion
        result.validation.diagnostics.add(utf8SafePrefix(redactSensitive(e.message), 240))
        cangjieCandidateEmitStage(stageSink, "candidate_materialization_finished", result.validation.status, vectorDeadlineAtMillis, "candidate=${stagedCandidateVersion}|diagnostic=${e.message}", candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    let materializationStats = kb.candidateMaterializationStats()
    if (materializationStats.checkpointDegraded) { result.validation.diagnostics.add("candidate_checkpoint_write_degraded") }
    cangjieCandidateEmitStage(stageSink, "candidate_materialization_finished", "ok", vectorDeadlineAtMillis, "candidate=${stagedCandidateVersion}", candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
    let candidateRecords = kb.candidateRecordSnapshot()
    if (forceFailure) {
        let validationDeadlineAtMillis = cangjieCandidateStageDeadline(budgetPlan, budgetPlan.validationBudgetMillis, deadlineAtMillis)
        result.validation = validateCandidateServingIndexWithVectorStatus(candidateRecords, stagedCandidateVersion, cangjieCandidateImplicitVectorStatus(candidateRecords), forceFailure: true, deadlineAtMillis: validationDeadlineAtMillis, validationScope: "candidate_promotion")
        cangjieCandidateEmitStage(stageSink, "candidate_validation_finished",
            result.validation.status, validationDeadlineAtMillis,
            "candidate=${stagedCandidateVersion}|ok=${result.validation.ok}|documents=${result.validation.servingDocumentCount}",
            itemCount: result.validation.servingDocumentCount,
            candidateKnowledgeVersion: stagedCandidateVersion,
            activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
        kb.markCandidateValidationFailed(stagedCandidateVersion)
        kb.persistCandidateSnapshot(store)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    if (cangjieCandidatePromotionDeadline(result, kb, store, stagedCandidateVersion, "candidate_vector_before", vectorDeadlineAtMillis, status: cangjieCandidateTimeoutStatus(budgetPlan, "candidate_vector_deadline_exceeded"))) {
        return result
    }
    let stagingCollection = cangjieCandidateStagingCollection(kb, stagedCandidateVersion, acquisitionContext)
    var collectionOwner = cangjieCandidateCollectionOwner(acquisitionContext, stagingCollection)
    // Unknown ownership must fail closed. Cleanup is enabled only after this
    // run durably owns the stable staging collection (legacy random staging
    // has no cross-run ownership contract and keeps the previous behavior).
    var cleanupRequired = !acquisitionContext.valid()
    var rollbackSnapshot = ActiveSnapshot()
    var rollbackFromStore = false
    var rollbackSourceAvailable = false
    var activeTransaction = CkbActiveSnapshotTransactionResult()
    try {
        if (acquisitionContext.valid()) {
            let ownerTempsRemoved = store.cleanupCandidateOwnerStaleTemps()
            if (ownerTempsRemoved > 0) { result.validation.diagnostics.add("candidate_owner_stale_temps_removed:count=${ownerTempsRemoved}") }
            let existingOwner = store.loadCandidateCollectionOwner(stagingCollection)
            if (existingOwner.status == "not_found") {
                collectionOwner = store.saveCandidateCollectionOwner(collectionOwner)
                cleanupRequired = true
            } else if (cangjieCandidateOwnerCanAdopt(existingOwner, collectionOwner)) {
                collectionOwner.state = "adopted"
                collectionOwner = store.saveCandidateCollectionOwner(collectionOwner)
                cleanupRequired = true
            } else {
                result.validation.ok = false
                result.validation.status = "candidate_staging_owner_conflict"
                result.validation.candidateVersion = stagedCandidateVersion
                result.validation.diagnostics.add("candidate_staging_owner_conflict:${ckbReleaseEvidenceHash(stagingCollection)}:${existingOwner.status}")
                result.activeVersion = kb.status().activeKnowledgeVersion
                return result
            }
        }
    let vectorStartedAtMillis = ckbCoreNowMillis()
    cangjieCandidateEmitStage(stageSink, "candidate_vector_started", "running", vectorDeadlineAtMillis, "candidate=${stagedCandidateVersion}|stagingCollection=${stagingCollection}|records=${candidateRecords.size}", itemCount: candidateRecords.size, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
    let vectorBuild = if (acquisitionContext.valid()) {
        kb.buildVectorIndexForRecordsDurable(candidateRecords, stagingCollection, store, acquisitionContext, progressSink: progressSink, deadlineAtMillis: vectorDeadlineAtMillis)
    } else {
        kb.buildVectorIndexForRecords(candidateRecords, stagingCollection, progressSink: progressSink, deadlineAtMillis: vectorDeadlineAtMillis)
    }
    var vectorStatus = cangjieCandidateVerifiedVectorStatus(kb, stagingCollection, candidateRecords.size, vectorBuild)
    cangjieCandidateEmitStage(stageSink, "candidate_vector_finished", if (vectorBuild.ok) { "ok" } else { "failed" }, vectorDeadlineAtMillis, "candidate=${stagedCandidateVersion}|stagingCollection=${stagingCollection}|vectorCount=${vectorBuild.vectorCount}|diagnostic=${vectorBuild.diagnostic}", durationMillis: ckbCoreNowMillis() - vectorStartedAtMillis, itemCount: vectorBuild.vectorCount, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
    if (!vectorBuild.ok) {
        result.validation = cangjieCandidateVectorFailureValidation(stagedCandidateVersion, vectorStatus)
        if (cangjieCandidateHasDeadlineDiagnostic(vectorBuild.diagnostic)) {
            result.validation.status = cangjieCandidateTimeoutStatus(budgetPlan, "candidate_vector_deadline_exceeded")
        }
        kb.markCandidateValidationFailed(stagedCandidateVersion)
        kb.persistCandidateSnapshot(store)
        cangjieCandidateEmitStage(stageSink, "candidate_validation_finished", result.validation.status, vectorDeadlineAtMillis, "candidate=${stagedCandidateVersion}|ok=false|vectorReason=${result.validation.vectorDegradedReason}", candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    let validationDeadlineAtMillis = cangjieCandidateStageDeadline(budgetPlan, budgetPlan.validationBudgetMillis, deadlineAtMillis)
    let validationStartedAtMillis = ckbCoreNowMillis()
    cangjieCandidateEmitStage(stageSink, "candidate_validation_started", "running", validationDeadlineAtMillis, "candidate=${stagedCandidateVersion}|records=${candidateRecords.size}", itemCount: candidateRecords.size, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
    result.validation = validateCandidateServingIndexWithVectorStatus(candidateRecords, stagedCandidateVersion, vectorStatus, forceFailure: false, deadlineAtMillis: validationDeadlineAtMillis, validationScope: "candidate_promotion")
    if (result.validation.status == "candidate_validation_timeout" && budgetPlan.segmented) {
        result.validation.status = "candidate_validation_deadline_exceeded"
    }
    cangjieCandidateEmitStage(stageSink, "candidate_validation_finished", result.validation.status, validationDeadlineAtMillis, "candidate=${stagedCandidateVersion}|ok=${result.validation.ok}|documents=${result.validation.servingDocumentCount}", durationMillis: ckbCoreNowMillis() - validationStartedAtMillis, itemCount: result.validation.servingDocumentCount, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
    if (!result.validation.ok) {
        kb.markCandidateValidationFailed(stagedCandidateVersion)
        kb.persistCandidateSnapshot(store)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    let activeCommitDeadlineAtMillis = cangjieCandidateStageDeadline(budgetPlan, budgetPlan.activeCommitBudgetMillis, deadlineAtMillis)
    if (cangjieCandidatePromotionDeadline(result, kb, store, stagedCandidateVersion, "candidate_active_commit_before", activeCommitDeadlineAtMillis, status: cangjieCandidateTimeoutStatus(budgetPlan, "candidate_active_commit_deadline_exceeded"))) {
        return result
    }
    let activeVersion = cangjieActiveVersionForCandidate(stagedCandidateVersion)
    let validatedServingSummary = cangjieValidatedServingIndexSummary(result.validation, candidateRecords)
    let rollbackPointer = store.loadActiveSnapshotPointer()
    rollbackFromStore = rollbackPointer.valid
    if (!rollbackFromStore) {
        rollbackSnapshot = kb.activeSnapshotForRollback()
    }
    rollbackSourceAvailable = rollbackFromStore || rollbackSnapshot.valid
    let activeCommitStartedAtMillis = ckbCoreNowMillis()
    cangjieCandidateEmitStage(stageSink, "candidate_active_commit_started", "running", activeCommitDeadlineAtMillis, "candidate=${stagedCandidateVersion}|active=${activeVersion}|stagingCollection=${stagingCollection}", itemCount: candidateRecords.size, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: activeVersion)
    try {
        result.activePromoted = kb.commitCandidateToActiveAfterVectorReady(activeVersion, stagingCollection,
            vectorStatus, deadlineAtMillis: activeCommitDeadlineAtMillis,
            validatedServingSummary: validatedServingSummary,
            releaseExistingGraph: rollbackSourceAvailable)
    } catch (e: Exception) {
        cangjieCandidatePromotionException(result, kb, store, stagedCandidateVersion, e.message, deadlineStatus: cangjieCandidateTimeoutStatus(budgetPlan, "candidate_active_commit_deadline_exceeded"))
        cangjieCandidateEmitStage(stageSink, "candidate_active_commit_finished", result.validation.status, activeCommitDeadlineAtMillis, "candidate=${stagedCandidateVersion}|active=${activeVersion}|diagnostic=${e.message}", durationMillis: ckbCoreNowMillis() - activeCommitStartedAtMillis, itemCount: candidateRecords.size, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: kb.status().activeKnowledgeVersion)
        _ = cangjieRestoreAndFinalizeCandidateFailure(kb, store,
            rollbackFromStore, rollbackSnapshot, stagedCandidateVersion,
            result.validation)
        result.ok = false
        result.activePromoted = false
        result.snapshotPointerCommitted = false
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    result.activeVersion = activeVersion
    cangjieCandidateEmitStage(stageSink, "candidate_active_commit_finished", if (result.activePromoted) { "ok" } else { "failed" }, activeCommitDeadlineAtMillis, "candidate=${stagedCandidateVersion}|active=${activeVersion}|promoted=${result.activePromoted}", durationMillis: ckbCoreNowMillis() - activeCommitStartedAtMillis, itemCount: candidateRecords.size, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: activeVersion)
    if (cangjieCandidatePromotionDeadline(result, kb, store, stagedCandidateVersion, "candidate_active_commit_after", activeCommitDeadlineAtMillis, status: cangjieCandidateTimeoutStatus(budgetPlan, "candidate_active_commit_deadline_exceeded"), persistFailure: false)) {
        _ = cangjieRestoreAndFinalizeCandidateFailure(kb, store,
            rollbackFromStore, rollbackSnapshot, stagedCandidateVersion,
            result.validation)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    if (result.activePromoted) {
        let snapshotDeadlineAtMillis = cangjieCandidateStageDeadline(budgetPlan, budgetPlan.snapshotBudgetMillis, deadlineAtMillis)
        if (cangjieCandidatePromotionDeadline(result, kb, store, stagedCandidateVersion, "candidate_active_snapshot_before", snapshotDeadlineAtMillis, status: cangjieCandidateTimeoutStatus(budgetPlan, "candidate_active_snapshot_deadline_exceeded"), persistFailure: false)) {
            _ = cangjieRestoreAndFinalizeCandidateFailure(kb, store,
                rollbackFromStore, rollbackSnapshot, stagedCandidateVersion,
                result.validation)
            result.activeVersion = kb.status().activeKnowledgeVersion
            return result
        }
        let activeSnapshotStartedAtMillis = ckbCoreNowMillis()
        cangjieCandidateEmitStage(stageSink, "candidate_active_snapshot_started", "running", snapshotDeadlineAtMillis, "candidate=${stagedCandidateVersion}|active=${activeVersion}|vectorCount=${vectorBuild.vectorCount}|spooled=${vectorBuild.spool.valid}", itemCount: vectorBuild.vectorCount, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: activeVersion)
        try {
            activeTransaction = kb.persistActiveSnapshotUsingVectorBuild(store, vectorBuild,
                persistVectorFile: cangjieCandidateShouldPersistVectorFile(vectorStatus),
                deadlineAtMillis: snapshotDeadlineAtMillis, stageSink: stageSink,
                releaseBundle: releaseBundle, repositoryEventIdentity: repositoryEventIdentity,
                faultInjector: snapshotFaultInjector)
            result.snapshotTxId = activeTransaction.txId
            result.snapshotPointerCommitted = activeTransaction.pointerCommitted
            result.snapshotLiveShadowConsistent = activeTransaction.liveShadowConsistent
            for (diagnostic in activeTransaction.diagnostics) {
                result.validation.diagnostics.add(diagnostic)
            }
        } catch (e: Exception) {
            result.activePromoted = false
            result.snapshotPointerCommitted = false
            result.snapshotLiveShadowConsistent = false
            result.validation.ok = false
            result.validation.status = if (e.message.startsWith("deadline_exceeded:")) { cangjieCandidateTimeoutStatus(budgetPlan, "candidate_active_snapshot_deadline_exceeded") } else { "candidate_active_snapshot_failed" }
            result.validation.diagnostics.add(if (e.message == "") { "candidate_active_snapshot_failed" } else { utf8SafePrefix(redactSensitive(e.message), 240) })
            cangjieCandidateEmitStage(stageSink, "candidate_active_snapshot_finished", result.validation.status, snapshotDeadlineAtMillis, "candidate=${stagedCandidateVersion}|active=${activeVersion}|diagnostic=${e.message}", durationMillis: ckbCoreNowMillis() - activeSnapshotStartedAtMillis, itemCount: vectorBuild.vectorRecords.size, candidateKnowledgeVersion: stagedCandidateVersion, activeKnowledgeVersion: if (rollbackPointer.valid) { rollbackPointer.activeVersion } else { kb.status().activeKnowledgeVersion })
            _ = cangjieRestoreAndFinalizeCandidateFailure(kb, store,
                rollbackFromStore, rollbackSnapshot, stagedCandidateVersion,
                result.validation)
            result.activeVersion = kb.status().activeKnowledgeVersion
            return result
        }
        if (!activeTransaction.pointerCommitted || !activeTransaction.businessCommitted) {
            result.validation.ok = false
            result.validation.status = "candidate_active_snapshot_failed"
            result.validation.diagnostics.add("candidate_active_snapshot_not_committed")
            result.activePromoted = false
            cangjieCandidateEmitStage(stageSink, "candidate_active_snapshot_finished", result.validation.status,
                snapshotDeadlineAtMillis, "candidate=${stagedCandidateVersion}|active=${activeVersion}|pointerCommitted=${activeTransaction.pointerCommitted}",
                durationMillis: ckbCoreNowMillis() - activeSnapshotStartedAtMillis,
                itemCount: vectorBuild.vectorCount,
                candidateKnowledgeVersion: stagedCandidateVersion,
                activeKnowledgeVersion: if (rollbackPointer.valid) {
                    rollbackPointer.activeVersion
                } else { kb.status().activeKnowledgeVersion })
            _ = cangjieRestoreAndFinalizeCandidateFailure(kb, store,
                rollbackFromStore, rollbackSnapshot, stagedCandidateVersion,
                result.validation)
            result.activeVersion = kb.status().activeKnowledgeVersion
            return result
        }
        // The v2 pointer is the irreversible business commit. Everything below
        // is repairable shadow/owner/spool work and must never roll back active.
        cleanupRequired = false
        if (!activeTransaction.liveShadowConsistent) {
            result.validation.diagnostics.add("candidate_active_live_shadow_degraded")
        }
        cangjieCandidateEmitStage(stageSink, "candidate_active_snapshot_finished",
            if (activeTransaction.liveShadowConsistent) { "ok" } else { "degraded" },
            snapshotDeadlineAtMillis,
            "candidate=${stagedCandidateVersion}|active=${activeVersion}|vectorCount=${vectorBuild.vectorCount}|spooled=${vectorBuild.spool.valid}|pointerCommitted=true|liveShadowConsistent=${activeTransaction.liveShadowConsistent}",
            durationMillis: ckbCoreNowMillis() - activeSnapshotStartedAtMillis,
            itemCount: vectorBuild.vectorCount,
            candidateKnowledgeVersion: stagedCandidateVersion,
            activeKnowledgeVersion: activeVersion)
        let postCommitDeadline = ckbDeadlineGuard("candidate_active_snapshot_after",
            snapshotDeadlineAtMillis)
        if (postCommitDeadline.exceeded) {
            result.validation.diagnostics.add("candidate_post_commit_degraded:${postCommitDeadline.diagnostic}")
        }
        if (collectionOwner.valid) {
            collectionOwner.state = "committed_active"
            try {
                _ = store.saveCandidateCollectionOwner(collectionOwner)
            } catch (e: Exception) {
                // The active snapshot is already authoritative. Owner metadata
                // degradation must not roll it back or make cleanup delete it.
                result.validation.diagnostics.add("candidate_owner_commit_degraded:${ckbReleaseEvidenceHash(stagingCollection)}:${utf8SafePrefix(redactSensitive(e.message), 120)}")
            }
        }
        // The pointer now protects the new collection. Retire older stable
        // owners immediately; cleanup is best effort and cannot reverse the
        // already committed business result.
        _ = ckbCleanupInactiveCandidateOwners(store,
            { collection: String => kb.deleteVectorCollection(collection) },
            result.validation.diagnostics)
        if (vectorBuild.spool.valid) {
            let cleaned = store.deleteS4ArtifactTree("metadata/vector-builds/${vectorBuild.spool.acquisitionId}")
            result.validation.diagnostics.add(if (cleaned) { "vector_spool_cleaned" } else { "vector_spool_cleanup_failed" })
        }
    }
    result.ok = result.activePromoted
    result
    } catch (e: Exception) {
        if (activeTransaction.pointerCommitted) {
            cleanupRequired = false
            result.ok = true
            result.activePromoted = true
            result.snapshotTxId = activeTransaction.txId
            result.snapshotPointerCommitted = true
            result.snapshotLiveShadowConsistent = activeTransaction.liveShadowConsistent
            result.activeVersion = activeTransaction.activeVersion
            result.validation.diagnostics.add("candidate_post_commit_degraded:${utf8SafePrefix(redactSensitive(if (e.message == "") { "unexpected_failure" } else { e.message }), 200)}")
            return result
        }
        result.ok = false
        result.activePromoted = false
        result.validation.ok = false
        result.validation.status = "candidate_promotion_unexpected_failure"
        result.validation.diagnostics.add(utf8SafePrefix(redactSensitive(if (e.message == "") { result.validation.status } else { e.message }), 240))
        if (rollbackSourceAvailable) {
            _ = cangjieRestoreAndFinalizeCandidateFailure(kb, store,
                rollbackFromStore, rollbackSnapshot, stagedCandidateVersion,
                result.validation)
        } else {
            try {
                kb.markCandidateValidationFailed(stagedCandidateVersion)
                kb.persistCandidateSnapshot(store)
            } catch (_: Exception) {
                result.validation.diagnostics.add("candidate_failure_persist_degraded")
            }
        }
        result.activeVersion = kb.status().activeKnowledgeVersion
        result
    } finally {
        if (cleanupRequired) {
            try { cangjieDeleteCandidateStaging(kb, store, stagingCollection, collectionOwner, result.validation) } catch (_: Exception) { result.validation.diagnostics.add("candidate_staging_cleanup_degraded:${ckbReleaseEvidenceHash(stagingCollection)}") }
        }
    }
}

private func cangjieRestoreCandidateRollback(kb: KnowledgeBase,
    store: FileKnowledgeStore, rollbackFromStore: Bool,
    fallback: ActiveSnapshot): Bool {
    if (rollbackFromStore) {
        let persisted = store.loadActiveSnapshot()
        return persisted.valid && kb.restoreActiveSnapshot(persisted)
    }
    fallback.valid && kb.restoreActiveSnapshot(fallback)
}

private func cangjieRestoreAndFinalizeCandidateFailure(kb: KnowledgeBase,
    store: FileKnowledgeStore, rollbackFromStore: Bool,
    fallback: ActiveSnapshot, stagedCandidateVersion: String,
    validation: CangjieCandidateValidationResult): Bool {
    if (!cangjieRestoreCandidateRollback(kb, store, rollbackFromStore,
        fallback)) {
        validation.diagnostics.add("candidate_rollback_failed")
        return false
    }
    kb.markCandidateValidationFailed(stagedCandidateVersion)
    try {
        // The rollback snapshot owns active state. Only the mutable candidate
        // lifecycle overlay is finalized after that active identity is restored.
        store.saveCandidateLifecycleMetadata(kb.status())
    } catch (_: Exception) {
        validation.diagnostics.add("candidate_failure_persist_degraded")
    }
    true
}

private func cangjieValidatedServingIndexSummary(validation: CangjieCandidateValidationResult,
    records: ArrayList<NormalizedRecord>): CkbValidatedServingIndexSummary {
    let summary = CkbValidatedServingIndexSummary()
    summary.valid = validation.ok && validation.status == "candidate_validation_passed" &&
        validation.coveragePass && validation.taskPackCoveragePass && validation.transportParityPass &&
        validation.performancePass && validation.vectorHealthPass && validation.servingDocumentCount > 0 &&
        ckbValidationEvidenceIsSha256(validation.evidenceHash)
    summary.validationStatus = validation.status
    summary.recordsEvidenceHash = ckbCandidateRecordsEvidenceHash(records)
    summary.activeVersion = validation.activeVersion
    summary.documentCount = validation.servingDocumentCount
    summary.servingDiagnostic = validation.servingIndexDiagnostic
    summary.validationEvidenceHash = validation.evidenceHash
    summary.evidenceHash = ckbValidatedServingIndexSummaryEvidenceHash(summary)
    summary
}

private func cangjieCandidateStageDeadline(plan: CangjieCandidatePromotionBudgetPlan, stageBudgetMillis: Int64, legacyDeadlineAtMillis: Int64): Int64 {
    if (!plan.segmented) {
        return legacyDeadlineAtMillis
    }
    ckbStageDeadlineAt(plan.deadlineClock.nowMillis(), plan.workerSoftDeadlineAtMillis, stageBudgetMillis)
}

private func cangjieCandidateTimeoutStatus(plan: CangjieCandidatePromotionBudgetPlan, segmentedStatus: String): String {
    if (plan.segmented) { segmentedStatus } else { "candidate_validation_timeout" }
}

private func cangjieCandidateHasDeadlineDiagnostic(diagnostic: String): Bool {
    diagnostic.contains("deadline_exceeded:") || diagnostic.contains("_deadline_exceeded")
}

private func cangjieCandidateEmitStage(stageSink: CkbStagedRebuildStageSink, stage: String, status: String, deadlineAtMillis: Int64, diagnostic: String, durationMillis!: Int64 = 0, itemCount!: Int64 = 0, candidateKnowledgeVersion!: String = "", activeKnowledgeVersion!: String = ""): Unit {
    let progress = CkbStagedRebuildStageProgress()
    progress.stage = stage
    progress.status = status
    progress.diagnostic = redactSensitive(diagnostic)
    progress.deadlineAtMillis = deadlineAtMillis
    progress.remainingMillis = ckbRemainingMillis(deadlineAtMillis)
    progress.atMillis = ckbCoreNowMillis()
    progress.durationMillis = durationMillis
    progress.itemCount = itemCount
    progress.candidateKnowledgeVersion = candidateKnowledgeVersion
    progress.activeKnowledgeVersion = activeKnowledgeVersion
    try {
        stageSink.onStagedRebuildStage(progress)
    } catch (_: Exception) {
        ()
    }
}

private func cangjieCandidatePromotionException(result: CangjieCandidatePromotionResult, kb: KnowledgeBase, store: FileKnowledgeStore, stagedCandidateVersion: String, message: String, deadlineStatus!: String = "candidate_validation_timeout"): Unit {
    result.activePromoted = false
    result.validation.ok = false
    result.validation.status = if (message.startsWith("deadline_exceeded:")) { deadlineStatus } else { "candidate_active_commit_failed" }
    result.validation.candidateVersion = stagedCandidateVersion
    result.validation.activeVersion = cangjieActiveVersionForCandidate(stagedCandidateVersion)
    result.validation.diagnostics.add(if (message == "") { result.validation.status } else { redactSensitive(message) })
    result.activeVersion = kb.status().activeKnowledgeVersion
}

private func cangjieCandidatePromotionDeadline(result: CangjieCandidatePromotionResult, kb: KnowledgeBase, store: FileKnowledgeStore, stagedCandidateVersion: String, stage: String, deadlineAtMillis: Int64, status!: String = "candidate_validation_timeout", persistFailure!: Bool = true): Bool {
    let deadline = ckbDeadlineGuard(stage, deadlineAtMillis)
    if (!deadline.exceeded) {
        return false
    }
    result.ok = false
    result.activePromoted = false
    result.validation.ok = false
    result.validation.status = status
    result.validation.candidateVersion = stagedCandidateVersion
    result.validation.activeVersion = cangjieActiveVersionForCandidate(stagedCandidateVersion)
    result.validation.diagnostics.add(deadline.diagnostic)
    if (persistFailure) {
        kb.markCandidateValidationFailed(stagedCandidateVersion)
        kb.persistCandidateSnapshot(store)
    }
    result.activeVersion = kb.status().activeKnowledgeVersion
    true
}

private func cangjieCandidateStagingCollection(kb: KnowledgeBase, candidateVersion: String, context: CkbCandidateAcquisitionContext): String {
    let status = kb.status()
    let activeCollection = status.storage.vectorActiveCollection.trimAscii()
    if (context.valid()) {
        let stable = ckbCandidateStableCollection(context)
        if (stable != activeCollection) { return stable }
        return ckbCandidateAlternateCollection(context)
    }
    let identity = "${candidateVersion}:${activeCollection}"
    "ckb_candidate_stage_${DateTime.now().toUnixTimeStamp().toMilliseconds()}_${stableSummaryHash(identity)}"
}

private func cangjieCandidateCollectionOwner(context: CkbCandidateAcquisitionContext, collection: String): CkbCandidateCollectionOwner {
    let owner = CkbCandidateCollectionOwner()
    owner.collection = collection
    owner.acquisitionId = context.acquisitionId
    owner.schedulerRunId = context.schedulerRunId
    owner.taskId = context.taskId
    owner.candidateVersion = context.candidateVersion
    owner.planHash = context.planHash
    owner.recordsEvidenceHash = context.recordsEvidenceHash
    owner.state = "planned"
    owner.valid = context.valid()
    owner
}

private func cangjieCandidateOwnerCanAdopt(existing: CkbCandidateCollectionOwner, expected: CkbCandidateCollectionOwner): Bool {
    existing.valid && expected.valid && existing.state != "committed_active" &&
        existing.collection == expected.collection && existing.acquisitionId == expected.acquisitionId &&
        existing.taskId == expected.taskId && existing.candidateVersion == expected.candidateVersion &&
        existing.planHash == expected.planHash && existing.recordsEvidenceHash == expected.recordsEvidenceHash
}

private func cangjieCandidateVerifiedVectorStatus(kb: KnowledgeBase, stagingCollection: String, expectedCount: Int64, vectorBuild: VectorIndexBuildResult): VectorStoreStatus {
    let status = kb.vectorCollectionStatus(stagingCollection)
    if (status.collection == "") {
        status.collection = stagingCollection
    }
    if (!vectorBuild.ok) {
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = if (vectorBuild.diagnostic != "") { vectorBuild.diagnostic } else { "candidate_vector_build_failed" }
        status.count = vectorBuild.vectorCount
        return status
    }
    if (status.state == EmbeddingProviderState.READY && status.count != expectedCount) {
        status.state = EmbeddingProviderState.DEGRADED
        status.degradedReason = "candidate_vector_count_mismatch:${status.count}:${expectedCount}:${stagingCollection}"
    }
    status
}

private func cangjieCandidateVectorFailureValidation(candidateVersion: String, vectorStatus: VectorStoreStatus): CangjieCandidateValidationResult {
    let result = CangjieCandidateValidationResult()
    result.candidateVersion = candidateVersion
    result.activeVersion = cangjieActiveVersionForCandidate(candidateVersion)
    result.status = "candidate_vector_failed"
    result.vectorState = vectorStatus.state
    result.vectorDimension = vectorStatus.dimension
    result.vectorDegradedReason = cangjieCandidateVectorDiagnostic(vectorStatus)
    result.vectorHealthPass = false
    result.diagnostics.add("candidate_vector_failed:${result.vectorDegradedReason}")
    result.diagnostics.add("vector_health_failed:${result.vectorDegradedReason}")
    result
}

private func cangjieCandidateShouldPersistVectorFile(status: VectorStoreStatus): Bool {
    status.backend != "qdrant"
}

private func cangjieDeleteCandidateStaging(kb: KnowledgeBase, store: FileKnowledgeStore, stagingCollection: String, expectedOwner: CkbCandidateCollectionOwner, validation: CangjieCandidateValidationResult): Unit {
    if (kb.status().storage.vectorActiveCollection == stagingCollection) {
        validation.diagnostics.add("candidate_staging_preserved_active:${stagingCollection}")
        return
    }
    if (expectedOwner.valid) {
        let activeAuthority = ckbLoadPersistedActiveCollectionAuthority(store)
        if (!activeAuthority.valid) {
            validation.diagnostics.add("candidate_staging_preserved_active_authority_unavailable:${ckbReleaseEvidenceHash(stagingCollection)}:${activeAuthority.status}")
            return
        }
        if (activeAuthority.metadataCollection == stagingCollection || activeAuthority.manifestCollection == stagingCollection) {
            validation.diagnostics.add("candidate_staging_preserved_persisted_active:${ckbReleaseEvidenceHash(stagingCollection)}")
            return
        }
        let persisted = store.loadCandidateCollectionOwner(stagingCollection)
        if (!ckbCandidateOwnerMatches(persisted, expectedOwner)) {
            validation.diagnostics.add("candidate_staging_preserved_owner_mismatch:${ckbReleaseEvidenceHash(stagingCollection)}")
            return
        }
    }
    let deleted = kb.deleteVectorCollection(stagingCollection)
    if (deleted.state == EmbeddingProviderState.READY) {
        validation.diagnostics.add("candidate_staging_deleted:${stagingCollection}")
        if (expectedOwner.valid) {
            expectedOwner.state = "cleaned"
            _ = store.saveCandidateCollectionOwner(expectedOwner)
            _ = store.deleteS4ArtifactTree("metadata/vector-builds/${expectedOwner.acquisitionId}")
        }
    } else if (deleted.degradedReason != "") {
        validation.diagnostics.add("candidate_staging_delete_failed:${deleted.degradedReason}")
    }
}

private func cangjieServingDocumentEvidenceHash(documents: ArrayList<CangjieServingDocument>): String {
    let digest = SHA256()
    for (doc in documents) {
        cangjieServingDigestField(digest, doc.documentId)
        cangjieServingDigestField(digest, doc.contentHash)
    }
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(cangjieServingHexNibble(byte / UInt8(16)))
        out.append(cangjieServingHexNibble(byte % UInt8(16)))
    }
    "hsha256:${out.toString()}"
}

private func cangjieServingDigestField(digest: SHA256, value: String): Unit {
    digest.write("${value.size}:".toArray())
    digest.write(value.toArray())
}

private func cangjieServingHexNibble(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }; if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }; if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}

private func cangjieCandidateRestMcpParityPass(index: CangjieServingIndex): Bool {
    if (index.documents.size == 0 || index.exactEntries.size == 0) {
        return false
    }
    let restPayloadHash = cangjieServingDocumentEvidenceHash(index.documents)
    let mcpPayloadHash = cangjieServingDocumentEvidenceHash(index.documents)
    restPayloadHash == mcpPayloadHash
}

private func cangjieCandidatePerformanceWithinThreshold(index: CangjieServingIndex): Bool {
    cangjieServingPerformanceProbe(index, cangjieCandidatePerformanceQueries(index), budget: 5, p95Threshold: 10000000).pass
}

public func cangjieServingPerformanceProbe(index: CangjieServingIndex, queries: ArrayList<String>, budget!: Int64 = 5, p95Threshold!: Int64 = 10000000): CangjieServingPerformanceProbe {
    let probe = CangjieServingPerformanceProbe()
    probe.queryCount = queries.size
    probe.threshold = p95Threshold
    if (index.documents.size == 0) {
        probe.diagnostics.add("serving_index_empty")
        return probe
    }
    if (queries.size == 0) {
        probe.diagnostics.add("query_set_empty")
        return probe
    }
    let costs = ArrayList<Int64>()
    let seed = StringBuilder()
    for (query in queries) {
        let request = CangjieServingSearchRequest()
        request.query = query
        request.budget = budget
        let serving = searchHybridServingIndex(index, request)
        let cost = index.documents.size + (if (serving.hits.size == 0) { 10 } else { serving.hits.size * 3 })
        cangjieServingProbeInsertCost(costs, cost)
        seed.append(query)
        seed.append("|")
        seed.append(serving.evidenceHash)
        seed.append("|")
    }
    probe.p95Cost = cangjieServingProbeP95(costs)
    probe.evidenceHash = stableSummaryHash(seed.toString())
    probe.pass = probe.p95Cost > 0 && probe.p95Cost <= p95Threshold
    if (!probe.pass) {
        probe.diagnostics.add("p95_cost_exceeded")
    }
    probe
}

private func cangjieCandidateImplicitVectorStatus(records: ArrayList<NormalizedRecord>): VectorStoreStatus {
    let status = VectorStoreStatus()
    status.backend = "local-file"
    status.collection = "candidate"
    status.activeCollection = "active"
    status.candidateCollection = "candidate"
    status.dimension = 16
    status.count = records.size
    status.state = if (records.size > 0) { EmbeddingProviderState.READY } else { EmbeddingProviderState.DEGRADED }
    status.degradedReason = if (records.size > 0) { "" } else { "empty_candidate_vectors" }
    status
}

private func cangjieCandidateVectorHealthPass(status: VectorStoreStatus): Bool {
    status.state == EmbeddingProviderState.READY && status.dimension > 0 && status.degradedReason == ""
}

private func cangjieCandidateVectorDiagnostic(status: VectorStoreStatus): String {
    if (status.degradedReason != "") {
        return status.degradedReason
    }
    if (status.state == "") {
        return "vector_state_missing"
    }
    if (status.dimension <= 0) {
        return "vector_dimension_missing"
    }
    status.state
}

private func cangjieCandidatePerformanceQueries(index: CangjieServingIndex): ArrayList<String> {
    let queries = ArrayList<String>()
    for (doc in index.documents) {
        if (queries.size >= 20) {
            break
        }
        if (doc.symbolKey != "") {
            queries.add(doc.symbolKey)
        } else if (doc.title != "") {
            queries.add(doc.title)
        }
    }
    queries
}

private func cangjieServingProbeInsertCost(costs: ArrayList<Int64>, cost: Int64): Unit {
    var inserted = false
    var i: Int64 = 0
    while (i < costs.size) {
        if (cost < costs[i]) {
            costs.add(cost, at: i)
            inserted = true
            break
        }
        i += 1
    }
    if (!inserted) {
        costs.add(cost)
    }
}

private func cangjieServingProbeP95(costs: ArrayList<Int64>): Int64 {
    if (costs.size == 0) {
        return 0
    }
    var index = (costs.size * 95) / 100
    if (index >= costs.size) {
        index = costs.size - 1
    }
    costs[index]
}

private func cangjieCandidateToolSelector(doc: CangjieServingDocument): String {
    let text = "${doc.symbolKey} ${doc.title} ${doc.text}".trimAscii()
    for (token in text.split(" ")) {
        let clean = token.trimAscii().replace("`", "").replace(":", "")
        if (clean != "" && !clean.contains("=")) {
            return clean
        }
    }
    "tool"
}

private func cangjieCandidateToolCommandSelector(doc: CangjieServingDocument): String {
    let text = "${doc.symbolKey} ${doc.title} ${doc.text}".trimAscii()
    let parts = text.split(" ")
    if (parts.size > 1) {
        return parts[1].trimAscii().replace("`", "").replace(":", "")
    }
    ""
}

public func renderCangjieCandidateValidationSummary(validation: CangjieCandidateValidationResult): String {
    "candidateValidation status=${validation.status} ok=${validation.ok} candidateVersion=${validation.candidateVersion} activeVersion=${validation.activeVersion} documents=${validation.servingDocumentCount} exactSymbolHits=${validation.exactSymbolHits} docSectionHits=${validation.docSectionHits} toolManualHits=${validation.toolManualHits} negativeRuleHits=${validation.negativeRuleHits} moduleHits=${validation.moduleHits} availabilityHits=${validation.availabilityHits} coveragePass=${validation.coveragePass} taskPackCoveragePass=${validation.taskPackCoveragePass} transportParityPass=${validation.transportParityPass} vectorHealthPass=${validation.vectorHealthPass} vectorState=${validation.vectorState} vectorDimension=${validation.vectorDimension} vectorDegradedReason=${validation.vectorDegradedReason} performancePass=${validation.performancePass} performanceP95Cost=${validation.performanceP95Cost} legacyVersionGapCount=${validation.legacyVersionGapCount} evidenceHash=${validation.evidenceHash} diagnostics=${cangjieCandidateDiagnostics(validation.diagnostics)}"
}

private func cangjieCandidateDiagnostics(values: ArrayList<String>): String {
    if (values.size == 0) {
        return "none"
    }
    var out = ""
    for (value in values) {
        if (out != "") {
            out += ","
        }
        out += value
    }
    out
}

public func runCangjieUpdatePromotionSmoke(args: Array<String>): Int64 {
    let config = CkbRuntimeConfig()
    config.networkEnabled = true
    config.websiteEnabled = true
    config.docsEnabled = true
    let successKb = newOfflineKnowledgeBase()
    let successOptions = LiveSyncOptions()
    successOptions.apply = true
    successOptions.maxItems = 3
    let successText = ckbSyncLive(successKb, config, successOptions, runner: FakeSourceFetchRunner(), store: FileKnowledgeStore("target/ckb-p6-smoke-success"))
    let successStatus = successKb.status()

    let failedKb = newOfflineKnowledgeBase()
    let before = failedKb.status().activeKnowledgeVersion
    let failedOptions = LiveSyncOptions()
    failedOptions.apply = true
    failedOptions.maxItems = 3
    failedOptions.simulateValidationFailure = true
    let failedText = ckbSyncLive(failedKb, config, failedOptions, runner: FakeSourceFetchRunner(), store: FileKnowledgeStore("target/ckb-p6-smoke-failed"))
    let failedStatus = failedKb.status()

    let curationInputs = ArrayList<CangjieBenchmarkGapInput>()
    let curation = CangjieBenchmarkGapInput()
    curation.caseId = "CJ-HUMANEVAL-000"
    curation.taskText = "Use ArrayList to collect values."
    curation.visibleTestExcerpt = "assert solve([1,2]) == 3"
    curation.compilerOutput = "ArrayList import required"
    curation.missingKnowledge = "ArrayList.add"
    curation.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    curationInputs.add(curation)
    let rejected = CangjieBenchmarkGapInput()
    rejected.caseId = "CJ-HUMANEVAL-001"
    rejected.taskText = "reference/solution leaked"
    rejected.officialCitation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
    curationInputs.add(rejected)
    let curationResult = curateBenchmarkGapRecords(curationInputs)

    let freshness = cangjieCorpusFreshnessReport(successStatus)
    let ok = successText.contains("activePromoted=true") &&
        successText.contains("candidate_validation_passed") &&
        successStatus.activeKnowledgeVersion.endsWith("-active") &&
        failedText.contains("activePromoted=false") &&
        failedStatus.activeKnowledgeVersion == before &&
        failedStatus.failedCandidateVersion.contains("candidate") &&
        freshness.sources.size >= 5 &&
        curationResult.accepted == 1 &&
        curationResult.rejected == 1

    println("update-promotion-smoke ok=${ok}")
    println("successActive=${successStatus.activeKnowledgeVersion} successCandidate=${successStatus.candidateKnowledgeVersion}")
    println("failedActive=${failedStatus.activeKnowledgeVersion} failedCandidate=${failedStatus.candidateKnowledgeVersion} failedVersion=${failedStatus.failedCandidateVersion}")
    println("freshnessSources=${freshness.sources.size} freshnessOk=${freshness.ok}")
    println("curationAccepted=${curationResult.accepted} curationRejected=${curationResult.rejected} curationDiagnostic=${curationResult.diagnostic}")
    if (ok) { 0 } else { 1 }
}
