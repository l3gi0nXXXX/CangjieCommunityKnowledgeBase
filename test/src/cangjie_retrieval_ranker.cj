package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CangjieRankedServingHit {
    public var document: CangjieServingDocument = CangjieServingDocument()
    public var score: Float64 = 0.0
    public var rankReason: String = ""

    public init() {}
}

public func rankServingHits(query: String, documents: ArrayList<CangjieServingDocument>, budget: Int64): ArrayList<CangjieRankedServingHit> {
    let ranked = ArrayList<CangjieRankedServingHit>()
    for (doc in documents) {
        if (doc.rejected) {
            continue
        }
        let score = cangjieServingRankScore(query, doc)
        if (score <= 0.0) {
            continue
        }
        let hit = CangjieRankedServingHit()
        hit.document = doc
        hit.score = score
        hit.rankReason = cangjieServingRankReason(query, doc)
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

private func cangjieServingRankScore(query: String, doc: CangjieServingDocument): Float64 {
    let q = query.toAsciiLower()
    let text = "${doc.title}\n${doc.text}\n${doc.symbolKey}\n${doc.module}".toAsciiLower()
    var score = 0.0
    if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD) {
        score += 10.0
        if (doc.symbolKey != "" && q.contains(doc.symbolKey.toAsciiLower())) {
            score += 8.0
        }
    } else if (doc.recordKind == CangjieServingRecordKinds.DOC_SECTION) {
        score += 5.0
    } else if (doc.recordKind == CangjieServingRecordKinds.EXAMPLE) {
        score += 4.0
    } else if (doc.recordKind == CangjieServingRecordKinds.RECIPE) {
        score += 3.0
    } else if (doc.recordKind == CangjieServingRecordKinds.NEGATIVE_RULE) {
        score += 2.0
    }
    if (doc.trustLevel == TrustLevels.OFFICIAL) {
        score += 2.0
    }
    if (doc.reviewState == ReviewStates.TRUSTED || doc.reviewState == ReviewStates.REVIEWED) {
        score += 1.0
    }
    for (token in q.split(" ")) {
        let clean = token.trimAscii()
        if (clean != "" && text.contains(clean)) {
            score += 1.0
        }
    }
    score
}

private func cangjieServingRankReason(query: String, doc: CangjieServingDocument): String {
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
