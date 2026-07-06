package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieRetrievalRankerTest {
    @TestCase
    public func p4Ut001ExactSymbolRanksAboveDocSection(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.DOC_SECTION, "ArrayList.add docs", "ArrayList.add docs", ""))
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.SYMBOL_CARD, "ArrayList.add", "func add(value: T): Unit", "ArrayList.add"))

        let hits = rankServingHits("ArrayList.add", docs, 2)

        @Expect(hits.size, 2)
        @Expect(hits[0].document.recordKind, CangjieServingRecordKinds.SYMBOL_CARD)
        @Expect(hits[0].rankReason, "exact_symbol_or_symbol_card")
        @Expect(cangjieP4RankHasStage(hits[0], "exact_boost"), true)
        @Expect(cangjieP4RankHasStage(hits[0], "source_trust"), true)
        @Expect(cangjieP4RankHasStage(hits[0], "symbol_module_match"), true)
    }

    @TestCase
    public func p4Neg001RejectedDocumentsAreExcluded(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        let doc = cangjieP4RankDoc(CangjieServingRecordKinds.SYMBOL_CARD, "ArrayList.add", "func add(value: T): Unit", "ArrayList.add")
        doc.rejected = true
        docs.add(doc)

        let hits = rankServingHits("ArrayList.add", docs, 2)

        @Expect(hits.size, 0)
    }

    @TestCase
    public func f4RankStagesExposeNegativeRuleAndLexicalContributions(): Unit {
        let docs = ArrayList<CangjieServingDocument>()
        docs.add(cangjieP4RankDoc(CangjieServingRecordKinds.NEGATIVE_RULE, "Negative Cangjie rule: arraylist_add_not_append", "Bad: .append(...)\nUse: ArrayList.add(...)", ""))

        let hits = rankServingHits("ArrayList append", docs, 1)

        @Expect(hits.size, 1)
        @Expect(cangjieP4RankHasStage(hits[0], "negative_rule_relevance"), true)
        @Expect(cangjieP4RankHasStage(hits[0], "lexical_overlap"), true)
        @Expect(hits[0].score > 0.0, true)
    }
}

private func cangjieP4RankDoc(kind: String, title: String, text: String, symbol: String): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "doc-${title}"
    doc.recordKind = kind
    doc.title = title
    doc.text = text
    doc.symbolKey = symbol
    doc.trustLevel = TrustLevels.OFFICIAL
    doc.reviewState = ReviewStates.TRUSTED
    doc.targetVersion = cangjieDefaultTargetVersion()
    doc.versionResolutionId = "v1"
    doc
}

private func cangjieP4RankHasStage(hit: CangjieRankedServingHit, stage: String): Bool {
    for (contribution in hit.contributions) {
        if (contribution.stage == stage && contribution.score != 0.0) {
            return true
        }
    }
    false
}
