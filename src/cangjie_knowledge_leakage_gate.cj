package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}

public class CangjieBenchmarkLeakageAuthority {
    public var fingerprints: ArrayList<String> = ArrayList<String>()
    public var fingerprintSet: HashSet<String> = HashSet<String>()

    public init() {}
}

public class CangjieStudentKnowledgeDiagnostic {
    public var ok: Bool = true
    public var code: String = "ok"
    public var reason: String = ""
    public var matchedField: String = ""

    public init() {}
}

public class CangjieStudentKnowledgeDiagnostics {
    public var diagnostics: ArrayList<CangjieStudentKnowledgeDiagnostic> =
        ArrayList<CangjieStudentKnowledgeDiagnostic>()
    public var scannedFields: Int64 = 0

    public init() {}
}

// The caller owns the authority records. This function only builds an in-memory
// comparison set and never reads an authority path from the Student plane.
public func buildCangjieBenchmarkLeakageAuthority(records: ArrayList<NormalizedRecord>): CangjieBenchmarkLeakageAuthority {
    let authority = CangjieBenchmarkLeakageAuthority()
    for (record in records) {
        cangjieLeakageAddFingerprint(authority, record.sourceId)
        cangjieLeakageAddFingerprint(authority, record.recordKind)
        cangjieLeakageAddFingerprint(authority, record.title)
        cangjieLeakageAddFingerprint(authority, record.chunk)
        cangjieLeakageAddFingerprint(authority, record.citation)
        cangjieLeakageAddFingerprint(authority, record.metadata.sourceId)
        cangjieLeakageAddFingerprint(authority, record.metadata.sourceType)
        cangjieLeakageAddFingerprint(authority, record.metadata.sourceSet)
        cangjieLeakageAddFingerprint(authority, record.metadata.sourceUrl)
        cangjieLeakageAddFingerprint(authority, record.metadata.repo)
        cangjieLeakageAddFingerprint(authority, record.metadata.path)
        cangjieLeakageAddFingerprint(authority, record.metadata.symbol)
        cangjieLeakageAddFingerprint(authority, record.metadata.commit)
        cangjieLeakageAddFingerprint(authority, record.metadata.docVersion)
        cangjieLeakageAddFingerprint(authority, record.metadata.targetVersion)
        cangjieLeakageAddFingerprint(authority, record.metadata.versionResolutionId)
        cangjieLeakageAddFingerprint(authority, record.metadata.crawlAt)
        cangjieLeakageAddFingerprint(authority, record.metadata.indexedAt)
        cangjieLeakageAddFingerprint(authority, record.metadata.knowledgeVersion)
        cangjieLeakageAddFingerprint(authority, record.metadata.candidateVersion)
        cangjieLeakageAddFingerprint(authority, record.metadata.trustLevel)
        cangjieLeakageAddFingerprint(authority, record.metadata.reviewState)
        cangjieLeakageAddFingerprint(authority, record.metadata.license)
        cangjieLeakageAddFingerprint(authority, record.metadata.repoVisibility)
        for (value in record.metadata.derivedFrom) { cangjieLeakageAddFingerprint(authority, value) }
    }
    authority
}

public func cangjieStudentRecordDiagnostic(record: NormalizedRecord,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostic {
    let collected = collectCangjieStudentRecordDiagnostics(record, authority: authority)
    if (collected.diagnostics.size > 0) { return collected.diagnostics[0] }
    CangjieStudentKnowledgeDiagnostic()
}

public func collectCangjieStudentRecordDiagnostics(record: NormalizedRecord,
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostics {
    let result = CangjieStudentKnowledgeDiagnostics()
    result.scannedFields = 27 + record.metadata.derivedFrom.size
    if (record.metadata.reviewState == ReviewStates.CANDIDATE || record.metadata.trustLevel == TrustLevels.WEB_CANDIDATE) {
        cangjieLeakageAddDiagnostic(result,
            cangjieLeakageRejected("approval", "student_record_not_approved"))
    }
    if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT || record.metadata.sourceSet == CangjieSourceSets.EVAL_SUPPORT) {
        cangjieLeakageAddDiagnostic(result, cangjieLeakageRejected(
            if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT) {
                "recordKind"
            } else { "sourceSet" }, "eval_support_not_student_visible"))
    }
    if (record.metadata.sourceSet == CangjieSourceSets.KNOWLEDGE_ATOMS &&
        record.recordKind != CangjieTypedRecordKinds.KNOWLEDGE_ATOM) {
        cangjieLeakageAddDiagnostic(result,
            cangjieLeakageRejected("knowledgeAtom", "atom_projection_invalid"))
    }
    let fields = [
        ("recordKind", record.recordKind),
        ("metadata.sourceId", record.metadata.sourceId),
        ("metadata.sourceType", record.metadata.sourceType),
        ("metadata.sourceSet", record.metadata.sourceSet),
        ("metadata.sourceUrl", record.metadata.sourceUrl),
        ("metadata.repo", record.metadata.repo),
        ("title", record.title),
        ("chunk", record.chunk),
        ("citation", record.citation),
        ("sourceId", record.sourceId),
        ("path", record.metadata.path),
        ("symbol", record.metadata.symbol),
        ("metadata.commit", record.metadata.commit),
        ("metadata.docVersion", record.metadata.docVersion),
        ("metadata.targetVersion", record.metadata.targetVersion),
        ("metadata.versionResolutionId", record.metadata.versionResolutionId),
        ("metadata.crawlAt", record.metadata.crawlAt),
        ("metadata.indexedAt", record.metadata.indexedAt),
        ("metadata.knowledgeVersion", record.metadata.knowledgeVersion),
        ("metadata.candidateVersion", record.metadata.candidateVersion),
        ("metadata.trustLevel", record.metadata.trustLevel),
        ("metadata.reviewState", record.metadata.reviewState),
        ("metadata.license", record.metadata.license),
        ("metadata.repoVisibility", record.metadata.repoVisibility)
    ]
    for (field in fields) {
        let diagnostic = cangjieLeakageTextDiagnostic(field[0], field[1], authority)
        cangjieLeakageAddDiagnostic(result, diagnostic)
    }
    for (value in record.metadata.derivedFrom) {
        let diagnostic = cangjieLeakageTextDiagnostic("derivedFrom", value, authority)
        cangjieLeakageAddDiagnostic(result, diagnostic)
    }
    if (cangjieLeakageCompositeArtifact(record.chunk)) {
        cangjieLeakageAddDiagnostic(result,
            cangjieLeakageRejected("chunk", "student_knowledge_leakage_blocked"))
    }
    if (record.recordKind == CangjieTypedRecordKinds.KNOWLEDGE_ATOM) {
        if (record.metadata.sourceSet != CangjieSourceSets.KNOWLEDGE_ATOMS || !record.sourceId.startsWith("knowledge-atom-") ||
            !record.metadata.path.startsWith("knowledge-atom/") || record.metadata.derivedFrom.size == 0) {
            cangjieLeakageAddDiagnostic(result,
                cangjieLeakageRejected("knowledgeAtom", "atom_projection_invalid"))
        }
        let projection = cangjieLeakageAtomProjection(record.chunk)
        if (validateKnowledgeAtomServingProjection(projection[0], projection[1]) != "") {
            cangjieLeakageAddDiagnostic(result,
                cangjieLeakageRejected("chunk", "student_knowledge_leakage_blocked"))
        }
    }
    result
}

public func validateCangjieStudentKnowledgeRecords(records: ArrayList<NormalizedRecord>,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostic {
    for (record in records) {
        let diagnostic = cangjieStudentRecordDiagnostic(record, authority: authority)
        if (!diagnostic.ok) { return diagnostic }
    }
    CangjieStudentKnowledgeDiagnostic()
}

public func validateCangjieTaskKnowledgeEvidence(pack: CangjieTaskKnowledgePack,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostic {
    let collected = collectCangjieTaskKnowledgeEvidenceDiagnostics(pack,
        authority: authority)
    if (collected.diagnostics.size > 0) { return collected.diagnostics[0] }
    CangjieStudentKnowledgeDiagnostic()
}

public func collectCangjieTaskKnowledgeEvidenceDiagnostics(pack: CangjieTaskKnowledgePack,
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostics {
    let result = CangjieStudentKnowledgeDiagnostics()
    // Request identity is an echoed routing contract, not retrieved knowledge.
    // Count it for field-coverage accounting without treating the caller's
    // benchmark identity as a leakage finding.
    result.scannedFields += 3
    cangjieLeakageScanFields(result, authority, [
        ("pack.knowledgeVersion", pack.knowledgeVersion),
        ("pack.targetVersion", pack.targetVersion),
        ("pack.evidenceHash", pack.evidenceHash),
        ("versionResolution.diagnostic", pack.versionResolution.diagnostic),
        ("versionResolution.targetVersion", pack.versionResolution.targetVersion),
        ("versionResolution.versionPolicy", pack.versionResolution.versionPolicy),
        ("versionResolution.versionResolutionId",
            pack.versionResolution.versionResolutionId)
    ])
    for (source in pack.versionResolution.sources) {
        cangjieLeakageScanFields(result, authority, [
            ("versionResolution.sources.targetVersion", source.targetVersion),
            ("versionResolution.sources.sourceSet", source.sourceSet),
            ("versionResolution.sources.sourceFamily", source.sourceFamily),
            ("versionResolution.sources.sourceRepo", source.sourceRepo),
            ("versionResolution.sources.sourceRef", source.sourceRef),
            ("versionResolution.sources.refKind", source.refKind),
            ("versionResolution.sources.resolvedCommit", source.resolvedCommit),
            ("versionResolution.sources.contentHash", source.contentHash)
        ])
    }
    for (diagnostic in pack.versionResolution.diagnostics) {
        cangjieLeakageScanFields(result, authority,
            [("versionResolution.diagnostics", diagnostic)])
    }
    // Query plan, required-knowledge, and coverage fields are deterministic
    // projections of the caller's request. They remain in field accounting,
    // but only retrieved evidence is eligible for leakage findings.
    for (_ in pack.queryPlan) { result.scannedFields += 7 }
    for (_ in pack.requiredKnowledge) { result.scannedFields += 4 }
    for (item in pack.matchedEvidence) {
        cangjieLeakageScanFields(result, authority, [
            ("matchedEvidence.sourceId", item.sourceId), ("matchedEvidence.title", item.title),
            ("matchedEvidence.citation", item.citation), ("matchedEvidence.provenance", item.provenance),
            ("matchedEvidence.contentHash", item.contentHash),
            ("matchedEvidence.knowledge", item.knowledge), ("matchedEvidence.example", item.example)
        ])
        if (cangjieLeakageCompositeArtifact("${item.title}\n${item.knowledge}\n${item.example}")) {
            cangjieLeakageAddDiagnostic(result,
                cangjieLeakageRejected("matchedEvidence",
                    "student_knowledge_leakage_blocked"))
        }
    }
    for (item in pack.examples) {
        cangjieLeakageScanFields(result, authority, [
            ("examples.exampleId", item.exampleId),
            ("examples.sourceId", item.sourceId), ("examples.title", item.title),
            ("examples.code", item.code), ("examples.explanation", item.explanation),
            ("examples.module", item.module), ("examples.symbol", item.symbol),
            ("examples.citation", item.citation),
            ("examples.versionResolutionId", item.versionResolutionId),
            ("examples.trustLevel", item.trustLevel),
            ("examples.reviewState", item.reviewState),
            ("examples.compileStatus", item.compileStatus),
            ("examples.provenance", item.provenance)
        ])
        if (cangjieLeakageCompositeArtifact("${item.title}\n${item.code}\n${item.explanation}")) {
            cangjieLeakageAddDiagnostic(result,
                cangjieLeakageRejected("examples",
                    "student_knowledge_leakage_blocked"))
        }
    }
    for (item in pack.negativeRules) {
        cangjieLeakageScanFields(result, authority, [
            ("negativeRules.ruleId", item.ruleId), ("negativeRules.title", item.title),
            ("negativeRules.badPattern", item.badPattern), ("negativeRules.replacement", item.replacement),
            ("negativeRules.citation", item.citation),
            ("negativeRules.versionResolutionId", item.versionResolutionId),
            ("negativeRules.provenance", item.provenance)
        ])
        if (cangjieLeakageCompositeArtifact("${item.title}\n${item.badPattern}\n${item.replacement}")) {
            cangjieLeakageAddDiagnostic(result,
                cangjieLeakageRejected("negativeRules",
                    "student_knowledge_leakage_blocked"))
        }
    }
    for (item in pack.citations) {
        cangjieLeakageScanFields(result, authority, [
            ("citations.sourceId", item.sourceId),
            ("citations.citation", item.citation),
            ("citations.knowledgeVersion", item.knowledgeVersion)
        ])
    }
    for (_ in pack.coverage.required) { result.scannedFields += 4 }
    for (note in pack.notes) {
        result.scannedFields += 1
        cangjieLeakageAddDiagnostic(result,
            cangjieLeakageTextDiagnostic("notes", note, authority))
    }
    for (diagnostic in pack.diagnostics) {
        result.scannedFields += 1
        cangjieLeakageAddDiagnostic(result,
            cangjieLeakageTextDiagnostic("diagnostics", diagnostic, authority))
    }
    result
}

public func collectCangjieStudentServingExactEntryDiagnostics(
    entry: CangjieServingExactEntry,
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostics {
    let result = CangjieStudentKnowledgeDiagnostics()
    cangjieLeakageScanFields(result, authority, [
        ("exact.lookupKind", entry.lookupKind), ("exact.key", entry.key),
        ("exact.selector", entry.selector), ("exact.sourceId", entry.sourceId),
        ("exact.documentId", entry.documentId)
    ])
    result
}

public func cangjieStudentVisibleTextDiagnostic(field: String, text: String,
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostic {
    cangjieLeakageTextDiagnostic(field, text, authority)
}

public func cangjieStudentRecordAllowed(record: NormalizedRecord): Bool {
    cangjieStudentRecordDiagnostic(record).ok
}

public func cangjieStudentServingDocumentDiagnostic(
    document: CangjieServingDocument,
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostic {
    let collected = collectCangjieStudentServingDocumentDiagnostics(document,
        authority: authority)
    if (collected.diagnostics.size > 0) { return collected.diagnostics[0] }
    CangjieStudentKnowledgeDiagnostic()
}

public func collectCangjieStudentServingDocumentDiagnostics(
    document: CangjieServingDocument,
    authority!: CangjieBenchmarkLeakageAuthority =
        CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostics {
    let result = CangjieStudentKnowledgeDiagnostics()
    if (document.sourceSet == CangjieSourceSets.EVAL_SUPPORT) {
        cangjieLeakageAddDiagnostic(result,
            cangjieLeakageRejected("serving.sourceSet",
                "eval_support_not_student_visible"))
    }
    for (field in [
        ("serving.documentId", document.documentId),
        ("serving.recordKind", document.recordKind),
        ("serving.title", document.title),
        ("serving.text", document.text),
        ("serving.symbolKey", document.symbolKey),
        ("serving.module", document.module),
        ("serving.sourceSet", document.sourceSet),
        ("serving.trustLevel", document.trustLevel),
        ("serving.reviewState", document.reviewState),
        ("serving.targetVersion", document.targetVersion),
        ("serving.versionResolutionId", document.versionResolutionId),
        ("serving.citation", document.citation),
        ("serving.sourceId", document.sourceId),
        ("serving.rankProfile", document.rankProfile),
        ("serving.diagnostic", document.diagnostic)
    ]) {
        result.scannedFields += 1
        let diagnostic = cangjieLeakageTextDiagnostic(field[0], field[1], authority)
        cangjieLeakageAddDiagnostic(result, diagnostic)
    }
    if (cangjieLeakageCompositeArtifact(document.text)) {
        cangjieLeakageAddDiagnostic(result,
            cangjieLeakageRejected("serving.text",
                "student_knowledge_leakage_blocked"))
    }
    result
}

private func cangjieLeakageAddFingerprint(authority: CangjieBenchmarkLeakageAuthority, raw: String): Unit {
    let clean = cangjieLeakageNormalize(raw).trimAscii()
    if (clean == "") { return }
    for (line in clean.split("\n")) {
        cangjieLeakageAddFingerprintWindows(authority, line.trimAscii())
    }
}

private func cangjieLeakageScanFields(result: CangjieStudentKnowledgeDiagnostics,
    authority: CangjieBenchmarkLeakageAuthority,
    fields: Array<(String, String)>): Unit {
    for (field in fields) {
        result.scannedFields += 1
        cangjieLeakageAddDiagnostic(result,
            cangjieLeakageTextDiagnostic(field[0], field[1], authority))
    }
}

private func cangjieLeakageAddFingerprintWindows(authority: CangjieBenchmarkLeakageAuthority, raw: String): Unit {
    let runes = raw.toRuneArray()
    if (runes.size < 24) { return }
    var start: Int64 = 0
    while (start + 24 <= runes.size) {
        let out = StringBuilder()
        for (i in start..(start + 24)) { out.append(runes[i]) }
        let fingerprint = out.toString()
        if (!authority.fingerprintSet.contains(fingerprint)) {
            authority.fingerprints.add(fingerprint); authority.fingerprintSet.add(fingerprint)
        }
        start += 12
    }
}

private func cangjieLeakageTextDiagnostic(field: String, raw: String,
    authority: CangjieBenchmarkLeakageAuthority): CangjieStudentKnowledgeDiagnostic {
    let clean = cangjieLeakageNormalize(raw)
    if (clean.contains("cj-humaneval-") || clean.contains("cangjie-humaneval") || clean.contains("humaneval") ||
        clean.contains("visible-benchmark/") || clean.contains("curated-gap-") || clean.contains("eval-support-")) {
        return cangjieLeakageRejected(field, "student_knowledge_leakage_blocked")
    }
    let runes = clean.toRuneArray()
    var start: Int64 = 0
    while (start + 24 <= runes.size) {
        let window = StringBuilder()
        for (i in start..(start + 24)) { window.append(runes[i]) }
        if (authority.fingerprintSet.contains(window.toString())) {
            return cangjieLeakageRejected(field, "student_knowledge_leakage_blocked")
        }
        start += 1
    }
    CangjieStudentKnowledgeDiagnostic()
}

private func cangjieLeakageNormalize(raw: String): String {
    let escaped = raw.toAsciiLower()
        .replace("\\u002d", "-").replace("\\u005f", "-")
        .replace("\\u002f", "/").replace("\\u005c", "/")
    let normalized = StringBuilder()
    for (rune in escaped.toRuneArray()) {
        if (rune == r'\u{200b}' || rune == r'\u{200c}' ||
            rune == r'\u{200d}' || rune == r'\u{feff}') {
            continue
        }
        if (rune == r'\\') { normalized.append("/") }
        else if (rune == r'_' || rune == r'\u{2013}' || rune == r'\u{2014}') {
            normalized.append("-")
        } else { normalized.append(rune) }
    }
    normalized.toString()
}

private func cangjieLeakageAddDiagnostic(result: CangjieStudentKnowledgeDiagnostics,
    diagnostic: CangjieStudentKnowledgeDiagnostic): Unit {
    if (diagnostic.ok) { return }
    for (existing in result.diagnostics) {
        if (existing.code == diagnostic.code &&
            existing.matchedField == diagnostic.matchedField) { return }
    }
    result.diagnostics.add(diagnostic)
}

private func cangjieLeakageCompositeArtifact(raw: String): Bool {
    let clean = raw.toAsciiLower()
    var markers: Int64 = 0
    if (clean.contains("task:")) { markers += 1 }
    if (clean.contains("visible tests:")) { markers += 1 }
    if (clean.contains("compiler output:")) { markers += 1 }
    if (clean.contains("missing knowledge:")) { markers += 1 }
    markers >= 2
}

private func cangjieLeakageAtomProjection(chunk: String): (String, String) {
    var knowledge = ""
    var example = ""
    for (line in chunk.split("\n")) {
        let clean = line.trimAscii()
        if (clean.startsWith("Knowledge:")) { knowledge = clean.replace("Knowledge:", "").trimAscii() }
        if (clean.startsWith("Example:")) { example = clean.replace("Example:", "").trimAscii() }
    }
    (knowledge, example)
}

private func cangjieLeakageRejected(field: String, reason: String): CangjieStudentKnowledgeDiagnostic {
    let diagnostic = CangjieStudentKnowledgeDiagnostic()
    diagnostic.ok = false
    diagnostic.code = if (reason == "student_record_not_approved" || reason == "eval_support_not_student_visible" || reason == "atom_projection_invalid") { reason } else { "student_knowledge_leakage_blocked" }
    diagnostic.reason = reason
    diagnostic.matchedField = field
    diagnostic
}
