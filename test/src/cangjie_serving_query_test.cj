package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.time.DateTime
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieServingQueryTest {
    @TestCase
    public func p2Pos001ExactSymbolLookupReturnsExactHitCitationAndAlias(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4Record("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nimportLine=import std.collection.*\nsignature=public func add(value: T): Unit\naliases=ArrayList.add;std.collection.ArrayList.add;add\navailability=stable", CangjieSourceSets.STD, "1.0.0", "vr-std-1"))
        let index = buildCangjieServingIndex(records, activeKnowledgeVersion: "active-p2")

        let exact = lookupExactSymbol(index, "ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0", versionResolutionId: "vr-std-1", budget: 3)
        let qualified = lookupExactSymbol(index, "std.collection.ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0", versionResolutionId: "vr-std-1", budget: 3)

        @Expect(exact.ok, true)
        @Expect(exact.diagnostic, "exact_hit")
        @Expect(exact.hits.size, 1)
        @Expect(exact.hits[0].document.citation, "test:sym-arraylist-add")
        @Expect(qualified.ok, true)
        @Expect(qualified.hits.size, 1)
    }

    @TestCase
    public func p2Neg001ExactSymbolLookupDoesNotReturnBroadHit(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4Record("sym-arraylist-addall", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.addAll", "symbolKey=ArrayList.addAll\nmodule=std.collection\nsignature=public func addAll(values: ArrayList<T>): Unit\naliases=ArrayList.addAll;std.collection.ArrayList.addAll;addAll", CangjieSourceSets.STD, "1.0.0", "vr-std-1"))
        let index = buildCangjieServingIndex(records, activeKnowledgeVersion: "active-p2")

        let miss = lookupExactSymbol(index, "ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0", versionResolutionId: "vr-std-1", budget: 3)

        @Expect(miss.ok, false)
        @Expect(miss.degraded, true)
        @Expect(miss.diagnostic, "exact_miss")
        @Expect(miss.hits.size, 0)
    }

    @TestCase
    public func p4Pos001LocalBackendExactLookupReturnsEvidenceHash(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieP4QueryRecord("r1", "ArrayList.add docs", "ArrayList.add appends values. values.add(1)."))
        let backend = LocalFixtureServingBackend(buildServingDocuments(records))
        let request = CangjieServingSearchRequest()
        request.query = "ArrayList.add"
        request.symbol = "ArrayList.add"
        request.budget = 2

        let result = backend.exactLookup(request)

        @Expect(result.ok, true)
        @Expect(result.hits.size > 0, true)
        @Expect(result.hits[0].document.recordKind, CangjieServingRecordKinds.SYMBOL_CARD)
        @Expect(result.evidenceHash.startsWith("h"), true)
    }

    @TestCase
    public func stP1001ServingDocumentsKeepCitationAndVersion(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieP4QueryRecord("r1", "ArrayList.add docs", "ArrayList.add appends values. values.add(1)."))
        let feed = buildServingDocuments(records)

        @Expect(feed.ok, true)
        @Expect(cangjieP4ServingDocVersion(feed, CangjieServingRecordKinds.DOC_SECTION), "v1")
        @Expect(cangjieP4ServingDocCitation(feed, CangjieServingRecordKinds.DOC_SECTION), "test:r1")
    }

    @TestCase
    public func f4Ut01ServingIndexExactLookupCoversSymbolDocToolAndNegativeRule(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4Record("sym-arraylist-add", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add", "symbolKey=ArrayList.add\nmodule=std.collection\nimportLine=import std.collection.*\nsignature=func add(value: T): Unit\navailability=stable", CangjieSourceSets.STD, "1.0.0", "vr-std-1"))
        records.add(cangjieF4Record("doc-arraylist-add", CangjieTypedRecordKinds.DOC_SECTION, "Collections", "sectionId=collections-arraylist\nArrayList.add appends values. Do not use append.", CangjieSourceSets.DOCS, "1.0.0", "vr-docs-1"))
        records.add(cangjieF4Record("tool-cjpm-test", CangjieTypedRecordKinds.TOOL_MANUAL, "cjpm test", "Tool manual for cjpm test. Run cjpm test for package tests.", CangjieSourceSets.TOOLS, "1.0.0", "vr-tools-1"))

        let index = buildCangjieServingIndex(records, activeKnowledgeVersion: "active-f4")
        let symbol = lookupExactSymbol(index, "ArrayList.add", module: "std.collection", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0", versionResolutionId: "vr-std-1", budget: 3)
        let doc = lookupDocSection(index, "doc-arraylist-add", sourceSet: CangjieSourceSets.DOCS, targetVersion: "1.0.0", versionResolutionId: "vr-docs-1", budget: 3)
        let tool = lookupToolManual(index, "cjpm", command: "test", targetVersion: "1.0.0", versionResolutionId: "vr-tools-1", budget: 3)
        let negative = lookupNegativeRules(index, "append", targetVersion: "1.0.0", versionResolutionId: "vr-docs-1", budget: 3)

        @Expect(symbol.hits.size > 0, true)
        @Expect(doc.hits.size > 0, true)
        @Expect(tool.hits.size > 0, true)
        @Expect(negative.hits.size > 0, true)
        @Expect(index.exactEntries[0].key.contains("active=active-f4"), true)
        @Expect(index.exactEntries[0].key.contains("sourceSet="), true)
        @Expect(index.exactEntries[0].key.contains("targetVersion="), true)
        @Expect(index.exactEntries[0].key.contains("versionResolutionId="), true)
    }

    @TestCase
    public func f4Bnd01SameSymbolDifferentVersionsDoNotBleedAcrossLookup(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieF4Record("sym-arraylist-add-v1", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add v1", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit", CangjieSourceSets.STD, "1.0.0", "vr-std-1"))
        records.add(cangjieF4Record("sym-arraylist-add-v2", CangjieTypedRecordKinds.SYMBOL_CARD, "ArrayList.add v2", "symbolKey=ArrayList.add\nmodule=std.collection\nsignature=func add(value: T): Unit", CangjieSourceSets.STD, "1.1.0", "vr-std-2"))
        let index = buildCangjieServingIndex(records, activeKnowledgeVersion: "active-f4")

        let v1 = lookupExactSymbol(index, "ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "1.0.0", versionResolutionId: "vr-std-1", budget: 5)
        let v2 = lookupExactSymbol(index, "ArrayList.add", sourceSet: CangjieSourceSets.STD, targetVersion: "1.1.0", versionResolutionId: "vr-std-2", budget: 5)

        @Expect(v1.hits.size, 1)
        @Expect(v2.hits.size, 1)
        @Expect(v1.hits[0].document.targetVersion, "1.0.0")
        @Expect(v2.hits[0].document.targetVersion, "1.1.0")
        @Expect(v1.hits[0].document.versionResolutionId, "vr-std-1")
        @Expect(v2.hits[0].document.versionResolutionId, "vr-std-2")
    }

    @TestCase
    public func f4Pos01HybridSearchOverBoundedSyntheticRecordsFindsTopHit(): Unit {
        let index = CangjieServingIndex()
        index.activeKnowledgeVersion = "active-f4"
        let recordCount: Int64 = 20000
        let needleIndex: Int64 = recordCount - 1
        for (i in 0..recordCount) {
            let title = if (i == needleIndex) { "needle19999 ArrayList.add" } else { "synthetic ${i}" }
            let chunk = if (i == needleIndex) { "needle19999 ArrayList.add appends values." } else { "plain synthetic record ${i}" }
            index.documents.add(cangjieF4ServingDoc("synthetic-${i}", title, chunk))
        }
        let start = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let request = CangjieServingSearchRequest()
        request.query = "needle19999 ArrayList.add"
        request.sourceSet = CangjieSourceSets.DOCS
        request.targetVersion = "1.0.0"
        request.versionResolutionId = "vr-docs-1"
        request.budget = 3
        let result = searchHybridServingIndex(index, request)
        let durationMs = DateTime.now().toUnixTimeStamp().toMilliseconds() - start

        @Expect(result.hits.size > 0, true)
        @Expect(result.hits[0].document.sourceId, "synthetic-${needleIndex}")
        @Expect(result.evidenceHash.startsWith("h"), true)
        @Expect(durationMs < 120000, true)
    }
}

private func cangjieP4QueryRecord(sourceId: String, title: String, chunk: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = title
    record.chunk = chunk
    record.citation = "test:${sourceId}"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.targetVersion = cangjieDefaultTargetVersion()
    record.metadata.versionResolutionId = "v1"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func cangjieF4Record(sourceId: String, kind: String, title: String, chunk: String, sourceSet: String, targetVersion: String, versionResolutionId: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = kind
    record.title = title
    record.chunk = chunk
    record.citation = "test:${sourceId}"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = if (sourceSet == CangjieSourceSets.STD || sourceSet == CangjieSourceSets.STDX) { SourceTypes.REPO } else { SourceTypes.DOC }
    record.metadata.sourceSet = sourceSet
    record.metadata.targetVersion = targetVersion
    record.metadata.versionResolutionId = versionResolutionId
    record.metadata.knowledgeVersion = "active-f4"
    record.metadata.path = if (kind == CangjieTypedRecordKinds.TOOL_MANUAL) { "tools/cjpm.md" } else { "docs/${sourceId}.md" }
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func cangjieF4ServingDoc(sourceId: String, title: String, text: String): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "serving-${sourceId}"
    doc.recordKind = CangjieServingRecordKinds.DOC_SECTION
    doc.title = title
    doc.text = text
    doc.sourceId = sourceId
    doc.sourceSet = CangjieSourceSets.DOCS
    doc.targetVersion = "1.0.0"
    doc.versionResolutionId = "vr-docs-1"
    doc.trustLevel = TrustLevels.OFFICIAL
    doc.reviewState = ReviewStates.TRUSTED
    doc.contentHash = stableSummaryHash("${sourceId}:${text}")
    doc.citation = "test:${sourceId}"
    doc
}

private func cangjieP4ServingDocVersion(feed: CangjieServingFeed, kind: String): String {
    for (doc in feed.documents) {
        if (doc.recordKind == kind) {
            return doc.versionResolutionId
        }
    }
    ""
}

private func cangjieP4ServingDocCitation(feed: CangjieServingFeed, kind: String): String {
    for (doc in feed.documents) {
        if (doc.recordKind == kind) {
            return doc.citation
        }
    }
    ""
}
