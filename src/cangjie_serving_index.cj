package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.sort.*

public class CangjieServingExactEntry {
    public var lookupKind: String = ""
    public var key: String = ""
    public var selector: String = ""
    public var sourceId: String = ""
    public var documentId: String = ""

    public init() {}
}

public class CangjieServingIndex {
    public var activeKnowledgeVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var records: ArrayList<NormalizedRecord> = ArrayList<NormalizedRecord>()
    public var documents: ArrayList<CangjieServingDocument> = ArrayList<CangjieServingDocument>()
    public var exactEntries: ArrayList<CangjieServingExactEntry> = ArrayList<CangjieServingExactEntry>()
    public var lexicalViewCount: Int64 = 0
    public var symbolViewCount: Int64 = 0
    public var moduleViewCount: Int64 = 0
    public var docViewCount: Int64 = 0
    public var toolViewCount: Int64 = 0
    public var negativeRuleViewCount: Int64 = 0
    public var recipeViewCount: Int64 = 0
    public var exampleViewCount: Int64 = 0
    public var provenanceViewCount: Int64 = 0
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public interface CangjieServingIndexBuildObserver {
    func onServingIndexBuild(recordCount: Int64): Unit
}

public class NoopCangjieServingIndexBuildObserver <: CangjieServingIndexBuildObserver {
    public init() {}
    public func onServingIndexBuild(recordCount: Int64): Unit {}
}

public func buildCangjieServingIndex(records: ArrayList<NormalizedRecord>, activeKnowledgeVersion!: String = "", deadlineAtMillis!: Int64 = 0, deadlineClock!: CkbMillisClock = SystemCkbMillisClock(), buildObserver!: CangjieServingIndexBuildObserver = NoopCangjieServingIndexBuildObserver()): CangjieServingIndex {
    buildObserver.onServingIndexBuild(records.size)
    let index = CangjieServingIndex()
    index.activeKnowledgeVersion = cangjieServingIndexActiveVersion(records, activeKnowledgeVersion)
    var processed: Int64 = 0
    for (record in records) {
        if (processed % 64 == 0) {
            if (deadlineAtMillis > 0 && deadlineClock.nowMillis() >= deadlineAtMillis) {
                index.diagnostics.add("deadline_exceeded:serving_index_build_records:now=${deadlineClock.nowMillis()}:deadline=${deadlineAtMillis}:processed=${processed}:total=${records.size}")
                return index
            }
        }
        if (!cangjieServingIndexRecordAllowed(record)) {
            index.diagnostics.add("serving_index_record_rejected:${record.sourceId}")
            processed += 1
            continue
        }
        index.records.add(record)
        let direct = cangjieServingIndexDocumentFromRecord(record)
        if (direct.recordKind != CangjieServingRecordKinds.SYMBOL_CARD) {
            index.documents.add(direct)
            cangjieServingIndexAddViewCounts(index, direct)
            cangjieServingIndexAddExactEntries(index, direct)
        }
        for (card in extractCangjieSymbols(record)) {
            let symbolDoc = cangjieServingIndexDocumentFromSymbol(card, index.activeKnowledgeVersion)
            if (!symbolDoc.rejected) {
                index.documents.add(symbolDoc)
                cangjieServingIndexAddViewCounts(index, symbolDoc)
                cangjieServingIndexAddExactEntries(index, symbolDoc)
            }
        }
        processed += 1
    }
    if (deadlineAtMillis > 0 && deadlineClock.nowMillis() >= deadlineAtMillis) {
        index.diagnostics.add("deadline_exceeded:serving_index_build_after:now=${deadlineClock.nowMillis()}:deadline=${deadlineAtMillis}:processed=${processed}:total=${records.size}")
        return index
    }
    cangjieServingIndexAddNegativeRuleDocuments(index)
    if (index.documents.size == 0) {
        index.diagnostics.add("serving_index_empty")
    }
    index
}

// Student-facing retrieval must fail closed without changing the internal
// authority/candidate index used by curation and validation workflows.
public func buildCangjieStudentServingIndex(records: ArrayList<NormalizedRecord>, activeKnowledgeVersion!: String = ""): CangjieServingIndex {
    let accepted = ArrayList<NormalizedRecord>()
    let rejectedDiagnostics = ArrayList<String>()
    for (record in records) {
        let diagnostic = cangjieStudentRecordDiagnostic(record)
        if (diagnostic.ok) {
            accepted.add(record)
        } else {
            rejectedDiagnostics.add("serving_index_record_rejected:${diagnostic.code}:${diagnostic.matchedField}")
        }
    }
    let index = buildCangjieServingIndex(accepted, activeKnowledgeVersion: activeKnowledgeVersion)
    for (diagnostic in rejectedDiagnostics) { index.diagnostics.add(diagnostic) }
    index
}

// The durable-validation workset needs only a stable partition map, document
// count, and identity evidence.  Building a full serving index here retained
// every rendered document and exact-entry view before partition validation,
// which exhausts memory on a clean 17k-record rebuild.  Keep only compact
// document identities; partition validation still builds and releases its
// normal serving index at each partition boundary.
public func buildCangjieCandidateValidationWorksetFromRecords(
    records: ArrayList<NormalizedRecord>, activeKnowledgeVersion: String): CangjieCandidateValidationWorkset {
    let workset = CangjieCandidateValidationWorkset()
    let partitions = HashSet<String>()
    let identities = ArrayList<String>()
    let allowed = ArrayList<NormalizedRecord>()
    for (record in records) {
        if (!cangjieServingIndexRecordAllowed(record)) { continue }
        allowed.add(record)
        let partition = cangjieCandidateValidationPartitionId(record.sourceId)
        partitions.add(partition)
        let direct = cangjieServingIndexDocumentFromRecord(record)
        if (direct.recordKind != CangjieServingRecordKinds.SYMBOL_CARD) {
            identities.add("${partition}:${direct.documentId}:${direct.contentHash}")
            workset.documentTotal += 1
        }
        for (card in extractCangjieSymbols(record)) {
            let symbol = cangjieServingIndexDocumentFromSymbol(card, activeKnowledgeVersion)
            if (!symbol.rejected) {
                let symbolPartition = cangjieCandidateValidationPartitionId(symbol.sourceId)
                partitions.add(symbolPartition)
                identities.add("${symbolPartition}:${symbol.documentId}:${symbol.contentHash}")
                workset.documentTotal += 1
            }
        }
    }
    let negativeRules = buildNegativeRuleRecords(allowed)
    for (rule in negativeRules) {
        let sourceId = "negative-rule-${rule.ruleId}"
        let partition = cangjieCandidateValidationPartitionId(sourceId)
        partitions.add(partition)
        identities.add("${partition}:negative:${rule.ruleId}:${rule.versionResolutionId}:${rule.replacement}")
        workset.documentTotal += 1
    }
    if (workset.documentTotal == 0 || partitions.size == 0) { return workset }
    let orderedPartitions = partitions.toArray()
    sort(orderedPartitions)
    for (partition in orderedPartitions) { workset.partitionIds.add(partition) }
    sort(identities)
    let evidence = StringBuilder()
    evidence.append("p6-validation-workset-v2|documents=${workset.documentTotal}")
    for (identity in identities) { evidence.append("|${identity}") }
    workset.evidenceHash = ckbReleaseEvidenceHash(evidence.toString())
    workset.valid = true
    workset
}

// Rehydrates a previously validated durable document artifact. The artifact
// contains the canonical serving documents; exact selectors and view counters
// are deterministically rebuilt without revisiting candidate normalized input.
public func cangjieServingIndexFromDurableDocuments(documents: ArrayList<CangjieServingDocument>,
    activeKnowledgeVersion: String): CangjieServingIndex {
    let index = CangjieServingIndex()
    index.activeKnowledgeVersion = activeKnowledgeVersion
    for (document in documents) {
        index.documents.add(document)
        cangjieServingIndexAddViewCounts(index, document)
        cangjieServingIndexAddExactEntries(index, document)
    }
    if (index.documents.size == 0) {
        index.diagnostics.add("serving_index_empty")
    }
    index
}

public func cangjieServingIndexDeadlineDiagnostic(index: CangjieServingIndex): String {
    for (diagnostic in index.diagnostics) {
        if (diagnostic.startsWith("deadline_exceeded:")) {
            return diagnostic
        }
    }
    ""
}

public func cangjieServingIndexKey(activeKnowledgeVersion: String, sourceSet: String, targetVersion: String, versionResolutionId: String, lookupKind: String, selector: String): String {
    "active=${activeKnowledgeVersion}|sourceSet=${sourceSet}|targetVersion=${targetVersion}|versionResolutionId=${versionResolutionId}|kind=${lookupKind}|selector=${selector.toAsciiLower()}"
}

public func lookupExactSymbol(index: CangjieServingIndex, symbol: String, module!: String = "", sourceSet!: String = "", targetVersion!: String = "", versionResolutionId!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieServingSearchResult {
    let docs = ArrayList<CangjieServingDocument>()
    let clean = symbol.trimAscii().toAsciiLower()
    let cleanModule = module.trimAscii().toAsciiLower()
    if (clean == "") {
        return cangjieServingIndexMiss("empty_symbol")
    }
    for (doc in index.documents) {
        if (docs.size >= cangjieServingIndexBudget(budget)) {
            break
        }
        if (doc.recordKind != CangjieServingRecordKinds.SYMBOL_CARD) {
            continue
        }
        if (!cangjieServingIndexDocAllowed(index, doc, sourceSet, targetVersion, versionResolutionId)) {
            continue
        }
        if (!cangjieServingIndexSymbolMatches(doc, clean)) {
            continue
        }
        if (cleanModule != "" && doc.module.toAsciiLower() != cleanModule && !doc.module.toAsciiLower().contains(cleanModule)) {
            continue
        }
        docs.add(doc)
    }
    let result = cangjieServingIndexResultFromDocs(symbol, docs, budget, "exact_miss")
    if (result.hits.size > 0) {
        result.diagnostic = "exact_hit"
    }
    result
}

public func lookupDocSection(index: CangjieServingIndex, sectionId: String, path!: String = "", heading!: String = "", sourceSet!: String = "", targetVersion!: String = "", versionResolutionId!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieServingSearchResult {
    let docs = ArrayList<CangjieServingDocument>()
    let cleanSection = sectionId.trimAscii().toAsciiLower()
    let cleanPath = path.trimAscii().toAsciiLower()
    let cleanHeading = heading.trimAscii().toAsciiLower()
    if (cleanSection == "" && cleanPath == "" && cleanHeading == "") {
        return cangjieServingIndexMiss("empty_doc_selector")
    }
    for (doc in index.documents) {
        if (docs.size >= cangjieServingIndexBudget(budget)) {
            break
        }
        if (doc.recordKind != CangjieServingRecordKinds.DOC_SECTION) {
            continue
        }
        if (!cangjieServingIndexDocAllowed(index, doc, sourceSet, targetVersion, versionResolutionId)) {
            continue
        }
        let docText = "${doc.sourceId}\n${doc.citation}\n${doc.title}\n${doc.text}".toAsciiLower()
        if (cleanSection != "" && !docText.contains(cleanSection)) {
            continue
        }
        if (cleanPath != "" && !doc.citation.toAsciiLower().contains(cleanPath) && !docText.contains(cleanPath)) {
            continue
        }
        if (cleanHeading != "" && !doc.title.toAsciiLower().contains(cleanHeading)) {
            continue
        }
        docs.add(doc)
    }
    cangjieServingIndexResultFromDocs("${sectionId} ${path} ${heading}", docs, budget, "exact_miss")
}

public func lookupToolManual(index: CangjieServingIndex, tool: String, command!: String = "", sourceSet!: String = "", targetVersion!: String = "", versionResolutionId!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieServingSearchResult {
    let docs = ArrayList<CangjieServingDocument>()
    let cleanTool = tool.trimAscii().toAsciiLower()
    let cleanCommand = command.trimAscii().toAsciiLower()
    if (cleanTool == "") {
        return cangjieServingIndexMiss("empty_tool")
    }
    for (doc in index.documents) {
        if (docs.size >= cangjieServingIndexBudget(budget)) {
            break
        }
        if (doc.recordKind != CangjieTypedRecordKinds.TOOL_MANUAL) {
            continue
        }
        if (!cangjieServingIndexDocAllowed(index, doc, if (sourceSet == "") { CangjieSourceSets.TOOLS } else { sourceSet }, targetVersion, versionResolutionId)) {
            continue
        }
        let text = "${doc.title}\n${doc.text}\n${doc.symbolKey}\n${doc.module}".toAsciiLower()
        if (!text.contains(cleanTool)) {
            continue
        }
        if (cleanCommand != "" && !text.contains(cleanCommand)) {
            continue
        }
        docs.add(doc)
    }
    cangjieServingIndexResultFromDocs("${tool} ${command}", docs, budget, "exact_miss")
}

public func lookupNegativeRules(index: CangjieServingIndex, query: String, sourceSet!: String = "", targetVersion!: String = "", versionResolutionId!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieServingSearchResult {
    let docs = ArrayList<CangjieServingDocument>()
    let clean = query.trimAscii().toAsciiLower()
    if (clean == "") {
        return cangjieServingIndexMiss("empty_negative_rule_query")
    }
    for (doc in index.documents) {
        if (docs.size >= cangjieServingIndexBudget(budget)) {
            break
        }
        if (doc.recordKind != CangjieServingRecordKinds.NEGATIVE_RULE) {
            continue
        }
        if (!cangjieServingIndexDocAllowed(index, doc, sourceSet, targetVersion, versionResolutionId)) {
            continue
        }
        let text = "${doc.title}\n${doc.text}".toAsciiLower()
        if (text.contains(clean) || cangjieServingIndexTokenOverlap(text, clean) > 0) {
            docs.add(doc)
        }
    }
    cangjieServingIndexResultFromDocs(query, docs, budget, "exact_miss")
}

public func lookupModule(index: CangjieServingIndex, module: String, sourceSet!: String = "", targetVersion!: String = "", versionResolutionId!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieServingSearchResult {
    let docs = ArrayList<CangjieServingDocument>()
    let clean = module.trimAscii().toAsciiLower()
    if (clean == "") {
        return cangjieServingIndexMiss("empty_module")
    }
    for (doc in index.documents) {
        if (docs.size >= cangjieServingIndexBudget(budget)) {
            break
        }
        if (!cangjieServingIndexDocAllowed(index, doc, sourceSet, targetVersion, versionResolutionId)) {
            continue
        }
        if (doc.module.toAsciiLower() == clean || doc.module.toAsciiLower().contains(clean) || doc.text.toAsciiLower().contains("module=${clean}") || doc.text.toAsciiLower().contains("package ${clean}")) {
            docs.add(doc)
        }
    }
    cangjieServingIndexResultFromDocs(module, docs, budget, "exact_miss")
}

public func lookupAvailability(index: CangjieServingIndex, symbol: String, sourceSet!: String = "", targetVersion!: String = "", versionResolutionId!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieServingSearchResult {
    let docs = ArrayList<CangjieServingDocument>()
    let clean = symbol.trimAscii().toAsciiLower()
    if (clean == "") {
        return cangjieServingIndexMiss("empty_availability_symbol")
    }
    for (doc in index.documents) {
        if (docs.size >= cangjieServingIndexBudget(budget)) {
            break
        }
        if (!cangjieServingIndexDocAllowed(index, doc, sourceSet, targetVersion, versionResolutionId)) {
            continue
        }
        let text = "${doc.symbolKey}\n${doc.title}\n${doc.text}".toAsciiLower()
        if ((doc.recordKind == CangjieTypedRecordKinds.AVAILABILITY || doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) && text.contains(clean)) {
            docs.add(doc)
        }
    }
    cangjieServingIndexResultFromDocs(symbol, docs, budget, "exact_miss")
}

public func searchHybridServingIndex(index: CangjieServingIndex, request: CangjieServingSearchRequest): CangjieServingSearchResult {
    if (request.symbol.trimAscii() != "") {
        return lookupExactSymbol(index, request.symbol, sourceSet: request.sourceSet, targetVersion: request.targetVersion, versionResolutionId: request.versionResolutionId, budget: request.budget)
    }
    let result = CangjieServingSearchResult()
    let limit = cangjieServingIndexBudget(request.budget)
    for (doc in index.documents) {
        if (!cangjieServingIndexDocAllowed(index, doc, request.sourceSet, request.targetVersion, request.versionResolutionId)) {
            continue
        }
        if (doc.rejected) {
            continue
        }
        let contributions = rankServingHitStages(request.query, doc)
        let score = cangjieServingIndexContributionScore(contributions)
        if (score <= 0.0) {
            continue
        }
        let hit = CangjieRankedServingHit()
        hit.document = doc
        hit.score = score
        hit.rankReason = cangjieServingIndexRankReason(doc)
        hit.contributions = contributions
        cangjieServingIndexInsertRankedHit(result.hits, hit, limit)
    }
    if (result.hits.size == 0) {
        result.ok = false
        result.degraded = true
        result.diagnostic = "serving_no_hits;vector_graph_fallback_not_configured"
        return result
    }
    result.evidenceHash = servingEvidenceHash(result.hits)
    result
}

public func servingEvidenceHash(hits: ArrayList<CangjieRankedServingHit>): String {
    let out = StringBuilder()
    for (hit in hits) {
        out.append(hit.document.documentId)
        out.append("|")
        out.append(hit.document.contentHash)
        out.append("|")
    }
    stableSummaryHash(out.toString())
}

public func cangjieServingIndexDiagnostics(index: CangjieServingIndex): String {
    if (index.diagnostics.size == 0) {
        return "ok"
    }
    var out = ""
    for (diagnostic in index.diagnostics) {
        if (out != "") {
            out += ","
        }
        out += diagnostic
    }
    out
}

private func cangjieServingIndexActiveVersion(records: ArrayList<NormalizedRecord>, requested: String): String {
    let clean = requested.trimAscii()
    if (clean != "") {
        return clean
    }
    for (record in records) {
        if (record.metadata.knowledgeVersion.trimAscii() != "") {
            return record.metadata.knowledgeVersion.trimAscii()
        }
    }
    "offline"
}

private func cangjieServingIndexRecordAllowed(record: NormalizedRecord): Bool {
    record.metadata.reviewState != ReviewStates.CANDIDATE && record.metadata.trustLevel != TrustLevels.WEB_CANDIDATE
}

private func cangjieServingIndexDocumentFromRecord(record: NormalizedRecord): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "serving-record-${stableSummaryHash("${record.sourceId}:${record.recordKind}:${record.metadata.versionResolutionId}")}"
    doc.recordKind = cangjieServingIndexRecordKind(record)
    doc.title = record.title
    doc.text = record.chunk
    doc.symbolKey = record.metadata.symbol
    doc.module = cangjieServingIndexRecordModule(record)
    doc.sourceSet = record.metadata.sourceSet
    doc.trustLevel = record.metadata.trustLevel
    doc.reviewState = record.metadata.reviewState
    doc.targetVersion = cangjieServingIndexTargetVersion(record.metadata.targetVersion)
    doc.versionResolutionId = record.metadata.versionResolutionId
    doc.contentHash = stableSummaryHash("${record.sourceId}:${record.recordKind}:${record.chunk}")
    doc.citation = record.citation
    doc.sourceId = record.sourceId
    doc.rankProfile = cangjieServingIndexRecordKind(record)
    doc
}

private func cangjieServingIndexDocumentFromSymbol(card: CangjieSymbolCardRecord, activeKnowledgeVersion: String): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "serving-symbol-${stableSummaryHash("${card.symbolKey}:${card.sourceSet}:${card.targetVersion}:${card.versionResolutionId}:${activeKnowledgeVersion}:${card.sourceRef}")}"
    doc.recordKind = CangjieServingRecordKinds.SYMBOL_CARD
    doc.title = card.symbolKey
    doc.text = "${card.signature}\n${card.importLine}\navailability=${card.availability}\naliases=${cangjieServingIndexJoinAliases(card.aliases)}"
    doc.symbolKey = card.symbolKey
    doc.module = card.module
    doc.sourceSet = card.sourceSet
    doc.trustLevel = card.trustLevel
    doc.reviewState = card.reviewState
    doc.targetVersion = cangjieServingIndexTargetVersion(card.targetVersion)
    doc.versionResolutionId = card.versionResolutionId
    doc.contentHash = card.contentHash
    doc.citation = card.citation
    doc.sourceId = card.sourceId
    doc.rankProfile = "exact-symbol"
    doc.rejected = card.incomplete
    doc.diagnostic = card.diagnostic
    doc
}

private func cangjieServingIndexRecordKind(record: NormalizedRecord): String {
    if (record.recordKind == CangjieTypedRecordKinds.SYMBOL_CARD) {
        return CangjieServingRecordKinds.SYMBOL_CARD
    }
    if (record.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL ||
        record.recordKind == CangjieTypedRecordKinds.MODULE_TREE ||
        record.recordKind == CangjieTypedRecordKinds.AVAILABILITY) {
        return record.recordKind
    }
    CangjieServingRecordKinds.DOC_SECTION
}

private func cangjieServingIndexRecordModule(record: NormalizedRecord): String {
    let text = "${record.title}\n${record.chunk}\n${record.metadata.path}".toAsciiLower()
    if (text.contains("std.collection")) { return "std.collection" }
    if (text.contains("std.regex")) { return "std.regex" }
    if (text.contains("std.time")) { return "std.time" }
    if (text.contains("stdx.json") || text.contains("stdx/json")) { return "stdx.json" }
    if (text.contains("cjpm") || text.contains("cjc") || record.metadata.sourceSet == CangjieSourceSets.TOOLS) { return "toolchain" }
    if (record.metadata.path.contains("/")) {
        return record.metadata.path.replace("/", ".").replace(".cj", "")
    }
    ""
}

private func cangjieServingIndexAddNegativeRuleDocuments(index: CangjieServingIndex): Unit {
    let rules = buildNegativeRuleRecords(index.records)
    for (rule in rules) {
        let doc = CangjieServingDocument()
        doc.documentId = "serving-negative-${stableSummaryHash("${rule.ruleId}:${rule.versionResolutionId}:${index.activeKnowledgeVersion}")}"
        doc.recordKind = CangjieServingRecordKinds.NEGATIVE_RULE
        doc.title = rule.title
        doc.text = "Bad: ${rule.badPattern}\nUse: ${rule.replacement}"
        doc.versionResolutionId = rule.versionResolutionId
        doc.targetVersion = cangjieServingIndexRuleTargetVersion(index, rule.versionResolutionId)
        doc.sourceSet = CangjieSourceSets.EVAL_SUPPORT
        doc.contentHash = stableSummaryHash("${rule.ruleId}:${rule.replacement}")
        doc.citation = rule.citation
        doc.sourceId = "negative-rule-${rule.ruleId}"
        doc.rankProfile = "negative-rule"
        index.documents.add(doc)
        cangjieServingIndexAddViewCounts(index, doc)
        cangjieServingIndexAddExactEntries(index, doc)
    }
}

private func cangjieServingIndexAddViewCounts(index: CangjieServingIndex, doc: CangjieServingDocument): Unit {
    if (doc.text != "" || doc.title != "") {
        index.lexicalViewCount += 1
    }
    if (doc.sourceId != "" && doc.citation != "") {
        index.provenanceViewCount += 1
    }
    if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) {
        index.symbolViewCount += 1
    } else if (doc.recordKind == CangjieTypedRecordKinds.MODULE_TREE) {
        index.moduleViewCount += 1
    } else if (doc.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL) {
        index.toolViewCount += 1
    } else if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE) {
        index.negativeRuleViewCount += 1
    } else if (doc.recordKind == CangjieServingRecordKinds.RECIPE) {
        index.recipeViewCount += 1
    } else if (doc.recordKind == CangjieServingRecordKinds.EXAMPLE) {
        index.exampleViewCount += 1
    } else {
        index.docViewCount += 1
    }
}

private func cangjieServingIndexRuleTargetVersion(index: CangjieServingIndex, versionResolutionId: String): String {
    for (record in index.records) {
        if (record.metadata.versionResolutionId == versionResolutionId) {
            return cangjieServingIndexTargetVersion(record.metadata.targetVersion)
        }
    }
    cangjieDefaultTargetVersion()
}

private func cangjieServingIndexAddExactEntries(index: CangjieServingIndex, doc: CangjieServingDocument): Unit {
    let selectors = cangjieServingIndexSelectors(doc)
    for (selector in selectors) {
        let entry = CangjieServingExactEntry()
        entry.lookupKind = cangjieServingIndexLookupKind(doc)
        entry.selector = selector
        entry.sourceId = doc.sourceId
        entry.documentId = doc.documentId
        entry.key = cangjieServingIndexKey(index.activeKnowledgeVersion, doc.sourceSet, doc.targetVersion, doc.versionResolutionId, entry.lookupKind, selector)
        index.exactEntries.add(entry)
    }
}

private func cangjieServingIndexSelectors(doc: CangjieServingDocument): ArrayList<String> {
    let out = ArrayList<String>()
    if (doc.symbolKey.trimAscii() != "") {
        cangjieServingIndexAddSelector(out, doc.symbolKey.trimAscii())
    }
    if (doc.title.trimAscii() != "") {
        cangjieServingIndexAddSelector(out, doc.title.trimAscii())
    }
    if (doc.sourceId.trimAscii() != "") {
        cangjieServingIndexAddSelector(out, doc.sourceId.trimAscii())
    }
    if (doc.module.trimAscii() != "") {
        cangjieServingIndexAddSelector(out, doc.module.trimAscii())
    }
    for (alias in cangjieServingIndexAliases(doc)) {
        cangjieServingIndexAddSelector(out, alias)
    }
    out
}

private func cangjieServingIndexSymbolMatches(doc: CangjieServingDocument, cleanSymbol: String): Bool {
    if (doc.symbolKey.toAsciiLower() == cleanSymbol) {
        return true
    }
    if (doc.module.trimAscii() != "" && "${doc.module}.${doc.symbolKey}".toAsciiLower() == cleanSymbol) {
        return true
    }
    for (alias in cangjieServingIndexAliases(doc)) {
        if (alias.toAsciiLower() == cleanSymbol) {
            return true
        }
    }
    false
}

private func cangjieServingIndexAliases(doc: CangjieServingDocument): ArrayList<String> {
    let aliases = ArrayList<String>()
    for (line in doc.text.split("\n")) {
        let clean = line.trimAscii()
        if (clean.startsWith("aliases=")) {
            let parts = clean.split("aliases=")
            if (parts.size > 1) {
                for (alias in parts[1].split(";")) {
                    cangjieServingIndexAddSelector(aliases, alias)
                }
            }
        }
    }
    aliases
}

private func cangjieServingIndexJoinAliases(aliases: ArrayList<String>): String {
    var out = ""
    for (alias in aliases) {
        if (out != "") {
            out += ";"
        }
        out += alias
    }
    out
}

private func cangjieServingIndexAddSelector(selectors: ArrayList<String>, selector: String): Unit {
    let clean = selector.trimAscii()
    if (clean == "") {
        return
    }
    for (existing in selectors) {
        if (existing.toAsciiLower() == clean.toAsciiLower()) {
            return
        }
    }
    selectors.add(clean)
}

private func cangjieServingIndexLookupKind(doc: CangjieServingDocument): String {
    if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) { return "symbol" }
    if (doc.recordKind == CangjieTypedRecordKinds.TOOL_MANUAL) { return "tool" }
    if (doc.recordKind == CangjieTypedRecordKinds.MODULE_TREE) { return "module" }
    if (doc.recordKind == CangjieTypedRecordKinds.AVAILABILITY) { return "availability" }
    if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE) { return "negative-rule" }
    "doc"
}

private func cangjieServingIndexDocAllowed(index: CangjieServingIndex, doc: CangjieServingDocument, sourceSet: String, targetVersion: String, versionResolutionId: String): Bool {
    if (doc.rejected) {
        return false
    }
    let cleanSourceSet = sourceSet.trimAscii()
    if (cleanSourceSet != "" && cleanSourceSet != CangjieSourceSets.ALL && doc.sourceSet != cleanSourceSet) {
        return false
    }
    let cleanTarget = cangjieServingIndexTargetVersion(targetVersion)
    if (cleanTarget != "" && doc.targetVersion != "" && doc.targetVersion != cleanTarget) {
        return false
    }
    let cleanVersionResolution = versionResolutionId.trimAscii()
    if (cleanVersionResolution != "" && doc.versionResolutionId != cleanVersionResolution) {
        return false
    }
    index.activeKnowledgeVersion != ""
}

private func cangjieServingIndexTargetVersion(raw: String): String {
    cangjieNormalizeTargetVersion(raw)
}

private func cangjieServingIndexBudget(raw: Int64): Int64 {
    if (raw < 1) { CangjieCapabilityLimits.DEFAULT_BUDGET } else { raw }
}

private func cangjieServingIndexMiss(diagnostic: String): CangjieServingSearchResult {
    let result = CangjieServingSearchResult()
    result.ok = false
    result.degraded = true
    result.diagnostic = diagnostic
    result
}

private func cangjieServingIndexResultFromDocs(query: String, docs: ArrayList<CangjieServingDocument>, budget: Int64, missDiagnostic: String): CangjieServingSearchResult {
    let result = CangjieServingSearchResult()
    result.hits = rankServingHits(query, docs, budget)
    if (result.hits.size == 0) {
        result.ok = false
        result.degraded = true
        result.diagnostic = missDiagnostic
        return result
    }
    result.evidenceHash = servingEvidenceHash(result.hits)
    result
}

private func cangjieServingIndexContributionScore(contributions: ArrayList<CangjieRankingContribution>): Float64 {
    var score = 0.0
    for (contribution in contributions) {
        score += contribution.score
    }
    score
}

private func cangjieServingIndexInsertRankedHit(ranked: ArrayList<CangjieRankedServingHit>, hit: CangjieRankedServingHit, limit: Int64): Unit {
    var inserted = false
    var i: Int64 = 0
    while (i < ranked.size) {
        if (hit.score > ranked[i].score) {
            ranked.add(hit, at: i)
            inserted = true
            break
        }
        i += 1
    }
    if (!inserted && ranked.size < limit) {
        ranked.add(hit)
    }
    while (ranked.size > limit) {
        ranked.remove(at: ranked.size - 1)
    }
}

private func cangjieServingIndexRankReason(doc: CangjieServingDocument): String {
    if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) { return "exact_symbol_or_symbol_card" }
    if (doc.recordKind == CangjieServingRecordKinds.DOC_SECTION) { return "official_doc_section" }
    if (doc.recordKind == CangjieServingRecordKinds.EXAMPLE) { return "official_example" }
    if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE) { return "negative_rule" }
    "serving_rank"
}

private func cangjieServingIndexTokenOverlap(text: String, query: String): Int64 {
    var count: Int64 = 0
    for (token in query.split(" ")) {
        let clean = token.trimAscii()
        if (clean.size >= 3 && text.contains(clean)) {
            count += 1
        }
    }
    count
}
