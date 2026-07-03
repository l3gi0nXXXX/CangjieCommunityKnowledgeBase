package cangjie_community_knowledge_base

import std.collection.ArrayList

public func cangjieServingSearch(kb: KnowledgeBase, query: String, budget: Int64, sourceSet!: String = "", targetVersion!: String = "", symbol!: String = ""): SearchResult {
    let options = SearchOptions()
    options.budget = cangjieServingWideBudget(budget)
    options.includeCandidates = false
    let wide = kb.search(query, options)
    let feed = buildServingDocuments(wide.records)
    let request = CangjieServingSearchRequest()
    request.query = query
    request.symbol = symbol
    request.sourceSet = sourceSet
    request.targetVersion = if (targetVersion == "") { cangjieDefaultTargetVersion() } else { targetVersion }
    request.budget = if (budget < 1) { CangjieCapabilityLimits.DEFAULT_BUDGET } else { budget }
    let backend = LocalFixtureServingBackend(feed)
    let serving = if (symbol != "") { backend.exactLookup(request) } else { backend.hybridSearch(request) }
    cangjieServingToSearchResult(wide, serving, request.budget)
}

public func runCangjieServingQuerySmoke(args: Array<String>): Int64 {
    let records = ArrayList<NormalizedRecord>()
    records.add(cangjieServingQuerySmokeRecord("smoke-doc", "ArrayList.add docs", "ArrayList.add appends values. Use import std.collection.* and values.add(1)."))
    records.add(cangjieServingQuerySmokeRecord("smoke-main", "Cangjie main", "main() { println(\"Hello\") }"))
    let feed = buildServingDocuments(records)
    let backend = LocalFixtureServingBackend(feed)
    let request = CangjieServingSearchRequest()
    request.query = "ArrayList.add"
    request.symbol = "ArrayList.add"
    request.budget = 3
    let result = backend.exactLookup(request)
    let ok = result.ok && result.hits.size > 0 && result.hits[0].document.recordKind == CangjieServingRecordKinds.SYMBOL_CARD
    let firstKind = if (result.hits.size > 0) { result.hits[0].document.recordKind } else { "none" }
    let diagnostic = if (result.diagnostic == "") { "none" } else { result.diagnostic }
    println("serving-query-smoke ok=${ok}")
    println("hits=${result.hits.size} firstKind=${firstKind} evidenceHash=${result.evidenceHash} diagnostic=${diagnostic}")
    if (ok) { 0 } else { 1 }
}

private func cangjieServingToSearchResult(wide: SearchResult, serving: CangjieServingSearchResult, budget: Int64): SearchResult {
    let result = SearchResult()
    result.queryId = "${wide.queryId}-serving"
    result.knowledgeVersion = wide.knowledgeVersion
    result.degraded = wide.degraded || serving.degraded
    result.fallbackReason = if (serving.diagnostic != "") { serving.diagnostic } else { wide.fallbackReason }
    for (hit in serving.hits) {
        if (result.records.size >= budget) {
            result.truncated = true
            break
        }
        let record = cangjieServingFindRecord(wide.records, hit.document.sourceId)
        if (record.sourceId != "" && !cangjieServingSearchResultContains(result, record.sourceId)) {
            record.score = hit.score
            result.records.add(record)
        }
    }
    for (record in wide.records) {
        if (result.records.size >= budget) {
            result.truncated = true
            break
        }
        if (!cangjieServingSearchResultContains(result, record.sourceId)) {
            result.records.add(record)
        }
    }
    result.truncated = result.truncated || wide.truncated
    result
}

private func cangjieServingFindRecord(records: ArrayList<NormalizedRecord>, sourceId: String): NormalizedRecord {
    for (record in records) {
        if (record.sourceId == sourceId) {
            return record
        }
    }
    NormalizedRecord()
}

private func cangjieServingSearchResultContains(result: SearchResult, sourceId: String): Bool {
    for (record in result.records) {
        if (record.sourceId == sourceId) {
            return true
        }
    }
    false
}

private func cangjieServingWideBudget(budget: Int64): Int64 {
    if (budget < 1) {
        return CangjieCapabilityLimits.DEFAULT_BUDGET * 4
    }
    let wide = budget * 4
    if (wide < CangjieCapabilityLimits.MAX_BUDGET) { wide } else { CangjieCapabilityLimits.MAX_BUDGET }
}

private func cangjieServingQuerySmokeRecord(sourceId: String, title: String, chunk: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = title
    record.chunk = chunk
    record.citation = "smoke:${sourceId}"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.targetVersion = cangjieDefaultTargetVersion()
    record.metadata.versionResolutionId = "cangjie-1.0.0-docs-release-1.0.0"
    record.metadata.docVersion = "release-1.0.0"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}
