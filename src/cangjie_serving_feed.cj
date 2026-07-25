package cangjie_community_knowledge_base

import std.collection.ArrayList

public func buildServingDocuments(records: ArrayList<NormalizedRecord>): CangjieServingFeed {
    let feed = CangjieServingFeed()
    let acceptedRecords = ArrayList<NormalizedRecord>()
    for (record in records) {
        let studentDiagnostic = cangjieStudentRecordDiagnostic(record)
        if (!studentDiagnostic.ok) {
            feed.diagnostics.add("serving_record_rejected:${studentDiagnostic.code}:${studentDiagnostic.matchedField}")
            continue
        }
        acceptedRecords.add(record)
        cangjieServingFeedAddClean(feed, cangjieServingDocumentFromRecord(record))
        for (card in extractCangjieSymbols(record)) {
            cangjieServingFeedAddClean(feed,
                cangjieServingDocumentFromSymbol(card))
        }
        for (example in buildExampleRecords(record)) {
            cangjieServingFeedAddClean(feed,
                cangjieServingDocumentFromExample(example))
        }
    }
    let negativeRules = buildNegativeRuleRecords(acceptedRecords)
    for (rule in negativeRules) {
        cangjieServingFeedAddClean(feed,
            cangjieServingDocumentFromNegativeRule(rule))
    }
    if (feed.documents.size == 0) {
        feed.ok = false
        if (feed.diagnostics.size == 0) {
            feed.diagnostics.add("serving_feed_empty")
        }
    }
    feed
}

private func cangjieServingFeedAddClean(feed: CangjieServingFeed,
    document: CangjieServingDocument): Unit {
    let diagnostic = cangjieStudentServingDocumentDiagnostic(document)
    if (!diagnostic.ok) {
        feed.diagnostics.add(
            "serving_projection_rejected:${diagnostic.code}:${diagnostic.matchedField}")
        return
    }
    feed.documents.add(document)
}

public func runCangjieServingFeedSmoke(args: Array<String>): Int64 {
    let records = ArrayList<NormalizedRecord>()
    records.add(cangjieServingSmokeRecord("smoke-arraylist", "ArrayList add docs", "import std.collection.*\nlet values = ArrayList<Int64>()\nvalues.add(1)\nArrayList.add appends an element.", CangjieSourceSets.DOCS))
    records.add(cangjieServingSmokeRecord("smoke-main", "Cangjie main syntax", "main() { println(\"Hello\") }\nDo not use Python def main.", CangjieSourceSets.DOCS))
    let feed = buildServingDocuments(records)
    let ok = feed.ok && cangjieServingCount(feed, CangjieServingRecordKinds.SYMBOL_CARD) > 0 && cangjieServingCount(feed, CangjieServingRecordKinds.EXAMPLE) > 0 && cangjieServingCount(feed, CangjieServingRecordKinds.NEGATIVE_RULE) > 0
    println("serving-feed-smoke ok=${ok}")
    println("documents=${feed.documents.size} docSections=${cangjieServingCount(feed, CangjieServingRecordKinds.DOC_SECTION)} symbols=${cangjieServingCount(feed, CangjieServingRecordKinds.SYMBOL_CARD)} examples=${cangjieServingCount(feed, CangjieServingRecordKinds.EXAMPLE)} negativeRules=${cangjieServingCount(feed, CangjieServingRecordKinds.NEGATIVE_RULE)} diagnostics=${cangjieServingDiagnostics(feed)}")
    if (ok) { 0 } else { 1 }
}

private func cangjieServingRecordAllowed(record: NormalizedRecord): Bool {
    cangjieStudentRecordAllowed(record)
}

private func cangjieServingDocumentFromRecord(record: NormalizedRecord): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "serving-doc-${stableSummaryHash(record.sourceId)}"
    doc.recordKind = CangjieServingRecordKinds.DOC_SECTION
    doc.title = record.title
    doc.text = record.chunk
    doc.sourceSet = record.metadata.sourceSet
    doc.trustLevel = record.metadata.trustLevel
    doc.reviewState = record.metadata.reviewState
    doc.targetVersion = record.metadata.targetVersion
    doc.versionResolutionId = record.metadata.versionResolutionId
    doc.contentHash = stableSummaryHash("${record.sourceId}:${record.chunk}")
    doc.citation = record.citation
    doc.sourceId = record.sourceId
    doc.rankProfile = "official-doc"
    doc
}

private func cangjieServingDocumentFromSymbol(card: CangjieSymbolCardRecord): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "serving-symbol-${stableSummaryHash("${card.symbolKey}:${card.versionResolutionId}:${card.sourceRef}")}"
    doc.recordKind = CangjieServingRecordKinds.SYMBOL_CARD
    doc.title = card.symbolKey
    doc.text = "${card.signature}\n${card.importLine}"
    doc.symbolKey = card.symbolKey
    doc.module = card.module
    doc.sourceSet = card.sourceSet
    doc.trustLevel = card.trustLevel
    doc.reviewState = card.reviewState
    doc.targetVersion = card.targetVersion
    doc.versionResolutionId = card.versionResolutionId
    doc.contentHash = card.contentHash
    doc.citation = card.citation
    doc.sourceId = card.sourceId
    doc.rankProfile = "exact-symbol"
    doc.rejected = card.incomplete
    doc.diagnostic = card.diagnostic
    doc
}

private func cangjieServingDocumentFromExample(example: CangjieExampleRecord): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "serving-example-${stableSummaryHash(example.exampleId)}"
    doc.recordKind = CangjieServingRecordKinds.EXAMPLE
    doc.title = example.title
    doc.text = example.code
    doc.symbolKey = example.symbol
    doc.module = example.module
    doc.trustLevel = example.trustLevel
    doc.reviewState = example.reviewState
    doc.versionResolutionId = example.versionResolutionId
    doc.contentHash = stableSummaryHash("${example.exampleId}:${example.code}")
    doc.citation = example.citation
    doc.sourceId = example.sourceId
    doc.rankProfile = "official-example"
    doc
}

private func cangjieServingDocumentFromNegativeRule(rule: CangjieNegativeRuleRecord): CangjieServingDocument {
    let doc = CangjieServingDocument()
    doc.documentId = "serving-negative-${stableSummaryHash(rule.ruleId)}"
    doc.recordKind = CangjieServingRecordKinds.NEGATIVE_RULE
    doc.title = rule.title
    doc.text = "Bad: ${rule.badPattern}\nUse: ${rule.replacement}"
    doc.versionResolutionId = rule.versionResolutionId
    doc.contentHash = stableSummaryHash("${rule.ruleId}:${rule.replacement}")
    doc.citation = rule.citation
    doc.rankProfile = "negative-rule"
    doc
}

private func cangjieServingSmokeRecord(sourceId: String, title: String, chunk: String, sourceSet: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = title
    record.chunk = chunk
    record.citation = "smoke:${sourceId}"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceSet = sourceSet
    record.metadata.targetVersion = cangjieDefaultTargetVersion()
    record.metadata.versionResolutionId = "cangjie-1.0.0-${sourceSet}-release-1.0.0"
    record.metadata.docVersion = "release-1.0.0"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func cangjieServingCount(feed: CangjieServingFeed, kind: String): Int64 {
    var count: Int64 = 0
    for (doc in feed.documents) {
        if (doc.recordKind == kind) {
            count += 1
        }
    }
    count
}

private func cangjieServingDiagnostics(feed: CangjieServingFeed): String {
    if (feed.diagnostics.size == 0) {
        return "none"
    }
    let out = StringBuilder()
    for (diagnostic in feed.diagnostics) {
        if (out.toString() != "") {
            out.append(",")
        }
        out.append(diagnostic)
    }
    out.toString()
}
