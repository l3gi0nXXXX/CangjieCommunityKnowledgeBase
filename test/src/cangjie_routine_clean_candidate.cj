package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap, HashSet}
import std.fs.{Directory, exists}

public class CkbStudentCleanRecordProjection {
    public var ok: Bool = true
    public var records: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var removedCount: Int64 = 0
    public var evidenceHash: String = ""
    public var errorCode: String = ""

    public init() {}
}

public class CkbStudentCleanRawProjection {
    public var ok: Bool = true
    public var records: ArrayList<RawRecord> = ArrayList<RawRecord>()
    public var removedCount: Int64 = 0
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

public class CkbStudentLeakageFinding {
    public var recordHash: String = ""
    public var code: String = ""
    public var field: String = ""
    public init() {}
}

public class CkbStudentLeakageReport {
    public var ok: Bool = true
    public var recordCount: Int64 = 0
    public var leakageCount: Int64 = 0
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
public func ckbCleanCandidateBaseDiagnostic(store: FileKnowledgeStore): CkbCleanCandidateBaseDiagnostic {
    let result = CkbCleanCandidateBaseDiagnostic()
    let pathHash = stableSummaryHash(store.root.toString())
    let lower = store.root.toString().toAsciiLower()
    if (lower.contains("ckb-data") || lower.contains("production") || lower.contains("final11")) {
        result.evidenceHash = stableSummaryHash("protected:${pathHash}")
        return result
    }
    if (exists(store.root)) {
        try {
            for (_ in Directory.readFrom(store.root)) {
                result.evidenceHash = stableSummaryHash("nonempty:${pathHash}")
                return result
            }
        } catch (_: Exception) {
            result.evidenceHash = stableSummaryHash("unreadable:${pathHash}")
            return result
        }
    }
    result.ok = true; result.code = "clean_candidate_base_allowed"
    result.evidenceHash = stableSummaryHash("empty:${pathHash}")
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
    let report = CkbStudentLeakageReport(); report.recordCount = records.size
    for (record in records) {
        let recordHash = ckbCleanNormalizedEvidence(record)
        ckbCollectLeakageFinding(report, recordHash, cangjieStudentRecordDiagnostic(record, authority: authority))
        let fields = [("title", record.title), ("chunk", record.chunk), ("citation", record.citation),
            ("sourceId", record.sourceId), ("path", record.metadata.path), ("symbol", record.metadata.symbol)]
        for (field in fields) {
            ckbCollectLeakageFinding(report, recordHash,
                cangjieStudentRecordDiagnostic(ckbLeakageFieldProbe(field[0], field[1]), authority: authority))
        }
        for (value in record.metadata.derivedFrom) {
            ckbCollectLeakageFinding(report, recordHash,
                cangjieStudentRecordDiagnostic(ckbLeakageFieldProbe("derivedFrom", value), authority: authority))
        }
    }
    report.ok = report.leakageCount == 0
    let body = StringBuilder()
    for (finding in report.findings) {
        body.append("{\"recordHash\":\""); body.append(finding.recordHash)
        body.append("\",\"code\":\""); body.append(ckbCleanJsonEscape(finding.code))
        body.append("\",\"field\":\""); body.append(ckbCleanJsonEscape(finding.field)); body.append("\"}\n")
    }
    report.json = "{\"ok\":${report.ok},\"recordCount\":${report.recordCount},\"leakageCount\":${report.leakageCount},\"findingsEvidenceHash\":\"${benchmarkGapSha256(body.toString())}\"}\n" + body.toString()
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
        report.evidenceHash = stableSummaryHash(report.jsonl); return report
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
        body.append("{\"atomHash\":\""); body.append(stableSummaryHash(atom.sourceId))
        body.append("\",\"queryHash\":\""); body.append(stableSummaryHash(query))
        body.append("\",\"hitCount\":${lookup.hits.size},\"passed\":${passed}}\n")
    }
    report.ok = report.indexBuildCount == 1 && report.failed == 0 && report.passed == atoms.size
    report.jsonl = "{\"ok\":${report.ok},\"indexBuildCount\":${report.indexBuildCount},\"atomCount\":${report.atomCount},\"passed\":${report.passed},\"failed\":${report.failed}}\n" + body.toString()
    report.evidenceHash = stableSummaryHash(report.jsonl)
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
    let seen = HashSet<String>()
    let removed = ArrayList<String>()
    for (record in records) {
        let diagnostic = cangjieStudentRecordDiagnostic(record, authority: authority)
        let identity = ckbCleanNormalizedIdentity(record)
        if (!diagnostic.ok || seen.contains(identity)) {
            result.removedCount += 1
            removed.add(stableSummaryHash("${identity}|${diagnostic.code}|${diagnostic.matchedField}"))
            continue
        }
        seen.add(identity)
        result.records.add(record)
    }
    result.evidenceHash = ckbCleanEvidenceHash(removed)
    result
}

public func ckbValidateIncomingStudentRecords(records: ArrayList<NormalizedRecord>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentCleanRecordProjection {
    let result = CkbStudentCleanRecordProjection()
    let seen = HashMap<String, String>()
    for (record in records) {
        let diagnostic = cangjieStudentRecordDiagnostic(record, authority: authority)
        if (!diagnostic.ok) {
            result.ok = false
            result.errorCode = diagnostic.code
            result.evidenceHash = stableSummaryHash("${diagnostic.code}|${diagnostic.matchedField}")
            return result
        }
        let identity = ckbCleanNormalizedIdentity(record)
        let evidence = ckbCleanNormalizedEvidence(record)
        match (seen.get(identity)) {
            case Some(existing) =>
                if (existing == evidence) { continue }
                result.ok = false; result.errorCode = "student_record_identity_conflict"
                result.evidenceHash = benchmarkGapSha256("${identity}|${existing}|${evidence}")
                return result
            case None => seen.add(identity, evidence)
        }
        result.records.add(record)
    }
    result.evidenceHash = stableSummaryHash("incoming:${result.records.size}")
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
    result.evidenceHash = stableSummaryHash("clean:${base.evidenceHash}|incoming:${delta.evidenceHash}|out:${result.records.size}")
    result
}

public func ckbCleanHistoricalStudentRawRecords(records: ArrayList<RawRecord>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CkbStudentCleanRawProjection {
    let result = CkbStudentCleanRawProjection()
    let seen = HashSet<String>()
    let removed = ArrayList<String>()
    for (record in records) {
        let diagnostic = cangjieStudentRecordDiagnostic(ckbStudentRawAsNormalized(record), authority: authority)
        let identity = if (record.sourceId != "") { record.sourceId } else { stableSummaryHash("${record.title}|${record.contentHash}") }
        if (!diagnostic.ok || seen.contains(identity)) {
            result.removedCount += 1
            removed.add(stableSummaryHash("${identity}|${diagnostic.code}|${diagnostic.matchedField}"))
            continue
        }
        seen.add(identity)
        result.records.add(record)
    }
    result.evidenceHash = ckbCleanEvidenceHash(removed)
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
    result.evidenceHash = stableSummaryHash("clean-raw:${base.evidenceHash}|out:${result.records.size}")
    result
}

public func ckbStudentCleanRemovalDiagnostic(kind: String, count: Int64, evidenceHash: String): String {
    "student_clean_${kind}:removed=${count}|evidenceHash=${evidenceHash}"
}

private func ckbCleanNormalizedIdentity(record: NormalizedRecord): String {
    if (record.sourceId != "") { return record.sourceId }
    stableSummaryHash("${record.recordKind}|${record.title}|${record.citation}")
}

private func ckbCleanNormalizedEvidence(record: NormalizedRecord): String {
    let body = StringBuilder()
    for (value in [record.recordKind, record.sourceId, record.title, record.chunk, record.citation,
        record.metadata.sourceId, record.metadata.sourceType, record.metadata.sourceSet,
        record.metadata.sourceUrl, record.metadata.repo, record.metadata.path,
        record.metadata.symbol, record.metadata.commit, record.metadata.docVersion,
        record.metadata.targetVersion, record.metadata.versionResolutionId,
        record.metadata.trustLevel, record.metadata.reviewState]) {
        body.append("${value.toArray().size}:${value}|")
    }
    body.append("derivedFrom=${record.metadata.derivedFrom.size}|")
    for (value in record.metadata.derivedFrom) { body.append("${value.toArray().size}:${value}|") }
    benchmarkGapSha256(body.toString())
}

private func ckbCleanEvidenceHash(values: ArrayList<String>): String {
    let out = StringBuilder()
    for (value in values) { out.append(value); out.append("|") }
    stableSummaryHash(out.toString())
}

private func ckbCollectLeakageFinding(report: CkbStudentLeakageReport, recordHash: String,
    diagnostic: CangjieStudentKnowledgeDiagnostic): Unit {
    if (diagnostic.ok) { return }
    for (existing in report.findings) {
        if (existing.recordHash == recordHash && existing.code == diagnostic.code &&
            existing.field == diagnostic.matchedField) { return }
    }
    let finding = CkbStudentLeakageFinding(); finding.recordHash = recordHash
    finding.code = diagnostic.code; finding.field = diagnostic.matchedField
    report.findings.add(finding); report.leakageCount += 1
}

private func ckbLeakageFieldProbe(field: String, value: String): NormalizedRecord {
    let record = NormalizedRecord(); record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.trustLevel = TrustLevels.OFFICIAL; record.metadata.reviewState = ReviewStates.TRUSTED
    if (field == "title") { record.title = value }
    if (field == "chunk") { record.chunk = value }
    if (field == "citation") { record.citation = value }
    if (field == "sourceId") { record.sourceId = value }
    if (field == "path") { record.metadata.path = value }
    if (field == "symbol") { record.metadata.symbol = value }
    if (field == "derivedFrom") { record.metadata.derivedFrom = [value] }
    record
}

private func ckbCleanQueryContainsSelector(query: String, atom: NormalizedRecord): Bool {
    let clean = query.toAsciiLower()
    clean.contains(atom.sourceId.toAsciiLower()) || clean.contains(atom.metadata.path.toAsciiLower()) ||
        clean.contains("humaneval") || clean.contains("visible-benchmark") ||
        clean.contains("curated-gap") || clean.contains("eval-support")
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
