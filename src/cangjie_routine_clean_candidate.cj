package cangjie_community_knowledge_base

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
    public var manifestEvidenceHash: String = ""
    public var summaryJson: String = ""
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
public func ckbCleanCandidateBaseDiagnostic(store: FileKnowledgeStore,
    protectedRoots!: ArrayList<String> = ArrayList<String>()): CkbCleanCandidateBaseDiagnostic {
    let result = CkbCleanCandidateBaseDiagnostic()
    let pathHash = benchmarkGapSha256(store.root.toString())
    let lower = store.root.toString().toAsciiLower()
    if (lower.contains("ckb-data") || lower.contains("production") || lower.contains("final11")) {
        result.evidenceHash = benchmarkGapSha256("protected:${pathHash}")
        return result
    }
    let stagingPath = ckbCleanCanonicalOutputPath(store.root)
    if (stagingPath[0] != "ok") {
        result.code = stagingPath[0]
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
            result.code = "clean_candidate_base_forbidden"
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
                if (existing == evidence) { continue }
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
        let diagnostic = cangjieStudentRecordDiagnostic(ckbStudentRawAsNormalized(record), authority: authority)
        let identity = if (record.sourceId != "") { record.sourceId } else { benchmarkGapSha256("${record.title}|${record.contentHash}") }
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
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()
): CkbCompleteCleanStudentCandidate {
    let result = CkbCompleteCleanStudentCandidate(); result.version = version
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
    if (!rawCombined.ok || rawCombined.removedCount != 0) {
        result.diagnostic = if (!rawCombined.ok) { rawCombined.errorCode }
            else { "clean_candidate_raw_identity_duplicate" }
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
    let consistency = ckbCleanCandidateConsistencyDiagnostic(result.rawRecords,
        result.normalizedRecords, result.activeRecords, version)
    if (!consistency.ok) {
        result.diagnostic = consistency.code
        result.evidenceHash = consistency.evidenceHash
        return result
    }
    result.candidateChecksum = consistency.candidateChecksum
    let removed = result.historicalNormalizedRemoved + result.historicalActiveRemoved +
        result.historicalRawRemoved
    let body = "{\"schemaVersion\":\"ckb-clean-candidate-v1\",\"ok\":true," +
        "\"versionHash\":\"${benchmarkGapSha256(version)}\",\"rawCount\":${result.rawRecords.size}," +
        "\"normalizedCount\":${result.normalizedRecords.size},\"activeCount\":${result.activeRecords.size}," +
        "\"historicalRemoved\":${removed},\"candidateChecksum\":\"${result.candidateChecksum}\""
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
        if (record.metadata.knowledgeVersion != version ||
            record.metadata.candidateVersion != version) {
            result.code = "clean_candidate_raw_version_mismatch"
            result.evidenceHash = benchmarkGapSha256(ckbCleanRawIdentity(record))
            return result
        }
    }
    if (!ckbCleanSourceIdentitySetsEqual(raw, normalized)) {
        result.code = "clean_candidate_raw_normalized_identity_mismatch"
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
            options.version, authority: authority.authority)
        result.rawCount = candidate.rawRecords.size
        result.normalizedCount = candidate.normalizedRecords.size
        result.activeCount = candidate.activeRecords.size
        result.removedCount = candidate.historicalRawRemoved +
            candidate.historicalNormalizedRemoved + candidate.historicalActiveRemoved
        result.candidateChecksum = candidate.candidateChecksum
        result.manifestEvidenceHash = candidate.evidenceHash
        if (!candidate.ok) {
            result.diagnostic = candidate.diagnostic
            return ckbFinalizeCleanCandidateBuildResult(result)
        }
        if (options.apply) {
            let materialized = staging.saveCandidateSnapshotImmutable(candidate.rawRecords,
                candidate.normalizedRecords, options.version)
            if (!materialized.ok) {
                result.diagnostic = materialized.status
                return ckbFinalizeCleanCandidateBuildResult(result)
            }
            staging.writeLinesAtomically(
                "candidate-artifacts/${options.version}/clean-candidate-manifest.json",
                candidate.manifestJson)
            if (staging.readText(
                "candidate-artifacts/${options.version}/clean-candidate-manifest.json") !=
                candidate.manifestJson) {
                result.diagnostic = "clean_candidate_manifest_readback_mismatch"
                return ckbFinalizeCleanCandidateBuildResult(result)
            }
            result.applied = true
        }
        result.ok = true; result.diagnostic = "ok"
        ckbFinalizeCleanCandidateBuildResult(result)
    } catch (_: Exception) {
        result.diagnostic = "clean_candidate_build_failed"
        ckbFinalizeCleanCandidateBuildResult(result)
    }
}

public func ckbStudentCleanRemovalDiagnostic(kind: String, count: Int64, evidenceHash: String): String {
    "student_clean_${kind}:removed=${count}|evidenceHash=${evidenceHash}"
}

private func ckbCleanNormalizedIdentity(record: NormalizedRecord): String {
    if (record.sourceId != "") {
        return benchmarkGapSha256("${record.sourceId}|${record.recordKind}|${record.title}|" +
            "${record.citation}|${record.metadata.path}|${record.metadata.symbol}")
    }
    benchmarkGapSha256("${record.recordKind}|${record.title}|${record.citation}")
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
    benchmarkGapSha256(out.toString())
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
        "\"manifestEvidenceHash\":\"${ckbCleanJsonEscape(result.manifestEvidenceHash)}\"," +
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
    if (record.sourceId != "") { return record.sourceId }
    benchmarkGapSha256("${record.title}|${record.contentHash}")
}

private func ckbCleanRawEvidence(record: RawRecord): String {
    ckbCleanNormalizedEvidence(ckbStudentRawAsNormalized(record))
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

private func ckbCleanSourceIdentitySetsEqual(raw: ArrayList<RawRecord>,
    normalized: ArrayList<NormalizedRecord>): Bool {
    ckbCleanRawSourceSetHash(raw) == ckbCleanNormalizedSourceSetHash(normalized)
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

private func ckbCleanCloneMetadataForVersion(
    metadata: KnowledgeMetadata, version: String): KnowledgeMetadata {
    let clone = KnowledgeMetadata()
    clone.sourceId = metadata.sourceId; clone.sourceType = metadata.sourceType
    clone.sourceUrl = metadata.sourceUrl; clone.repo = metadata.repo
    clone.path = metadata.path; clone.symbol = metadata.symbol
    clone.commit = metadata.commit; clone.docVersion = metadata.docVersion
    clone.targetVersion = metadata.targetVersion
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
