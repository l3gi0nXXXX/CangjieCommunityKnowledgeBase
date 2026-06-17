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
        if (cleanTask == "") {
            pack.degraded = true
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

    public func syntaxQuery(q: String, targetVersion!: String = "", budget!: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET): CangjieKnowledgePack {
        let query = cangjieSafeText(q)
        let pack = this.newPack(query, targetVersion, budget)
        if (query == "") {
            pack.degraded = true
            pack.notes.add("empty_query")
            return pack
        }
        let limit = this.effectiveBudget(pack, budget)
        let result = cangjie_doc_search(this.kb, this.syntaxQueryText(query), limit)
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
        let result = cangjie_hybrid_search(this.kb, "${query} ${module} ${symbol} ${sourceSet}", limit)
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
        let result = cangjie_doc_search(this.kb, this.diagnosticQueryText(query), limit)
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
        let result = cangjie_hybrid_search(this.kb, query, limit)
        for (record in result.records) {
            if (!cangjieRecordTrusted(record)) {
                continue
            }
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
        pack.degraded = pack.degraded || result.degraded
        pack.truncated = pack.truncated || result.truncated
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
    trimmed[0..CangjieCapabilityLimits.MAX_TEXT_CHARS]
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
    clean[0..360]
}
