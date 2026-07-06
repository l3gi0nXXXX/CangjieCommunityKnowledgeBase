package cangjie_community_knowledge_base_test

import std.collection.ArrayList

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
    public var diagnostic: String = "ok"
    public var records: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func curateBenchmarkGapRecords(inputs: ArrayList<CangjieBenchmarkGapInput>, targetVersion!: String = cangjieDefaultTargetVersion()): CangjieBenchmarkGapCurationResult {
    let result = CangjieBenchmarkGapCurationResult()
    for (input in inputs) {
        normalizeBenchmarkGapInput(input, targetVersion)
        let diagnostic = validateBenchmarkGapInput(input)
        if (diagnostic != "") {
            result.rejected += 1
            result.diagnostics.add("${input.caseId}:${diagnostic}")
            continue
        }
        result.records.add(benchmarkGapRecord(input, targetVersion))
        result.accepted += 1
    }
    if (result.accepted == 0) {
        result.ok = false
        result.diagnostic = "no_gap_records_accepted"
    }
    if (result.rejected > 0) {
        result.diagnostic = if (result.accepted > 0) { "partial" } else { "no_gap_records_accepted" }
    }
    result
}

public func parseBenchmarkGapInputsJsonl(text: String): ArrayList<CangjieBenchmarkGapInput> {
    let inputs = ArrayList<CangjieBenchmarkGapInput>()
    for (line in text.split("\n")) {
        let raw = line.trimAscii()
        if (raw == "") {
            continue
        }
        let input = CangjieBenchmarkGapInput()
        input.caseId = cangjieBenchmarkGapJsonStringField(raw, "caseId")
        input.benchmark = cangjieBenchmarkGapJsonStringField(raw, "benchmark")
        if (input.benchmark == "") {
            input.benchmark = "Cangjie-HumanEval"
        }
        input.taskText = cangjieBenchmarkGapJsonStringField(raw, "taskText")
        input.visibleTestExcerpt = cangjieBenchmarkGapJsonStringField(raw, "visibleTestExcerpt")
        input.compilerOutput = cangjieBenchmarkGapJsonStringField(raw, "compilerOutput")
        input.missingKnowledge = cangjieBenchmarkGapJsonStringField(raw, "missingKnowledge")
        input.interfaceId = cangjieBenchmarkGapJsonStringField(raw, "interfaceId")
        input.contentFamily = cangjieBenchmarkGapJsonStringField(raw, "contentFamily")
        input.updateMechanism = cangjieBenchmarkGapJsonStringField(raw, "updateMechanism")
        input.targetVersion = cangjieBenchmarkGapJsonStringField(raw, "targetVersion")
        input.officialCitation = cangjieBenchmarkGapJsonStringField(raw, "officialCitation")
        inputs.add(input)
    }
    inputs
}

public func curateBenchmarkGapRecordsFromJsonl(text: String, targetVersion!: String = cangjieDefaultTargetVersion()): CangjieBenchmarkGapCurationResult {
    curateBenchmarkGapRecords(parseBenchmarkGapInputsJsonl(text), targetVersion: targetVersion)
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
    if (visible.contains("/reference/") || visible.contains("reference/") || visible.contains("\\reference\\") || visible.contains("/hidden/") || visible.contains("hidden/") || visible.contains("\\hidden\\")) {
        return "hidden_or_reference_source_rejected"
    }
    ""
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

private func cangjieBenchmarkGapJsonStringField(text: String, field: String): String {
    let marker = "\"${field}\":\""
    let parts = text.split(marker)
    if (parts.size <= 1) {
        return ""
    }
    let tail = parts[1]
    match (tail.indexOf("\"")) {
        case Some(end) => tail[..end].replace("\\n", "\n").replace("\\\"", "\"").replace("\\\\", "\\")
        case None => ""
    }
}
