package cangjie_community_knowledge_base_test

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

// The caller owns the authority records. This function only builds an in-memory
// comparison set and never reads an authority path from the Student plane.
public func buildCangjieBenchmarkLeakageAuthority(records: ArrayList<NormalizedRecord>): CangjieBenchmarkLeakageAuthority {
    let authority = CangjieBenchmarkLeakageAuthority()
    for (record in records) {
        cangjieLeakageAddFingerprint(authority, record.sourceId)
        cangjieLeakageAddFingerprint(authority, record.title)
        cangjieLeakageAddFingerprint(authority, record.chunk)
        cangjieLeakageAddFingerprint(authority, record.citation)
        cangjieLeakageAddFingerprint(authority, record.metadata.path)
        cangjieLeakageAddFingerprint(authority, record.metadata.symbol)
        for (value in record.metadata.derivedFrom) { cangjieLeakageAddFingerprint(authority, value) }
    }
    authority
}

public func cangjieStudentRecordDiagnostic(record: NormalizedRecord,
    authority!: CangjieBenchmarkLeakageAuthority = CangjieBenchmarkLeakageAuthority()): CangjieStudentKnowledgeDiagnostic {
    if (record.metadata.reviewState == ReviewStates.CANDIDATE || record.metadata.trustLevel == TrustLevels.WEB_CANDIDATE) {
        return cangjieLeakageRejected("approval", "student_record_not_approved")
    }
    if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT || record.metadata.sourceSet == CangjieSourceSets.EVAL_SUPPORT) {
        return cangjieLeakageRejected(if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT) { "recordKind" } else { "sourceSet" }, "eval_support_not_student_visible")
    }
    if (record.metadata.sourceSet == CangjieSourceSets.KNOWLEDGE_ATOMS &&
        record.recordKind != CangjieTypedRecordKinds.KNOWLEDGE_ATOM) {
        return cangjieLeakageRejected("knowledgeAtom", "atom_projection_invalid")
    }
    let fields = [
        ("title", record.title),
        ("chunk", record.chunk),
        ("citation", record.citation),
        ("sourceId", record.sourceId),
        ("path", record.metadata.path),
        ("symbol", record.metadata.symbol)
    ]
    for (field in fields) {
        let diagnostic = cangjieLeakageTextDiagnostic(field[0], field[1], authority)
        if (!diagnostic.ok) { return diagnostic }
    }
    for (value in record.metadata.derivedFrom) {
        let diagnostic = cangjieLeakageTextDiagnostic("derivedFrom", value, authority)
        if (!diagnostic.ok) { return diagnostic }
    }
    if (cangjieLeakageCompositeArtifact(record.chunk)) {
        return cangjieLeakageRejected("chunk", "student_knowledge_leakage_blocked")
    }
    if (record.recordKind == CangjieTypedRecordKinds.KNOWLEDGE_ATOM) {
        if (record.metadata.sourceSet != CangjieSourceSets.KNOWLEDGE_ATOMS || !record.sourceId.startsWith("knowledge-atom-") ||
            !record.metadata.path.startsWith("knowledge-atom/") || record.metadata.derivedFrom.size == 0) {
            return cangjieLeakageRejected("knowledgeAtom", "atom_projection_invalid")
        }
        let projection = cangjieLeakageAtomProjection(record.chunk)
        if (validateKnowledgeAtomServingProjection(projection[0], projection[1]) != "") {
            return cangjieLeakageRejected("chunk", "student_knowledge_leakage_blocked")
        }
    }
    CangjieStudentKnowledgeDiagnostic()
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
    for (item in pack.matchedEvidence) {
        for (field in [("matchedEvidence.sourceId", item.sourceId), ("matchedEvidence.title", item.title),
            ("matchedEvidence.citation", item.citation), ("matchedEvidence.provenance", item.provenance),
            ("matchedEvidence.knowledge", item.knowledge), ("matchedEvidence.example", item.example)]) {
            let diagnostic = cangjieLeakageTextDiagnostic(field[0], field[1], authority)
            if (!diagnostic.ok) { return diagnostic }
        }
        if (cangjieLeakageCompositeArtifact("${item.title}\n${item.knowledge}\n${item.example}")) {
            return cangjieLeakageRejected("matchedEvidence", "student_knowledge_leakage_blocked")
        }
    }
    for (item in pack.examples) {
        for (field in [("examples.sourceId", item.sourceId), ("examples.title", item.title),
            ("examples.code", item.code), ("examples.explanation", item.explanation),
            ("examples.module", item.module), ("examples.symbol", item.symbol),
            ("examples.citation", item.citation), ("examples.provenance", item.provenance)]) {
            let diagnostic = cangjieLeakageTextDiagnostic(field[0], field[1], authority)
            if (!diagnostic.ok) { return diagnostic }
        }
        if (cangjieLeakageCompositeArtifact("${item.title}\n${item.code}\n${item.explanation}")) {
            return cangjieLeakageRejected("examples", "student_knowledge_leakage_blocked")
        }
    }
    for (item in pack.negativeRules) {
        for (field in [("negativeRules.ruleId", item.ruleId), ("negativeRules.title", item.title),
            ("negativeRules.badPattern", item.badPattern), ("negativeRules.replacement", item.replacement),
            ("negativeRules.citation", item.citation), ("negativeRules.provenance", item.provenance)]) {
            let diagnostic = cangjieLeakageTextDiagnostic(field[0], field[1], authority)
            if (!diagnostic.ok) { return diagnostic }
        }
        if (cangjieLeakageCompositeArtifact("${item.title}\n${item.badPattern}\n${item.replacement}")) {
            return cangjieLeakageRejected("negativeRules", "student_knowledge_leakage_blocked")
        }
    }
    for (item in pack.citations) {
        for (field in [("citations.sourceId", item.sourceId), ("citations.citation", item.citation)]) {
            let diagnostic = cangjieLeakageTextDiagnostic(field[0], field[1], authority)
            if (!diagnostic.ok) { return diagnostic }
        }
    }
    CangjieStudentKnowledgeDiagnostic()
}

public func cangjieStudentRecordAllowed(record: NormalizedRecord): Bool {
    cangjieStudentRecordDiagnostic(record).ok
}

private func cangjieLeakageAddFingerprint(authority: CangjieBenchmarkLeakageAuthority, raw: String): Unit {
    let clean = raw.trimAscii().toAsciiLower()
    if (clean == "") { return }
    for (line in clean.split("\n")) {
        cangjieLeakageAddFingerprintWindows(authority, line.trimAscii())
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
    let clean = raw.toAsciiLower()
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
