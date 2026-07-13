package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.collection.HashMap
import stdx.encoding.json.*

public class CangjieBenchmarkGapInput {
    public var caseId: String = ""
    public var benchmark: String = "Cangjie-HumanEval"
    public var taskText: String = ""
    public var visibleTestExcerpt: String = ""
    public var compilerOutput: String = ""
    public var missingKnowledge: String = ""
    public var interfaceId: String = ""
    public var contentFamily: String = ""
    public var updateMechanism: String = ""
    public var targetVersion: String = ""
    public var officialCitation: String = ""

    public init() {}
}

public class CangjieBenchmarkGapCurationResult {
    public var ok: Bool = true
    public var accepted: Int64 = 0
    public var rejected: Int64 = 0
    public var duplicates: Int64 = 0
    public var diagnostic: String = "ok"
    public var records: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieBenchmarkGapParseResult {
    public var ok: Bool = true
    public var inputs: ArrayList<CangjieBenchmarkGapInput> = ArrayList<CangjieBenchmarkGapInput>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func curateBenchmarkGapRecords(inputs: ArrayList<CangjieBenchmarkGapInput>, targetVersion!: String = cangjieDefaultTargetVersion()): CangjieBenchmarkGapCurationResult {
    let result = CangjieBenchmarkGapCurationResult()
    let identityHashes = HashMap<String, String>()
    var itemNumber: Int64 = 0
    for (input in inputs) {
        itemNumber += 1
        normalizeBenchmarkGapInput(input, targetVersion)
        let diagnostic = validateBenchmarkGapInput(input)
        if (diagnostic != "") {
            result.rejected += 1
            result.diagnostics.add("item=${itemNumber}:errorCode=${diagnostic}")
            continue
        }
        let identity = canonicalBenchmarkGapIdentity(input)
        let canonicalHash = canonicalBenchmarkGapInputHash(input)
        match (identityHashes.get(identity)) {
            case Some(existingHash) =>
                if (existingHash == canonicalHash) {
                    result.duplicates += 1
                    continue
                }
                result.rejected += 1
                result.diagnostics.add("item=${itemNumber}:errorCode=benchmark_gap_identity_conflict:identityHash=${stableSummaryHash(identity)}")
                continue
            case None => identityHashes.add(identity, canonicalHash)
        }
        result.records.add(benchmarkGapRecord(input, targetVersion))
        result.accepted += 1
    }
    if (result.accepted == 0) {
        result.ok = false
        result.diagnostic = "no_gap_records_accepted"
    }
    if (result.rejected > 0) {
        result.ok = false
        result.records.clear()
        result.diagnostic = benchmarkGapPrimaryDiagnostic(result.diagnostics)
    }
    result
}

public func parseBenchmarkGapInputsJsonl(text: String): CangjieBenchmarkGapParseResult {
    let result = CangjieBenchmarkGapParseResult()
    var lineNumber: Int64 = 0
    for (line in text.split("\n")) {
        lineNumber += 1
        let raw = line.trimAscii()
        if (raw == "") {
            continue
        }
        try {
            let object = JsonValue.fromStr(raw).asObject()
            try {
                let input = CangjieBenchmarkGapInput()
                input.caseId = benchmarkGapJsonString(object, "caseId")
                input.benchmark = benchmarkGapJsonString(object, "benchmark")
                if (input.benchmark == "") {
                    input.benchmark = "Cangjie-HumanEval"
                }
                input.taskText = benchmarkGapJsonString(object, "taskText")
                input.visibleTestExcerpt = benchmarkGapJsonString(object, "visibleTestExcerpt")
                input.compilerOutput = benchmarkGapJsonString(object, "compilerOutput")
                input.missingKnowledge = benchmarkGapJsonString(object, "missingKnowledge")
                input.interfaceId = benchmarkGapJsonString(object, "interfaceId")
                input.contentFamily = benchmarkGapJsonString(object, "contentFamily")
                input.updateMechanism = benchmarkGapJsonString(object, "updateMechanism")
                input.targetVersion = benchmarkGapJsonString(object, "targetVersion")
                input.officialCitation = benchmarkGapJsonString(object, "officialCitation")
                result.inputs.add(input)
            } catch (_: Exception) {
                result.ok = false
                result.diagnostics.add("line=${lineNumber}:errorCode=field_contract_invalid")
            }
        } catch (_: Exception) {
            result.ok = false
            result.diagnostics.add("line=${lineNumber}:errorCode=malformed_json")
        }
    }
    result
}

public func curateBenchmarkGapRecordsFromJsonl(text: String, targetVersion!: String = cangjieDefaultTargetVersion()): CangjieBenchmarkGapCurationResult {
    let parsed = parseBenchmarkGapInputsJsonl(text)
    if (!parsed.ok) {
        let result = CangjieBenchmarkGapCurationResult()
        result.ok = false
        result.rejected = parsed.diagnostics.size
        result.diagnostic = benchmarkGapPrimaryDiagnostic(parsed.diagnostics)
        for (diagnostic in parsed.diagnostics) { result.diagnostics.add(diagnostic) }
        return result
    }
    curateBenchmarkGapRecords(parsed.inputs, targetVersion: targetVersion)
}

private func normalizeBenchmarkGapInput(input: CangjieBenchmarkGapInput, fallbackTargetVersion: String): Unit {
    if (input.targetVersion.trimAscii() == "") {
        input.targetVersion = fallbackTargetVersion
    }
    if (input.interfaceId.trimAscii() == "") {
        input.interfaceId = benchmarkGapInterfaceId(input.missingKnowledge)
    }
    if (input.contentFamily.trimAscii() == "") {
        input.contentFamily = benchmarkGapContentFamily(input.missingKnowledge)
    }
    if (input.updateMechanism.trimAscii() == "") {
        input.updateMechanism = "KU-11"
    }
}

private func validateBenchmarkGapInput(input: CangjieBenchmarkGapInput): String {
    let visible = "${input.taskText}\n${input.visibleTestExcerpt}\n${input.compilerOutput}\n${input.officialCitation}\n${input.interfaceId}\n${input.contentFamily}\n${input.updateMechanism}".toAsciiLower()
    if (input.caseId.trimAscii() == "") {
        return "case_id_required"
    }
    if (!benchmarkGapSafeIdentityPart(input.caseId, 256)) {
        return "case_id_invalid"
    }
    if (!benchmarkGapSafeIdentityPart(input.benchmark, 128)) {
        return "benchmark_invalid"
    }
    if (visible.contains("/reference/") || visible.contains("reference/") || visible.contains("\\reference\\") || visible.contains("/hidden/") || visible.contains("hidden/") || visible.contains("\\hidden\\")) {
        return "hidden_or_reference_source_rejected"
    }
    if (input.missingKnowledge.trimAscii() == "") {
        return "missing_knowledge_required"
    }
    if (benchmarkGapRuneLength(input.taskText) > 65536 || benchmarkGapRuneLength(input.visibleTestExcerpt) > 65536 || benchmarkGapRuneLength(input.compilerOutput) > 65536 || benchmarkGapRuneLength(input.missingKnowledge) > 4096) {
        return "benchmark_gap_field_too_long"
    }
    if (input.taskText.trimAscii() == "" && input.compilerOutput.trimAscii() == "") {
        return "visible_failure_signal_required"
    }
    if (input.interfaceId.trimAscii() == "") {
        return "interface_id_required"
    }
    if (input.contentFamily.trimAscii() == "") {
        return "content_family_required"
    }
    if (input.updateMechanism.trimAscii() == "") {
        return "update_mechanism_required"
    }
    if (input.officialCitation.trimAscii() == "") {
        return "official_citation_required"
    }
    if (!input.officialCitation.trimAscii().toAsciiLower().startsWith("https://docs.cangjie-lang.cn/")) {
        return "official_citation_not_allowed"
    }
    let expectedInterface = benchmarkGapInterfaceId(input.missingKnowledge)
    if (input.interfaceId.trimAscii() != expectedInterface) {
        return "interface_mapping_mismatch:${expectedInterface}"
    }
    let expectedFamily = benchmarkGapContentFamily(input.missingKnowledge)
    if (input.contentFamily.trimAscii() != expectedFamily) {
        return "content_family_mapping_mismatch:${expectedFamily}"
    }
    let expectedUpdate = benchmarkGapUpdateMechanism(input.missingKnowledge)
    if (input.updateMechanism.trimAscii() != expectedUpdate) {
        return "update_mechanism_mapping_mismatch:${expectedUpdate}"
    }
    ""
}

public func canonicalBenchmarkGapIdentity(input: CangjieBenchmarkGapInput): String {
    "${input.benchmark.trimAscii().toAsciiLower()}:${input.caseId.trimAscii().toAsciiLower()}"
}

private func canonicalBenchmarkGapInputHash(input: CangjieBenchmarkGapInput): String {
    stableSummaryHash(benchmarkGapCanonicalPart(canonicalBenchmarkGapIdentity(input)) +
        benchmarkGapCanonicalPart(input.taskText) + benchmarkGapCanonicalPart(input.visibleTestExcerpt) +
        benchmarkGapCanonicalPart(input.compilerOutput) + benchmarkGapCanonicalPart(input.missingKnowledge.trimAscii().toAsciiUpper()) +
        benchmarkGapCanonicalPart(input.interfaceId.trimAscii()) + benchmarkGapCanonicalPart(input.contentFamily.trimAscii()) +
        benchmarkGapCanonicalPart(input.updateMechanism.trimAscii()) + benchmarkGapCanonicalPart(input.targetVersion.trimAscii()) +
        benchmarkGapCanonicalPart(input.officialCitation.trimAscii()))
}

private func benchmarkGapCanonicalPart(value: String): String {
    "${value.size}:${value}"
}

private func benchmarkGapPrimaryDiagnostic(diagnostics: ArrayList<String>): String {
    if (diagnostics.size == 0) { return "benchmark_gap_input_rejected" }
    let first = diagnostics[0]
    let marker = "errorCode="
    match (first.indexOf(marker)) {
        case Some(start) =>
            let value = first[(start + marker.size)..first.size]
            match (value.indexOf(":")) {
                case Some(end) => value[..end]
                case None => value
            }
        case None => "benchmark_gap_input_rejected"
    }
}

private func benchmarkGapSafeIdentityPart(raw: String, maxRunes: Int64): Bool {
    let trimmed = raw.trimAscii()
    let chars = trimmed.toRuneArray()
    if (chars.size == 0 || chars.size > maxRunes) { return false }
    for (ch in chars) {
        let asciiAlphaNumeric = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9')
        if (!asciiAlphaNumeric && ch != r'-' && ch != r'_' && ch != r'.') { return false }
    }
    true
}

private func benchmarkGapRuneLength(raw: String): Int64 {
    raw.toRuneArray().size
}

private func benchmarkGapRecord(input: CangjieBenchmarkGapInput, targetVersion: String): NormalizedRecord {
    let record = NormalizedRecord()
    let resolvedTargetVersion = if (input.targetVersion.trimAscii() == "") { targetVersion } else { input.targetVersion.trimAscii() }
    record.sourceId = "curated-gap-${stableSummaryHash("${input.caseId}:${benchmarkGapRecordKey(input)}")}"
    record.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
    record.title = "HumanEval gap ${input.caseId}: ${input.missingKnowledge}"
    record.chunk = "Task: ${input.taskText}\nVisible tests: ${input.visibleTestExcerpt}\nCompiler output: ${input.compilerOutput}\nMissing knowledge: ${input.missingKnowledge}\nInterface ID: ${input.interfaceId}\nContent family: ${input.contentFamily}\nUpdate mechanism: ${input.updateMechanism}"
    record.citation = input.officialCitation
    record.requiresReview = false
    record.metadata.sourceId = record.sourceId
    record.metadata.sourceType = SourceTypes.DERIVED
    record.metadata.sourceSet = CangjieSourceSets.EVAL_SUPPORT
    record.metadata.targetVersion = resolvedTargetVersion
    record.metadata.versionResolutionId = "cangjie-${resolvedTargetVersion}-eval-support-curated"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.REVIEWED
    record.metadata.path = "visible-benchmark/${input.benchmark}/${input.caseId}/${input.interfaceId}"
    record.metadata.symbol = "${input.interfaceId}:${input.missingKnowledge}"
    record.metadata.contentSize = record.chunk.size
    record
}

private func benchmarkGapRecordKey(input: CangjieBenchmarkGapInput): String {
    "${input.interfaceId}:${input.contentFamily}:${input.updateMechanism}:${input.missingKnowledge}"
}

private func benchmarkGapInterfaceId(missingKnowledge: String): String {
    let gap = benchmarkGapPrimaryCode(missingKnowledge)
    if (gap == "G-RECIPE" || gap == "G-TIMEOUT" || gap == "G-EDGE") { return "KI-07" }
    if (gap == "G-EVALVALUE" || gap == "G-EVALENTRY") { return "KI-05" }
    if (gap == "G-ARRAYLIST" || gap == "G-STRING" || gap == "G-HASHMAP" || gap == "G-FLOAT64") { return "KI-02" }
    "KI-04"
}

private func benchmarkGapContentFamily(missingKnowledge: String): String {
    let gap = benchmarkGapPrimaryCode(missingKnowledge)
    if (gap == "G-RECIPE" || gap == "G-TIMEOUT" || gap == "G-EDGE" || gap == "G-EVALVALUE" || gap == "G-EVALENTRY") { return "KC-05" }
    if (gap == "G-ARRAYLIST" || gap == "G-STRING" || gap == "G-HASHMAP" || gap == "G-FLOAT64") { return "KC-02" }
    "KC-01"
}

private func benchmarkGapUpdateMechanism(_missingKnowledge: String): String {
    "KU-11"
}

private func benchmarkGapPrimaryCode(missingKnowledge: String): String {
    let raw = missingKnowledge.trimAscii()
    if (raw == "") {
        return "G-RECIPE"
    }
    let first = raw.split(",")[0].trimAscii().toAsciiUpper()
    if (first.startsWith("G-")) {
        return first
    }
    let lower = raw.toAsciiLower()
    if (lower.contains("arraylist")) { return "G-ARRAYLIST" }
    if (lower.contains("hashmap")) { return "G-HASHMAP" }
    if (lower.contains("string") || lower.contains("rune")) { return "G-STRING" }
    if (lower.contains("float")) { return "G-FLOAT64" }
    if (lower.contains("evalvalue")) { return "G-EVALVALUE" }
    if (lower.contains("evalentry")) { return "G-EVALENTRY" }
    if (lower.contains("int") || lower.contains("numeric")) { return "G-INT64" }
    "G-RECIPE"
}

private func benchmarkGapJsonString(object: JsonObject, field: String): String {
    match (object.get(field)) {
        case Some(value) => value.asString().getValue()
        case None => ""
    }
}
