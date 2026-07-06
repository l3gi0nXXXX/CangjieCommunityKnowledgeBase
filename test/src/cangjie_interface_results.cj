package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CangjieSymbolCardResult {
    public var ok: Bool = true
    public var diagnostic: String = "ok"
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var versionResolutionId: String = ""
    public var evidenceHash: String = ""
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var sourceSet: String = ""
    public var knowledgeVersion: String = ""
    public var degraded: Bool = false
    public var truncated: Bool = false
    public var pack: CangjieKnowledgePack = CangjieKnowledgePack()

    public init() {}
}

public class CangjieDocSectionResult {
    public var ok: Bool = true
    public var diagnostic: String = "ok"
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var versionResolutionId: String = ""
    public var evidenceHash: String = ""
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var sourceSet: String = ""
    public var knowledgeVersion: String = ""
    public var degraded: Bool = false
    public var truncated: Bool = false
    public var pack: CangjieKnowledgePack = CangjieKnowledgePack()

    public init() {}
}

public class CangjieToolManualResult {
    public var ok: Bool = true
    public var diagnostic: String = "ok"
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var versionResolutionId: String = ""
    public var evidenceHash: String = ""
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var sourceSet: String = ""
    public var knowledgeVersion: String = ""
    public var degraded: Bool = false
    public var truncated: Bool = false
    public var pack: CangjieKnowledgePack = CangjieKnowledgePack()

    public init() {}
}

public class CangjieNegativeRulesResult {
    public var ok: Bool = true
    public var diagnostic: String = "ok"
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var versionResolutionId: String = ""
    public var evidenceHash: String = ""
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var sourceSet: String = ""
    public var knowledgeVersion: String = ""
    public var degraded: Bool = false
    public var truncated: Bool = false
    public var pack: CangjieKnowledgePack = CangjieKnowledgePack()

    public init() {}
}

public class CangjieCorpusFreshnessResult {
    public var ok: Bool = true
    public var diagnostic: String = "ok"
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var versionResolutionId: String = ""
    public var evidenceHash: String = ""
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var sourceSet: String = "mixed"
    public var activeKnowledgeVersion: String = ""
    public var candidateKnowledgeVersion: String = ""
    public var failedCandidateVersion: String = ""
    public var degraded: Bool = false
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public var report: CangjieCorpusFreshnessReport = CangjieCorpusFreshnessReport()

    public init() {}
}

public func cangjieSymbolCardResultFromPack(pack: CangjieKnowledgePack, sourceSet!: String = ""): CangjieSymbolCardResult {
    let result = CangjieSymbolCardResult()
    cangjieInterfaceCopyPackFields(result, pack, sourceSet)
    result
}

public func cangjieDocSectionResultFromPack(pack: CangjieKnowledgePack, sourceSet!: String = ""): CangjieDocSectionResult {
    let result = CangjieDocSectionResult()
    cangjieInterfaceCopyPackFields(result, pack, sourceSet)
    result
}

public func cangjieToolManualResultFromPack(pack: CangjieKnowledgePack, sourceSet!: String = ""): CangjieToolManualResult {
    let result = CangjieToolManualResult()
    cangjieInterfaceCopyPackFields(result, pack, sourceSet)
    result
}

public func cangjieNegativeRulesResultFromPack(pack: CangjieKnowledgePack, sourceSet!: String = ""): CangjieNegativeRulesResult {
    let result = CangjieNegativeRulesResult()
    cangjieInterfaceCopyPackFields(result, pack, sourceSet)
    result
}

public func cangjieCorpusFreshnessResultFromReport(report: CangjieCorpusFreshnessReport): CangjieCorpusFreshnessResult {
    let result = CangjieCorpusFreshnessResult()
    result.ok = report.ok
    result.targetVersion = report.targetVersion
    result.versionResolutionId = "freshness-${stableSummaryHash("${report.targetVersion}:${report.activeKnowledgeVersion}")}"
    result.activeKnowledgeVersion = report.activeKnowledgeVersion
    result.candidateKnowledgeVersion = report.candidateKnowledgeVersion
    result.failedCandidateVersion = report.failedCandidateVersion
    result.degraded = report.degraded
    result.diagnostic = cangjieInterfaceDiagnostic(report.degraded, report.diagnostics)
    result.evidenceHash = cangjieCorpusFreshnessEvidenceHash(report)
    result.report = report
    for (diagnostic in report.diagnostics) {
        result.diagnostics.add(diagnostic)
    }
    result
}

public func renderCangjieSymbolCardResultJson(result: CangjieSymbolCardResult): String {
    cangjieInterfacePackResultJson("symbol_card", result.ok, result.diagnostic, result.targetVersion, result.versionResolutionId, result.evidenceHash, result.sourceSet, result.knowledgeVersion, result.degraded, result.truncated, result.citations, result.pack, "symbolCards")
}

public func renderCangjieDocSectionResultJson(result: CangjieDocSectionResult): String {
    cangjieInterfacePackResultJson("doc_section", result.ok, result.diagnostic, result.targetVersion, result.versionResolutionId, result.evidenceHash, result.sourceSet, result.knowledgeVersion, result.degraded, result.truncated, result.citations, result.pack, "docSections")
}

public func renderCangjieToolManualResultJson(result: CangjieToolManualResult): String {
    cangjieInterfacePackResultJson("tool_manual", result.ok, result.diagnostic, result.targetVersion, result.versionResolutionId, result.evidenceHash, result.sourceSet, result.knowledgeVersion, result.degraded, result.truncated, result.citations, result.pack, "manuals")
}

public func renderCangjieNegativeRulesResultJson(result: CangjieNegativeRulesResult): String {
    cangjieInterfacePackResultJson("negative_rules", result.ok, result.diagnostic, result.targetVersion, result.versionResolutionId, result.evidenceHash, result.sourceSet, result.knowledgeVersion, result.degraded, result.truncated, result.citations, result.pack, "rules")
}

public func renderCangjieCorpusFreshnessResultJson(result: CangjieCorpusFreshnessResult): String {
    var out = cangjieInterfaceResultPrefix("corpus_freshness", result.ok, result.diagnostic, result.targetVersion, result.versionResolutionId, result.evidenceHash, result.sourceSet, result.activeKnowledgeVersion, result.degraded, false, result.citations, "", "", "", "")
    out += ",\"activeKnowledgeVersion\":\"${cangjieInterfaceJsonEscape(result.activeKnowledgeVersion)}\",\"candidateKnowledgeVersion\":\"${cangjieInterfaceJsonEscape(result.candidateKnowledgeVersion)}\",\"failedCandidateVersion\":\"${cangjieInterfaceJsonEscape(result.failedCandidateVersion)}\",\"diagnostics\":${cangjieInterfaceStringArrayJson(result.diagnostics)},\"sources\":["
    for (i in 0..result.report.sources.size) {
        if (i > 0) {
            out += ","
        }
        let source = result.report.sources[i]
        out += "{\"sourceSet\":\"${cangjieInterfaceJsonEscape(source.sourceSet)}\",\"sourceFamily\":\"${cangjieInterfaceJsonEscape(source.sourceFamily)}\",\"sourceRepo\":\"${cangjieInterfaceJsonEscape(source.sourceRepo)}\",\"sourceRef\":\"${cangjieInterfaceJsonEscape(source.sourceRef)}\",\"refKind\":\"${cangjieInterfaceJsonEscape(source.refKind)}\",\"resolvedCommit\":\"${cangjieInterfaceJsonEscape(source.resolvedCommit)}\",\"contentHash\":\"${cangjieInterfaceJsonEscape(source.contentHash)}\",\"targetVersion\":\"${cangjieInterfaceJsonEscape(source.targetVersion)}\",\"crawlAt\":\"${cangjieInterfaceJsonEscape(source.crawlAt)}\",\"indexedAt\":\"${cangjieInterfaceJsonEscape(source.indexedAt)}\",\"staleness\":\"${cangjieInterfaceJsonEscape(source.staleness)}\",\"status\":\"${cangjieInterfaceJsonEscape(source.status)}\"}"
    }
    out + "]}"
}

private func cangjieInterfaceCopyPackFields(result: CangjieSymbolCardResult, pack: CangjieKnowledgePack, sourceSet: String): Unit {
    result.ok = !pack.degraded
    result.diagnostic = cangjieInterfacePackDiagnostic(pack)
    result.targetVersion = pack.targetVersion
    result.versionResolutionId = pack.versionResolutionId
    result.evidenceHash = cangjiePackEvidenceHash(pack)
    result.sourceSet = cangjieInterfaceSourceSet(sourceSet, pack)
    result.knowledgeVersion = pack.knowledgeVersion
    result.degraded = pack.degraded
    result.truncated = pack.truncated
    result.pack = pack
    cangjieInterfaceCopyCitations(result.citations, pack.citations)
}

private func cangjieInterfaceCopyPackFields(result: CangjieDocSectionResult, pack: CangjieKnowledgePack, sourceSet: String): Unit {
    result.ok = !pack.degraded
    result.diagnostic = cangjieInterfacePackDiagnostic(pack)
    result.targetVersion = pack.targetVersion
    result.versionResolutionId = pack.versionResolutionId
    result.evidenceHash = cangjiePackEvidenceHash(pack)
    result.sourceSet = cangjieInterfaceSourceSet(sourceSet, pack)
    result.knowledgeVersion = pack.knowledgeVersion
    result.degraded = pack.degraded
    result.truncated = pack.truncated
    result.pack = pack
    cangjieInterfaceCopyCitations(result.citations, pack.citations)
}

private func cangjieInterfaceCopyPackFields(result: CangjieToolManualResult, pack: CangjieKnowledgePack, sourceSet: String): Unit {
    result.ok = !pack.degraded
    result.diagnostic = cangjieInterfacePackDiagnostic(pack)
    result.targetVersion = pack.targetVersion
    result.versionResolutionId = pack.versionResolutionId
    result.evidenceHash = cangjiePackEvidenceHash(pack)
    result.sourceSet = cangjieInterfaceSourceSet(sourceSet, pack)
    result.knowledgeVersion = pack.knowledgeVersion
    result.degraded = pack.degraded
    result.truncated = pack.truncated
    result.pack = pack
    cangjieInterfaceCopyCitations(result.citations, pack.citations)
}

private func cangjieInterfaceCopyPackFields(result: CangjieNegativeRulesResult, pack: CangjieKnowledgePack, sourceSet: String): Unit {
    result.ok = !pack.degraded
    result.diagnostic = cangjieInterfacePackDiagnostic(pack)
    result.targetVersion = pack.targetVersion
    result.versionResolutionId = pack.versionResolutionId
    result.evidenceHash = cangjiePackEvidenceHash(pack)
    result.sourceSet = cangjieInterfaceSourceSet(sourceSet, pack)
    result.knowledgeVersion = pack.knowledgeVersion
    result.degraded = pack.degraded
    result.truncated = pack.truncated
    result.pack = pack
    cangjieInterfaceCopyCitations(result.citations, pack.citations)
}

private func cangjieInterfacePackResultJson(kind: String, ok: Bool, diagnostic: String, targetVersion: String, versionResolutionId: String, evidenceHash: String, sourceSet: String, knowledgeVersion: String, degraded: Bool, truncated: Bool, citations: ArrayList<SourceReference>, pack: CangjieKnowledgePack, itemAlias: String): String {
    var out = cangjieInterfaceResultPrefix(kind, ok, diagnostic, targetVersion, versionResolutionId, evidenceHash, sourceSet, knowledgeVersion, degraded, truncated, citations, pack.sourceRef, pack.resolvedCommit, pack.contentHash, pack.sourceRepo)
    out += ",\"queryId\":\"${cangjieInterfaceJsonEscape(pack.queryId)}\",\"task\":\"${cangjieInterfaceJsonEscape(pack.task)}\""
    out += ",\"${itemAlias}\":${cangjieInterfaceKnowledgeItemsJson(pack.items)},\"items\":${cangjieInterfaceKnowledgeItemsJson(pack.items)},\"apiItems\":${cangjieInterfaceApiItemsJson(pack.apiItems)},\"examples\":${cangjieInterfaceExamplesJson(pack.examples)},\"diagnostics\":${cangjieInterfaceDiagnosticItemsJson(pack.diagnostics)},\"notes\":${cangjieInterfaceStringArrayJson(pack.notes)}}"
    out
}

private func cangjieInterfaceResultPrefix(kind: String, ok: Bool, diagnostic: String, targetVersion: String, versionResolutionId: String, evidenceHash: String, sourceSet: String, knowledgeVersion: String, degraded: Bool, truncated: Bool, citations: ArrayList<SourceReference>, sourceRef: String, resolvedCommit: String, contentHash: String, sourceRepo: String): String {
    "{\"resultType\":\"${cangjieInterfaceJsonEscape(kind)}\",\"ok\":${ok},\"diagnostic\":\"${cangjieInterfaceJsonEscape(diagnostic)}\",\"targetVersion\":\"${cangjieInterfaceJsonEscape(targetVersion)}\",\"versionResolutionId\":\"${cangjieInterfaceJsonEscape(versionResolutionId)}\",\"sourceRef\":\"${cangjieInterfaceJsonEscape(sourceRef)}\",\"resolvedCommit\":\"${cangjieInterfaceJsonEscape(resolvedCommit)}\",\"contentHash\":\"${cangjieInterfaceJsonEscape(contentHash)}\",\"sourceRepo\":\"${cangjieInterfaceJsonEscape(sourceRepo)}\",\"evidenceHash\":\"${cangjieInterfaceJsonEscape(evidenceHash)}\",\"citations\":${cangjieInterfaceCitationsJson(citations)},\"sourceSet\":\"${cangjieInterfaceJsonEscape(sourceSet)}\",\"knowledgeVersion\":\"${cangjieInterfaceJsonEscape(knowledgeVersion)}\",\"degraded\":${degraded},\"truncated\":${truncated}"
}

private func cangjieInterfacePackDiagnostic(pack: CangjieKnowledgePack): String {
    if (pack.degraded) {
        for (note in pack.notes) {
            if (note != "") {
                return note
            }
        }
        return "degraded"
    }
    for (note in pack.notes) {
        if (note == "exact_hit") {
            return "exact_hit"
        }
    }
    "ok"
}

private func cangjieInterfaceDiagnostic(degraded: Bool, diagnostics: ArrayList<String>): String {
    if (diagnostics.size > 0) {
        return diagnostics[0]
    }
    if (degraded) {
        return "degraded"
    }
    "ok"
}

private func cangjieInterfaceSourceSet(raw: String, pack: CangjieKnowledgePack): String {
    let clean = raw.trimAscii()
    if (clean != "") {
        return clean
    }
    if (pack.citations.size > 0 || pack.items.size > 0 || pack.apiItems.size > 0 || pack.examples.size > 0 || pack.diagnostics.size > 0) {
        return "mixed"
    }
    ""
}

private func cangjiePackEvidenceHash(pack: CangjieKnowledgePack): String {
    var seed = "${pack.versionResolutionId}|${pack.knowledgeVersion}|${pack.targetVersion}|${pack.items.size}|${pack.apiItems.size}|${pack.examples.size}|${pack.diagnostics.size}"
    for (citation in pack.citations) {
        seed += "|${citation.sourceId}:${citation.citation}:${citation.knowledgeVersion}"
    }
    for (note in pack.notes) {
        seed += "|note:${note}"
    }
    stableSummaryHash(seed)
}

private func cangjieCorpusFreshnessEvidenceHash(report: CangjieCorpusFreshnessReport): String {
    var seed = "${report.activeKnowledgeVersion}|${report.candidateKnowledgeVersion}|${report.failedCandidateVersion}|${report.targetVersion}|${report.degraded}"
    for (source in report.sources) {
        seed += "|${source.sourceSet}:${source.sourceRepo}:${source.sourceRef}:${source.resolvedCommit}:${source.contentHash}:${source.staleness}:${source.status}"
    }
    for (diagnostic in report.diagnostics) {
        seed += "|diagnostic:${diagnostic}"
    }
    stableSummaryHash(seed)
}

private func cangjieInterfaceCopyCitations(target: ArrayList<SourceReference>, source: ArrayList<SourceReference>): Unit {
    for (citation in source) {
        target.add(SourceReference(citation.sourceId, citation.citation, citation.knowledgeVersion))
    }
}

private func cangjieInterfaceKnowledgeItemsJson(items: ArrayList<CangjieKnowledgeItem>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        let item = items[i]
        out += "{\"kind\":\"${cangjieInterfaceJsonEscape(item.kind)}\",\"title\":\"${cangjieInterfaceJsonEscape(item.title)}\",\"content\":\"${cangjieInterfaceJsonEscape(item.content)}\",\"module\":\"${cangjieInterfaceJsonEscape(item.module)}\",\"symbol\":\"${cangjieInterfaceJsonEscape(item.symbol)}\",\"importLine\":\"${cangjieInterfaceJsonEscape(item.importLine)}\",\"signature\":\"${cangjieInterfaceJsonEscape(item.signature)}\",\"example\":\"${cangjieInterfaceJsonEscape(item.example)}\",\"citation\":\"${cangjieInterfaceJsonEscape(item.citation)}\",\"sourceId\":\"${cangjieInterfaceJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${cangjieInterfaceJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${cangjieInterfaceJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${cangjieInterfaceJsonEscape(item.trustLevel)}\",\"reviewState\":\"${cangjieInterfaceJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
    }
    out + "]"
}

private func cangjieInterfaceApiItemsJson(items: ArrayList<CangjieApiItem>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        let item = items[i]
        out += "{\"module\":\"${cangjieInterfaceJsonEscape(item.module)}\",\"symbol\":\"${cangjieInterfaceJsonEscape(item.symbol)}\",\"importLine\":\"${cangjieInterfaceJsonEscape(item.importLine)}\",\"signature\":\"${cangjieInterfaceJsonEscape(item.signature)}\",\"summary\":\"${cangjieInterfaceJsonEscape(item.summary)}\",\"example\":\"${cangjieInterfaceJsonEscape(item.example)}\",\"citation\":\"${cangjieInterfaceJsonEscape(item.citation)}\",\"sourceId\":\"${cangjieInterfaceJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${cangjieInterfaceJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${cangjieInterfaceJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${cangjieInterfaceJsonEscape(item.trustLevel)}\",\"reviewState\":\"${cangjieInterfaceJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
    }
    out + "]"
}

private func cangjieInterfaceExamplesJson(items: ArrayList<CangjieExampleItem>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        let item = items[i]
        out += "{\"title\":\"${cangjieInterfaceJsonEscape(item.title)}\",\"code\":\"${cangjieInterfaceJsonEscape(item.code)}\",\"explanation\":\"${cangjieInterfaceJsonEscape(item.explanation)}\",\"module\":\"${cangjieInterfaceJsonEscape(item.module)}\",\"symbol\":\"${cangjieInterfaceJsonEscape(item.symbol)}\",\"citation\":\"${cangjieInterfaceJsonEscape(item.citation)}\",\"sourceId\":\"${cangjieInterfaceJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${cangjieInterfaceJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${cangjieInterfaceJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${cangjieInterfaceJsonEscape(item.trustLevel)}\",\"reviewState\":\"${cangjieInterfaceJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
    }
    out + "]"
}

private func cangjieInterfaceDiagnosticItemsJson(items: ArrayList<CangjieDiagnosticItem>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        let item = items[i]
        out += "{\"rule\":\"${cangjieInterfaceJsonEscape(item.rule)}\",\"message\":\"${cangjieInterfaceJsonEscape(item.message)}\",\"relatedSyntax\":\"${cangjieInterfaceJsonEscape(item.relatedSyntax)}\",\"suggestedQuery\":\"${cangjieInterfaceJsonEscape(item.suggestedQuery)}\",\"citation\":\"${cangjieInterfaceJsonEscape(item.citation)}\",\"sourceId\":\"${cangjieInterfaceJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${cangjieInterfaceJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${cangjieInterfaceJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${cangjieInterfaceJsonEscape(item.trustLevel)}\",\"reviewState\":\"${cangjieInterfaceJsonEscape(item.reviewState)}\",\"executed\":${item.executed}}"
    }
    out + "]"
}

private func cangjieInterfaceCitationsJson(citations: ArrayList<SourceReference>): String {
    var out = "["
    for (i in 0..citations.size) {
        if (i > 0) { out += "," }
        let citation = citations[i]
        out += "{\"sourceId\":\"${cangjieInterfaceJsonEscape(citation.sourceId)}\",\"citation\":\"${cangjieInterfaceJsonEscape(citation.citation)}\",\"knowledgeVersion\":\"${cangjieInterfaceJsonEscape(citation.knowledgeVersion)}\"}"
    }
    out + "]"
}

private func cangjieInterfaceStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) { out += "," }
        out += "\"${cangjieInterfaceJsonEscape(values[i])}\""
    }
    out + "]"
}

private func cangjieInterfaceJsonEscape(raw: String): String {
    let text = redactSensitive(raw)
    let out = StringBuilder()
    for (ch in text.toRuneArray()) {
        if (ch == r'"') {
            out.append("\\\"")
        } else if (ch == r'\\') {
            out.append("\\\\")
        } else if (ch == r'\n') {
            out.append("\\n")
        } else if (ch == r'\r') {
            out.append("\\r")
        } else if (ch == r'\t') {
            out.append("\\t")
        } else {
            out.append(ch)
        }
    }
    out.toString()
}
