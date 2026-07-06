package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieRankingContribution {
    public var stage: String = ""
    public var score: Float64 = 0.0
    public var reason: String = ""

    public init() {}
}

public class CangjieRankedServingHit {
    public var document: CangjieServingDocument = CangjieServingDocument()
    public var score: Float64 = 0.0
    public var rankReason: String = ""
    public var contributions: ArrayList<CangjieRankingContribution> = ArrayList<CangjieRankingContribution>()

    public init() {}
}

public func rankServingHits(query: String, documents: ArrayList<CangjieServingDocument>, budget: Int64): ArrayList<CangjieRankedServingHit> {
    let ranked = ArrayList<CangjieRankedServingHit>()
    for (doc in documents) {
        if (doc.rejected) {
            continue
        }
        let contributions = rankServingHitStages(query, doc)
        let score = cangjieServingRankScore(contributions)
        if (score <= 0.0) {
            continue
        }
        let hit = CangjieRankedServingHit()
        hit.document = doc
        hit.score = score
        hit.rankReason = cangjieServingRankReason(doc)
        hit.contributions = contributions
        cangjieInsertRankedHit(ranked, hit)
    }
    let out = ArrayList<CangjieRankedServingHit>()
    let limit = if (budget < 1) { ranked.size } else { budget }
    for (i in 0..ranked.size) {
        if (out.size >= limit) {
            break
        }
        out.add(ranked[i])
    }
    out
}

public func rankServingHitStages(query: String, doc: CangjieServingDocument): ArrayList<CangjieRankingContribution> {
    let contributions = ArrayList<CangjieRankingContribution>()
    let q = query.toAsciiLower()
    let text = "${doc.title}\n${doc.text}\n${doc.symbolKey}\n${doc.module}\n${doc.sourceId}\n${doc.citation}".toAsciiLower()
    var relevant = false
    if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) {
        if (doc.symbolKey != "" && q.contains(doc.symbolKey.toAsciiLower())) {
            contributions.add(cangjieRankingContribution("exact_boost", 18.0, "exact_symbol_match"))
            relevant = true
        } else {
            contributions.add(cangjieRankingContribution("exact_boost", 6.0, "symbol_card"))
        }
    } else if (doc.recordKind == CangjieServingRecordKinds.DOC_SECTION) {
        contributions.add(cangjieRankingContribution("exact_boost", 2.0, "doc_section"))
    } else if (doc.recordKind == CangjieServingRecordKinds.EXAMPLE) {
        contributions.add(cangjieRankingContribution("exact_boost", 2.0, "example"))
    } else if (doc.recordKind == CangjieServingRecordKinds.RECIPE) {
        contributions.add(cangjieRankingContribution("exact_boost", 1.5, "recipe"))
    } else if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE) {
        contributions.add(cangjieRankingContribution("negative_rule_relevance", cangjieNegativeRuleRankScore(q, text), "negative_rule"))
        relevant = relevant || cangjieNegativeRuleRankScore(q, text) > 0.0
    }
    if (doc.trustLevel == TrustLevels.OFFICIAL) {
        contributions.add(cangjieRankingContribution("source_trust", 2.0, "official"))
    }
    if (doc.reviewState == ReviewStates.TRUSTED || doc.reviewState == ReviewStates.REVIEWED) {
        contributions.add(cangjieRankingContribution("source_trust", 1.0, doc.reviewState))
    }
    if (doc.targetVersion != "" && doc.targetVersion == cangjieNormalizeTargetVersion("")) {
        contributions.add(cangjieRankingContribution("version_match", 2.0, "target_version_match"))
    }
    if (doc.symbolKey != "" && q.contains(doc.symbolKey.toAsciiLower())) {
        contributions.add(cangjieRankingContribution("symbol_module_match", 4.0, "symbol_match"))
        relevant = true
    }
    if (doc.module != "" && q.contains(doc.module.toAsciiLower())) {
        contributions.add(cangjieRankingContribution("symbol_module_match", 2.0, "module_match"))
        relevant = true
    }
    let lexical = cangjieLexicalOverlapRankScore(q, text)
    if (lexical > 0.0) {
        contributions.add(cangjieRankingContribution("lexical_overlap", lexical, "token_overlap"))
        relevant = true
    }
    if (!relevant) {
        contributions.add(cangjieRankingContribution("relevance_gate", -1000.0, "no_query_overlap"))
    }
    contributions
}

private func cangjieServingRankScore(contributions: ArrayList<CangjieRankingContribution>): Float64 {
    var score = 0.0
    for (contribution in contributions) {
        score += contribution.score
    }
    score
}

private func cangjieLexicalOverlapRankScore(query: String, text: String): Float64 {
    var score = 0.0
    for (token in query.split(" ")) {
        let clean = token.trimAscii()
        if (clean != "" && text.contains(clean)) {
            score += 1.0
        }
    }
    score
}

private func cangjieNegativeRuleRankScore(query: String, text: String): Float64 {
    var score = 0.0
    for (token in query.split(" ")) {
        let clean = token.trimAscii()
        if (clean.size >= 3 && text.contains(clean)) {
            score += 2.0
        }
    }
    score
}

private func cangjieRankingContribution(stage: String, score: Float64, reason: String): CangjieRankingContribution {
    let contribution = CangjieRankingContribution()
    contribution.stage = stage
    contribution.score = score
    contribution.reason = reason
    contribution
}

private func cangjieServingRankReason(doc: CangjieServingDocument): String {
    if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) {
        return "exact_symbol_or_symbol_card"
    }
    if (doc.recordKind == CangjieServingRecordKinds.DOC_SECTION) {
        return "official_doc_section"
    }
    if (doc.recordKind == CangjieServingRecordKinds.EXAMPLE) {
        return "official_example"
    }
    if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE) {
        return "negative_rule"
    }
    "serving_rank"
}

private func cangjieInsertRankedHit(ranked: ArrayList<CangjieRankedServingHit>, hit: CangjieRankedServingHit): Unit {
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
    if (!inserted) {
        ranked.add(hit)
    }
}
