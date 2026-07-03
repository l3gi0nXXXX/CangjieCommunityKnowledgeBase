package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieExampleRecord {
    public var exampleId: String = ""
    public var title: String = ""
    public var code: String = ""
    public var explanation: String = ""
    public var module: String = ""
    public var symbol: String = ""
    public var citation: String = ""
    public var sourceId: String = ""
    public var versionResolutionId: String = ""
    public var trustLevel: String = ""
    public var reviewState: String = ""

    public init() {}
}

public class CangjieRecipeRuleRecord {
    public var recipeId: String = ""
    public var title: String = ""
    public var tags: ArrayList<String> = ArrayList<String>()
    public var steps: String = ""
    public var evidenceCitation: String = ""
    public var versionResolutionId: String = ""
    public var reviewed: Bool = false
    public var diagnostic: String = ""

    public init() {}
}

public class CangjieNegativeRuleRecord {
    public var ruleId: String = ""
    public var title: String = ""
    public var badPattern: String = ""
    public var replacement: String = ""
    public var citation: String = ""
    public var versionResolutionId: String = ""

    public init() {}
}

public class CangjieRecipeRuleBuildResult {
    public var records: ArrayList<CangjieRecipeRuleRecord> = ArrayList<CangjieRecipeRuleRecord>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func buildExampleRecords(record: NormalizedRecord): ArrayList<CangjieExampleRecord> {
    let out = ArrayList<CangjieExampleRecord>()
    let fenced = cangjieExtractCodeFence(record.chunk)
    if (fenced != "") {
        out.add(cangjieExampleRecord(record, fenced, "code fence example"))
        return out
    }
    let generated = cangjieGeneratedExampleFromRecord(record)
    if (generated != "") {
        out.add(cangjieExampleRecord(record, generated, "derived minimal example"))
    }
    out
}

public func buildRecipeRuleRecords(gapRows: ArrayList<String>, evidence: ArrayList<NormalizedRecord>): CangjieRecipeRuleBuildResult {
    let result = CangjieRecipeRuleBuildResult()
    if (evidence.size == 0) {
        result.diagnostics.add("recipe_evidence_missing")
        return result
    }
    for (gap in gapRows) {
        let clean = gap.trimAscii()
        if (clean == "") {
            continue
        }
        let trusted = cangjieFirstTrustedEvidence(evidence, clean)
        if (trusted.sourceId == "") {
            result.diagnostics.add("recipe_evidence_missing:${clean}")
            continue
        }
        let recipe = CangjieRecipeRuleRecord()
        recipe.recipeId = "recipe-${stableSummaryHash(clean)}"
        recipe.title = "HumanEval recipe: ${clean}"
        recipe.tags.add(clean)
        recipe.steps = cangjieRecipeStepsForGap(clean)
        recipe.evidenceCitation = trusted.citation
        recipe.versionResolutionId = trusted.metadata.versionResolutionId
        recipe.reviewed = trusted.metadata.reviewState == ReviewStates.TRUSTED || trusted.metadata.reviewState == ReviewStates.REVIEWED
        if (!recipe.reviewed) {
            recipe.diagnostic = "recipe_evidence_not_reviewed"
        }
        result.records.add(recipe)
    }
    result
}

public func buildNegativeRuleRecords(evidence: ArrayList<NormalizedRecord>): ArrayList<CangjieNegativeRuleRecord> {
    let out = ArrayList<CangjieNegativeRuleRecord>()
    for (record in evidence) {
        let text = "${record.title}\n${record.chunk}".toAsciiLower()
        if (text.contains("main")) {
            out.add(cangjieNegativeRule(record, "no_python_main", "def main() / if __name__", "Use Cangjie main() { ... }"))
        }
        if (text.contains("arraylist")) {
            out.add(cangjieNegativeRule(record, "arraylist_add_not_append", ".append(...)", "Use ArrayList.add(...)"))
        }
        if (text.contains("option")) {
            out.add(cangjieNegativeRule(record, "option_no_null", "null", "Use Some<T>(value) or None<T>"))
        }
    }
    out
}

private func cangjieExampleRecord(record: NormalizedRecord, code: String, title: String): CangjieExampleRecord {
    let example = CangjieExampleRecord()
    example.exampleId = "example-${stableSummaryHash("${record.sourceId}:${code}")}"
    example.title = "${title}: ${record.title}"
    example.code = code
    example.explanation = cangjieShortText(record.chunk)
    example.module = cangjieExampleModule(record)
    example.symbol = if (record.metadata.symbol != "") { record.metadata.symbol } else { cangjieExampleSymbol(record) }
    example.citation = record.citation
    example.sourceId = record.sourceId
    example.versionResolutionId = record.metadata.versionResolutionId
    example.trustLevel = record.metadata.trustLevel
    example.reviewState = record.metadata.reviewState
    example
}

private func cangjieExtractCodeFence(text: String): String {
    var inFence = false
    var captured = false
    let out = StringBuilder()
    for (line in text.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith("```")) {
            if (!inFence && (trimmed.contains("cangjie") || trimmed == "```")) {
                inFence = true
                continue
            }
            if (inFence) {
                break
            }
        }
        if (inFence) {
            out.append(line)
            out.append("\n")
            captured = true
        }
    }
    if (captured) { out.toString().trimAscii() } else { "" }
}

private func cangjieGeneratedExampleFromRecord(record: NormalizedRecord): String {
    let text = "${record.title}\n${record.chunk}\n${record.metadata.symbol}".toAsciiLower()
    if (text.contains("arraylist.add") || (text.contains("arraylist") && text.contains("add"))) {
        return "import std.collection.*\nlet values = ArrayList<Int64>()\nvalues.add(1)"
    }
    if (text.contains("arraylist")) {
        return "import std.collection.*\nlet values = ArrayList<Int64>()"
    }
    if (text.contains("hashmap")) {
        return "import std.collection.*\nlet counts = HashMap<String, Int64>()"
    }
    if (text.contains("option")) {
        return "let value: Option<String> = Some<String>(\"ok\")"
    }
    if (text.contains("main()")) {
        return "main() {\n    println(\"Hello\")\n}"
    }
    ""
}

private func cangjieFirstTrustedEvidence(evidence: ArrayList<NormalizedRecord>, gap: String): NormalizedRecord {
    let needle = gap.toAsciiLower()
    for (record in evidence) {
        if ((record.metadata.reviewState == ReviewStates.TRUSTED || record.metadata.reviewState == ReviewStates.REVIEWED) && "${record.title}\n${record.chunk}".toAsciiLower().contains(needle)) {
            return record
        }
    }
    if (evidence.size > 0 && (evidence[0].metadata.reviewState == ReviewStates.TRUSTED || evidence[0].metadata.reviewState == ReviewStates.REVIEWED)) {
        return evidence[0]
    }
    NormalizedRecord()
}

private func cangjieRecipeStepsForGap(gap: String): String {
    let lower = gap.toAsciiLower()
    if (lower.contains("arraylist")) {
        return "Import std.collection.*, construct ArrayList<T>, iterate with for-in, and use add(...) for append behavior."
    }
    if (lower.contains("string")) {
        return "Use String methods and Rune-safe iteration instead of byte-index assumptions."
    }
    if (lower.contains("float64")) {
        return "Use Float64 arithmetic and compare with an explicit tolerance when tests require approximate equality."
    }
    "Use the cited official/eval-support knowledge before generating the Cangjie implementation."
}

private func cangjieNegativeRule(record: NormalizedRecord, ruleId: String, badPattern: String, replacement: String): CangjieNegativeRuleRecord {
    let rule = CangjieNegativeRuleRecord()
    rule.ruleId = ruleId
    rule.title = "Negative Cangjie rule: ${ruleId}"
    rule.badPattern = badPattern
    rule.replacement = replacement
    rule.citation = record.citation
    rule.versionResolutionId = record.metadata.versionResolutionId
    rule
}

private func cangjieExampleModule(record: NormalizedRecord): String {
    let text = "${record.title}\n${record.chunk}\n${record.metadata.path}".toAsciiLower()
    if (text.contains("std.collection")) { return "std.collection" }
    if (text.contains("std.regex")) { return "std.regex" }
    if (text.contains("std.time")) { return "std.time" }
    if (text.contains("cjpm") || text.contains("cjc")) { return "toolchain" }
    ""
}

private func cangjieExampleSymbol(record: NormalizedRecord): String {
    let cards = extractCangjieSymbols(record)
    if (cards.size > 0) {
        return cards[0].symbolKey
    }
    ""
}

private func cangjieShortText(raw: String): String {
    let clean = redactSensitive(raw.trimAscii().replace("\n", " ").replace("\r", " "))
    if (clean.size <= 240) {
        return clean
    }
    utf8SafePrefix(clean, 240)
}
