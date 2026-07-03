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
