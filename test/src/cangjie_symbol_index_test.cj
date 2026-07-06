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

    @TestCase
    public func p3Pos002StructuredSymbolCardBypassesTextGuessing(): Unit {
        let typed = CangjieTypedRecord()
        typed.recordKind = CangjieTypedRecordKinds.SYMBOL_CARD
        typed.sourceId = "source-symbol-std-arraylist-add"
        typed.title = "Symbol: ArrayList.add"
        typed.content = "symbolKey=ArrayList.add\nmodule=std.collection\nimportLine=import std.collection.*\nsignature=public func add(value: T): Unit\nreceiver=ArrayList\nparams=value: T\nreturnType=Unit\navailability=stable\ndiagnostic="
        typed.citation = "Cangjie/cangjie_runtime@offline-baseline-std:src/std/collection/arraylist.cj#ArrayList.add"
        typed.sourceSet = CangjieSourceSets.STD
        typed.path = "src/std/collection/arraylist.cj"
        typed.symbol = "ArrayList.add"
        typed.targetVersion = "1.0.0"
        typed.versionResolutionId = "cangjie-1.0.0-std"
        typed.sourceRef = "release-1.0.0"
        typed.resolvedCommit = "offline-baseline-std"
        typed.trustLevel = TrustLevels.OFFICIAL
        typed.reviewState = ReviewStates.TRUSTED
        let normalized = cangjieTypedRecordToNormalized(typed, KnowledgeMetadata())

        let cards = extractCangjieSymbols(normalized)

        @Expect(cards.size, 1)
        @Expect(cards[0].symbolKey, "ArrayList.add")
        @Expect(cards[0].module, "std.collection")
        @Expect(cards[0].sourceSet, CangjieSourceSets.STD)
        @Expect(cards[0].signature, "public func add(value: T): Unit")
        @Expect(cangjieSymbolCardMatches(cards[0], "std.collection.ArrayList.add", "", CangjieSourceSets.STD), true)
        @Expect(cangjieSymbolCardMatches(cards[0], "ArrayList.addAll", "", CangjieSourceSets.STD), false)
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
