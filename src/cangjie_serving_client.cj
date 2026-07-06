package cangjie_community_knowledge_base

import std.collection.ArrayList

public class CangjieServingBackendStatus {
    public var ready: Bool = false
    public var documentCount: Int64 = 0
    public var diagnostic: String = ""

    public init() {}
}

public class CangjieServingSearchRequest {
    public var query: String = ""
    public var symbol: String = ""
    public var sourceSet: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var versionResolutionId: String = ""
    public var budget: Int64 = 5

    public init() {}
}

public class CangjieServingSearchResult {
    public var ok: Bool = true
    public var hits: ArrayList<CangjieRankedServingHit> = ArrayList<CangjieRankedServingHit>()
    public var degraded: Bool = false
    public var diagnostic: String = ""
    public var evidenceHash: String = ""

    public init() {}
}

public interface ServingSearchBackend {
    func exactLookup(request: CangjieServingSearchRequest): CangjieServingSearchResult
    func hybridSearch(request: CangjieServingSearchRequest): CangjieServingSearchResult
    func feedStatus(): CangjieServingBackendStatus
}

public class LocalFixtureServingBackend <: ServingSearchBackend {
    private let feed: CangjieServingFeed

    public init(feed: CangjieServingFeed) {
        this.feed = feed
    }

    public func exactLookup(request: CangjieServingSearchRequest): CangjieServingSearchResult {
        let docs = ArrayList<CangjieServingDocument>()
        for (doc in this.feed.documents) {
            if (doc.recordKind == CangjieServingRecordKinds.SYMBOL_CARD && cangjieServingDocAllowed(doc, request) && cangjieLocalServingSymbolMatches(doc, request.symbol)) {
                docs.add(doc)
            }
        }
        cangjieServingResultFromDocs(request.query, docs, request.budget)
    }

    public func hybridSearch(request: CangjieServingSearchRequest): CangjieServingSearchResult {
        let docs = ArrayList<CangjieServingDocument>()
        for (doc in this.feed.documents) {
            if (cangjieServingDocAllowed(doc, request)) {
                docs.add(doc)
            }
        }
        cangjieServingResultFromDocs(request.query, docs, request.budget)
    }

    public func feedStatus(): CangjieServingBackendStatus {
        let status = CangjieServingBackendStatus()
        status.ready = this.feed.ok
        status.documentCount = this.feed.documents.size
        status.diagnostic = if (this.feed.ok) { "ok" } else { "feed_not_ready" }
        status
    }
}

private func cangjieLocalServingSymbolMatches(doc: CangjieServingDocument, symbol: String): Bool {
    let clean = symbol.trimAscii().toAsciiLower()
    if (clean == "") {
        return false
    }
    if (doc.symbolKey.toAsciiLower() == clean) {
        return true
    }
    if (doc.module.trimAscii() != "" && "${doc.module}.${doc.symbolKey}".toAsciiLower() == clean) {
        return true
    }
    for (line in doc.text.split("\n")) {
        let trimmed = line.trimAscii()
        if (!trimmed.startsWith("aliases=")) {
            continue
        }
        let parts = trimmed.split("aliases=")
        if (parts.size < 2) {
            continue
        }
        for (alias in parts[1].split(";")) {
            if (alias.trimAscii().toAsciiLower() == clean) {
                return true
            }
        }
    }
    false
}

private func cangjieServingDocAllowed(doc: CangjieServingDocument, request: CangjieServingSearchRequest): Bool {
    if (doc.rejected) {
        return false
    }
    if (request.sourceSet != "" && doc.sourceSet != "" && doc.sourceSet != request.sourceSet) {
        return false
    }
    if (request.targetVersion != "" && doc.targetVersion != "" && doc.targetVersion != request.targetVersion) {
        return false
    }
    if (request.versionResolutionId != "" && doc.versionResolutionId != "" && doc.versionResolutionId != request.versionResolutionId) {
        return false
    }
    true
}

private func cangjieServingResultFromDocs(query: String, docs: ArrayList<CangjieServingDocument>, budget: Int64): CangjieServingSearchResult {
    let result = CangjieServingSearchResult()
    result.hits = rankServingHits(query, docs, budget)
    if (result.hits.size == 0) {
        result.ok = false
        result.degraded = true
        result.diagnostic = "serving_no_hits"
    } else {
        result.evidenceHash = cangjieServingEvidenceHash(result.hits)
    }
    result
}

private func cangjieServingEvidenceHash(hits: ArrayList<CangjieRankedServingHit>): String {
    let out = StringBuilder()
    for (hit in hits) {
        out.append(hit.document.documentId)
        out.append("|")
    }
    stableSummaryHash(out.toString())
}
