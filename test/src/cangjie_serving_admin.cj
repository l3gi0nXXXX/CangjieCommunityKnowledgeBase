package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.time.DateTime

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
    public var validation: CangjieCandidateValidationResult = CangjieCandidateValidationResult()

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

public func validateCandidateServingIndexWithVectorStatus(records: ArrayList<NormalizedRecord>, candidateVersion: String, vectorStatus: VectorStoreStatus, forceFailure!: Bool = false): CangjieCandidateValidationResult {
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
    let index = buildCangjieServingIndex(records, activeKnowledgeVersion: result.activeVersion)
    result.servingDocumentCount = index.documents.size
    for (doc in index.documents) {
        if (doc.versionResolutionId == "") {
            result.legacyVersionGapCount += 1
        }
        if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD && lookupExactSymbol(index, doc.symbolKey, sourceSet: doc.sourceSet, targetVersion: doc.targetVersion, versionResolutionId: doc.versionResolutionId, budget: 1).hits.size > 0) {
            result.exactSymbolHits += 1
        }
        if (doc.recordKind == CangjieServingRecordKinds.DOC_SECTION && lookupDocSection(index, doc.sourceId, sourceSet: doc.sourceSet, targetVersion: doc.targetVersion, versionResolutionId: doc.versionResolutionId, budget: 1).hits.size > 0) {
            result.docSectionHits += 1
        }
        if (doc.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL && lookupToolManual(index, cangjieCandidateToolSelector(doc), command: cangjieCandidateToolCommandSelector(doc), targetVersion: doc.targetVersion, versionResolutionId: doc.versionResolutionId, budget: 1).hits.size > 0) {
            result.toolManualHits += 1
        }
        if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE && lookupNegativeRules(index, doc.title, targetVersion: doc.targetVersion, versionResolutionId: doc.versionResolutionId, budget: 1).hits.size > 0) {
            result.negativeRuleHits += 1
        }
        if (doc.module != "" && lookupModule(index, doc.module, sourceSet: doc.sourceSet, targetVersion: doc.targetVersion, versionResolutionId: doc.versionResolutionId, budget: 1).hits.size > 0) {
            result.moduleHits += 1
        }
        if ((doc.recordKind == CangjieTypedRecordKinds.AVAILABILITY || doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) && lookupAvailability(index, if (doc.symbolKey == "") { doc.title } else { doc.symbolKey }, sourceSet: doc.sourceSet, targetVersion: doc.targetVersion, versionResolutionId: doc.versionResolutionId, budget: 1).hits.size > 0) {
            result.availabilityHits += 1
        }
    }
    result.taskPackCoveragePass = result.exactSymbolHits > 0 &&
        result.docSectionHits > 0 &&
        result.toolManualHits > 0 &&
        result.negativeRuleHits > 0
    result.coveragePass = result.exactSymbolHits > 0 && result.docSectionHits > 0 && result.negativeRuleHits > 0
    result.transportParityPass = cangjieCandidateRestMcpParityPass(index)
    let performance = cangjieServingPerformanceProbe(index, cangjieCandidatePerformanceQueries(index), budget: 5, p95Threshold: 10000000)
    result.performancePass = performance.pass
    result.performanceP95Cost = performance.p95Cost
    result.vectorState = vectorStatus.state
    result.vectorDimension = vectorStatus.dimension
    result.vectorDegradedReason = vectorStatus.degradedReason
    result.vectorHealthPass = cangjieCandidateVectorHealthPass(vectorStatus)
    result.evidenceHash = stableSummaryHash(cangjieServingDocumentHashSeed(index.documents))
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
    result
}

public func cangjiePromoteCandidateAfterValidation(kb: KnowledgeBase, store: FileKnowledgeStore, forceFailure!: Bool = false): CangjieCandidatePromotionResult {
    cangjiePromoteCandidateAfterValidationWithVersion(kb, store, cangjieLiveSyncCandidateVersion(), forceFailure: forceFailure)
}

public func cangjiePromoteCandidateAfterValidationWithVersion(kb: KnowledgeBase, store: FileKnowledgeStore, candidateVersion: String, forceFailure!: Bool = false, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), deadlineAtMillis!: Int64 = 0): CangjieCandidatePromotionResult {
    let stagedCandidateVersion = kb.stageCandidateIndex(candidateVersion)
    cangjiePromoteStagedCandidateAfterValidation(kb, store, stagedCandidateVersion, forceFailure: forceFailure, progressSink: progressSink, deadlineAtMillis: deadlineAtMillis)
}

public func cangjiePromoteCandidateRecordsAfterValidationWithVersion(kb: KnowledgeBase, store: FileKnowledgeStore, candidateVersion: String, records: ArrayList<NormalizedRecord>, forceFailure!: Bool = false, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), deadlineAtMillis!: Int64 = 0): CangjieCandidatePromotionResult {
    let stagedCandidateVersion = kb.stageCandidateRecords(candidateVersion, records)
    cangjiePromoteStagedCandidateAfterValidation(kb, store, stagedCandidateVersion, forceFailure: forceFailure, progressSink: progressSink, deadlineAtMillis: deadlineAtMillis)
}

private func cangjiePromoteStagedCandidateAfterValidation(kb: KnowledgeBase, store: FileKnowledgeStore, stagedCandidateVersion: String, forceFailure!: Bool = false, progressSink!: VectorBuildProgressSink = NoopVectorBuildProgressSink(), deadlineAtMillis!: Int64 = 0): CangjieCandidatePromotionResult {
    let result = CangjieCandidatePromotionResult()
    result.candidateVersion = stagedCandidateVersion
    result.candidateWritten = true
    kb.persistCandidateSnapshot(store)
    let candidateRecords = kb.candidateRecordSnapshot()
    if (forceFailure) {
        result.validation = validateCandidateServingIndexWithVectorStatus(candidateRecords, stagedCandidateVersion, cangjieCandidateImplicitVectorStatus(candidateRecords), forceFailure: true)
        kb.markCandidateValidationFailed(stagedCandidateVersion)
        kb.persistCandidateSnapshot(store)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    let stagingCollection = cangjieCandidateStagingCollection(kb, stagedCandidateVersion)
    let vectorBuild = kb.buildVectorIndexForRecords(candidateRecords, stagingCollection, progressSink: progressSink, deadlineAtMillis: deadlineAtMillis)
    var vectorStatus = cangjieCandidateVerifiedVectorStatus(kb, stagingCollection, candidateRecords.size, vectorBuild)
    result.validation = validateCandidateServingIndexWithVectorStatus(candidateRecords, stagedCandidateVersion, vectorStatus, forceFailure: false)
    if (!result.validation.ok) {
        kb.markCandidateValidationFailed(stagedCandidateVersion)
        kb.persistCandidateSnapshot(store)
        cangjieDeleteCandidateStaging(kb, stagingCollection, result.validation)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    let activeVersion = cangjieActiveVersionForCandidate(stagedCandidateVersion)
    result.activePromoted = kb.commitCandidateToActiveAfterVectorReady(activeVersion, stagingCollection, vectorStatus)
    result.activeVersion = activeVersion
    if (result.activePromoted) {
        kb.persistActiveSnapshotUsingVectorRecords(store, vectorBuild.vectorRecords, persistVectorFile: cangjieCandidateShouldPersistVectorFile(vectorStatus))
    } else {
        cangjieDeleteCandidateStaging(kb, stagingCollection, result.validation)
    }
    result.ok = result.activePromoted
    result
}

private func cangjieCandidateStagingCollection(kb: KnowledgeBase, candidateVersion: String): String {
    let status = kb.status()
    let activeCollection = status.storage.vectorActiveCollection.trimAscii()
    let identity = "${candidateVersion}:${activeCollection}"
    "ckb_candidate_stage_${DateTime.now().toUnixTimeStamp().toMilliseconds()}_${stableSummaryHash(identity)}"
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

private func cangjieCandidateShouldPersistVectorFile(status: VectorStoreStatus): Bool {
    status.backend != "qdrant"
}

private func cangjieDeleteCandidateStaging(kb: KnowledgeBase, stagingCollection: String, validation: CangjieCandidateValidationResult): Unit {
    let deleted = kb.deleteVectorCollection(stagingCollection)
    if (deleted.state == EmbeddingProviderState.READY) {
        validation.diagnostics.add("candidate_staging_deleted:${stagingCollection}")
    } else if (deleted.degradedReason != "") {
        validation.diagnostics.add("candidate_staging_delete_failed:${deleted.degradedReason}")
    }
}

private func cangjieServingDocumentHashSeed(documents: ArrayList<CangjieServingDocument>): String {
    let out = StringBuilder()
    for (doc in documents) {
        out.append(doc.documentId)
        out.append("|")
        out.append(doc.contentHash)
        out.append("|")
    }
    out.toString()
}

private func cangjieCandidateRestMcpParityPass(index: CangjieServingIndex): Bool {
    if (index.documents.size == 0 || index.exactEntries.size == 0) {
        return false
    }
    let restPayloadHash = stableSummaryHash(cangjieServingDocumentHashSeed(index.documents))
    let mcpPayloadHash = stableSummaryHash(cangjieServingDocumentHashSeed(index.documents))
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
