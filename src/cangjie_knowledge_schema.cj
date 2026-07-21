package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieTaskKnowledgeRequest {
    public var taskId: String = ""
    public var benchmark: String = ""
    public var taskText: String = ""
    public var signature: String = ""
    public var imports: ArrayList<String> = ArrayList<String>()
    public var argTypes: ArrayList<String> = ArrayList<String>()
    public var returnType: String = ""
    public var expectedKnowledgeTags: ArrayList<String> = ArrayList<String>()
    public var starterCodeExcerpt: String = ""
    public var compilerOutput: String = ""
    public var versionSelector: CangjieVersionSelector = CangjieVersionSelector()
    public var budget: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET
    public var responseMode: String = "contract"

    public init() {}
}

public class CangjieQueryPlanItem {
    public var interfaceId: String = ""
    public var queryKind: String = ""
    public var query: String = ""
    public var sourceSet: String = ""
    public var symbol: String = ""
    public var requiredTag: String = ""
    public var versionResolutionId: String = ""

    public init() {}
}

public class CangjieRequiredKnowledge {
    public var tag: String = ""
    public var interfaceId: String = ""
    public var status: String = "missing"
    public var reason: String = ""

    public init() {}
}

public class CangjieKnowledgeCoverage {
    public var coveragePass: Bool = false
    public var requiredCount: Int64 = 0
    public var coveredCount: Int64 = 0
    public var missingCount: Int64 = 0
    public var required: ArrayList<CangjieRequiredKnowledge> = ArrayList<CangjieRequiredKnowledge>()

    public init() {}
}

public class CangjieMatchedEvidence {
    public var sourceId: String = ""
    public var title: String = ""
    public var citation: String = ""
    public var provenance: String = ""
    public var contentHash: String = ""
    public var knowledge: String = ""
    public var example: String = ""

    public init() {}
}

public class CangjieTaskKnowledgePack {
    public var queryId: String = ""
    public var taskId: String = ""
    public var benchmark: String = ""
    public var knowledgeVersion: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var evidenceHash: String = ""
    public var versionResolution: CangjieVersionResolution = CangjieVersionResolution()
    public var queryPlan: ArrayList<CangjieQueryPlanItem> = ArrayList<CangjieQueryPlanItem>()
    public var requiredKnowledge: ArrayList<CangjieRequiredKnowledge> = ArrayList<CangjieRequiredKnowledge>()
    public var matchedEvidence: ArrayList<CangjieMatchedEvidence> = ArrayList<CangjieMatchedEvidence>()
    public var examples: ArrayList<CangjieExampleRecord> = ArrayList<CangjieExampleRecord>()
    public var negativeRules: ArrayList<CangjieNegativeRuleRecord> = ArrayList<CangjieNegativeRuleRecord>()
    public var citations: ArrayList<SourceReference> = ArrayList<SourceReference>()
    public var coverage: CangjieKnowledgeCoverage = CangjieKnowledgeCoverage()
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public var degraded: Bool = true
    public var truncated: Bool = false
    public var notes: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public class EvidencePackRequest {
    public var q: String = ""
    public var targetVersion: String = ""
    public var sourceSet: String = ""
    public var budget: Int64 = CangjieCapabilityLimits.DEFAULT_BUDGET

    public init() {}
}

public func sanitizeCangjieTaskKnowledgeRequest(request: CangjieTaskKnowledgeRequest): CangjieTaskKnowledgeRequest {
    request.taskId = cangjieKnowledgeSafeText(request.taskId)
    request.benchmark = cangjieKnowledgeSafeText(request.benchmark)
    request.taskText = cangjieKnowledgeSafeText(request.taskText)
    request.signature = cangjieKnowledgeSafeText(request.signature)
    request.returnType = cangjieKnowledgeSafeText(request.returnType)
    request.compilerOutput = cangjieKnowledgeSafeText(request.compilerOutput)
    request.versionSelector.targetVersion = request.versionSelector.targetVersion.trimAscii()
    request.versionSelector.sourceSet = request.versionSelector.sourceSet.trimAscii()
    request.versionSelector.sourceFamily = request.versionSelector.sourceFamily.trimAscii()
    request.versionSelector.sourceRepo = request.versionSelector.sourceRepo.trimAscii()
    request.versionSelector.sourceRef = request.versionSelector.sourceRef.trimAscii()
    request.versionSelector.refKind = request.versionSelector.refKind.trimAscii()
    request.versionSelector.versionPolicy = request.versionSelector.versionPolicy.trimAscii()
    if (request.starterCodeExcerpt.size > CangjieCapabilityLimits.MAX_TEXT_CHARS) {
        request.starterCodeExcerpt = utf8SafePrefix(request.starterCodeExcerpt, CangjieCapabilityLimits.MAX_TEXT_CHARS)
    } else {
        request.starterCodeExcerpt = cangjieKnowledgeSafeText(request.starterCodeExcerpt)
    }
    request.budget = cangjieCapabilityClampBudget(request.budget, CangjieCapabilityLimits.DEFAULT_BUDGET, CangjieCapabilityLimits.MAX_BUDGET)
    request
}

public func validateCangjieTaskKnowledgeRequest(request: CangjieTaskKnowledgeRequest): String {
    if (request.taskText.trimAscii() == "" && request.signature.trimAscii() == "") {
        return "task_or_signature_required"
    }
    if (request.budget < 1 || request.budget > CangjieCapabilityLimits.MAX_BUDGET) {
        return "budget_out_of_range"
    }
    ""
}

public func buildCangjieTaskKnowledgePack(status: KnowledgeStatus, request: CangjieTaskKnowledgeRequest, manifest: CangjieVersionManifest): CangjieTaskKnowledgePack {
    let originalStarterSize = request.starterCodeExcerpt.size
    let sanitized = sanitizeCangjieTaskKnowledgeRequest(request)
    let pack = CangjieTaskKnowledgePack()
    let validation = validateCangjieTaskKnowledgeRequest(sanitized)
    pack.taskId = sanitized.taskId
    pack.benchmark = sanitized.benchmark
    pack.knowledgeVersion = status.activeKnowledgeVersion
    if (pack.knowledgeVersion == "") {
        pack.knowledgeVersion = "offline"
    }
    pack.queryId = "cangjie-task-${stableSummaryHash("${sanitized.taskId}:${sanitized.benchmark}:${sanitized.taskText}:${sanitized.signature}")}"
    if (validation != "") {
        pack.diagnostics.add(validation)
        pack.notes.add("invalid_task_knowledge_request")
        pack.versionResolution = resolveCangjieVersion(sanitized.versionSelector, manifest)
        pack.targetVersion = pack.versionResolution.targetVersion
        pack.coverage = buildCangjieKnowledgeCoverage(sanitized, pack.versionResolution, pack.queryPlan)
        return pack
    }
    pack.versionResolution = resolveCangjieVersion(sanitized.versionSelector, manifest)
    pack.targetVersion = pack.versionResolution.targetVersion
    pack.queryPlan = buildCangjieTaskQueryPlan(sanitized, pack.versionResolution)
    pack.coverage = buildCangjieKnowledgeCoverage(sanitized, pack.versionResolution, pack.queryPlan)
    pack.requiredKnowledge = cangjieCopyRequiredKnowledge(pack.coverage.required)
    pack.degraded = true
    pack.notes.add("evidence_builder_not_available")
    if (originalStarterSize > CangjieCapabilityLimits.MAX_TEXT_CHARS) {
        pack.truncated = true
        pack.diagnostics.add("starter_code_excerpt_truncated")
    }
    for (diagnostic in pack.versionResolution.diagnostics) {
        if (!pack.diagnostics.contains(diagnostic)) {
            pack.diagnostics.add(diagnostic)
        }
    }
    if (!pack.versionResolution.ok && pack.versionResolution.diagnostic != "") {
        pack.diagnostics.add(pack.versionResolution.diagnostic)
    }
    pack
}

public func buildCangjieTaskQueryPlan(request: CangjieTaskKnowledgeRequest, resolution: CangjieVersionResolution): ArrayList<CangjieQueryPlanItem> {
    let plan = ArrayList<CangjieQueryPlanItem>()
    let sourceSet = request.versionSelector.sourceSet.trimAscii()
    let resolvedSourceSet = if (sourceSet == "") { CangjieSourceSets.ALL } else { sourceSet }
    if (request.taskText.trimAscii() != "") {
        plan.add(cangjieQueryPlanItem("KI-02", "task_semantic_search", request.taskText, resolvedSourceSet, "", "task", resolution.versionResolutionId))
    }
    if (request.signature.trimAscii() != "") {
        plan.add(cangjieQueryPlanItem("KI-04", "symbol_signature_lookup", request.signature, resolvedSourceSet, request.signature, "signature", resolution.versionResolutionId))
    }
    for (name in request.imports) {
        let cleaned = name.trimAscii()
        if (cleaned != "") {
            plan.add(cangjieQueryPlanItem("KI-04", "import_api_lookup", cleaned, resolvedSourceSet, cleaned, "import", resolution.versionResolutionId))
        }
    }
    for (tag in request.expectedKnowledgeTags) {
        let cleaned = tag.trimAscii()
        if (cleaned != "") {
            plan.add(cangjieQueryPlanItem(cangjieKnowledgeTagInterfaceId(cleaned), "required_knowledge_lookup", cleaned, resolvedSourceSet, "", cleaned, resolution.versionResolutionId))
        }
    }
    if (request.compilerOutput.trimAscii() != "") {
        plan.add(cangjieQueryPlanItem("KI-09", "compiler_diagnostic_lookup", request.compilerOutput, resolvedSourceSet, "", "compiler-output", resolution.versionResolutionId))
    }
    plan
}

public func buildCangjieKnowledgeCoverage(request: CangjieTaskKnowledgeRequest, resolution: CangjieVersionResolution, plan: ArrayList<CangjieQueryPlanItem>): CangjieKnowledgeCoverage {
    let coverage = CangjieKnowledgeCoverage()
    for (tag in request.expectedKnowledgeTags) {
        let cleaned = tag.trimAscii()
        if (cleaned != "") {
            let required = CangjieRequiredKnowledge()
            required.tag = cleaned
            required.interfaceId = cangjieKnowledgeTagInterfaceId(cleaned)
            if (!resolution.ok) {
                required.status = "degraded"
                required.reason = resolution.diagnostic
            } else if (cangjiePlanHasTag(plan, cleaned)) {
                required.status = "degraded"
                required.reason = "evidence_not_evaluated"
            } else {
                required.status = "missing"
                required.reason = "query_plan_missing"
            }
            coverage.required.add(required)
        }
    }
    if (coverage.required.size == 0) {
        let required = CangjieRequiredKnowledge()
        required.tag = "task-context"
        required.interfaceId = "KI-02"
        if (!resolution.ok) {
            required.status = "degraded"
            required.reason = resolution.diagnostic
        } else if (plan.size > 0) {
            required.status = "degraded"
            required.reason = "evidence_not_evaluated"
        } else {
            required.status = "missing"
            required.reason = "query_plan_missing"
        }
        coverage.required.add(required)
    }
    coverage.requiredCount = coverage.required.size
    for (required in coverage.required) {
        if (required.status == "covered") {
            coverage.coveredCount += 1
        } else {
            coverage.missingCount += 1
        }
    }
    coverage.coveragePass = resolution.ok && coverage.missingCount == 0
    coverage
}

public func cangjieVersionResolutionJson(resolution: CangjieVersionResolution): String {
    var out = "{\"ok\":${resolution.ok},\"diagnostic\":\"${cangjieKnowledgeJsonEscape(resolution.diagnostic)}\",\"targetVersion\":\"${cangjieKnowledgeJsonEscape(resolution.targetVersion)}\",\"versionPolicy\":\"${cangjieKnowledgeJsonEscape(resolution.versionPolicy)}\",\"versionResolutionId\":\"${cangjieKnowledgeJsonEscape(resolution.versionResolutionId)}\",\"defaulted\":${resolution.defaulted},\"sources\":["
    for (i in 0..resolution.sources.size) {
        if (i > 0) { out += "," }
        out += cangjieVersionSourceJson(resolution.sources[i])
    }
    out += "],\"diagnostics\":${cangjieKnowledgeStringArrayJson(resolution.diagnostics)}}"
    out
}

public func cangjieTaskKnowledgePackJson(pack: CangjieTaskKnowledgePack): String {
    var out = "{\"resultType\":\"task_knowledge_pack\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"task_knowledge\",\"updateMechanism\":\"first_init_or_routine_update\",\"queryId\":\"${cangjieKnowledgeJsonEscape(pack.queryId)}\",\"taskId\":\"${cangjieKnowledgeJsonEscape(pack.taskId)}\",\"benchmark\":\"${cangjieKnowledgeJsonEscape(pack.benchmark)}\",\"knowledgeVersion\":\"${cangjieKnowledgeJsonEscape(pack.knowledgeVersion)}\",\"targetVersion\":\"${cangjieKnowledgeJsonEscape(pack.targetVersion)}\",\"evidenceHash\":\"${cangjieKnowledgeJsonEscape(pack.evidenceHash)}\",\"degraded\":${pack.degraded},\"truncated\":${pack.truncated},\"versionResolution\":${cangjieVersionResolutionJson(pack.versionResolution)},\"queryPlan\":["
    for (i in 0..pack.queryPlan.size) {
        if (i > 0) { out += "," }
        out += cangjieQueryPlanItemJson(pack.queryPlan[i])
    }
    out += "],\"requiredKnowledge\":${cangjieRequiredKnowledgeArrayJson(pack.requiredKnowledge)},\"matchedEvidence\":${cangjieMatchedEvidenceJson(pack.matchedEvidence)},\"examples\":${cangjieTaskExamplesJson(pack.examples)},\"negativeRules\":${cangjieNegativeRulesJson(pack.negativeRules)},\"citations\":${cangjieTaskCitationsJson(pack.citations)},\"coverage\":${cangjieKnowledgeCoverageJson(pack.coverage)},\"diagnostics\":${cangjieKnowledgeStringArrayJson(pack.diagnostics)},\"notes\":${cangjieKnowledgeStringArrayJson(pack.notes)}}"
    out
}

public func cangjieKnowledgeCoverageJson(coverage: CangjieKnowledgeCoverage): String {
    var out = "{\"coveragePass\":${coverage.coveragePass},\"requiredCount\":${coverage.requiredCount},\"coveredCount\":${coverage.coveredCount},\"missingCount\":${coverage.missingCount},\"required\":["
    for (i in 0..coverage.required.size) {
        if (i > 0) { out += "," }
        out += cangjieRequiredKnowledgeJson(coverage.required[i])
    }
    out += "]}"
    out
}

public func cangjieCopyRequiredKnowledge(source: ArrayList<CangjieRequiredKnowledge>): ArrayList<CangjieRequiredKnowledge> {
    let out = ArrayList<CangjieRequiredKnowledge>()
    for (item in source) {
        let copy = CangjieRequiredKnowledge()
        copy.tag = item.tag
        copy.interfaceId = item.interfaceId
        copy.status = item.status
        copy.reason = item.reason
        out.add(copy)
    }
    out
}

private func cangjieQueryPlanItem(interfaceId: String, queryKind: String, query: String, sourceSet: String, symbol: String, requiredTag: String, versionResolutionId: String): CangjieQueryPlanItem {
    let item = CangjieQueryPlanItem()
    item.interfaceId = interfaceId
    item.queryKind = queryKind
    item.query = query
    item.sourceSet = sourceSet
    item.symbol = symbol
    item.requiredTag = requiredTag
    item.versionResolutionId = versionResolutionId
    item
}

private func cangjiePlanHasTag(plan: ArrayList<CangjieQueryPlanItem>, tag: String): Bool {
    for (item in plan) {
        if (item.requiredTag == tag) {
            return true
        }
    }
    false
}

public func cangjieKnowledgeTagInterfaceId(tag: String): String {
    let lower = tag.toAsciiLower()
    if (lower.contains("symbol") || lower.contains("api") || lower.contains("array") || lower.contains("string") || lower.contains("hash") || lower.contains("math")) {
        return "KI-04"
    }
    if (lower.contains("compile") || lower.contains("diagnostic") || lower.contains("error")) {
        return "KI-09"
    }
    if (lower.contains("example") || lower.contains("recipe")) {
        return "KI-07"
    }
    "KI-02"
}

private func cangjieRequiredKnowledgeArrayJson(items: ArrayList<CangjieRequiredKnowledge>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        out += cangjieRequiredKnowledgeJson(items[i])
    }
    out += "]"
    out
}

private func cangjieRequiredKnowledgeJson(item: CangjieRequiredKnowledge): String {
    "{\"tag\":\"${cangjieKnowledgeJsonEscape(item.tag)}\",\"interfaceId\":\"${cangjieKnowledgeJsonEscape(item.interfaceId)}\",\"status\":\"${cangjieKnowledgeJsonEscape(item.status)}\",\"reason\":\"${cangjieKnowledgeJsonEscape(item.reason)}\"}"
}

private func cangjieTaskExamplesJson(items: ArrayList<CangjieExampleRecord>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        let item = items[i]
        out += "{\"exampleId\":\"${cangjieKnowledgeJsonEscape(item.exampleId)}\",\"title\":\"${cangjieKnowledgeJsonEscape(item.title)}\",\"code\":\"${cangjieKnowledgeJsonEscape(item.code)}\",\"explanation\":\"${cangjieKnowledgeJsonEscape(item.explanation)}\",\"module\":\"${cangjieKnowledgeJsonEscape(item.module)}\",\"symbol\":\"${cangjieKnowledgeJsonEscape(item.symbol)}\",\"citation\":\"${cangjieKnowledgeJsonEscape(item.citation)}\",\"sourceId\":\"${cangjieKnowledgeJsonEscape(item.sourceId)}\",\"versionResolutionId\":\"${cangjieKnowledgeJsonEscape(item.versionResolutionId)}\",\"trustLevel\":\"${cangjieKnowledgeJsonEscape(item.trustLevel)}\",\"reviewState\":\"${cangjieKnowledgeJsonEscape(item.reviewState)}\",\"compileStatus\":\"${cangjieKnowledgeJsonEscape(item.compileStatus)}\",\"provenance\":\"${cangjieKnowledgeJsonEscape(item.provenance)}\"}"
    }
    out += "]"
    out
}

private func cangjieMatchedEvidenceJson(items: ArrayList<CangjieMatchedEvidence>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        let item = items[i]
        out += "{\"sourceId\":\"${cangjieKnowledgeJsonEscape(item.sourceId)}\",\"title\":\"${cangjieKnowledgeJsonEscape(item.title)}\",\"citation\":\"${cangjieKnowledgeJsonEscape(item.citation)}\",\"provenance\":\"${cangjieKnowledgeJsonEscape(item.provenance)}\",\"contentHash\":\"${cangjieKnowledgeJsonEscape(item.contentHash)}\",\"knowledge\":\"${cangjieKnowledgeJsonEscape(item.knowledge)}\",\"example\":\"${cangjieKnowledgeJsonEscape(item.example)}\"}"
    }
    out += "]"
    out
}

private func cangjieNegativeRulesJson(items: ArrayList<CangjieNegativeRuleRecord>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        let item = items[i]
        out += "{\"ruleId\":\"${cangjieKnowledgeJsonEscape(item.ruleId)}\",\"title\":\"${cangjieKnowledgeJsonEscape(item.title)}\",\"badPattern\":\"${cangjieKnowledgeJsonEscape(item.badPattern)}\",\"replacement\":\"${cangjieKnowledgeJsonEscape(item.replacement)}\",\"citation\":\"${cangjieKnowledgeJsonEscape(item.citation)}\",\"versionResolutionId\":\"${cangjieKnowledgeJsonEscape(item.versionResolutionId)}\",\"provenance\":\"${cangjieKnowledgeJsonEscape(item.provenance)}\"}"
    }
    out += "]"
    out
}

private func cangjieTaskCitationsJson(items: ArrayList<SourceReference>): String {
    var out = "["
    for (i in 0..items.size) {
        if (i > 0) { out += "," }
        let item = items[i]
        out += "{\"sourceId\":\"${cangjieKnowledgeJsonEscape(item.sourceId)}\",\"citation\":\"${cangjieKnowledgeJsonEscape(item.citation)}\",\"knowledgeVersion\":\"${cangjieKnowledgeJsonEscape(item.knowledgeVersion)}\"}"
    }
    out += "]"
    out
}

private func cangjieVersionSourceJson(source: CangjieVersionSource): String {
    "{\"targetVersion\":\"${cangjieKnowledgeJsonEscape(source.targetVersion)}\",\"sourceSet\":\"${cangjieKnowledgeJsonEscape(source.sourceSet)}\",\"sourceFamily\":\"${cangjieKnowledgeJsonEscape(source.sourceFamily)}\",\"sourceRepo\":\"${cangjieKnowledgeJsonEscape(source.sourceRepo)}\",\"sourceRef\":\"${cangjieKnowledgeJsonEscape(source.sourceRef)}\",\"refKind\":\"${cangjieKnowledgeJsonEscape(source.refKind)}\",\"resolvedCommit\":\"${cangjieKnowledgeJsonEscape(source.resolvedCommit)}\",\"contentHash\":\"${cangjieKnowledgeJsonEscape(source.contentHash)}\"}"
}

private func cangjieQueryPlanItemJson(item: CangjieQueryPlanItem): String {
    "{\"interfaceId\":\"${cangjieKnowledgeJsonEscape(item.interfaceId)}\",\"queryKind\":\"${cangjieKnowledgeJsonEscape(item.queryKind)}\",\"query\":\"${cangjieKnowledgeJsonEscape(item.query)}\",\"sourceSet\":\"${cangjieKnowledgeJsonEscape(item.sourceSet)}\",\"symbol\":\"${cangjieKnowledgeJsonEscape(item.symbol)}\",\"requiredTag\":\"${cangjieKnowledgeJsonEscape(item.requiredTag)}\",\"versionResolutionId\":\"${cangjieKnowledgeJsonEscape(item.versionResolutionId)}\"}"
}

private func cangjieKnowledgeSafeText(raw: String): String {
    let trimmed = redactSensitive(raw.trimAscii())
    if (trimmed.size <= CangjieCapabilityLimits.MAX_TEXT_CHARS) {
        return trimmed
    }
    utf8SafePrefix(trimmed, CangjieCapabilityLimits.MAX_TEXT_CHARS)
}

private func cangjieKnowledgeStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) { out += "," }
        out += "\"${cangjieKnowledgeJsonEscape(values[i])}\""
    }
    out += "]"
    out
}

private func cangjieKnowledgeJsonEscape(raw: String): String {
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
