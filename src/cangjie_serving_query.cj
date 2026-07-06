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

public func cangjieExactSymbolLookup(kb: KnowledgeBase, symbol: String, module!: String = "", sourceSet!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): SearchResult {
    let query = symbol.trimAscii()
    let result = cangjieExactLookupBase(kb, "exact-symbol-${stableSummaryHash("${symbol}:${module}:${sourceSet}:${targetVersion}")}")
    if (query == "") {
        return cangjieExactLookupMiss(result, "empty_symbol")
    }
    let target = cangjieNormalizeTargetVersion(targetVersion)
    let limit = cangjieCapabilityClampBudget(budget, CangjieCapabilityLimits.DEFAULT_BUDGET, CangjieCapabilityLimits.MAX_BUDGET)
    for (record in kb.activeRecordSnapshot()) {
        if (result.records.size >= limit) {
            result.truncated = true
            break
        }
        if (record.recordKind != CangjieTypedRecordKinds.SYMBOL_CARD) {
            continue
        }
        if (!cangjieExactRecordTrusted(record) || !cangjieExactVersionMatches(record, target) || !cangjieExactSourceSetMatches(record, sourceSet)) {
            continue
        }
        if (!cangjieExactTextEquals(record.metadata.symbol, query)) {
            continue
        }
        if (module.trimAscii() != "" && !cangjieExactModuleMatches(record, module)) {
            continue
        }
        record.score = 100.0
        result.records.add(record)
    }
    if (result.records.size == 0) {
        return cangjieExactLookupMiss(result, "exact_miss")
    }
    result
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
    for (record in kb.activeRecordSnapshot()) {
        if (result.records.size >= limit) {
            result.truncated = true
            break
        }
        if (record.recordKind != CangjieTypedRecordKinds.DOC_SECTION) {
            continue
        }
        if (!cangjieExactRecordTrusted(record) || !cangjieExactVersionMatches(record, target)) {
            continue
        }
        if (cleanSection != "" && !cangjieExactDocSectionMatches(record, cleanSection)) {
            continue
        }
        if (cleanPath != "" && record.metadata.path != cleanPath) {
            continue
        }
        if (cleanHeading != "" && !cangjieExactHeadingMatches(record, cleanHeading)) {
            continue
        }
        record.score = 100.0
        result.records.add(record)
    }
    if (result.records.size == 0) {
        return cangjieExactLookupMiss(result, "exact_miss")
    }
    result
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
    for (record in kb.activeRecordSnapshot()) {
        if (result.records.size >= limit) {
            result.truncated = true
            break
        }
        if (record.recordKind != CangjieTypedRecordKinds.TOOL_MANUAL) {
            continue
        }
        if (!cangjieExactRecordTrusted(record) || !cangjieExactVersionMatches(record, target) || record.metadata.sourceSet != CangjieSourceSets.TOOLS) {
            continue
        }
        if (!cangjieExactToolMatches(record, cleanTool)) {
            continue
        }
        if (cleanCommand != "" && !cangjieExactToolCommandMatches(record, cleanCommand)) {
            continue
        }
        record.score = 100.0
        result.records.add(record)
    }
    if (result.records.size == 0) {
        return cangjieExactLookupMiss(result, "exact_miss")
    }
    result
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
