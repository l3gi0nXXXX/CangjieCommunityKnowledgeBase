package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieServingQueryTest {
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
