package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap, HashSet}
import std.fs.{Directory, Path, canonicalize, exists}
import std.sort.*

public class CkbStudentCleanRecordProjection {
    public var ok: Bool = true
    public var records: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var inputCount: Int64 = 0
    public var keptCount: Int64 = 0
    public var removedCount: Int64 = 0
    public var rejectionCounts: HashMap<String, Int64> = HashMap<String, Int64>()
    public var inputChecksum: String = ""
    public var outputChecksum: String = ""
    public var evidenceHash: String = ""
    public var errorCode: String = ""

    public init() {}
}

public class CkbStudentCleanRawProjection {
    public var ok: Bool = true
    public var records: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public var inputCount: Int64 = 0
    public var keptCount: Int64 = 0
    public var removedCount: Int64 = 0
    public var rejectionCounts: HashMap<String, Int64> = HashMap<String, Int64>()
    public var inputChecksum: String = ""
    public var outputChecksum: String = ""
    public var evidenceHash: String = ""
    public var errorCode: String = ""

    public init() {}
}

public class CkbCleanCandidateBaseDiagnostic {
    public var ok: Bool = false
    public var code: String = "contaminated_base_forbidden"
    public var evidenceHash: String = ""
    public init() {}
}

public class CkbCleanCandidateConsistencyDiagnostic {
    public var ok: Bool = false
    public var code: String = "clean_candidate_consistency_not_checked"
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var activeCount: Int64 = 0
    public var candidateChecksum: String = ""
    public var evidenceHash: String = ""
    public init() {}
}

public class CkbCompleteCleanStudentCandidate {
    public var ok: Bool = false
    public var diagnostic: String = "clean_candidate_not_built"
    public var version: String = ""
    public var rawRecords: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public var normalizedRecords: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var activeRecords: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var historicalNormalizedRemoved: Int64 = 0
    public var historicalActiveRemoved: Int64 = 0
    public var historicalRawRemoved: Int64 = 0
    public var candidateChecksum: String = ""
    public var authorityHash: String = ""
    public var auditJson: String = ""
    public var auditEvidenceHash: String = ""
    public var evidenceHash: String = ""
    public var manifestJson: String = ""
    public init() {}
}

public class CkbCleanCandidateBuildOptions {
    public var sourceStore: String = ""
    public var stagingStore: String = ""
    public var authorityStore: String = ""
    public var atomsStore: String = ""
    public var version: String = ""
    public var apply: Bool = false
    public var json: Bool = false
    public init() {}
}

public class CkbCleanCandidateBuildResult {
    public var ok: Bool = false
    public var diagnostic: String = "clean_candidate_build_not_run"
    public var applied: Bool = false
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var activeCount: Int64 = 0
    public var removedCount: Int64 = 0
    public var candidateChecksum: String = ""
    public var candidateEvidenceHash: String = ""
    public var manifestEvidenceHash: String = ""
    public var immutableManifestHash: String = ""
    public var authorityHash: String = ""
    public var auditEvidenceHash: String = ""
    public var cleanManifestHash: String = ""
    public var summaryJson: String = ""
    public init() {}
}

public class CkbStudentLeakageFinding {
    public var recordHash: String = ""
    public var layer: String = ""
    public var code: String = ""
    public var field: String = ""
    public init() {}
}

public class CkbStudentLeakageScanInput {
    public var rawRecords: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public var normalizedRecords: ArrayList<NormalizedRecord> =
        ArrayList<NormalizedRecord>()
    public var servingDocuments: ArrayList<CangjieServingDocument> =
        ArrayList<CangjieServingDocument>()
    public var indexRecords: ArrayList<NormalizedRecord> =
        ArrayList<NormalizedRecord>()
    public var indexDocuments: ArrayList<CangjieServingDocument> =
        ArrayList<CangjieServingDocument>()
    public var exactEntries: ArrayList<CangjieServingExactEntry> =
        ArrayList<CangjieServingExactEntry>()
    public var taskPacks: ArrayList<CangjieTaskKnowledgePack> =
        ArrayList<CangjieTaskKnowledgePack>()
    public var authorityHash: String = ""
    public var candidateChecksum: String = ""
    public init() {}
}

public class CkbStudentLeakageReport {
    public var ok: Bool = true
    public var recordCount: Int64 = 0
    public var scannedRecords: Int64 = 0
    public var scannedFields: Int64 = 0
    public var rawRecordCount: Int64 = 0
    public var normalizedRecordCount: Int64 = 0
    public var servingDocumentCount: Int64 = 0
    public var indexRecordCount: Int64 = 0
    public var indexDocumentCount: Int64 = 0
    public var exactEntryCount: Int64 = 0
    public var taskPackCount: Int64 = 0
    public var leakageCount: Int64 = 0
    public var authorityHash: String = ""
    public var candidateChecksum: String = ""
    public var findings: ArrayList<CkbStudentLeakageFinding> = ArrayList<CkbStudentLeakageFinding>()
    public var json: String = ""
    public var evidenceHash: String = ""
    public init() {}
}

public class CkbAnonymousAtomQueryReport {
    public var ok: Bool = false
    public var indexBuildCount: Int64 = 0
    public var atomCount: Int64 = 0
    public var passed: Int64 = 0
    public var failed: Int64 = 0
    public var jsonl: String = ""
    public var evidenceHash: String = ""
    public init() {}
}

public class CkbStudentServingLeakageReport {
    public var ok: Bool = false
    public var diagnostic: String = "student_serving_leakage_not_run"
    public var probeCount: Int64 = 0
    public var failed: Int64 = 0
    public var restJson: String = ""
    public var mcpStdioJson: String = ""
    public var mcpHttpJson: String = ""
    public var summaryJson: String = ""
    public var evidenceHash: String = ""
    public init() {}
}

public class CkbStudentServingProbe {
    public var probeId: String = ""
    public var query: String = ""
    public var expectedBlocked: Bool = false
    public init() {}
}

public class CkbBenchmarkLeakageAuthorityLoadResult {
    public var ok: Bool = true
    public var diagnostic: String = "ok"
    public var authority: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()
    public var authorityRecordCount: Int64 = 0
    public var authorityHash: String = ""
    public init() {}
}

private class CkbCleanQueryBuildObserver <: CangjieServingIndexBuildObserver {
    public var count: Int64 = 0
    public func onServingIndexBuild(_recordCount: Int64): Unit { this.count += 1 }
}

// A clean rebuild must start from a new, empty staging store. Existing active
// state and named production/final certification roots are never accepted as a
// merge base.
public func ckbCleanCandidateBaseDiagnostic(store: FileKnowledgeStore,
    protectedRoots!: ArrayList<String> = ArrayList<String>()): CkbCleanCandidateBaseDiagnostic {
    let result = CkbCleanCandidateBaseDiagnostic()
    let pathHash = benchmarkGapSha256(store.root.toString())
    let lower = store.root.toString().toAsciiLower()
    if (lower.contains("ckb-data") || lower.contains("production") || lower.contains("final11")) {
        result.code = "contaminated_base_forbidden"
        result.evidenceHash = benchmarkGapSha256("protected:${pathHash}")
        return result
    }
    let stagingPath = ckbCleanCanonicalOutputPath(store.root)
    if (stagingPath[0] != "ok") {
        result.code = stagingPath[0]
        result.evidenceHash = benchmarkGapSha256("${result.code}:${pathHash}")
        return result
    }
    let canonicalLower = stagingPath[1].toAsciiLower()
    if (canonicalLower.contains("ckb-data") || canonicalLower.contains("production") ||
        canonicalLower.contains("final11")) {
        result.code = "contaminated_base_forbidden"
        result.evidenceHash = benchmarkGapSha256("${result.code}:${pathHash}")
        return result
    }
    for (protectedRoot in protectedRoots) {
        let protectedPath = ckbCleanCanonicalExistingPath(protectedRoot)
        if (protectedPath[0] != "ok") {
            result.code = "clean_candidate_protected_root_invalid"
            result.evidenceHash = benchmarkGapSha256("${result.code}:${benchmarkGapSha256(protectedRoot)}")
            return result
        }
        if (stagingPath[1] == protectedPath[1] ||
            stagingPath[1].startsWith(protectedPath[1] + "/")) {
            result.code = "contaminated_base_forbidden"
            result.evidenceHash = benchmarkGapSha256("${result.code}:${pathHash}")
            return result
        }
    }
    if (exists(store.root)) {
        try {
            for (_ in Directory.readFrom(store.root)) {
                result.evidenceHash = benchmarkGapSha256("nonempty:${pathHash}")
                return result
            }
        } catch (_: Exception) {
            result.evidenceHash = benchmarkGapSha256("unreadable:${pathHash}")
            return result
        }
    }
    result.ok = true; result.code = "clean_candidate_base_allowed"
    result.evidenceHash = benchmarkGapSha256("empty:${pathHash}")
    result
}

public func ckbLoadBenchmarkLeakageAuthority(store: FileKnowledgeStore): CkbBenchmarkLeakageAuthorityLoadResult {
    let result = CkbBenchmarkLeakageAuthorityLoadResult()
    let loaded = loadVersionedEvalSupportAuthority(store)
    if (!loaded.ok) {
        if (loaded.diagnostic == "eval_support_authority_not_found") { return result }
        result.ok = false; result.diagnostic = loaded.diagnostic; return result
    }
    let records = ArrayList<NormalizedRecord>()
    for (typed in loaded.records) { records.add(cangjieTypedRecordToNormalized(typed, KnowledgeMetadata())) }
    result.authority = buildCangjieBenchmarkLeakageAuthority(records)
    result.authorityRecordCount = loaded.snapshot.recordCount
    result.authorityHash = loaded.snapshot.authorityHash
    result
}

public func ckbBuildStudentLeakageReport(records: ArrayList<NormalizedRecord>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentLeakageReport {
    let input = CkbStudentLeakageScanInput()
    input.normalizedRecords = records
    input.candidateChecksum = ckbCertifiedNormalizedRecordsChecksum(records)
    ckbBuildStudentLeakageReportFromLayers(input, authority: authority)
}

public func ckbBuildStudentLeakageReportFromLayers(input: CkbStudentLeakageScanInput,
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CkbStudentLeakageReport {
    let report = CkbStudentLeakageReport()
    report.rawRecordCount = input.rawRecords.size
    report.normalizedRecordCount = input.normalizedRecords.size
    report.servingDocumentCount = input.servingDocuments.size
    report.indexRecordCount = input.indexRecords.size
    report.indexDocumentCount = input.indexDocuments.size
    report.exactEntryCount = input.exactEntries.size
    report.taskPackCount = input.taskPacks.size
    report.recordCount = input.normalizedRecords.size
    report.scannedRecords = report.rawRecordCount + report.normalizedRecordCount +
        report.servingDocumentCount + report.indexRecordCount +
        report.indexDocumentCount + report.exactEntryCount + report.taskPackCount
    report.authorityHash = input.authorityHash
    report.candidateChecksum = if (input.candidateChecksum == "") {
        ckbCertifiedNormalizedRecordsChecksum(input.normalizedRecords)
    } else { input.candidateChecksum }
    for (record in input.rawRecords) {
        ckbCollectLeakageDiagnostics(report, "raw",
            ckbCleanRawEvidence(record),
            collectCangjieStudentRecordDiagnostics(
                ckbStudentRawAsNormalized(record), authority: authority))
    }
    for (record in input.normalizedRecords) {
        let recordHash = ckbCleanNormalizedEvidence(record)
        ckbCollectLeakageDiagnostics(report, "normalized", recordHash,
            collectCangjieStudentRecordDiagnostics(record, authority: authority))
    }
    for (document in input.servingDocuments) {
        ckbCollectLeakageDiagnostics(report, "serving",
            benchmarkGapSha256("${document.documentId}|${document.contentHash}"),
            collectCangjieStudentServingDocumentDiagnostics(document,
                authority: authority))
    }
    for (record in input.indexRecords) {
        ckbCollectLeakageDiagnostics(report, "index",
            ckbCleanNormalizedEvidence(record),
            collectCangjieStudentRecordDiagnostics(record, authority: authority))
    }
    for (document in input.indexDocuments) {
        ckbCollectLeakageDiagnostics(report, "index-document",
            benchmarkGapSha256("${document.documentId}|${document.contentHash}"),
            collectCangjieStudentServingDocumentDiagnostics(document,
                authority: authority))
    }
    for (entry in input.exactEntries) {
        ckbCollectLeakageDiagnostics(report, "exact-entry",
            benchmarkGapSha256("${entry.lookupKind}|${entry.key}|${entry.selector}|${entry.sourceId}|${entry.documentId}"),
            collectCangjieStudentServingExactEntryDiagnostics(entry,
                authority: authority))
    }
    for (pack in input.taskPacks) {
        ckbCollectLeakageDiagnostics(report, "task",
            benchmarkGapSha256(cangjieTaskKnowledgePackJson(pack)),
            collectCangjieTaskKnowledgeEvidenceDiagnostics(pack,
                authority: authority))
    }
    report.ok = report.leakageCount == 0
    let body = StringBuilder()
    for (finding in report.findings) {
        body.append("{\"recordHash\":\""); body.append(finding.recordHash)
        body.append("\",\"layer\":\""); body.append(ckbCleanJsonEscape(finding.layer))
        body.append("\",\"code\":\""); body.append(ckbCleanJsonEscape(finding.code))
        body.append("\",\"field\":\""); body.append(ckbCleanJsonEscape(finding.field)); body.append("\"}\n")
    }
    report.json = "{\"schemaVersion\":\"ckb-student-leakage-report-v2\",\"ok\":${report.ok},\"recordCount\":${report.recordCount},\"scannedRecords\":${report.scannedRecords},\"scannedFields\":${report.scannedFields},\"rawRecordCount\":${report.rawRecordCount},\"normalizedRecordCount\":${report.normalizedRecordCount},\"servingDocumentCount\":${report.servingDocumentCount},\"indexRecordCount\":${report.indexRecordCount},\"indexDocumentCount\":${report.indexDocumentCount},\"exactEntryCount\":${report.exactEntryCount},\"taskPackCount\":${report.taskPackCount},\"leakageCount\":${report.leakageCount},\"authorityHash\":\"${ckbCleanJsonEscape(report.authorityHash)}\",\"candidateChecksum\":\"${ckbCleanJsonEscape(report.candidateChecksum)}\",\"findingsEvidenceHash\":\"${benchmarkGapSha256(body.toString())}\"}\n" + body.toString()
    report.evidenceHash = benchmarkGapSha256(report.json)
    report
}

public func ckbBuildAnonymousAtomQueryReport(candidateRecords: ArrayList<NormalizedRecord>,
    atoms: ArrayList<NormalizedRecord>): CkbAnonymousAtomQueryReport {
    let report = CkbAnonymousAtomQueryReport(); report.atomCount = atoms.size
    let validation = validateCangjieStudentKnowledgeRecords(candidateRecords)
    if (!validation.ok) {
        report.failed = atoms.size
        report.jsonl = "{\"status\":\"candidate_leakage_blocked\",\"code\":\"${ckbCleanJsonEscape(validation.code)}\"}\n"
        report.evidenceHash = benchmarkGapSha256(report.jsonl); return report
    }
    let observer = CkbCleanQueryBuildObserver()
    let index = buildCangjieServingIndex(candidateRecords,
        activeKnowledgeVersion: "anonymous-atom-proof", buildObserver: observer)
    report.indexBuildCount = observer.count
    let body = StringBuilder()
    for (atom in atoms) {
        let query = ckbBenchmarkGapAnonymousQuery(atom)
        let cleanQuery = !ckbCleanQueryContainsSelector(query, atom)
        let request = CangjieServingSearchRequest(); request.query = query
        request.sourceSet = CangjieSourceSets.KNOWLEDGE_ATOMS
        request.targetVersion = atom.metadata.targetVersion; request.budget = candidateRecords.size
        let lookup = searchHybridServingIndex(index, request)
        var matched = false
        for (hit in lookup.hits) { if (hit.document.sourceId == atom.sourceId) { matched = true } }
        let passed = cleanQuery && matched
        if (passed) { report.passed += 1 } else { report.failed += 1 }
        body.append("{\"atomHash\":\""); body.append(benchmarkGapSha256(atom.sourceId))
        body.append("\",\"queryHash\":\""); body.append(benchmarkGapSha256(query))
        body.append("\",\"hitCount\":${lookup.hits.size},\"passed\":${passed}}\n")
    }
    report.ok = report.indexBuildCount == 1 && report.failed == 0 && report.passed == atoms.size
    report.jsonl = "{\"ok\":${report.ok},\"indexBuildCount\":${report.indexBuildCount},\"atomCount\":${report.atomCount},\"passed\":${report.passed},\"failed\":${report.failed}}\n" + body.toString()
    report.evidenceHash = benchmarkGapSha256(report.jsonl)
    report
}

public func ckbBuildStudentServingLeakageReport(
    service: CkbCommandLoopService,
    probes: ArrayList<CkbStudentServingProbe>,
    anonymousQueryArtifactHash!: String = "",
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CkbStudentServingLeakageReport {
    ckbBuildStudentServingLeakageReportWithBlockedService(service, service, probes,
        anonymousQueryArtifactHash: anonymousQueryArtifactHash,
        authority: authority)
}

public func ckbBuildStudentServingLeakageReportWithBlockedService(
    service: CkbCommandLoopService,
    blockedService: CkbCommandLoopService,
    probes: ArrayList<CkbStudentServingProbe>,
    anonymousQueryArtifactHash!: String = "",
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CkbStudentServingLeakageReport {
    let report = CkbStudentServingLeakageReport()
    report.probeCount = probes.size
    let restEvidence = StringBuilder()
    let stdioEvidence = StringBuilder()
    let httpEvidence = StringBuilder()
    var parity = true
    for (i in 0..probes.size) {
        let probe = probes[i]
        let probeService = if (probe.expectedBlocked) { blockedService } else { service }
        let body = ckbStudentTransportTaskBody(probe, i)
        let call = ckbStudentTransportToolCall(body, i)
        let pack = probeService.cangjieTaskKnowledgePack(
            ckbStudentTransportTaskRequest(probe, i))
        let expectedHash = pack.evidenceHash
        let evidenceOk = validateCangjieTaskKnowledgeEvidence(pack,
            authority: authority).ok
        let rest = ckbApiHandle(probeService, "POST",
            "/v1/cangjie/task-knowledge-pack", body, [])
        let stdio = CkbMcpStdioServer(probeService).handleRequest(call)
        let http = ckbStudentTransportMcpHttp(probeService, call)
        let restOk = ckbStudentTransportResponseOk(rest, probe.expectedBlocked,
            expectedHash, evidenceOk)
        let stdioOk = ckbStudentTransportResponseOk(stdio, probe.expectedBlocked,
            expectedHash, evidenceOk)
        let httpOk = ckbStudentTransportResponseOk(http, probe.expectedBlocked,
            expectedHash, evidenceOk)
        let canonical = if (probe.expectedBlocked) {
            benchmarkGapSha256("student_knowledge_leakage_blocked")
        } else { benchmarkGapSha256(expectedHash) }
        let canonicalParity = canonical != "" &&
            ckbStudentTransportCanonicalPresent(rest, probe.expectedBlocked,
                expectedHash, canonical) &&
            ckbStudentTransportCanonicalPresent(stdio, probe.expectedBlocked,
                expectedHash, canonical) &&
            ckbStudentTransportCanonicalPresent(http, probe.expectedBlocked,
                expectedHash, canonical)
        if (!restOk || !stdioOk || !httpOk || !canonicalParity) {
            report.failed += 1
        }
        parity = parity && canonicalParity
        ckbStudentTransportAppendObservation(restEvidence, probe, rest,
            restOk && canonicalParity, canonical)
        ckbStudentTransportAppendObservation(stdioEvidence, probe, stdio,
            stdioOk && canonicalParity, canonical)
        ckbStudentTransportAppendObservation(httpEvidence, probe, http,
            httpOk && canonicalParity, canonical)
    }
    report.restJson = ckbStudentTransportLeakageJson(
        "rest", probes.size, report.failed, restEvidence.toString())
    report.mcpStdioJson = ckbStudentTransportLeakageJson(
        "mcp-stdio", probes.size, report.failed, stdioEvidence.toString())
    report.mcpHttpJson = ckbStudentTransportLeakageJson(
        "mcp-http", probes.size, report.failed, httpEvidence.toString())
    let knowledgeEvidenceHash = benchmarkGapSha256(
        restEvidence.toString() + stdioEvidence.toString() +
        httpEvidence.toString())
    let body = "{\"schemaVersion\":\"ckb-student-serving-leakage-v2\"," +
        "\"ok\":${report.failed == 0 && parity},\"probeCount\":${probes.size}," +
        "\"failed\":${report.failed},\"transportCount\":3," +
        "\"restArtifactHash\":\"${benchmarkGapSha256(report.restJson)}\"," +
        "\"mcpStdioArtifactHash\":\"${benchmarkGapSha256(report.mcpStdioJson)}\"," +
        "\"mcpHttpArtifactHash\":\"${benchmarkGapSha256(report.mcpHttpJson)}\"," +
        "\"anonymousQueryArtifactHash\":\"${anonymousQueryArtifactHash}\"," +
        "\"knowledgeEvidenceHash\":\"${knowledgeEvidenceHash}\"," +
        "\"transportParity\":${parity}"
    report.evidenceHash = benchmarkGapSha256(body + "}")
    report.summaryJson = body +
        ",\"evidenceHash\":\"${report.evidenceHash}\"}\n"
    report.ok = report.failed == 0 && parity && probes.size >= 3
    report.diagnostic = if (report.ok) { "ok" } else {
        "student_serving_transport_probe_failed"
    }
    report
}

public func ckbPersistStudentTrustReports(store: FileKnowledgeStore, leakagePath: String,
    queryPath: String, leakage: CkbStudentLeakageReport, queries: CkbAnonymousAtomQueryReport): Bool {
    try {
        store.writeLinesAtomically(leakagePath, leakage.json)
        store.writeLinesAtomically(queryPath, queries.jsonl)
        store.readText(leakagePath) == leakage.json && store.readText(queryPath) == queries.jsonl
    } catch (_: Exception) { false }
}

// Historical records are purified rather than trusted merely because they were
// active before the anti-leak gate existed. Diagnostics contain only counts and
// hashes; rejected text and identifiers never leave this boundary.
public func ckbCleanHistoricalStudentRecords(records: ArrayList<NormalizedRecord>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentCleanRecordProjection {
    let result = CkbStudentCleanRecordProjection()
    result.inputCount = records.size
    result.inputChecksum = ckbCleanNormalizedRecordsChecksum(records)
    let seen = HashMap<String, String>()
    let removed = ArrayList<String>()
    for (record in records) {
        if (ckbCleanTextBlank(record.chunk)) {
            result.removedCount += 1
            ckbCleanIncrementRejection(result.rejectionCounts,
                "student_normalized_content_required")
            removed.add(benchmarkGapSha256(
                "${ckbCleanNormalizedIdentity(record)}|student_normalized_content_required"))
            continue
        }
        let diagnostic = cangjieStudentRecordDiagnostic(record, authority: authority)
        let identity = ckbCleanNormalizedIdentity(record)
        let evidence = ckbCleanNormalizedEvidence(record)
        if (!diagnostic.ok) {
            result.removedCount += 1
            ckbCleanIncrementRejection(result.rejectionCounts, diagnostic.code)
            removed.add(benchmarkGapSha256("${identity}|${diagnostic.code}|${diagnostic.matchedField}"))
            continue
        }
        match (seen.get(identity)) {
            case Some(existing) =>
                if (existing != evidence) {
                    result.ok = false
                    result.errorCode = "student_record_identity_conflict"
                    result.evidenceHash = benchmarkGapSha256("${identity}|${existing}|${evidence}")
                    return result
                }
                result.removedCount += 1
                ckbCleanIncrementRejection(result.rejectionCounts, "student_record_identity_duplicate")
                removed.add(benchmarkGapSha256("${identity}|student_record_identity_duplicate"))
            case None =>
                seen.add(identity, evidence)
                result.records.add(record)
        }
    }
    result.records = ckbCleanSortNormalizedRecords(result.records)
    result.keptCount = result.records.size
    result.outputChecksum = ckbCleanNormalizedRecordsChecksum(result.records)
    result.evidenceHash = benchmarkGapSha256(
        "input=${result.inputChecksum}|output=${result.outputChecksum}|removed=${ckbCleanEvidenceHash(removed)}")
    result
}

public func ckbValidateIncomingStudentRecords(records: ArrayList<NormalizedRecord>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentCleanRecordProjection {
    let result = CkbStudentCleanRecordProjection()
    let seen = HashMap<String, String>()
    for (record in records) {
        if (ckbCleanTextBlank(record.chunk)) {
            result.ok = false
            result.errorCode = "student_normalized_content_required"
            result.evidenceHash = benchmarkGapSha256(result.errorCode)
            return result
        }
        let diagnostic = cangjieStudentRecordDiagnostic(record, authority: authority)
        if (!diagnostic.ok) {
            result.ok = false
            result.errorCode = diagnostic.code
            result.evidenceHash = benchmarkGapSha256("${diagnostic.code}|${diagnostic.matchedField}")
            return result
        }
        let identity = ckbCleanNormalizedIdentity(record)
        let evidence = ckbCleanNormalizedEvidence(record)
        match (seen.get(identity)) {
            case Some(existing) =>
                if (existing == evidence) {
                    ckbCleanIncrementRejection(result.rejectionCounts,
                        "student_record_identity_duplicate")
                    continue
                }
                result.ok = false; result.errorCode = "student_record_identity_conflict"
                result.evidenceHash = benchmarkGapSha256("${identity}|${existing}|${evidence}")
                return result
            case None => seen.add(identity, evidence)
        }
        result.records.add(record)
    }
    result.records = ckbCleanSortNormalizedRecords(result.records)
    result.inputCount = records.size
    result.keptCount = result.records.size
    result.removedCount = records.size - result.records.size
    result.inputChecksum = ckbCleanNormalizedRecordsChecksum(records)
    result.outputChecksum = ckbCleanNormalizedRecordsChecksum(result.records)
    result.evidenceHash = benchmarkGapSha256("incoming:${result.records.size}")
    result
}

public func ckbOverlayCleanStudentRecords(historical: ArrayList<NormalizedRecord>,
    incoming: ArrayList<NormalizedRecord>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentCleanRecordProjection {
    ckbOverlayCleanStudentRecordsForOwner(historical, incoming, "", "", ArrayList<String>(), authority: authority)
}

public func ckbOverlayCleanStudentRecordsForOwner(historical: ArrayList<NormalizedRecord>,
    incoming: ArrayList<NormalizedRecord>, owner: String, targetVersion: String,
    removedSourceIds: ArrayList<String>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentCleanRecordProjection {
    let result = CkbStudentCleanRecordProjection()
    let base = ckbCleanHistoricalStudentRecords(historical, authority: authority)
    let delta = ckbValidateIncomingStudentRecords(incoming, authority: authority)
    result.removedCount = base.removedCount
    if (!delta.ok) {
        result.ok = false; result.errorCode = delta.errorCode
        result.evidenceHash = delta.evidenceHash
        return result
    }
    let replaced = HashSet<String>()
    let removed = HashSet<String>(removedSourceIds)
    for (record in delta.records) { replaced.add(record.sourceId) }
    for (record in base.records) {
        let owned = owner != "" && record.metadata.crawlAt == owner &&
            (targetVersion == "" || record.metadata.targetVersion == targetVersion)
        if (!owned && !removed.contains(record.sourceId) && !replaced.contains(record.sourceId)) {
            result.records.add(record)
        }
    }
    for (record in delta.records) { result.records.add(record) }
    result.evidenceHash = benchmarkGapSha256("clean:${base.evidenceHash}|incoming:${delta.evidenceHash}|out:${result.records.size}")
    result
}

public func ckbCleanHistoricalStudentRawRecords(records: ArrayList<RawRecord>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentCleanRawProjection {
    let result = CkbStudentCleanRawProjection()
    result.inputCount = records.size
    result.inputChecksum = ckbCleanRawRecordsChecksum(records)
    let seen = HashMap<String, String>()
    let removed = ArrayList<String>()
    for (record in records) {
        if (ckbCleanTextBlank(record.content)) {
            result.ok = false
            result.errorCode = "student_raw_content_required"
            result.evidenceHash = benchmarkGapSha256(
                "${ckbCleanRawIdentity(record)}|student_raw_content_required")
            return result
        }
        if (ckbCleanTextBlank(record.contentHash)) {
            result.ok = false
            result.errorCode = "student_raw_content_hash_required"
            result.evidenceHash = benchmarkGapSha256(
                "${ckbCleanRawIdentity(record)}|student_raw_content_hash_required")
            return result
        }
        if (!ckbCleanRawContentHashValid(record)) {
            result.ok = false
            result.errorCode = "student_raw_content_hash_mismatch"
            result.evidenceHash = benchmarkGapSha256(
                "${ckbCleanRawIdentity(record)}|student_raw_content_hash_mismatch")
            return result
        }
        let diagnostic = cangjieStudentRecordDiagnostic(ckbStudentRawAsNormalized(record), authority: authority)
        let identity = ckbCleanRawIdentity(record)
        let evidence = ckbCleanRawEvidence(record)
        if (!diagnostic.ok) {
            result.removedCount += 1
            ckbCleanIncrementRejection(result.rejectionCounts, diagnostic.code)
            removed.add(benchmarkGapSha256("${identity}|${diagnostic.code}|${diagnostic.matchedField}"))
            continue
        }
        match (seen.get(identity)) {
            case Some(existing) =>
                if (existing != evidence) {
                    result.ok = false
                    result.errorCode = "student_raw_record_identity_conflict"
                    result.evidenceHash = benchmarkGapSha256("${identity}|${existing}|${evidence}")
                    return result
                }
                result.removedCount += 1
                ckbCleanIncrementRejection(result.rejectionCounts, "student_record_identity_duplicate")
                removed.add(benchmarkGapSha256("${identity}|student_record_identity_duplicate"))
            case None =>
                seen.add(identity, evidence)
                result.records.add(record)
        }
    }
    result.records = ckbCleanSortRawRecords(result.records)
    result.keptCount = result.records.size
    result.outputChecksum = ckbCleanRawRecordsChecksum(result.records)
    result.evidenceHash = benchmarkGapSha256(
        "input=${result.inputChecksum}|output=${result.outputChecksum}|removed=${ckbCleanEvidenceHash(removed)}")
    result
}

public func ckbOverlayCleanStudentRawRecords(historical: ArrayList<RawRecord>,
    incoming: ArrayList<RawRecord>, owner!: String = "", targetVersion!: String = "",
    removedSourceIds!: ArrayList<String> = ArrayList<String>(),
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentCleanRawProjection {
    let result = CkbStudentCleanRawProjection()
    let base = ckbCleanHistoricalStudentRawRecords(historical, authority: authority)
    let cleanIncoming = ckbCleanHistoricalStudentRawRecords(incoming, authority: authority)
    if (cleanIncoming.removedCount > 0) {
        result.ok = false; result.errorCode = "student_knowledge_leakage_blocked"
        result.evidenceHash = cleanIncoming.evidenceHash
        return result
    }
    let replaced = HashSet<String>()
    let removed = HashSet<String>(removedSourceIds)
    for (record in cleanIncoming.records) { replaced.add(record.sourceId) }
    for (record in base.records) {
        let owned = owner != "" && record.metadata.crawlAt == owner &&
            (targetVersion == "" || record.metadata.targetVersion == targetVersion)
        if (!owned && !removed.contains(record.sourceId) && !replaced.contains(record.sourceId)) {
            result.records.add(record)
        }
    }
    for (record in cleanIncoming.records) { result.records.add(record) }
    result.removedCount = base.removedCount
    result.evidenceHash = benchmarkGapSha256("clean-raw:${base.evidenceHash}|out:${result.records.size}")
    result
}

// Builds a replacement candidate from complete historical and selected-atom
// inputs. This path intentionally does not call either overlay helper.
public func ckbBuildCompleteCleanStudentCandidate(historicalRaw: ArrayList<RawRecord>,
    historicalNormalized: ArrayList<NormalizedRecord>,
    historicalActive: ArrayList<NormalizedRecord>,
    selectedRaw: ArrayList<RawRecord>,
    selectedNormalized: ArrayList<NormalizedRecord>,
    selectedActive: ArrayList<NormalizedRecord>,
    version: String,
    authorityHash!: String = "",
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()
): CkbCompleteCleanStudentCandidate {
    let result = CkbCompleteCleanStudentCandidate()
    result.version = version; result.authorityHash = authorityHash
    if (!ckbCleanCandidateVersionAllowed(version)) {
        result.diagnostic = "clean_candidate_version_invalid"; return result
    }
    let historicalNormalizedClean = ckbCleanHistoricalStudentRecords(
        historicalNormalized, authority: authority)
    let historicalActiveClean = ckbCleanHistoricalStudentRecords(
        historicalActive, authority: authority)
    let historicalRawClean = ckbCleanHistoricalStudentRawRecords(
        historicalRaw, authority: authority)
    result.historicalNormalizedRemoved = historicalNormalizedClean.removedCount
    result.historicalActiveRemoved = historicalActiveClean.removedCount
    result.historicalRawRemoved = historicalRawClean.removedCount
    if (!historicalNormalizedClean.ok || !historicalActiveClean.ok || !historicalRawClean.ok) {
        result.diagnostic = ckbCleanFirstError(
            historicalNormalizedClean.errorCode,
            historicalActiveClean.errorCode,
            historicalRawClean.errorCode)
        return result
    }
    let selectedNormalizedClean = ckbValidateIncomingStudentRecords(
        selectedNormalized, authority: authority)
    let selectedActiveClean = ckbValidateIncomingStudentRecords(
        selectedActive, authority: authority)
    let selectedRawClean = ckbCleanHistoricalStudentRawRecords(selectedRaw, authority: authority)
    if (!selectedNormalizedClean.ok || !selectedActiveClean.ok || !selectedRawClean.ok ||
        selectedRawClean.removedCount != 0) {
        result.diagnostic = if (!selectedNormalizedClean.ok) { selectedNormalizedClean.errorCode }
            else if (!selectedActiveClean.ok) { selectedActiveClean.errorCode }
            else if (!selectedRawClean.ok) { selectedRawClean.errorCode }
            else { "selected_raw_record_rejected" }
        return result
    }
    if (!ckbCleanNormalizedCollectionsEqual(historicalNormalizedClean.records,
        historicalActiveClean.records) ||
        !ckbCleanNormalizedCollectionsEqual(selectedNormalizedClean.records,
            selectedActiveClean.records)) {
        result.diagnostic = "clean_candidate_input_active_normalized_mismatch"; return result
    }

    let normalizedInput = ArrayList<NormalizedRecord>()
    normalizedInput.add(all: historicalNormalizedClean.records)
    normalizedInput.add(all: selectedNormalizedClean.records)
    let normalizedCombined = ckbValidateIncomingStudentRecords(normalizedInput, authority: authority)
    if (!normalizedCombined.ok) {
        result.diagnostic = normalizedCombined.errorCode; return result
    }
    let rawInput = ArrayList<RawRecord>()
    rawInput.add(all: historicalRawClean.records); rawInput.add(all: selectedRawClean.records)
    let rawCombined = ckbCleanHistoricalStudentRawRecords(rawInput, authority: authority)
    if (!rawCombined.ok) {
        result.diagnostic = rawCombined.errorCode
        return result
    }

    for (record in rawCombined.records) {
        result.rawRecords.add(ckbCleanCloneRawForVersion(record, version))
    }
    for (record in normalizedCombined.records) {
        let clone = ckbCleanCloneNormalizedForVersion(record, version)
        result.normalizedRecords.add(clone)
        result.activeRecords.add(ckbCleanCloneNormalizedForVersion(record, version))
    }
    result.rawRecords = ckbCleanSortRawRecords(result.rawRecords)
    result.normalizedRecords = ckbCleanSortNormalizedRecords(result.normalizedRecords)
    result.activeRecords = ckbCleanSortNormalizedRecords(result.activeRecords)
    let postClone = ckbCleanCandidatePostCloneDiagnostic(result.rawRecords,
        result.normalizedRecords, result.activeRecords, authority)
    if (postClone != "ok") {
        result.diagnostic = postClone
        result.evidenceHash = benchmarkGapSha256(postClone)
        return result
    }
    let consistency = ckbCleanCandidateConsistencyDiagnostic(result.rawRecords,
        result.normalizedRecords, result.activeRecords, version)
    if (!consistency.ok) {
        result.diagnostic = consistency.code
        result.evidenceHash = consistency.evidenceHash
        return result
    }
    result.candidateChecksum = consistency.candidateChecksum
    result.auditJson = ckbCleanCandidateAuditJson(
        historicalRawClean, historicalNormalizedClean, historicalActiveClean,
        selectedRawClean, selectedNormalizedClean, selectedActiveClean,
        rawCombined, normalizedCombined)
    result.auditEvidenceHash = benchmarkGapSha256(result.auditJson)
    let removed = result.historicalNormalizedRemoved + result.historicalActiveRemoved +
        result.historicalRawRemoved
    let body = "{\"schemaVersion\":\"ckb-clean-candidate-v1\",\"ok\":true," +
        "\"versionHash\":\"${benchmarkGapSha256(version)}\",\"rawCount\":${result.rawRecords.size}," +
        "\"normalizedCount\":${result.normalizedRecords.size},\"activeCount\":${result.activeRecords.size}," +
        "\"historicalRemoved\":${removed},\"candidateChecksum\":\"${result.candidateChecksum}\"," +
        "\"authorityHash\":\"${ckbCleanJsonEscape(authorityHash)}\"," +
        "\"auditEvidenceHash\":\"${result.auditEvidenceHash}\""
    result.evidenceHash = benchmarkGapSha256(body + "}")
    result.manifestJson = body + ",\"evidenceHash\":\"${result.evidenceHash}\"}\n"
    result.ok = true; result.diagnostic = "ok"; result
}

public func ckbCleanCandidateConsistencyDiagnostic(raw: ArrayList<RawRecord>,
    normalized: ArrayList<NormalizedRecord>, active: ArrayList<NormalizedRecord>,
    version: String): CkbCleanCandidateConsistencyDiagnostic {
    let result = CkbCleanCandidateConsistencyDiagnostic()
    result.rawCount = raw.size; result.normalizedCount = normalized.size
    result.activeCount = active.size
    if (!ckbCleanCandidateVersionAllowed(version)) {
        result.code = "clean_candidate_version_invalid"; return result
    }
    if (!ckbCleanNormalizedCollectionsEqual(normalized, active)) {
        result.code = "clean_candidate_active_normalized_mismatch"
        result.evidenceHash = benchmarkGapSha256(
            "${ckbCleanNormalizedRecordsChecksum(normalized)}|${ckbCleanNormalizedRecordsChecksum(active)}")
        return result
    }
    for (record in normalized) {
        if (ckbCleanTextBlank(record.chunk)) {
            result.code = "clean_candidate_normalized_content_required"
            return result
        }
        if (record.metadata.knowledgeVersion != version ||
            record.metadata.candidateVersion != version) {
            result.code = "clean_candidate_normalized_version_mismatch"
            result.evidenceHash = benchmarkGapSha256(ckbCleanNormalizedIdentity(record))
            return result
        }
    }
    for (record in active) {
        if (record.metadata.knowledgeVersion != version ||
            record.metadata.candidateVersion != version) {
            result.code = "clean_candidate_active_version_mismatch"
            result.evidenceHash = benchmarkGapSha256(ckbCleanNormalizedIdentity(record))
            return result
        }
    }
    for (record in raw) {
        if (ckbCleanTextBlank(record.content)) {
            result.code = "clean_candidate_raw_content_required"; return result
        }
        if (ckbCleanTextBlank(record.contentHash)) {
            result.code = "clean_candidate_raw_content_hash_required"; return result
        }
        if (record.metadata.knowledgeVersion != version ||
            record.metadata.candidateVersion != version) {
            result.code = "clean_candidate_raw_version_mismatch"
            result.evidenceHash = benchmarkGapSha256(ckbCleanRawIdentity(record))
            return result
        }
    }
    let layerDiagnostic = ckbCleanRawNormalizedLayerDiagnostic(raw, normalized)
    if (layerDiagnostic != "ok") {
        result.code = layerDiagnostic
        result.evidenceHash = benchmarkGapSha256(
            "${ckbCleanRawSourceSetHash(raw)}|${ckbCleanNormalizedSourceSetHash(normalized)}")
        return result
    }
    result.candidateChecksum = ckbCertifiedNormalizedRecordsChecksum(normalized)
    result.evidenceHash = benchmarkGapSha256(
        "${result.rawCount}|${result.normalizedCount}|${result.activeCount}|${result.candidateChecksum}|${benchmarkGapSha256(version)}")
    result.ok = true; result.code = "ok"; result
}

public func ckbStudentCleanRejectionCount(counts: HashMap<String, Int64>, code: String): Int64 {
    match (counts.get(code)) {
        case Some(value) => value
        case None => 0
    }
}

public func runCkbCleanCandidateBuildCli(args: Array<String>): Int64 {
    let options = CkbCleanCandidateBuildOptions()
    let parsed = ckbParseCleanCandidateBuildOptions(args, options)
    if (parsed != "ok") {
        println("clean candidate build blocked: ${parsed}"); return 2
    }
    let result = ckbRunCleanCandidateBuild(options)
    if (options.json) {
        println(result.summaryJson)
    } else {
        println("clean candidate build ok=${result.ok} applied=${result.applied} raw=${result.rawCount} normalized=${result.normalizedCount} active=${result.activeCount} removed=${result.removedCount} candidateChecksum=${result.candidateChecksum} manifestEvidenceHash=${result.manifestEvidenceHash} diagnostic=${result.diagnostic}")
    }
    if (result.ok) { 0 } else { 1 }
}

public func ckbRunCleanCandidateBuild(options: CkbCleanCandidateBuildOptions): CkbCleanCandidateBuildResult {
    let result = CkbCleanCandidateBuildResult()
    let sourcePath = ckbCleanCanonicalExistingPath(options.sourceStore)
    let authorityPath = ckbCleanCanonicalExistingPath(options.authorityStore)
    if (sourcePath[0] != "ok" || authorityPath[0] != "ok") {
        result.diagnostic = "clean_candidate_source_invalid"
        return ckbFinalizeCleanCandidateBuildResult(result)
    }
    let protected = ArrayList<String>()
    protected.add(sourcePath[1]); protected.add(authorityPath[1])
    var atomsStore = FileKnowledgeStore(options.sourceStore)
    var atomsSnapshot = ActiveSnapshot()
    if (options.atomsStore != "") {
        let atomsPath = ckbCleanCanonicalExistingPath(options.atomsStore)
        if (atomsPath[0] != "ok") {
            result.diagnostic = "clean_candidate_atoms_store_invalid"
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        protected.add(atomsPath[1]); atomsStore = FileKnowledgeStore(atomsPath[1])
    }
    let staging = FileKnowledgeStore(options.stagingStore)
    let base = ckbCleanCandidateBaseDiagnostic(staging, protectedRoots: protected)
    if (!base.ok) {
        result.diagnostic = base.code
        return ckbFinalizeCleanCandidateBuildResult(result)
    }
    try {
        let sourceStore = FileKnowledgeStore(sourcePath[1])
        let authorityStore = FileKnowledgeStore(authorityPath[1])
        if (ckbCleanSnapshotUtf8Diagnostic(sourceStore) != "ok") {
            result.diagnostic = "invalid_response_encoding"
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        let sourceSnapshot = sourceStore.loadActiveSnapshot()
        if (!sourceSnapshot.valid) {
            result.diagnostic = "clean_candidate_source_snapshot_invalid"
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        let authority = ckbLoadBenchmarkLeakageAuthority(authorityStore)
        if (!authority.ok || authority.authorityRecordCount <= 0) {
            result.diagnostic = if (!authority.ok) { authority.diagnostic }
                else { "clean_candidate_authority_required" }
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        if (options.atomsStore != "") {
            if (ckbCleanSnapshotUtf8Diagnostic(atomsStore) != "ok") {
                result.diagnostic = "invalid_response_encoding"
                return ckbFinalizeCleanCandidateBuildResult(result)
            }
            atomsSnapshot = atomsStore.loadActiveSnapshot()
            if (!atomsSnapshot.valid) {
                result.diagnostic = "clean_candidate_atoms_snapshot_invalid"
                return ckbFinalizeCleanCandidateBuildResult(result)
            }
        }
        let candidate = ckbBuildCompleteCleanStudentCandidate(
            sourceSnapshot.rawRecords, sourceSnapshot.normalizedRecords, sourceSnapshot.activeIndex,
            atomsSnapshot.rawRecords, atomsSnapshot.normalizedRecords, atomsSnapshot.activeIndex,
            options.version, authorityHash: authority.authorityHash, authority: authority.authority)
        result.rawCount = candidate.rawRecords.size
        result.normalizedCount = candidate.normalizedRecords.size
        result.activeCount = candidate.activeRecords.size
        result.removedCount = candidate.historicalRawRemoved +
            candidate.historicalNormalizedRemoved + candidate.historicalActiveRemoved
        result.candidateChecksum = candidate.candidateChecksum
        result.candidateEvidenceHash = candidate.evidenceHash
        result.authorityHash = candidate.authorityHash
        result.auditEvidenceHash = candidate.auditEvidenceHash
        if (!candidate.ok) {
            result.diagnostic = candidate.diagnostic
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        if (options.apply) {
            let persisted = ckbPersistCompleteCleanStudentCandidate(staging, candidate)
            if (!persisted.ok) {
                result.diagnostic = persisted.diagnostic
                return ckbFinalizeCleanCandidateBuildResult(result)
            }
            result.manifestEvidenceHash = persisted.manifestEvidenceHash
            result.immutableManifestHash = persisted.immutableManifestHash
            result.cleanManifestHash = persisted.cleanManifestHash
            result.applied = persisted.applied
        }
        result.ok = true; result.diagnostic = "ok"
        ckbFinalizeCleanCandidateBuildResult(result)
    } catch (_: Exception) {
        result.diagnostic = "clean_candidate_build_failed"
        ckbFinalizeCleanCandidateBuildResult(result)
    }
}

public func ckbPersistCompleteCleanStudentCandidate(staging: FileKnowledgeStore,
    candidate: CkbCompleteCleanStudentCandidate): CkbCleanCandidateBuildResult {
    let result = CkbCleanCandidateBuildResult()
    result.rawCount = candidate.rawRecords.size
    result.normalizedCount = candidate.normalizedRecords.size
    result.activeCount = candidate.activeRecords.size
    result.candidateChecksum = candidate.candidateChecksum
    result.candidateEvidenceHash = candidate.evidenceHash
    result.authorityHash = candidate.authorityHash
    result.auditEvidenceHash = candidate.auditEvidenceHash
    if (!candidate.ok || candidate.version == "") {
        result.diagnostic = if (candidate.diagnostic == "") {
            "clean_candidate_not_built"
        } else { candidate.diagnostic }
        return ckbFinalizeCleanCandidateBuildResult(result)
    }
    try {
        let materialized = staging.saveCandidateSnapshotImmutable(
            candidate.rawRecords, candidate.normalizedRecords, candidate.version)
        if (!materialized.ok) {
            result.diagnostic = materialized.status
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        let base = "candidate-artifacts/${candidate.version}"
        let immutableManifest = staging.readText("${base}/manifest.ckb")
        if (ckbCleanImmutableManifestDiagnostic(immutableManifest,
            materialized, candidate.version) != "ok") {
            result.diagnostic = "clean_candidate_immutable_manifest_readback_mismatch"
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        let immutableReadback = staging.saveCandidateSnapshotImmutable(
            candidate.rawRecords, candidate.normalizedRecords, candidate.version)
        if (!immutableReadback.ok || !immutableReadback.immutableReused ||
            immutableReadback.manifestEvidenceHash != materialized.manifestEvidenceHash ||
            immutableReadback.rawEvidenceHash != materialized.rawEvidenceHash ||
            immutableReadback.normalizedEvidenceHash != materialized.normalizedEvidenceHash ||
            immutableReadback.batchCount != materialized.batchCount) {
            result.diagnostic = "clean_candidate_immutable_files_readback_mismatch"
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        result.manifestEvidenceHash = materialized.manifestEvidenceHash
        result.immutableManifestHash = benchmarkGapSha256(immutableManifest)
        candidate.manifestJson = ckbCleanBoundManifestJson(candidate, materialized,
            result.immutableManifestHash)
        staging.writeLinesAtomically("${base}/clean-candidate-audit.json",
            candidate.auditJson + "\n")
        staging.writeLinesAtomically("${base}/clean-candidate-manifest.json",
            candidate.manifestJson)
        if (staging.readText("${base}/clean-candidate-audit.json") !=
            candidate.auditJson + "\n" ||
            staging.readText("${base}/clean-candidate-manifest.json") !=
            candidate.manifestJson) {
            result.diagnostic = "clean_candidate_manifest_readback_mismatch"
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        result.cleanManifestHash = benchmarkGapSha256(candidate.manifestJson)
        result.applied = true; result.ok = true; result.diagnostic = "ok"
        ckbFinalizeCleanCandidateBuildResult(result)
    } catch (_: Exception) {
        result.diagnostic = "clean_candidate_build_failed"
        ckbFinalizeCleanCandidateBuildResult(result)
    }
}

public func ckbStudentCleanRemovalDiagnostic(kind: String, count: Int64, evidenceHash: String): String {
    "student_clean_${kind}:removed=${count}|evidenceHash=${evidenceHash}"
}

public func ckbFilterIndependentCertificationRecords(records:ArrayList<NormalizedRecord>):ArrayList<NormalizedRecord>{
    let out=ArrayList<NormalizedRecord>();for(record in records){if(ckbIndependentRecordAllowed(record)){out.add(record)}};out
}
public func ckbIndependentAssetLineageDiagnostic(records:ArrayList<NormalizedRecord>):String{
    if(records.size==0){return "independent_certification_records_empty"};for(record in records){if(!ckbIndependentRecordAllowed(record)){return "non_independent_record:${utf8SafePrefix(redactSensitive(record.sourceId),120)}"}};"ok"
}
private func ckbIndependentRecordAllowed(record:NormalizedRecord):Bool{
    let source=(record.sourceId+"\n"+record.title+"\n"+record.citation+"\n"+record.metadata.sourceId+"\n"+record.metadata.sourceType+"\n"+record.metadata.path+"\n"+record.metadata.derivedFrom.toString()).toAsciiLower()
    if(source.contains("humaneval")||source.contains("eval-support")||source.contains("teacher")||source.contains("student_solution")||source.contains("benchmark-gap")){return false}
    [SourceTypes.DOC,SourceTypes.WEBSITE,SourceTypes.REPO,SourceTypes.COMMUNITY].contains(record.metadata.sourceType)&&record.metadata.sourceId!=""&&record.citation!=""
}

private func ckbCleanNormalizedIdentity(record: NormalizedRecord): String {
    let body = StringBuilder()
    for (value in [record.sourceId, record.recordKind, record.chunk]) {
        body.append("${value.toArray().size}:${value}|")
    }
    benchmarkGapSha256(body.toString())
}

private func ckbCleanNormalizedEvidence(record: NormalizedRecord): String {
    let body = StringBuilder()
    for (value in [record.recordKind, record.sourceId, record.title, record.chunk, record.citation,
        "${record.score}", "${record.requiresReview}",
        record.metadata.sourceId, record.metadata.sourceType, record.metadata.sourceSet,
        record.metadata.sourceUrl, record.metadata.repo, record.metadata.path,
        record.metadata.symbol, record.metadata.commit, record.metadata.docVersion,
        record.metadata.targetVersion, record.metadata.versionResolutionId,
        record.metadata.crawlAt, record.metadata.indexedAt,
        record.metadata.knowledgeVersion, record.metadata.candidateVersion,
        "${record.metadata.contentSize}", record.metadata.trustLevel,
        record.metadata.reviewState, record.metadata.license,
        record.metadata.repoVisibility]) {
        body.append("${value.toArray().size}:${value}|")
    }
    body.append("derivedFrom=${record.metadata.derivedFrom.size}|")
    for (value in record.metadata.derivedFrom) { body.append("${value.toArray().size}:${value}|") }
    benchmarkGapSha256(body.toString())
}

private func ckbCleanEvidenceHash(values: ArrayList<String>): String {
    let out = StringBuilder()
    for (value in values) { out.append(value); out.append("|") }
    benchmarkGapSha256(out.toString())
}

private func ckbCollectLeakageFinding(report: CkbStudentLeakageReport, recordHash: String,
    diagnostic: CangjieStudentKnowledgeDiagnostic, layer!: String = "normalized"): Unit {
    if (diagnostic.ok) { return }
    for (existing in report.findings) {
        if (existing.recordHash == recordHash && existing.code == diagnostic.code &&
            existing.field == diagnostic.matchedField && existing.layer == layer) { return }
    }
    let finding = CkbStudentLeakageFinding(); finding.recordHash = recordHash
    finding.layer = layer
    finding.code = diagnostic.code; finding.field = diagnostic.matchedField
    report.findings.add(finding); report.leakageCount += 1
}

private func ckbCollectLeakageDiagnostics(report: CkbStudentLeakageReport,
    layer: String, recordHash: String,
    collected: CangjieStudentKnowledgeDiagnostics): Unit {
    report.scannedFields += collected.scannedFields
    for (diagnostic in collected.diagnostics) {
        ckbCollectLeakageFinding(report, recordHash, diagnostic, layer: layer)
    }
}

private func ckbCleanQueryContainsSelector(query: String, atom: NormalizedRecord): Bool {
    let clean = query.toAsciiLower()
    clean.contains(atom.sourceId.toAsciiLower()) || clean.contains(atom.metadata.path.toAsciiLower()) ||
        clean.contains("humaneval") || clean.contains("visible-benchmark") ||
        clean.contains("curated-gap") || clean.contains("eval-support")
}

private func ckbStudentTaskEvidenceProjection(pack: CangjieTaskKnowledgePack): String {
    cangjieTaskKnowledgePackJson(pack)
}

private func ckbStudentTransportLeakageJson(transport: String, probeCount: Int64,
    failed: Int64, observations: String): String {
    let body = "{\"schemaVersion\":\"ckb-student-transport-leakage-v1\"," +
        "\"transport\":\"${transport}\",\"ok\":${failed == 0}," +
        "\"probeCount\":${probeCount},\"failed\":${failed}," +
        "\"observationsHash\":\"${benchmarkGapSha256(observations)}\""
    body + ",\"evidenceHash\":\"${benchmarkGapSha256(body + "}")}\"}\n" +
        observations
}

private func ckbStudentTransportTaskRequest(probe: CkbStudentServingProbe,
    index: Int64): CangjieTaskKnowledgeRequest {
    let request = CangjieTaskKnowledgeRequest()
    request.taskId = "student-precert-probe-${index}"
    request.taskText = probe.query
    request.versionSelector.targetVersion = cangjieDefaultTargetVersion()
    request.versionSelector.sourceSet = CangjieSourceSets.ALL
    request.budget = CangjieCapabilityLimits.DEFAULT_BUDGET
    request
}

private func ckbStudentTransportTaskBody(probe: CkbStudentServingProbe,
    index: Int64): String {
    "{\"taskId\":\"student-precert-probe-${index}\",\"benchmark\":\"\"," +
        "\"taskText\":\"${ckbCleanJsonEscape(probe.query)}\",\"signature\":\"\"," +
        "\"imports\":[],\"argTypes\":[],\"returnType\":\"\"," +
        "\"expectedKnowledgeTags\":[],\"starterCodeExcerpt\":\"\"," +
        "\"compilerOutput\":\"\",\"targetVersion\":\"${cangjieDefaultTargetVersion()}\"," +
        "\"sourceSet\":\"all\",\"sourceRef\":\"\",\"versionPolicy\":\"default\"," +
        "\"budget\":${CangjieCapabilityLimits.DEFAULT_BUDGET}}"
}

private func ckbStudentTransportToolCall(arguments: String, index: Int64): String {
    "{\"jsonrpc\":\"2.0\",\"id\":${index + 1},\"method\":\"tools/call\"," +
        "\"params\":{\"name\":\"cangjie_task_knowledge_pack\"," +
        "\"arguments\":${arguments}}}"
}

private func ckbStudentTransportResponseOk(raw: String, expectedBlocked: Bool,
    expectedHash: String, evidenceOk: Bool): Bool {
    if (expectedBlocked) {
        return raw.contains("student_knowledge_leakage_blocked")
    }
    evidenceOk && expectedHash != "" && raw.contains(expectedHash) &&
        !raw.contains("student_knowledge_leakage_blocked")
}

private func ckbStudentTransportCanonicalPresent(raw: String,
    expectedBlocked: Bool, expectedHash: String, canonical: String): Bool {
    if (expectedBlocked) {
        return canonical == benchmarkGapSha256("student_knowledge_leakage_blocked") &&
            raw.contains("student_knowledge_leakage_blocked")
    }
    expectedHash != "" && raw.contains(expectedHash) &&
        canonical == benchmarkGapSha256(expectedHash)
}

private func ckbStudentTransportAppendObservation(out: StringBuilder,
    probe: CkbStudentServingProbe, response: String, passed: Bool,
    canonical: String): Unit {
    out.append("{\"probeId\":\"${ckbCleanJsonEscape(probe.probeId)}\",")
    out.append("\"requestHash\":\"${benchmarkGapSha256(probe.query)}\",")
    out.append("\"expectedBlocked\":${probe.expectedBlocked},\"passed\":${passed},")
    out.append("\"canonicalEvidenceHash\":\"${ckbCleanJsonEscape(canonical)}\",")
    out.append("\"responseHash\":\"${benchmarkGapSha256(response)}\"}\n")
}

private func ckbStudentTransportMcpHttp(service: CkbCommandLoopService,
    toolCall: String): String {
    let sessions = CkbMcpHttpSessionStore()
    let http = CkbHttpServiceConfig()
    let mcp = CkbMcpHttpServiceConfig()
    let initHeaders = [
        "Content-Type: application/json",
        "Accept: application/json, text/event-stream"
    ]
    let initialized = handleCkbMcpHttpRequest(service, "POST", "/mcp",
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"candidate-precert\",\"version\":\"1\"}}}",
        initHeaders, http, mcp, sessions)
    let sessionId = ckbStudentTransportSessionId(initialized.headers)
    if (sessionId == "") { return initialized.body }
    let headers = [
        "Content-Type: application/json",
        "Accept: application/json, text/event-stream",
        "MCP-Protocol-Version: 2025-06-18",
        "Mcp-Session-Id: ${sessionId}"
    ]
    _ = handleCkbMcpHttpRequest(service, "POST", "/mcp",
        "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}",
        headers, http, mcp, sessions)
    handleCkbMcpHttpRequest(service, "POST", "/mcp", toolCall, headers,
        http, mcp, sessions).body
}

private func ckbStudentTransportSessionId(headers: ArrayList<String>): String {
    for (header in headers) {
        if (header.toAsciiLower().startsWith("mcp-session-id:")) {
            return header["mcp-session-id:".size..header.size].trimAscii()
        }
    }
    ""
}

private func ckbCleanJsonEscape(value: String): String {
    let out = StringBuilder()
    for (ch in value.toRuneArray()) {
        if (ch == r'\\') { out.append("\\\\") }
        else if (ch == r'\"') { out.append("\\\"") }
        else if (ch == r'\n') { out.append("\\n") }
        else if (ch == r'\r') { out.append("\\r") }
        else if (ch == r'\t') { out.append("\\t") }
        else { out.append(ch) }
    }
    out.toString()
}

private func ckbStudentRawAsNormalized(record: RawRecord): NormalizedRecord {
    let normalized = NormalizedRecord()
    normalized.sourceId = record.sourceId
    normalized.recordKind = if (record.metadata.sourceSet == CangjieSourceSets.EVAL_SUPPORT) {
        CangjieTypedRecordKinds.EVAL_SUPPORT
    } else if (record.sourceId.startsWith("knowledge-atom-") ||
        record.metadata.sourceSet == CangjieSourceSets.KNOWLEDGE_ATOMS) {
        CangjieTypedRecordKinds.KNOWLEDGE_ATOM
    } else { CangjieTypedRecordKinds.DOC_SECTION }
    normalized.title = record.title; normalized.chunk = record.content
    normalized.citation = record.metadata.sourceUrl; normalized.metadata = record.metadata
    normalized.requiresReview = record.requiresReview
    normalized
}

private func ckbParseCleanCandidateBuildOptions(args: Array<String>,
    options: CkbCleanCandidateBuildOptions): String {
    var commandSeen = false; var modeSeen = false; var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-clean-candidate-build" && !commandSeen) {
            commandSeen = true; i += 1; continue
        }
        if (arg == "--dry-run" || arg == "--apply") {
            if (modeSeen) { return "duplicate_mode" }
            modeSeen = true; options.apply = arg == "--apply"; i += 1; continue
        }
        if (arg == "--json") {
            if (options.json) { return "duplicate_argument" }
            options.json = true; i += 1; continue
        }
        if (arg != "--source-store" && arg != "--staging-store" &&
            arg != "--authority-store" && arg != "--atoms-store" &&
            arg != "--candidate-version") {
            return "unknown_argument"
        }
        if (i + 1 >= args.size) { return "missing_argument_value" }
        let value = args[i + 1]
        if (arg == "--source-store") {
            if (options.sourceStore != "") { return "duplicate_argument" }
            options.sourceStore = value
        } else if (arg == "--staging-store") {
            if (options.stagingStore != "") { return "duplicate_argument" }
            options.stagingStore = value
        } else if (arg == "--authority-store") {
            if (options.authorityStore != "") { return "duplicate_argument" }
            options.authorityStore = value
        } else if (arg == "--atoms-store") {
            if (options.atomsStore != "") { return "duplicate_argument" }
            options.atomsStore = value
        } else {
            if (options.version != "") { return "duplicate_argument" }
            options.version = value
        }
        i += 2
    }
    if (!commandSeen) { return "command_required" }
    if (!modeSeen) { return "dry_run_or_apply_required" }
    if (options.sourceStore == "" || options.stagingStore == "" ||
        options.authorityStore == "" || options.version == "") {
        return "required_argument_missing"
    }
    if (!ckbCleanCandidateVersionAllowed(options.version)) {
        return "clean_candidate_version_invalid"
    }
    "ok"
}

private func ckbFinalizeCleanCandidateBuildResult(
    result: CkbCleanCandidateBuildResult): CkbCleanCandidateBuildResult {
    result.summaryJson = "{\"ok\":${result.ok},\"applied\":${result.applied}," +
        "\"rawCount\":${result.rawCount},\"normalizedCount\":${result.normalizedCount}," +
        "\"activeCount\":${result.activeCount},\"removedCount\":${result.removedCount}," +
        "\"candidateChecksum\":\"${ckbCleanJsonEscape(result.candidateChecksum)}\"," +
        "\"candidateEvidenceHash\":\"${ckbCleanJsonEscape(result.candidateEvidenceHash)}\"," +
        "\"manifestEvidenceHash\":\"${ckbCleanJsonEscape(result.manifestEvidenceHash)}\"," +
        "\"immutableManifestHash\":\"${ckbCleanJsonEscape(result.immutableManifestHash)}\"," +
        "\"authorityHash\":\"${ckbCleanJsonEscape(result.authorityHash)}\"," +
        "\"auditEvidenceHash\":\"${ckbCleanJsonEscape(result.auditEvidenceHash)}\"," +
        "\"cleanManifestHash\":\"${ckbCleanJsonEscape(result.cleanManifestHash)}\"," +
        "\"diagnostic\":\"${ckbCleanJsonEscape(result.diagnostic)}\"}"
    result
}

private func ckbCleanCanonicalExistingPath(path: String): (String, String) {
    if (path.trimAscii() == "" || path.contains("\u{0000}")) {
        return ("clean_candidate_path_invalid", "")
    }
    try {
        let value = canonicalize(Path(path)).toString()
        if (value == "") { return ("clean_candidate_path_invalid", "") }
        ("ok", value)
    } catch (_: Exception) {
        ("clean_candidate_path_invalid", "")
    }
}

private func ckbCleanSnapshotUtf8Diagnostic(store: FileKnowledgeStore): String {
    let pointer = store.loadActiveSnapshotPointer()
    if (!pointer.valid) { return "active_snapshot_pointer_invalid" }
    let prefix = "transactions/${pointer.txId}"
    try {
        _ = store.readText("${prefix}/raw/records.ckb")
        _ = store.readText("${prefix}/normalized/records.ckb")
        _ = store.readText("${prefix}/index/active.ckb")
        "ok"
    } catch (_: Exception) {
        "invalid_response_encoding"
    }
}

private func ckbCleanCanonicalOutputPath(path: Path): (String, String) {
    if (path.toString().trimAscii() == "" || path.toString().contains("\u{0000}")) {
        return ("clean_candidate_path_invalid", "")
    }
    try {
        let parent = canonicalize(path.parent).toString()
        let expected = Path(parent).join(path.fileName).toString()
        if (exists(path)) {
            let actual = canonicalize(path).toString()
            if (actual != expected) { return ("clean_candidate_staging_symlink_forbidden", "") }
        }
        ("ok", expected)
    } catch (_: Exception) {
        ("clean_candidate_path_invalid", "")
    }
}

private func ckbCleanCandidateVersionAllowed(version: String): Bool {
    let clean = version.trimAscii()
    clean != "" && clean == version && !clean.contains("/") && !clean.contains("\\") &&
        !clean.contains("..") && !clean.contains("\u{0000}")
}

private func ckbCleanFirstError(first: String, second: String, third: String): String {
    if (first != "") { return first }
    if (second != "") { return second }
    if (third != "") { return third }
    "clean_candidate_historical_projection_failed"
}

private func ckbCleanIncrementRejection(counts: HashMap<String, Int64>, code: String): Unit {
    let key = if (code == "") { "student_record_rejected" } else { code }
    match (counts.get(key)) {
        case Some(value) => counts[key] = value + 1
        case None => counts.add(key, 1)
    }
}

private func ckbCleanSortNormalizedRecords(
    records: ArrayList<NormalizedRecord>): ArrayList<NormalizedRecord> {
    let keys = ArrayList<String>(); let byKey = HashMap<String, NormalizedRecord>()
    for (record in records) {
        let key = "${ckbCleanNormalizedIdentity(record)}|${ckbCleanNormalizedEvidence(record)}"
        keys.add(key); byKey[key] = record
    }
    let sorted = keys.toArray(); sort(sorted)
    let out = ArrayList<NormalizedRecord>()
    for (key in sorted) {
        match (byKey.get(key)) {
            case Some(record) => out.add(record)
            case None => ()
        }
    }
    out
}

private func ckbCleanSortRawRecords(records: ArrayList<RawRecord>): ArrayList<RawRecord> {
    let keys = ArrayList<String>(); let byKey = HashMap<String, RawRecord>()
    for (record in records) {
        let key = "${ckbCleanRawIdentity(record)}|${ckbCleanRawEvidence(record)}"
        keys.add(key); byKey[key] = record
    }
    let sorted = keys.toArray(); sort(sorted)
    let out = ArrayList<RawRecord>()
    for (key in sorted) {
        match (byKey.get(key)) {
            case Some(record) => out.add(record)
            case None => ()
        }
    }
    out
}

private func ckbCleanNormalizedRecordsChecksum(records: ArrayList<NormalizedRecord>): String {
    let values = ArrayList<String>()
    for (record in records) {
        values.add("${ckbCleanNormalizedIdentity(record)}|${ckbCleanNormalizedEvidence(record)}")
    }
    let ordered = values.toArray(); sort(ordered)
    let seed = StringBuilder()
    for (value in ordered) { seed.append("${value.toArray().size}:${value}") }
    benchmarkGapSha256(seed.toString())
}

private func ckbCleanRawIdentity(record: RawRecord): String {
    let body = StringBuilder()
    for (value in [record.sourceId, record.content]) {
        body.append("${value.toArray().size}:${value}|")
    }
    benchmarkGapSha256(body.toString())
}

private func ckbCleanRawEvidence(record: RawRecord): String {
    benchmarkGapSha256("${record.contentHash.toArray().size}:${record.contentHash}|" +
        ckbCleanNormalizedEvidence(ckbStudentRawAsNormalized(record)))
}

private func ckbCleanRawContentHashValid(record: RawRecord): Bool {
    !ckbCleanTextBlank(record.content) && !ckbCleanTextBlank(record.contentHash) &&
        (record.contentHash == benchmarkGapSha256(record.content) ||
        record.contentHash == stableSummaryHash(record.content) ||
        record.contentHash == ckbReleaseEvidenceHash(record.content) ||
        record.contentHash == cangjieTypedRecordContentHash(record.sourceId, record.content) ||
        record.contentHash == ckbCleanLegacyContentHash(record.sourceId, record.content))
}

private func ckbCleanLegacyContentHash(sourceId: String, content: String): String {
    var hash: Int64 = 5381
    let modulus: Int64 = 1000000007
    for (byte in "${sourceId}:${content}".toArray()) {
        hash = ((hash * 33) % modulus + (Int64(byte) % modulus)) % modulus
    }
    "hash-${hash}-${content.size}"
}

private func ckbCleanRawRecordsChecksum(records: ArrayList<RawRecord>): String {
    let values = ArrayList<String>()
    for (record in records) {
        values.add("${ckbCleanRawIdentity(record)}|${ckbCleanRawEvidence(record)}")
    }
    let ordered = values.toArray(); sort(ordered)
    let seed = StringBuilder()
    for (value in ordered) { seed.append("${value.toArray().size}:${value}") }
    benchmarkGapSha256(seed.toString())
}

private func ckbCleanNormalizedCollectionsEqual(first: ArrayList<NormalizedRecord>,
    second: ArrayList<NormalizedRecord>): Bool {
    first.size == second.size &&
        ckbCleanNormalizedRecordsChecksum(first) == ckbCleanNormalizedRecordsChecksum(second)
}

private func ckbCleanRawNormalizedLayerDiagnostic(raw: ArrayList<RawRecord>,
    normalized: ArrayList<NormalizedRecord>): String {
    let bySource = HashMap<String, ArrayList<String>>()
    for (record in raw) {
        match (bySource.get(record.sourceId)) {
            case Some(contents) => contents.add(record.content)
            case None =>
                let contents = ArrayList<String>()
                contents.add(record.content)
                bySource.add(record.sourceId, contents)
        }
    }
    for (record in normalized) {
        match (bySource.get(record.sourceId)) {
            case Some(contents) =>
                if (ckbCleanTextBlank(record.chunk)) {
                    return "clean_candidate_normalized_content_required"
                }
                var matched = false
                for (content in contents) {
                    if (record.chunk == content || content.contains(record.chunk)) {
                        matched = true
                        break
                    }
                }
                if (matched) { continue }
                return "clean_candidate_raw_normalized_content_mismatch"
            case None =>
                if (!ckbCleanNormalizedOnlyAllowed(record)) {
                    return "clean_candidate_normalized_only_provenance_invalid"
                }
        }
    }
    "ok"
}

private func ckbCleanNormalizedOnlyAllowed(record: NormalizedRecord): Bool {
    let roleAllowed = (record.recordKind == CangjieTypedRecordKinds.DOC_SECTION &&
        record.metadata.sourceSet == CangjieSourceSets.DOCS) ||
        (record.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL &&
        record.metadata.sourceSet == CangjieSourceSets.TOOLS)
    roleAllowed && !ckbCleanTextBlank(record.sourceId) &&
        !ckbCleanTextBlank(record.recordKind) &&
        record.metadata.sourceId == record.sourceId &&
        !ckbCleanTextBlank(record.metadata.sourceId) &&
        record.metadata.sourceType == SourceTypes.DOC &&
        !ckbCleanTextBlank(record.metadata.sourceType) &&
        !ckbCleanTextBlank(record.metadata.sourceSet) &&
        !ckbCleanTextBlank(record.chunk) && !ckbCleanTextBlank(record.citation) &&
        record.metadata.sourceUrl == record.citation &&
        !ckbCleanTextBlank(record.metadata.sourceUrl) &&
        !ckbCleanTextBlank(record.metadata.path) &&
        !ckbCleanTextBlank(record.metadata.targetVersion) &&
        !ckbCleanTextBlank(record.metadata.versionResolutionId) &&
        record.metadata.trustLevel == TrustLevels.OFFICIAL &&
        record.metadata.reviewState == ReviewStates.TRUSTED &&
        cangjieStudentRecordDiagnostic(record).ok
}

private func ckbCleanCandidatePostCloneDiagnostic(raw: ArrayList<RawRecord>,
    normalized: ArrayList<NormalizedRecord>, active: ArrayList<NormalizedRecord>,
    authority: CangjieBenchmarkLeakageAuthority): String {
    for (record in raw) {
        if (ckbCleanTextBlank(record.content)) { return "student_raw_content_required" }
        if (ckbCleanTextBlank(record.contentHash)) {
            return "student_raw_content_hash_required"
        }
        if (!ckbCleanRawContentHashValid(record)) {
            return "student_raw_content_hash_mismatch"
        }
        let diagnostic = cangjieStudentRecordDiagnostic(
            ckbStudentRawAsNormalized(record), authority: authority)
        if (!diagnostic.ok) { return diagnostic.code }
    }
    for (record in normalized) {
        if (ckbCleanTextBlank(record.chunk)) {
            return "student_normalized_content_required"
        }
        let diagnostic = cangjieStudentRecordDiagnostic(record, authority: authority)
        if (!diagnostic.ok) { return diagnostic.code }
    }
    for (record in active) {
        if (ckbCleanTextBlank(record.chunk)) {
            return "student_normalized_content_required"
        }
        let diagnostic = cangjieStudentRecordDiagnostic(record, authority: authority)
        if (!diagnostic.ok) { return diagnostic.code }
    }
    "ok"
}

private func ckbCleanTextBlank(value: String): Bool {
    if (value == "") { return true }
    for (rune in value.toRuneArray()) {
        if (!(rune == r' ' || rune == r'\t' || rune == r'\r' || rune == r'\n' ||
            rune == r'\u{00a0}' || (rune >= r'\u{2000}' && rune <= r'\u{200a}') ||
            rune == r'\u{2028}' || rune == r'\u{2029}' || rune == r'\u{202f}' ||
            rune == r'\u{205f}' || rune == r'\u{3000}' || rune == r'\u{feff}')) {
            return false
        }
    }
    true
}

private func ckbCleanRawSourceSetHash(records: ArrayList<RawRecord>): String {
    let values = ArrayList<String>(); let seen = HashSet<String>()
    for (record in records) {
        let identity = ckbCleanRawIdentity(record)
        if (!seen.contains(identity)) { seen.add(identity); values.add(identity) }
    }
    ckbCleanSortedValueHash(values)
}

private func ckbCleanNormalizedSourceSetHash(records: ArrayList<NormalizedRecord>): String {
    let values = ArrayList<String>(); let seen = HashSet<String>()
    for (record in records) {
        let identity = if (record.sourceId != "") { record.sourceId }
            else { ckbCleanNormalizedIdentity(record) }
        if (!seen.contains(identity)) { seen.add(identity); values.add(identity) }
    }
    ckbCleanSortedValueHash(values)
}

private func ckbCleanSortedValueHash(values: ArrayList<String>): String {
    let ordered = values.toArray(); sort(ordered); let seed = StringBuilder()
    for (value in ordered) { seed.append("${value.toArray().size}:${value}") }
    benchmarkGapSha256(seed.toString())
}

private func ckbCleanCandidateAuditJson(historicalRaw: CkbStudentCleanRawProjection,
    historicalNormalized: CkbStudentCleanRecordProjection,
    historicalActive: CkbStudentCleanRecordProjection,
    selectedRaw: CkbStudentCleanRawProjection,
    selectedNormalized: CkbStudentCleanRecordProjection,
    selectedActive: CkbStudentCleanRecordProjection,
    combinedRaw: CkbStudentCleanRawProjection,
    combinedNormalized: CkbStudentCleanRecordProjection): String {
    let layerRoles = ckbCleanLayerRoleAuditJson(
        combinedRaw.records, combinedNormalized.records)
    "{\"historicalRaw\":${ckbCleanRawProjectionAuditJson(historicalRaw)}," +
        "\"historicalNormalized\":${ckbCleanNormalizedProjectionAuditJson(historicalNormalized)}," +
        "\"historicalActive\":${ckbCleanNormalizedProjectionAuditJson(historicalActive)}," +
        "\"selectedRaw\":${ckbCleanRawProjectionAuditJson(selectedRaw)}," +
        "\"selectedNormalized\":${ckbCleanNormalizedProjectionAuditJson(selectedNormalized)}," +
        "\"selectedActive\":${ckbCleanNormalizedProjectionAuditJson(selectedActive)}," +
        "\"combinedRaw\":${ckbCleanRawProjectionAuditJson(combinedRaw)}," +
        "\"combinedNormalized\":${ckbCleanNormalizedProjectionAuditJson(combinedNormalized)}," +
        "\"layerRoles\":${layerRoles}}"
}

private func ckbCleanLayerRoleAuditJson(raw: ArrayList<RawRecord>,
    normalized: ArrayList<NormalizedRecord>): String {
    let rawIds = HashSet<String>(); let normalizedIds = HashSet<String>()
    for (record in raw) { rawIds.add(record.sourceId) }
    for (record in normalized) { normalizedIds.add(record.sourceId) }
    var rawOnly: Int64 = 0; var normalizedOnly: Int64 = 0
    for (identity in rawIds) { if (!normalizedIds.contains(identity)) { rawOnly += 1 } }
    for (identity in normalizedIds) { if (!rawIds.contains(identity)) { normalizedOnly += 1 } }
    "{\"rawOnly\":${rawOnly},\"normalizedOnly\":${normalizedOnly}," +
        "\"rawIdentityHash\":\"${ckbCleanRawSourceSetHash(raw)}\"," +
        "\"normalizedIdentityHash\":\"${ckbCleanNormalizedSourceSetHash(normalized)}\"}"
}

private func ckbCleanRawProjectionAuditJson(result: CkbStudentCleanRawProjection): String {
    "{\"input\":${result.inputCount},\"kept\":${result.keptCount}," +
        "\"removed\":${result.removedCount},\"inputChecksum\":\"${result.inputChecksum}\"," +
        "\"outputChecksum\":\"${result.outputChecksum}\"," +
        "\"evidenceHash\":\"${result.evidenceHash}\"," +
        "\"rejections\":${ckbCleanRejectionCountsJson(result.rejectionCounts)}}"
}

private func ckbCleanNormalizedProjectionAuditJson(
    result: CkbStudentCleanRecordProjection): String {
    "{\"input\":${result.inputCount},\"kept\":${result.keptCount}," +
        "\"removed\":${result.removedCount},\"inputChecksum\":\"${result.inputChecksum}\"," +
        "\"outputChecksum\":\"${result.outputChecksum}\"," +
        "\"evidenceHash\":\"${result.evidenceHash}\"," +
        "\"rejections\":${ckbCleanRejectionCountsJson(result.rejectionCounts)}}"
}

private func ckbCleanRejectionCountsJson(counts: HashMap<String, Int64>): String {
    let entries = ArrayList<String>()
    for ((key, value) in counts) {
        entries.add("\"${ckbCleanJsonEscape(key)}\":${value}")
    }
    let ordered = entries.toArray(); sort(ordered)
    let out = StringBuilder(); out.append("{")
    for (index in 0..ordered.size) {
        if (index > 0) { out.append(",") }
        out.append(ordered[index])
    }
    out.append("}"); out.toString()
}

private func ckbCleanImmutableManifestDiagnostic(text: String,
    materialized: CkbCandidateMaterializationResult, version: String): String {
    if (ckbCleanManifestField(text, "schemaVersion") != "p5-candidate-durable-v2" ||
        ckbCleanManifestField(text, "version") != version ||
        ckbCleanManifestField(text, "rawCount") != "${materialized.rawCount}" ||
        ckbCleanManifestField(text, "normalizedCount") != "${materialized.normalizedCount}" ||
        ckbCleanManifestField(text, "batchCount") != "${materialized.batchCount}" ||
        ckbCleanManifestField(text, "rawEvidenceHash") != materialized.rawEvidenceHash ||
        ckbCleanManifestField(text, "normalizedEvidenceHash") != materialized.normalizedEvidenceHash ||
        ckbCleanManifestField(text, "manifestEvidenceHash") != materialized.manifestEvidenceHash) {
        return "clean_candidate_immutable_manifest_mismatch"
    }
    for (index in 0..materialized.batchCount) {
        if (ckbCleanManifestField(text, "batch${index}Path") == "" ||
            ckbCleanManifestField(text, "batch${index}Count") == "" ||
            ckbCleanManifestField(text, "batch${index}Hash") == "") {
            return "clean_candidate_immutable_batch_manifest_mismatch"
        }
    }
    "ok"
}

private func ckbCleanManifestField(text: String, key: String): String {
    let prefix = "${key}="
    for (line in text.split("\n")) {
        if (line.startsWith(prefix)) {
            return line[prefix.size..line.size]
        }
    }
    ""
}

private func ckbCleanBoundManifestJson(candidate: CkbCompleteCleanStudentCandidate,
    materialized: CkbCandidateMaterializationResult, immutableManifestHash: String): String {
    let removed = candidate.historicalNormalizedRemoved +
        candidate.historicalActiveRemoved + candidate.historicalRawRemoved
    let body = "{\"schemaVersion\":\"ckb-clean-candidate-v1\",\"ok\":true," +
        "\"versionHash\":\"${benchmarkGapSha256(candidate.version)}\"," +
        "\"rawCount\":${candidate.rawRecords.size}," +
        "\"normalizedCount\":${candidate.normalizedRecords.size}," +
        "\"activeCount\":${candidate.activeRecords.size}," +
        "\"historicalRemoved\":${removed}," +
        "\"candidateChecksum\":\"${candidate.candidateChecksum}\"," +
        "\"authorityHash\":\"${ckbCleanJsonEscape(candidate.authorityHash)}\"," +
        "\"auditEvidenceHash\":\"${candidate.auditEvidenceHash}\"," +
        "\"materializationManifestEvidenceHash\":\"${materialized.manifestEvidenceHash}\"," +
        "\"immutableManifestHash\":\"${immutableManifestHash}\"," +
        "\"rawEvidenceHash\":\"${materialized.rawEvidenceHash}\"," +
        "\"normalizedEvidenceHash\":\"${materialized.normalizedEvidenceHash}\"," +
        "\"batchCount\":${materialized.batchCount}"
    body + ",\"evidenceHash\":\"${benchmarkGapSha256(body + "}")}\"}\n"
}

private func ckbCleanCloneMetadataForVersion(
    metadata: KnowledgeMetadata, version: String): KnowledgeMetadata {
    let clone = KnowledgeMetadata()
    clone.sourceId = metadata.sourceId; clone.sourceType = metadata.sourceType
    clone.sourceUrl = metadata.sourceUrl; clone.repo = metadata.repo
    clone.path = metadata.path; clone.symbol = metadata.symbol
    clone.commit = metadata.commit; clone.docVersion = metadata.docVersion
    clone.targetVersion = metadata.targetVersion
    clone.sourceSet = metadata.sourceSet
    clone.versionResolutionId = metadata.versionResolutionId
    clone.crawlAt = metadata.crawlAt; clone.indexedAt = metadata.indexedAt
    clone.knowledgeVersion = version; clone.candidateVersion = version
    clone.contentSize = metadata.contentSize; clone.trustLevel = metadata.trustLevel
    clone.reviewState = metadata.reviewState; clone.license = metadata.license
    clone.repoVisibility = metadata.repoVisibility
    let derived = ArrayList<String>()
    for (value in metadata.derivedFrom) { derived.add(value) }
    clone.derivedFrom = derived.toArray()
    clone
}

private func ckbCleanCloneRawForVersion(record: RawRecord, version: String): RawRecord {
    let clone = RawRecord(); clone.sourceId = record.sourceId; clone.title = record.title
    clone.content = record.content; clone.contentHash = record.contentHash
    clone.requiresReview = record.requiresReview
    clone.metadata = ckbCleanCloneMetadataForVersion(record.metadata, version)
    clone
}

private func ckbCleanCloneNormalizedForVersion(
    record: NormalizedRecord, version: String): NormalizedRecord {
    let clone = NormalizedRecord(); clone.sourceId = record.sourceId
    clone.recordKind = record.recordKind; clone.title = record.title
    clone.chunk = record.chunk; clone.citation = record.citation; clone.score = record.score
    clone.requiresReview = record.requiresReview
    clone.metadata = ckbCleanCloneMetadataForVersion(record.metadata, version)
    clone
}
