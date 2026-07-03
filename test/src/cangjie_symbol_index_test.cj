package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieSymbolIndexTest {
    @TestCase
    public func p3Ut001ExtractsArrayListAddAndStringContains(): Unit {
        let record = cangjieP3SymbolTestRecord("r1", "ArrayList.add and String.contains", "import std.collection.*\nvalues.add(1)\nString contains API", "v1")

        let cards = extractCangjieSymbols(record)

        @Expect(cangjieP3SymbolHas(cards, "ArrayList.add", "v1"), true)
        @Expect(cangjieP3SymbolHas(cards, "String.contains", "v1"), true)
        @Expect(cangjieP3SymbolImport(cards, "ArrayList.add"), "import std.collection.*")
    }

    @TestCase
    public func p3Bnd001SameSymbolDifferentVersionIsNotMerged(): Unit {
        let cards = ArrayList<CangjieSymbolCardRecord>()
        cards.add(extractCangjieSymbols(cangjieP3SymbolTestRecord("r1", "ArrayList.add", "ArrayList.add", "v1"))[0])
        cards.add(extractCangjieSymbols(cangjieP3SymbolTestRecord("r2", "ArrayList.add", "ArrayList.add", "v2"))[0])

        let merged = mergeSymbolCards(cards)

        @Expect(merged.size, 2)
        @Expect(cangjieP3SymbolHas(merged, "ArrayList.add", "v1"), true)
        @Expect(cangjieP3SymbolHas(merged, "ArrayList.add", "v2"), true)
    }

    @TestCase
    public func stU1001ExactSymbolCardCarriesVersionFields(): Unit {
        let card = extractCangjieSymbols(cangjieP3SymbolTestRecord("r1", "ArrayList.add", "ArrayList.add", "v1"))[0]

        @Expect(card.symbolKey, "ArrayList.add")
        @Expect(card.targetVersion, "1.0.0")
        @Expect(card.versionResolutionId, "v1")
        @Expect(card.sourceSet, CangjieSourceSets.DOCS)
        @Expect(card.incomplete, false)
    }
}

private func cangjieP3SymbolTestRecord(sourceId: String, title: String, chunk: String, versionResolutionId: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.title = title
    record.chunk = chunk
    record.citation = "test:${sourceId}"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.targetVersion = cangjieDefaultTargetVersion()
    record.metadata.versionResolutionId = versionResolutionId
    record.metadata.docVersion = "release-1.0.0"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func cangjieP3SymbolHas(cards: ArrayList<CangjieSymbolCardRecord>, symbol: String, versionResolutionId: String): Bool {
    for (card in cards) {
        if (card.symbolKey == symbol && card.versionResolutionId == versionResolutionId) {
            return true
        }
    }
    false
}

private func cangjieP3SymbolImport(cards: ArrayList<CangjieSymbolCardRecord>, symbol: String): String {
    for (card in cards) {
        if (card.symbolKey == symbol) {
            return card.importLine
        }
    }
    ""
}
