package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public func cangjieServingSearch(kb: KnowledgeBase, query: String, budget: Int64, sourceSet!: String = "", targetVersion!: String = "", symbol!: String = ""): SearchResult {
    let status = kb.status()
    let index = buildCangjieServingIndex(kb.activeRecordSnapshot(), activeKnowledgeVersion: status.activeKnowledgeVersion)
    let request = CangjieServingSearchRequest()
    request.query = query
    request.symbol = symbol
    request.sourceSet = sourceSet
    request.targetVersion = if (targetVersion == "") { cangjieDefaultTargetVersion() } else { targetVersion }
    request.budget = if (budget < 1) { CangjieCapabilityLimits.DEFAULT_BUDGET } else { budget }
    let interfaceId = if (symbol.trimAscii() != "") { "exact-symbol" } else { "hybrid-search" }
    let cacheKey = cangjieServingCacheKey("", status.activeKnowledgeVersion, sourceSet, query, request.budget, "knowledge-pack", targetVersion: request.targetVersion, interfaceId: interfaceId, selector: "${sourceSet}:${request.targetVersion}:${symbol}")
    let cacheLookup = kb.servingCacheLookup(cacheKey)
    let serving = if (symbol != "") {
        lookupExactSymbol(index, symbol, sourceSet: sourceSet, targetVersion: request.targetVersion, budget: request.budget)
    } else {
        searchHybridServingIndex(index, request)
    }
    let result = cangjieServingToSearchResult(index, serving, request.budget)
    result.queryId = "serving-${stableSummaryHash("${query}:${sourceSet}:${request.targetVersion}:${symbol}")}"
    result.knowledgeVersion = status.activeKnowledgeVersion
    if (serving.evidenceHash != "") {
        kb.servingCachePutResult(cacheKey, serving.evidenceHash, cangjieServingCacheSummary(serving), cangjieServingCacheHitIds(serving))
    }
    if (cacheLookup.hit && !result.degraded) {
        kb.recordServingCacheDiagnostic("cache_hit")
    }
    if (serving.hits.size == 0) {
        cangjieServingAppendLegacyFallback(kb, result, query, request.budget, serving.diagnostic)
    }
    result
}

private func cangjieServingCacheSummary(serving: CangjieServingSearchResult): String {
    "ok=${serving.ok};degraded=${serving.degraded};hits=${serving.hits.size};diagnostic=${serving.diagnostic}"
}

private func cangjieServingCacheHitIds(serving: CangjieServingSearchResult): ArrayList<String> {
    let out = ArrayList<String>()
    for (hit in serving.hits) {
        out.add(hit.document.documentId)
    }
    out
}

public func cangjieExactSymbolLookup(kb: KnowledgeBase, symbol: String, module!: String = "", sourceSet!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): SearchResult {
    let query = symbol.trimAscii()
    let result = cangjieExactLookupBase(kb, "exact-symbol-${stableSummaryHash("${symbol}:${module}:${sourceSet}:${targetVersion}")}")
    if (query == "") {
        return cangjieExactLookupMiss(result, "empty_symbol")
    }
    let target = cangjieNormalizeTargetVersion(targetVersion)
    let limit = cangjieCapabilityClampBudget(budget, CangjieCapabilityLimits.DEFAULT_BUDGET, CangjieCapabilityLimits.MAX_BUDGET)
    let index = buildCangjieServingIndex(kb.activeRecordSnapshot(), activeKnowledgeVersion: result.knowledgeVersion)
    let serving = lookupExactSymbol(index, query, module: module, sourceSet: sourceSet, targetVersion: target, budget: limit)
    let out = cangjieServingToSearchResult(index, serving, limit)
    out.queryId = result.queryId
    out.knowledgeVersion = result.knowledgeVersion
    if (out.records.size == 0) {
        return cangjieExactLookupMiss(out, if (serving.diagnostic == "") { "exact_miss" } else { serving.diagnostic })
    }
    out
}

public func cangjieExactDocSectionLookup(kb: KnowledgeBase, sectionId: String, path!: String = "", heading!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): SearchResult {
    let cleanSection = sectionId.trimAscii()
    let cleanPath = path.trimAscii()
    let cleanHeading = heading.trimAscii()
    let result = cangjieExactLookupBase(kb, "exact-doc-${stableSummaryHash("${sectionId}:${path}:${heading}:${targetVersion}")}")
    if (cleanSection == "" && cleanPath == "" && cleanHeading == "") {
        return cangjieExactLookupMiss(result, "empty_doc_selector")
    }
    let target = cangjieNormalizeTargetVersion(targetVersion)
    let limit = cangjieCapabilityClampBudget(budget, CangjieCapabilityLimits.DEFAULT_BUDGET, CangjieCapabilityLimits.MAX_BUDGET)
    let index = buildCangjieServingIndex(kb.activeRecordSnapshot(), activeKnowledgeVersion: result.knowledgeVersion)
    let serving = lookupDocSection(index, cleanSection, path: cleanPath, heading: cleanHeading, targetVersion: target, budget: limit)
    let out = cangjieServingToSearchResult(index, serving, limit)
    out.queryId = result.queryId
    out.knowledgeVersion = result.knowledgeVersion
    if (out.records.size == 0) {
        return cangjieExactLookupMiss(out, if (serving.diagnostic == "") { "exact_miss" } else { serving.diagnostic })
    }
    out
}

public func cangjieExactToolManualLookup(kb: KnowledgeBase, tool: String, command!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): SearchResult {
    let cleanTool = tool.trimAscii()
    let cleanCommand = command.trimAscii()
    let result = cangjieExactLookupBase(kb, "exact-tool-${stableSummaryHash("${tool}:${command}:${targetVersion}")}")
    if (cleanTool == "") {
        return cangjieExactLookupMiss(result, "empty_tool")
    }
    let target = cangjieNormalizeTargetVersion(targetVersion)
    let limit = cangjieCapabilityClampBudget(budget, CangjieCapabilityLimits.DEFAULT_BUDGET, CangjieCapabilityLimits.MAX_BUDGET)
    let index = buildCangjieServingIndex(kb.activeRecordSnapshot(), activeKnowledgeVersion: result.knowledgeVersion)
    let serving = lookupToolManual(index, cleanTool, command: cleanCommand, targetVersion: target, budget: limit)
    let out = cangjieServingToSearchResult(index, serving, limit)
    out.queryId = result.queryId
    out.knowledgeVersion = result.knowledgeVersion
    if (out.records.size == 0) {
        return cangjieExactLookupMiss(out, if (serving.diagnostic == "") { "exact_miss" } else { serving.diagnostic })
    }
    out
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

private func cangjieExactLookupBase(kb: KnowledgeBase, queryId: String): SearchResult {
    let result = SearchResult()
    result.queryId = queryId
    result.knowledgeVersion = kb.status().activeKnowledgeVersion
    result
}

private func cangjieExactLookupMiss(result: SearchResult, reason: String): SearchResult {
    result.degraded = true
    result.fallbackReason = reason
    result
}

private func cangjieExactRecordTrusted(record: NormalizedRecord): Bool {
    record.metadata.reviewState != ReviewStates.CANDIDATE && record.metadata.trustLevel != TrustLevels.WEB_CANDIDATE
}

private func cangjieExactVersionMatches(record: NormalizedRecord, targetVersion: String): Bool {
    record.metadata.targetVersion == targetVersion
}

private func cangjieExactSourceSetMatches(record: NormalizedRecord, sourceSet: String): Bool {
    let clean = sourceSet.trimAscii()
    clean == "" || record.metadata.sourceSet == clean
}

private func cangjieExactTextEquals(left: String, right: String): Bool {
    left.trimAscii().toAsciiLower() == right.trimAscii().toAsciiLower()
}

private func cangjieExactModuleMatches(record: NormalizedRecord, module: String): Bool {
    let clean = module.trimAscii().toAsciiLower()
    let body = record.chunk.toAsciiLower()
    body.contains("module=${clean}") || body.contains("package ${clean}") || record.title.toAsciiLower().contains(clean) || record.metadata.path.toAsciiLower().contains(clean)
}

private func cangjieExactDocSectionMatches(record: NormalizedRecord, sectionId: String): Bool {
    let clean = sectionId.trimAscii()
    record.citation.contains("#${clean}") || record.sourceId == clean || record.sourceId.endsWith(clean)
}

private func cangjieExactHeadingMatches(record: NormalizedRecord, heading: String): Bool {
    let clean = heading.trimAscii().toAsciiLower()
    record.title.toAsciiLower().contains(clean)
}

private func cangjieExactToolMatches(record: NormalizedRecord, tool: String): Bool {
    let clean = tool.trimAscii().toAsciiLower()
    record.metadata.symbol.toAsciiLower().startsWith(clean) || record.metadata.path.toAsciiLower().contains(clean) || record.title.toAsciiLower().contains(clean) || record.chunk.toAsciiLower().contains(clean)
}

private func cangjieExactToolCommandMatches(record: NormalizedRecord, command: String): Bool {
    let clean = command.trimAscii().toAsciiLower()
    let symbol = record.metadata.symbol.toAsciiLower()
    symbol.contains(" ${clean}") || record.title.toAsciiLower().contains(clean) || record.chunk.toAsciiLower().contains(" ${clean}") || record.chunk.toAsciiLower().contains("`${clean}`")
}

private func cangjieServingToSearchResult(index: CangjieServingIndex, serving: CangjieServingSearchResult, budget: Int64): SearchResult {
    let result = SearchResult()
    result.queryId = "serving-${serving.evidenceHash}"
    result.knowledgeVersion = index.activeKnowledgeVersion
    result.degraded = serving.degraded
    result.fallbackReason = serving.diagnostic
    for (hit in serving.hits) {
        if (result.records.size >= budget) {
            result.truncated = true
            break
        }
        var record = cangjieServingFindRecord(index.records, hit.document.sourceId)
        if (record.sourceId == "") {
            record = cangjieServingRecordFromDocument(hit.document, index.activeKnowledgeVersion)
        }
        if (record.sourceId != "" && !cangjieServingSearchResultContains(result, record.sourceId)) {
            record.score = hit.score
            result.records.add(record)
        }
    }
    result
}

private func cangjieServingAppendLegacyFallback(kb: KnowledgeBase, result: SearchResult, query: String, budget: Int64, servingDiagnostic: String): Unit {
    let options = SearchOptions()
    options.budget = cangjieServingWideBudget(budget)
    options.includeCandidates = false
    options.includeVector = false
    let legacy = kb.search(query, options)
    result.degraded = true
    result.fallbackReason = if (servingDiagnostic == "") { "legacy_search_degraded" } else { "${servingDiagnostic};legacy_search_degraded" }
    for (record in legacy.records) {
        if (result.records.size >= budget) {
            result.truncated = true
            break
        }
        if (!cangjieServingSearchResultContains(result, record.sourceId)) {
            result.records.add(record)
        }
    }
    result.truncated = result.truncated || legacy.truncated
}

private func cangjieServingFindRecord(records: ArrayList<NormalizedRecord>, sourceId: String): NormalizedRecord {
    for (record in records) {
        if (record.sourceId == sourceId) {
            return record
        }
    }
    NormalizedRecord()
}

private func cangjieServingRecordFromDocument(doc: CangjieServingDocument, activeKnowledgeVersion: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = doc.sourceId
    record.recordKind = doc.recordKind
    record.title = doc.title
    record.chunk = doc.text
    record.citation = doc.citation
    record.metadata.sourceId = doc.sourceId
    record.metadata.sourceType = SourceTypes.DERIVED
    record.metadata.sourceUrl = doc.citation
    record.metadata.path = doc.citation
    record.metadata.symbol = doc.symbolKey
    record.metadata.targetVersion = doc.targetVersion
    record.metadata.sourceSet = doc.sourceSet
    record.metadata.versionResolutionId = doc.versionResolutionId
    record.metadata.knowledgeVersion = activeKnowledgeVersion
    record.metadata.trustLevel = doc.trustLevel
    record.metadata.reviewState = doc.reviewState
    record
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
