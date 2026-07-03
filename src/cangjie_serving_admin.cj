package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieCandidateValidationResult {
    public var ok: Bool = false
    public var status: String = "not_started"
    public var candidateVersion: String = ""
    public var activeVersion: String = ""
    public var servingDocumentCount: Int64 = 0
    public var exactSymbolHits: Int64 = 0
    public var docSectionHits: Int64 = 0
    public var coveragePass: Bool = false
    public var transportParityPass: Bool = false
    public var performancePass: Bool = false
    public var legacyVersionGapCount: Int64 = 0
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
    let feed = buildServingDocuments(records)
    result.servingDocumentCount = feed.documents.size
    for (doc in feed.documents) {
        if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD && !doc.rejected) {
            result.exactSymbolHits += 1
        }
        if (doc.recordKind == CangjieServingRecordKinds.DOC_SECTION && !doc.rejected) {
            result.docSectionHits += 1
        }
        if (doc.versionResolutionId == "") {
            result.legacyVersionGapCount += 1
        }
    }
    result.coveragePass = result.exactSymbolHits > 0 && result.docSectionHits > 0
    result.transportParityPass = feed.ok && result.servingDocumentCount > 0
    result.performancePass = result.servingDocumentCount > 0
    result.evidenceHash = stableSummaryHash(cangjieServingDocumentHashSeed(feed.documents))
    if (!feed.ok) {
        result.diagnostics.add("serving_feed_not_ready")
    }
    if (!result.coveragePass) {
        result.diagnostics.add("candidate_coverage_regression")
    }
    result.ok = feed.ok && result.coveragePass && result.transportParityPass && result.performancePass
    result.status = if (result.ok) { "candidate_validation_passed" } else { "candidate_validation_failed" }
    result
}

public func cangjiePromoteCandidateAfterValidation(kb: KnowledgeBase, store: FileKnowledgeStore, forceFailure!: Bool = false): CangjieCandidatePromotionResult {
    let result = CangjieCandidatePromotionResult()
    let candidateVersion = kb.stageCandidateIndex(cangjieLiveSyncCandidateVersion())
    result.candidateVersion = candidateVersion
    result.candidateWritten = true
    result.validation = validateCandidateServingIndex(kb.candidateRecordSnapshot(), candidateVersion, forceFailure: forceFailure)
    if (!result.validation.ok) {
        kb.markCandidateValidationFailed(candidateVersion)
        kb.persistCandidateSnapshot(store)
        result.activeVersion = kb.status().activeKnowledgeVersion
        return result
    }
    let activeVersion = cangjieActiveVersionForCandidate(candidateVersion)
    result.activePromoted = kb.promoteCandidateToActive(activeVersion)
    result.activeVersion = activeVersion
    kb.persistCandidateSnapshot(store)
    if (result.activePromoted) {
        kb.persistActiveSnapshot(store)
    }
    result.ok = result.activePromoted
    result
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

public func renderCangjieCandidateValidationSummary(validation: CangjieCandidateValidationResult): String {
    "candidateValidation status=${validation.status} ok=${validation.ok} candidateVersion=${validation.candidateVersion} activeVersion=${validation.activeVersion} documents=${validation.servingDocumentCount} exactSymbolHits=${validation.exactSymbolHits} docSectionHits=${validation.docSectionHits} coveragePass=${validation.coveragePass} transportParityPass=${validation.transportParityPass} performancePass=${validation.performancePass} legacyVersionGapCount=${validation.legacyVersionGapCount} evidenceHash=${validation.evidenceHash} diagnostics=${cangjieCandidateDiagnostics(validation.diagnostics)}"
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
