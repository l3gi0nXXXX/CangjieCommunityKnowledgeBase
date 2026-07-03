package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CangjieBenchmarkGapInput {
    public var caseId: String = ""
    public var benchmark: String = "Cangjie-HumanEval"
    public var taskText: String = ""
    public var visibleTestExcerpt: String = ""
    public var compilerOutput: String = ""
    public var missingKnowledge: String = ""
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

private func validateBenchmarkGapInput(input: CangjieBenchmarkGapInput): String {
    let visible = "${input.taskText}\n${input.visibleTestExcerpt}\n${input.compilerOutput}\n${input.officialCitation}".toAsciiLower()
    if (input.caseId.trimAscii() == "") {
        return "case_id_required"
    }
    if (input.taskText.trimAscii() == "" && input.compilerOutput.trimAscii() == "") {
        return "visible_failure_signal_required"
    }
    if (input.officialCitation.trimAscii() == "") {
        return "official_citation_required"
    }
    if (visible.contains("/reference/") || visible.contains("reference/") || visible.contains("\\reference\\") || visible.contains("/hidden/") || visible.contains("hidden/") || visible.contains("\\hidden\\")) {
        return "hidden_or_reference_source_rejected"
    }
    ""
}

private func benchmarkGapRecord(input: CangjieBenchmarkGapInput, targetVersion: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = "curated-gap-${stableSummaryHash(input.caseId)}"
    record.recordKind = CangjieTypedRecordKinds.EVAL_SUPPORT
    record.title = "HumanEval gap ${input.caseId}: ${input.missingKnowledge}"
    record.chunk = "Task: ${input.taskText}\nVisible tests: ${input.visibleTestExcerpt}\nCompiler output: ${input.compilerOutput}\nMissing knowledge: ${input.missingKnowledge}"
    record.citation = input.officialCitation
    record.requiresReview = false
    record.metadata.sourceId = record.sourceId
    record.metadata.sourceType = SourceTypes.DERIVED
    record.metadata.sourceSet = CangjieSourceSets.EVAL_SUPPORT
    record.metadata.targetVersion = targetVersion
    record.metadata.versionResolutionId = "cangjie-${targetVersion}-eval-support-curated"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.REVIEWED
    record.metadata.path = "visible-benchmark/${input.benchmark}/${input.caseId}"
    record.metadata.symbol = input.missingKnowledge
    record.metadata.contentSize = record.chunk.size
    record
}
