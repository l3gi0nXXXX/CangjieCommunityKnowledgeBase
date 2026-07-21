package cangjie_community_knowledge_base_test

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CangjieServingFeedTest {
    @TestCase
    public func p3Pos002BuildsServingDocumentsWithFilters(): Unit {
        let records = ArrayList<NormalizedRecord>()
        records.add(cangjieP3ServingRecord("r1", "ArrayList.add docs", "ArrayList.add appends values. Use values.add(1)."))

        let feed = buildServingDocuments(records)

        @Expect(feed.ok, true)
        @Expect(cangjieP3ServingHasKind(feed, CangjieServingRecordKinds.DOC_SECTION), true)
        @Expect(cangjieP3ServingHasKind(feed, CangjieServingRecordKinds.SYMBOL_CARD), true)
        @Expect(cangjieP3ServingHasKind(feed, CangjieServingRecordKinds.EXAMPLE), true)
        @Expect(cangjieP3ServingSymbolVersion(feed, "ArrayList.add"), "v1")
    }

    @TestCase
    public func p3Bnd002CandidateWebRecordsAreRejectedFromServingFeed(): Unit {
        let records = ArrayList<NormalizedRecord>()
        let record = cangjieP3ServingRecord("r1", "Candidate web", "ArrayList.add")
        record.metadata.trustLevel = TrustLevels.WEB_CANDIDATE
        record.metadata.reviewState = ReviewStates.CANDIDATE
        records.add(record)

        let feed = buildServingDocuments(records)

        @Expect(feed.ok, false)
        @Expect(feed.diagnostics.contains("serving_record_rejected:student_record_not_approved:approval"), true)
        @Expect(feed.documents.size, 0)
    }
}

private func cangjieP3ServingRecord(sourceId: String, title: String, chunk: String): NormalizedRecord {
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
    record.metadata.docVersion = "release-1.0.0"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func cangjieP3ServingHasKind(feed: CangjieServingFeed, kind: String): Bool {
    for (doc in feed.documents) {
        if (doc.recordKind == kind) {
            return true
        }
    }
    false
}

private func cangjieP3ServingSymbolVersion(feed: CangjieServingFeed, symbol: String): String {
    for (doc in feed.documents) {
        if (doc.symbolKey == symbol) {
            return doc.versionResolutionId
        }
    }
    ""
}
