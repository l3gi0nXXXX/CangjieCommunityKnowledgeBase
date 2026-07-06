package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieCapabilityLimits {
    public static let DEFAULT_BUDGET: Int64 = 5
    public static let MAX_BUDGET: Int64 = 20
    public static let MAX_TEXT_CHARS: Int64 = 12000
    public static let DEFAULT_EXAMPLE_LIMIT: Int64 = 3
}

public class CangjieTargetVersionResult {
    public var value: String = cangjieDefaultTargetVersion()
    public var normalized: Bool = false
    public var diagnostic: String = ""

    public init() {}
}

public class CangjieKnowledgeItem {
    public var kind: String = ""
    public var title: String = ""
    public var content: String = ""
    public var module: String = ""
    public var symbol: String = ""
    public var importLine: String = ""
    public var signature: String = ""
    public var example: String = ""
    public var citation: String = ""
    public var sourceId: String = ""
    public var knowledgeVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var requiresReview: Bool = false
    public var score: Float64 = 0.0

    public init() {}
}

public class CangjieApiItem {
    public var module: String = ""
    public var symbol: String = ""
    public var importLine: String = ""
    public var signature: String = ""
    public var summary: String = ""
    public var example: String = ""
    public var citation: String = ""
    public var sourceId: String = ""
    public var knowledgeVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var requiresReview: Bool = false
    public var score: Float64 = 0.0

    public init() {}
}

public class CangjieExampleItem {
    public var title: String = ""
    public var code: String = ""
    public var explanation: String = ""
    public var module: String = ""
    public var symbol: String = ""
    public var citation: String = ""
    public var sourceId: String = ""
    public var knowledgeVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var requiresReview: Bool = false

    public init() {}
}

public class CangjieDiagnosticItem {
    public var rule: String = ""
    public var message: String = ""
    public var relatedSyntax: String = ""
    public var suggestedQuery: String = ""
    public var citation: String = ""
    public var sourceId: String = ""
    public var knowledgeVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var trustLevel: String = ""
    public var reviewState: String = ""
    public var executed: Bool = false

    public init() {}
}

public class CangjieCorpusStatus {
    public var activeKnowledgeVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var docsUrls: ArrayList<String> = ArrayList<String>()
    public var stdSources: ArrayList<String> = ArrayList<String>()
    public var rawCount: Int64 = 0
    public var normalizedCount: Int64 = 0
    public var indexCount: Int64 = 0
    public var degraded: Bool = false
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class CangjieKnowledgePack {
    public var queryId: String = ""
    public var task: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var knowledgeVersion: String = ""
    public var versionResolutionId: String = ""
    public var truncated: Bool = false
    public var degraded: Bool = false
    public var executed: Bool = false
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var items: ArrayList<CangjieKnowledgeItem> = ArrayList<CangjieKnowledgeItem>()
    public var apiItems: ArrayList<CangjieApiItem> = ArrayList<CangjieApiItem>()
    public var examples: ArrayList<CangjieExampleItem> = ArrayList<CangjieExampleItem>()
    public var diagnostics: ArrayList<CangjieDiagnosticItem> = ArrayList<CangjieDiagnosticItem>()
    public var notes: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func cangjieDefaultTargetVersion(): String {
    "1.0.0"
}

public func cangjieNormalizeTargetVersion(raw: String): String {
    cangjieNormalizeTargetVersionResult(raw).value
}

public func cangjieNormalizeTargetVersionResult(raw: String): CangjieTargetVersionResult {
    let result = CangjieTargetVersionResult()
    let value = raw.trimAscii()
    if (value == "") {
        result.value = cangjieDefaultTargetVersion()
        result.normalized = true
        result.diagnostic = "target_version_defaulted"
        return result
    }
    if (cangjieTargetVersionAllowed(value)) {
        result.value = value
        return result
    }
    result.value = cangjieDefaultTargetVersion()
    result.normalized = true
    result.diagnostic = "target_version_normalized"
    result
}

public func cangjieCapabilityClampBudget(raw: Int64, fallback: Int64, max: Int64): Int64 {
    if (raw < 1) {
        return fallback
    }
    if (raw > max) {
        return max
    }
    raw
}

public class CangjieCapabilityService {
    private let kb: KnowledgeBase

    public init(kb: KnowledgeBase) {
        this.kb = kb
    }

    public func knowledgePack(task: String, targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET, includeExamples!: Bool = true, includeAntiPatterns!: Bool = true): CangjieKnowledgePack {
        let cleanTask = cangjieSafeText(task)
        let pack = this.newPack(cleanTask, targetVersion, budget)
        pack.degraded = true
        pack.notes.add("legacy_endpoint_degraded")
        if (cleanTask == "") {
            pack.notes.add("empty_task")
            return pack
        }
        let limit = this.effectiveBudget(pack, budget)
        this.mergePackItems(pack, this.syntaxQuery(cleanTask, targetVersion: pack.targetVersion, budget: limit))
        this.mergePackItems(pack, this.apiSearch(cleanTask, module: "", symbol: "", sourceSet: "", targetVersion: pack.targetVersion, budget: limit))
        if (includeExamples) {
            this.mergePackItems(pack, this.examples(cleanTask, module: "", symbol: "", maxExamples: CangjieCapabilityLimits.DEFAULT_EXAMPLE_LIMIT, targetVersion: pack.targetVersion))
        }
        if (includeAntiPatterns) {
            this.mergePackItems(pack, this.syntaxQuery("${cleanTask} antipattern", targetVersion: pack.targetVersion, budget: 2))
        }
        if (pack.items.size + pack.apiItems.size + pack.examples.size == 0) {
            pack.degraded = true
            pack.notes.add("no_cangjie_knowledge_match")
        }
        pack
    }

    public func resolveVersion(selector: CangjieVersionSelector): CangjieVersionResolution {
        resolveCangjieVersion(selector, defaultCangjieVersionManifest())
    }

    public func taskKnowledgePack(request: CangjieTaskKnowledgeRequest): CangjieTaskKnowledgePack {
        buildCangjieTaskKnowledgePack(this.kb.status(), request, defaultCangjieVersionManifest())
    }

    public func knowledgeCoverage(request: CangjieTaskKnowledgeRequest): CangjieKnowledgeCoverage {
        let pack = this.taskKnowledgePack(request)
        pack.coverage
    }

    public func compileDiagnoseV2(code: String, compilerOutput: String, context!: String = "", targetVersion!: String = "", sourceSet!: String = "", sourceRef!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieTaskKnowledgePack {
        let request = CangjieTaskKnowledgeRequest()
        request.taskText = if (context.trimAscii() == "") { compilerOutput } else { "${compilerOutput} ${context}" }
        request.signature = code
        request.compilerOutput = compilerOutput
        request.versionSelector = cangjieVersionSelector(targetVersion: targetVersion, sourceSet: sourceSet, sourceRef: sourceRef, versionPolicy: if (sourceRef.trimAscii() == "") { CangjieVersionPolicies.DEFAULT } else { CangjieVersionPolicies.EXACT })
        request.budget = budget
        this.taskKnowledgePack(request)
    }

    public func syntaxQuery(q: String, targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let query = cangjieSafeText(q)
        let pack = this.newPack(query, targetVersion, budget)
        if (query == "") {
            pack.degraded = true
            pack.notes.add("empty_query")
            return pack
        }
        let limit = this.effectiveBudget(pack, budget)
        let result = cangjieServingSearch(this.kb, this.syntaxQueryText(query), limit, targetVersion: pack.targetVersion)
        this.addKnowledgeItems(pack, result, "syntax")
        pack.degraded = pack.degraded || result.degraded
        pack.truncated = pack.truncated || result.truncated
        pack
    }

    public func apiSearch(q: String, module!: String = "", symbol!: String = "", sourceSet!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let query = cangjieSafeText(if (q.trimAscii() != "") { q } else { "${module} ${symbol}" })
        let pack = this.newPack(query, targetVersion, budget)
        if (query == "") {
            pack.degraded = true
            pack.notes.add("empty_query")
            return pack
        }
        let limit = this.effectiveBudget(pack, budget)
        let result = cangjieServingSearch(this.kb, "${query} ${module} ${symbol} ${sourceSet}", limit, sourceSet: sourceSet, targetVersion: pack.targetVersion, symbol: symbol)
        this.addApiItems(pack, result, module, symbol, sourceSet)
        pack.degraded = pack.degraded || result.degraded
        pack.truncated = pack.truncated || result.truncated
        pack
    }

    public func cookbook(task: String, constraints!: String = "", targetVersion!: String = "", style!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let query = cangjieSafeText("${task} ${constraints} ${style}")
        let pack = this.newPack(query, targetVersion, budget)
        if (query == "") {
            pack.degraded = true
            pack.notes.add("empty_task")
            return pack
        }
        this.mergePackItems(pack, this.knowledgePack(query, targetVersion: pack.targetVersion, budget: budget, includeExamples: true, includeAntiPatterns: true))
        pack.notes.add("cookbook_steps_are_grounded_in_citations")
        pack
    }

    public func diagnose(code: String, compilerOutput: String, context!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let query = cangjieSafeText("${compilerOutput} ${context}")
        let pack = this.newPack(query, targetVersion, budget)
        pack.executed = false
        if (query == "") {
            pack.degraded = true
            pack.notes.add("empty_compiler_output")
            return pack
        }
        let limit = this.effectiveBudget(pack, budget)
        let result = cangjieServingSearch(this.kb, this.diagnosticQueryText(query), limit, targetVersion: pack.targetVersion)
        for (record in result.records) {
            if (!cangjieRecordTrusted(record)) {
                continue
            }
            let item = CangjieDiagnosticItem()
            item.rule = "knowledge_only_diagnose"
            item.message = cangjieExcerpt(record.chunk)
            item.relatedSyntax = record.title
            item.suggestedQuery = record.metadata.symbol
            item.citation = record.citation
            item.sourceId = record.sourceId
            item.knowledgeVersion = record.metadata.knowledgeVersion
            item.targetVersion = pack.targetVersion
            item.trustLevel = record.metadata.trustLevel
            item.reviewState = record.metadata.reviewState
            item.executed = false
            pack.diagnostics.add(item)
            this.addCitation(pack, record)
        }
        pack.degraded = pack.degraded || result.degraded
        pack.truncated = pack.truncated || result.truncated
        if (pack.diagnostics.size == 0) {
            pack.notes.add("no_diagnostic_match")
        }
        pack
    }

    public func examples(q: String, module!: String = "", symbol!: String = "", maxExamples!: Int64 = CangjieCapabilityLimits.DEFAULT_EXAMPLE_LIMIT, targetVersion!: String = ""): CangjieKnowledgePack {
        let query = cangjieSafeText("${q} ${module} ${symbol} example")
        let pack = this.newPack(query, targetVersion, maxExamples)
        if (query == "") {
            pack.degraded = true
            pack.notes.add("empty_query")
            return pack
        }
        let limit = this.effectiveBudget(pack, maxExamples)
        let result = cangjieServingSearch(this.kb, query, limit, targetVersion: pack.targetVersion, symbol: symbol)
        for (record in result.records) {
            if (!cangjieRecordTrusted(record)) {
                continue
            }
            let extracted = buildExampleRecords(record)
            if (extracted.size > 0) {
                for (candidate in extracted) {
                    let example = CangjieExampleItem()
                    example.title = candidate.title
                    example.code = candidate.code
                    example.explanation = candidate.explanation
                    example.module = if (module != "") { module } else { candidate.module }
                    example.symbol = if (symbol != "") { symbol } else { candidate.symbol }
                    example.citation = candidate.citation
                    example.sourceId = candidate.sourceId
                    example.knowledgeVersion = record.metadata.knowledgeVersion
                    example.targetVersion = pack.targetVersion
                    example.trustLevel = candidate.trustLevel
                    example.reviewState = candidate.reviewState
                    example.requiresReview = record.requiresReview
                    pack.examples.add(example)
                    this.addCitation(pack, record)
                }
            } else {
                let example = CangjieExampleItem()
                example.title = record.title
                example.code = cangjieExampleFromRecord(record)
                example.explanation = cangjieExcerpt(record.chunk)
                example.module = module
                example.symbol = if (symbol != "") { symbol } else { record.metadata.symbol }
                example.citation = record.citation
                example.sourceId = record.sourceId
                example.knowledgeVersion = record.metadata.knowledgeVersion
                example.targetVersion = pack.targetVersion
                example.trustLevel = record.metadata.trustLevel
                example.reviewState = record.metadata.reviewState
                example.requiresReview = record.requiresReview
                pack.examples.add(example)
                this.addCitation(pack, record)
            }
        }
        pack.degraded = pack.degraded || result.degraded
        pack.truncated = pack.truncated || result.truncated
        pack
    }

    public func symbolLookup(symbol: String, module!: String = "", sourceSet!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let query = cangjieSafeText(symbol)
        let pack = this.newPack(query, targetVersion, budget)
        pack.notes.add("exact_symbol_lookup_endpoint")
        if (query == "") {
            pack.degraded = true
            pack.notes.add("empty_symbol")
            return pack
        }
        let result = cangjieExactSymbolLookup(this.kb, query, module: module, sourceSet: sourceSet, targetVersion: pack.targetVersion, budget: this.effectiveBudget(pack, budget))
        this.addApiItems(pack, result, module, query, sourceSet)
        this.applyExactLookupState(pack, result)
        pack
    }

    public func docSection(sectionId: String, path!: String = "", heading!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let query = cangjieSafeText("${sectionId} ${path} ${heading} doc section")
        let pack = this.newPack(query, targetVersion, budget)
        pack.notes.add("exact_doc_section_endpoint")
        let result = cangjieExactDocSectionLookup(this.kb, sectionId, path: path, heading: heading, targetVersion: pack.targetVersion, budget: this.effectiveBudget(pack, budget))
        this.addKnowledgeItems(pack, result, "doc_section")
        this.applyExactLookupState(pack, result)
        pack
    }

    public func toolManual(tool: String, command!: String = "", targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let query = cangjieSafeText("${tool} ${command} tool manual")
        let pack = this.newPack(query, targetVersion, budget)
        pack.notes.add("exact_tool_manual_endpoint")
        let result = cangjieExactToolManualLookup(this.kb, tool, command: command, targetVersion: pack.targetVersion, budget: this.effectiveBudget(pack, budget))
        this.addKnowledgeItems(pack, result, "tool_manual")
        this.applyExactLookupState(pack, result)
        pack
    }

    public func negativeRules(query: String, targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let pack = this.syntaxQuery("${query} negative rule antipattern", targetVersion: targetVersion, budget: budget)
        pack.notes.add("negative_rules_endpoint")
        pack
    }

    public func corpusStatus(): CangjieCorpusStatus {
        let status = this.kb.status()
        let out = CangjieCorpusStatus()
        out.activeKnowledgeVersion = status.activeKnowledgeVersion
        out.targetVersion = cangjieDefaultTargetVersion()
        out.rawCount = status.storage.rawCount
        out.normalizedCount = status.storage.normalizedCount
        out.indexCount = status.storage.indexCount
        out.degraded = status.storage.vectorState == EmbeddingProviderState.DEGRADED || status.storage.graphState == EmbeddingProviderState.DEGRADED
        for (url in status.sourceScope.docsUrls) {
            out.docsUrls.add(url)
        }
        for (source in status.sourceScope.stdSources) {
            out.stdSources.add(source)
        }
        if (out.docsUrls.size == 0) {
            out.diagnostics.add("docs_urls_empty")
        }
        if (out.stdSources.size == 0) {
            out.diagnostics.add("std_sources_empty")
        }
        out
    }

    private func newPack(task: String, targetVersion: String, budget: Int64): CangjieKnowledgePack {
        let pack = CangjieKnowledgePack()
        let version = cangjieNormalizeTargetVersionResult(targetVersion)
        let status = this.kb.status()
        pack.task = cangjieSafeText(task)
        pack.queryId = "cangjie-${stableSummaryHash(pack.task)}"
        pack.targetVersion = version.value
        pack.knowledgeVersion = status.activeKnowledgeVersion
        pack.versionResolutionId = "legacy-${stableSummaryHash("${pack.targetVersion}:${pack.knowledgeVersion}")}"
        if (version.normalized) {
            pack.notes.add(version.diagnostic)
        }
        if (budget > CangjieCapabilityLimits.MAX_BUDGET) {
            pack.truncated = true
            pack.notes.add("budget_clamped")
        }
        pack
    }

    private func effectiveBudget(pack: CangjieKnowledgePack, budget: Int64): Int64 {
        let value = cangjieCapabilityClampBudget(budget, CangjieCapabilityLimits.DEFAULT_BUDGET, CangjieCapabilityLimits.MAX_BUDGET)
        if (budget > CangjieCapabilityLimits.MAX_BUDGET) {
            pack.truncated = true
        }
        value
    }

    private func syntaxQueryText(query: String): String {
        "${query} syntax function option main import std stdx"
    }

    private func diagnosticQueryText(query: String): String {
        let lower = query.toAsciiLower()
        if (lower.contains("main")) {
            return "main function syntax"
        }
        if (lower.contains("option") || lower.contains("none") || lower.contains("some")) {
            return "option syntax"
        }
        if (lower.contains("json")) {
            return "JSON stdx"
        }
        "${query} syntax API error"
    }

    private func addKnowledgeItems(pack: CangjieKnowledgePack, result: SearchResult, kind: String): Unit {
        for (record in result.records) {
            if (!cangjieRecordTrusted(record)) {
                continue
            }
            if (this.hasCitation(pack, record.sourceId)) {
                continue
            }
            let item = CangjieKnowledgeItem()
            item.kind = kind
            item.title = record.title
            item.content = cangjieExcerpt(record.chunk)
            item.module = cangjieModuleFromRecord(record)
            item.symbol = record.metadata.symbol
            item.importLine = cangjieImportLineFromRecord(record)
            item.signature = cangjieSignatureFromRecord(record)
            item.example = cangjieExampleFromRecord(record)
            item.citation = record.citation
            item.sourceId = record.sourceId
            item.knowledgeVersion = record.metadata.knowledgeVersion
            item.targetVersion = pack.targetVersion
            item.trustLevel = record.metadata.trustLevel
            item.reviewState = record.metadata.reviewState
            item.requiresReview = record.requiresReview
            item.score = record.score
            pack.items.add(item)
            this.addCitation(pack, record)
        }
    }

    private func addApiItems(pack: CangjieKnowledgePack, result: SearchResult, module: String, symbol: String, sourceSet: String): Unit {
        for (record in result.records) {
            if (!cangjieRecordTrusted(record)) {
                continue
            }
            var addedFromSymbol = false
            for (card in extractCangjieSymbols(record)) {
                if (!cangjieSymbolCardMatches(card, symbol, module, sourceSet)) {
                    continue
                }
                let item = CangjieApiItem()
                item.module = card.module
                item.symbol = card.symbolKey
                item.importLine = card.importLine
                item.signature = card.signature
                item.summary = cangjieExcerpt(record.chunk)
                item.example = cangjieExampleFromRecord(record)
                item.citation = card.citation
                item.sourceId = card.sourceId
                item.knowledgeVersion = record.metadata.knowledgeVersion
                item.targetVersion = pack.targetVersion
                item.trustLevel = card.trustLevel
                item.reviewState = card.reviewState
                item.requiresReview = record.requiresReview || card.incomplete
                item.score = record.score + 2.0 + cangjieExactApiBoost(record, module, symbol)
                pack.apiItems.add(item)
                this.addCitation(pack, record)
                addedFromSymbol = true
            }
            if (addedFromSymbol) {
                continue
            }
            if (!cangjieRecordMatchesApiFilter(record, module, symbol, sourceSet)) {
                continue
            }
            let item = CangjieApiItem()
            item.module = if (module.trimAscii() != "") { module.trimAscii() } else { cangjieModuleFromRecord(record) }
            item.symbol = if (symbol.trimAscii() != "") { symbol.trimAscii() } else { record.metadata.symbol }
            item.importLine = cangjieImportLineFromRecord(record)
            item.signature = cangjieSignatureFromRecord(record)
            item.summary = cangjieExcerpt(record.chunk)
            item.example = cangjieExampleFromRecord(record)
            item.citation = record.citation
            item.sourceId = record.sourceId
            item.knowledgeVersion = record.metadata.knowledgeVersion
            item.targetVersion = pack.targetVersion
            item.trustLevel = record.metadata.trustLevel
            item.reviewState = record.metadata.reviewState
            item.requiresReview = record.requiresReview
            item.score = record.score + cangjieExactApiBoost(record, module, symbol)
            pack.apiItems.add(item)
            this.addCitation(pack, record)
        }
    }

    private func mergePackItems(target: CangjieKnowledgePack, source: CangjieKnowledgePack): Unit {
        target.truncated = target.truncated || source.truncated
        target.degraded = target.degraded || source.degraded
        for (note in source.notes) {
            if (!target.notes.contains(note)) {
                target.notes.add(note)
            }
        }
        for (item in source.items) {
            if (!this.hasCitation(target, item.sourceId)) {
                target.items.add(item)
                target.citations.add(SourceReference(item.sourceId, item.citation, item.knowledgeVersion))
            }
        }
        for (item in source.apiItems) {
            if (!this.hasCitation(target, item.sourceId)) {
                target.apiItems.add(item)
                target.citations.add(SourceReference(item.sourceId, item.citation, item.knowledgeVersion))
            }
        }
        for (item in source.examples) {
            if (!this.hasCitation(target, item.sourceId)) {
                target.examples.add(item)
                target.citations.add(SourceReference(item.sourceId, item.citation, item.knowledgeVersion))
            }
        }
        for (item in source.diagnostics) {
            if (!this.hasCitation(target, item.sourceId)) {
                target.diagnostics.add(item)
                target.citations.add(SourceReference(item.sourceId, item.citation, item.knowledgeVersion))
            }
        }
    }

    private func applyExactLookupState(pack: CangjieKnowledgePack, result: SearchResult): Unit {
        pack.degraded = pack.degraded || result.degraded
        pack.truncated = pack.truncated || result.truncated
        if (result.degraded) {
            let reason = if (result.fallbackReason == "") { "exact_miss" } else { result.fallbackReason }
            if (!pack.notes.contains(reason)) {
                pack.notes.add(reason)
            }
        } else if (!pack.notes.contains("exact_hit")) {
            pack.notes.add("exact_hit")
        }
    }

    private func addCitation(pack: CangjieKnowledgePack, record: NormalizedRecord): Unit {
        if (!this.hasCitation(pack, record.sourceId)) {
            pack.citations.add(SourceReference(record.sourceId, record.citation, record.metadata.knowledgeVersion))
        }
    }

    private func hasCitation(pack: CangjieKnowledgePack, sourceId: String): Bool {
        for (citation in pack.citations) {
            if (citation.sourceId == sourceId) {
                return true
            }
        }
        false
    }
}

private func cangjieTargetVersionAllowed(value: String): Bool {
    if (value == "" || value.startsWith("-") || value.endsWith("-") || value.contains("..")) {
        return false
    }
    var hyphenCount: Int64 = 0
    for (ch in value.toRuneArray()) {
        let ok = (ch >= r'0' && ch <= r'9') || ch == r'.' || ch == r'-' || (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z')
        if (!ok) {
            return false
        }
        if (ch == r'-') {
            hyphenCount += 1
            if (hyphenCount > 1) {
                return false
            }
        }
    }
    true
}

private func cangjieSafeText(raw: String): String {
    let trimmed = redactSensitive(raw.trimAscii())
    if (trimmed.size <= CangjieCapabilityLimits.MAX_TEXT_CHARS) {
        return trimmed
    }
    utf8SafePrefix(trimmed, CangjieCapabilityLimits.MAX_TEXT_CHARS)
}

private func cangjieRecordTrusted(record: NormalizedRecord): Bool {
    record.metadata.reviewState != ReviewStates.CANDIDATE && record.metadata.trustLevel != TrustLevels.WEB_CANDIDATE
}

private func cangjieRecordMatchesApiFilter(record: NormalizedRecord, module: String, symbol: String, sourceSet: String): Bool {
    let haystack = "${record.title} ${record.chunk} ${record.metadata.repo} ${record.metadata.path} ${record.metadata.symbol} ${record.metadata.sourceUrl}".toAsciiLower()
    let cleanModule = module.trimAscii().toAsciiLower()
    let cleanSymbol = symbol.trimAscii().toAsciiLower()
    let cleanSourceSet = sourceSet.trimAscii().toAsciiLower()
    if (cleanModule != "" && !haystack.contains(cleanModule)) {
        return false
    }
    if (cleanSymbol != "" && record.metadata.symbol.toAsciiLower() != cleanSymbol && !haystack.contains(cleanSymbol)) {
        return false
    }
    if (cleanSourceSet != "" && !haystack.contains(cleanSourceSet)) {
        return false
    }
    true
}

private func cangjieExactApiBoost(record: NormalizedRecord, module: String, symbol: String): Float64 {
    var boost = 0.0
    if (symbol.trimAscii() != "" && record.metadata.symbol.toAsciiLower() == symbol.trimAscii().toAsciiLower()) {
        boost += 1.0
    }
    if (module.trimAscii() != "" && "${record.title} ${record.chunk} ${record.metadata.path}".toAsciiLower().contains(module.trimAscii().toAsciiLower())) {
        boost += 0.5
    }
    boost
}

private func cangjieModuleFromRecord(record: NormalizedRecord): String {
    let text = "${record.title} ${record.chunk} ${record.metadata.path} ${record.metadata.sourceUrl}".toAsciiLower()
    if (text.contains("std.collection")) { return "std.collection" }
    if (text.contains("std.regex")) { return "std.regex" }
    if (text.contains("std.time")) { return "std.time" }
    if (text.contains("stdx") || text.contains("json")) { return "stdx" }
    if (text.contains("cjpm") || text.contains("cjc")) { return "toolchain" }
    ""
}

private func cangjieImportLineFromRecord(record: NormalizedRecord): String {
    let module = cangjieModuleFromRecord(record)
    if (module == "std.collection") { return "import std.collection.*" }
    if (module == "std.regex") { return "import std.regex.*" }
    if (module == "std.time") { return "import std.time.*" }
    if (module == "stdx") { return "import stdx.*" }
    ""
}

private func cangjieSignatureFromRecord(record: NormalizedRecord): String {
    if (record.metadata.symbol != "") {
        return record.metadata.symbol
    }
    if (record.title.contains("main")) {
        return "main() { ... }"
    }
    ""
}

private func cangjieExampleFromRecord(record: NormalizedRecord): String {
    let text = record.chunk
    if (text.contains("ArrayList")) {
        return "let values = ArrayList<String>()"
    }
    if (text.contains("Option") || text.contains("Some") || text.contains("None")) {
        return "let value: Option<String> = Some<String>(\"ok\")"
    }
    if (text.contains("main")) {
        return "main() {\n    println(\"Hello\")\n}"
    }
    if (text.contains("Regex") || text.contains("regex")) {
        return "import std.regex.*"
    }
    if (text.contains("JSON") || text.contains("json")) {
        return "import stdx.*"
    }
    cangjieExcerpt(text)
}

private func cangjieExcerpt(raw: String): String {
    let clean = redactSensitive(raw.trimAscii().replace("\n", " ").replace("\r", " "))
    if (clean.size <= 360) {
        return clean
    }
    utf8SafePrefix(clean, 360)
}

public func renderCangjieKnowledgePackMarkdown(pack: CangjieKnowledgePack): String {
    cangjieRenderPackMarkdown(pack, "knowledge-pack", CangjieMarkdownRenderLimits.PACK_MAX_CHARS)
}

public func renderCangjieLlmsTxt(status: KnowledgeStatus, pack: CangjieKnowledgePack): String {
    let builder = CangjieMarkdownBuilder(CangjieMarkdownRenderLimits.LLMS_MAX_CHARS)
    let knowledgeVersion = if (pack.knowledgeVersion != "") { pack.knowledgeVersion } else { status.activeKnowledgeVersion }
    builder.add("# Cangjie\n\n")
    builder.add("knowledgeVersion: ${cangjieMarkdownText(knowledgeVersion)}\n")
    builder.add("targetVersion: ${cangjieMarkdownText(pack.targetVersion)}\n")
    builder.add("truncated: ${pack.truncated}\n")
    builder.add("degraded: ${pack.degraded}\n\n")
    builder.add("## Official docs\n")
    for (url in status.sourceScope.docsUrls) {
        builder.add("- ${cangjieMarkdownText(url)}\n")
    }
    if (status.sourceScope.docsUrls.size == 0) {
        builder.add("- https://docs.cangjie-lang.cn/docs/1.0.0/\n")
    }
    builder.add("\n")
    builder.add(cangjieRenderPackBody(pack, builder.remaining()))
    return builder.finish()
}

public func renderCangjieContextPack(pack: CangjieKnowledgePack): String {
    cangjieRenderPackMarkdown(pack, "context-pack", CangjieMarkdownRenderLimits.CONTEXT_MAX_CHARS)
}

private class CangjieMarkdownRenderLimits {
    static let PACK_MAX_CHARS: Int64 = 12000
    static let LLMS_MAX_CHARS: Int64 = 8000
    static let CONTEXT_MAX_CHARS: Int64 = 8000
}

private class CangjieMarkdownBuilder {
    private let maxChars: Int64
    public var out: String = ""
    public var truncated: Bool = false

    init(maxChars: Int64) {
        this.maxChars = maxChars
    }

    public func add(raw: String): Unit {
        if (this.out.size >= this.maxChars) {
            this.truncated = true
            return
        }
        let clean = redactSensitive(raw)
        let room = this.maxChars - this.out.size
        if (clean.size <= room) {
            this.out += clean
        } else {
            this.out += utf8SafePrefix(clean, room)
            this.truncated = true
        }
    }

    public func remaining(): Int64 {
        if (this.out.size >= this.maxChars) {
            return 0
        }
        this.maxChars - this.out.size
    }

    public func finish(): String {
        this.out
    }
}

private func cangjieRenderPackMarkdown(pack: CangjieKnowledgePack, title: String, maxChars: Int64): String {
    let body = CangjieMarkdownBuilder(maxChars)
    body.add(cangjieRenderPackBody(pack, maxChars))
    let truncated = pack.truncated || body.truncated || body.out.size >= maxChars
    let header = "# Cangjie ${title}\n\nknowledgeVersion: ${cangjieMarkdownText(pack.knowledgeVersion)}\ntargetVersion: ${cangjieMarkdownText(pack.targetVersion)}\ncitations: ${pack.citations.size}\ntruncated=${truncated}\ndegraded=${pack.degraded}\nexecuted=${pack.executed}\n\n"
    let builder = CangjieMarkdownBuilder(maxChars)
    builder.add(header)
    builder.add(body.out)
    if (truncated || builder.truncated) {
        builder.add("\n\ntruncated=true\n")
    }
    builder.finish()
}

private func cangjieRenderPackBody(pack: CangjieKnowledgePack, maxChars: Int64): String {
    let builder = CangjieMarkdownBuilder(maxChars)
    if (pack.task != "") {
        builder.add("## Task\n${cangjieMarkdownText(pack.task)}\n\n")
    }
    if (pack.items.size > 0) {
        builder.add("## Knowledge\n")
        for (item in pack.items) {
            builder.add("### ${cangjieMarkdownText(item.title)}\n")
            builder.add("kind: ${cangjieMarkdownText(item.kind)}\n")
            if (item.module != "") { builder.add("module: ${cangjieMarkdownText(item.module)}\n") }
            if (item.symbol != "") { builder.add("symbol: ${cangjieMarkdownText(item.symbol)}\n") }
            if (item.importLine != "") { builder.add("import: `${cangjieMarkdownInlineCode(item.importLine)}`\n") }
            if (item.signature != "") { builder.add("signature: `${cangjieMarkdownInlineCode(item.signature)}`\n") }
            builder.add("${cangjieMarkdownText(item.content)}\n\n")
            if (item.example != "") {
                builder.add("```cangjie\n${cangjieMarkdownCode(item.example)}\n```\n")
            }
            builder.add("citation: ${cangjieMarkdownText(item.citation)}\nknowledgeVersion: ${cangjieMarkdownText(item.knowledgeVersion)}\ntargetVersion: ${cangjieMarkdownText(item.targetVersion)}\n\n")
        }
    }
    if (pack.apiItems.size > 0) {
        builder.add("## APIs\n")
        for (item in pack.apiItems) {
            let name = if (item.symbol != "") { item.symbol } else { item.module }
            builder.add("### ${cangjieMarkdownText(name)}\n")
            if (item.module != "") { builder.add("module: ${cangjieMarkdownText(item.module)}\n") }
            if (item.importLine != "") { builder.add("import: `${cangjieMarkdownInlineCode(item.importLine)}`\n") }
            if (item.signature != "") { builder.add("signature: `${cangjieMarkdownInlineCode(item.signature)}`\n") }
            builder.add("${cangjieMarkdownText(item.summary)}\n\n")
            if (item.example != "") {
                builder.add("```cangjie\n${cangjieMarkdownCode(item.example)}\n```\n")
            }
            builder.add("citation: ${cangjieMarkdownText(item.citation)}\nknowledgeVersion: ${cangjieMarkdownText(item.knowledgeVersion)}\ntargetVersion: ${cangjieMarkdownText(item.targetVersion)}\n\n")
        }
    }
    if (pack.examples.size > 0) {
        builder.add("## Examples\n")
        for (item in pack.examples) {
            builder.add("### ${cangjieMarkdownText(item.title)}\n")
            builder.add("```cangjie\n${cangjieMarkdownCode(item.code)}\n```\n")
            builder.add("${cangjieMarkdownText(item.explanation)}\n\ncitation: ${cangjieMarkdownText(item.citation)}\nknowledgeVersion: ${cangjieMarkdownText(item.knowledgeVersion)}\ntargetVersion: ${cangjieMarkdownText(item.targetVersion)}\n\n")
        }
    }
    if (pack.diagnostics.size > 0) {
        builder.add("## Diagnostics\n")
        for (item in pack.diagnostics) {
            builder.add("- rule=${cangjieMarkdownText(item.rule)} executed=${item.executed} message=${cangjieMarkdownText(item.message)} citation=${cangjieMarkdownText(item.citation)} knowledgeVersion=${cangjieMarkdownText(item.knowledgeVersion)} targetVersion=${cangjieMarkdownText(item.targetVersion)}\n")
        }
        builder.add("\n")
    }
    if (pack.notes.size > 0) {
        builder.add("## Notes\n")
        for (note in pack.notes) {
            builder.add("- ${cangjieMarkdownText(note)}\n")
        }
        builder.add("\n")
    }
    builder.add("## citations\n")
    for (citation in pack.citations) {
        builder.add("- sourceId=${cangjieMarkdownText(citation.sourceId)} citation=${cangjieMarkdownText(citation.citation)} knowledgeVersion=${cangjieMarkdownText(citation.knowledgeVersion)}\n")
    }
    if (pack.citations.size == 0) {
        builder.add("- none\n")
    }
    builder.finish()
}

private func cangjieMarkdownText(raw: String): String {
    redactSensitive(raw).replace("\r", " ").trimAscii()
}

private func cangjieMarkdownInlineCode(raw: String): String {
    cangjieMarkdownText(raw).replace("`", "'")
}

private func cangjieMarkdownCode(raw: String): String {
    redactSensitive(raw).replace("```", "'''").trimAscii()
}
