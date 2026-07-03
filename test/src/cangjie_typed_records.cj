package cangjie_community_knowledge_base_test

import std.collection.ArrayList

public class CangjieTypedRecordKinds {
    public static let DOC_SECTION: String = "doc_section"
    public static let TOOL_MANUAL: String = "tool_manual"
    public static let EVAL_SUPPORT: String = "eval_support"
}

public class CangjieTypedRecord {
    public var recordKind: String = ""
    public var sourceId: String = ""
    public var title: String = ""
    public var content: String = ""
    public var citation: String = ""
    public var sourceSet: String = ""
    public var sourceFamily: String = ""
    public var path: String = ""
    public var heading: String = ""
    public var sectionId: String = ""
    public var symbol: String = ""
    public var toolName: String = ""
    public var command: String = ""
    public var caseId: String = ""
    public var contentHash: String = ""
    public var versionResolutionId: String = ""
    public var targetVersion: String = cangjieDefaultTargetVersion()
    public var sourceRef: String = ""
    public var refKind: String = ""
    public var resolvedCommit: String = ""
    public var trustLevel: String = TrustLevels.OFFICIAL
    public var reviewState: String = ReviewStates.TRUSTED
    public var diagnostic: String = ""

    public init() {}
}

public class CangjieTypedRecordResult {
    public var ok: Bool = true
    public var diagnostics: ArrayList<String> = ArrayList<String>()
    public var records: ArrayList<CangjieTypedRecord> = ArrayList<CangjieTypedRecord>()

    public init() {}

    public func addDiagnostic(diagnostic: String): Unit {
        if (diagnostic.trimAscii() != "") {
            this.ok = false
            this.diagnostics.add(diagnostic)
        }
    }
}

public func cangjieTypedRecordToNormalized(record: CangjieTypedRecord, base: KnowledgeMetadata): NormalizedRecord {
    let normalized = NormalizedRecord()
    normalized.sourceId = record.sourceId
    normalized.recordKind = record.recordKind
    normalized.title = record.title
    normalized.chunk = record.content
    normalized.citation = record.citation
    normalized.metadata = cangjieTypedMetadata(record, base)
    normalized.requiresReview = record.reviewState == ReviewStates.CANDIDATE
    normalized
}

public func cangjieTypedRecordContentHash(sourceId: String, content: String): String {
    stableSummaryHash("${sourceId}\n${content}")
}

public func cangjieTypedMetadata(record: CangjieTypedRecord, base: KnowledgeMetadata): KnowledgeMetadata {
    let metadata = cangjieCopyKnowledgeMetadata(base)
    metadata.sourceId = record.sourceId
    metadata.sourceType = if (record.recordKind == CangjieTypedRecordKinds.EVAL_SUPPORT) { SourceTypes.DERIVED } else { SourceTypes.DOC }
    metadata.path = record.path
    metadata.symbol = record.symbol
    metadata.commit = if (record.resolvedCommit != "") { record.resolvedCommit } else { base.commit }
    metadata.targetVersion = if (record.targetVersion != "") { record.targetVersion } else { base.targetVersion }
    metadata.sourceSet = if (record.sourceSet != "") { record.sourceSet } else { base.sourceSet }
    metadata.versionResolutionId = if (record.versionResolutionId != "") { record.versionResolutionId } else { base.versionResolutionId }
    metadata.contentSize = record.content.size
    metadata.trustLevel = record.trustLevel
    metadata.reviewState = record.reviewState
    metadata
}

public func cangjieCopyKnowledgeMetadata(base: KnowledgeMetadata): KnowledgeMetadata {
    let metadata = KnowledgeMetadata()
    metadata.sourceId = base.sourceId
    metadata.sourceType = base.sourceType
    metadata.sourceUrl = base.sourceUrl
    metadata.repo = base.repo
    metadata.path = base.path
    metadata.symbol = base.symbol
    metadata.commit = base.commit
    metadata.docVersion = base.docVersion
    metadata.targetVersion = base.targetVersion
    metadata.sourceSet = base.sourceSet
    metadata.versionResolutionId = base.versionResolutionId
    metadata.crawlAt = base.crawlAt
    metadata.indexedAt = base.indexedAt
    metadata.knowledgeVersion = base.knowledgeVersion
    metadata.candidateVersion = base.candidateVersion
    metadata.contentSize = base.contentSize
    metadata.trustLevel = base.trustLevel
    metadata.reviewState = base.reviewState
    metadata.license = base.license
    metadata.repoVisibility = base.repoVisibility
    metadata.derivedFrom = base.derivedFrom
    metadata
}

public func cangjieMetadataFromVersionResolution(resolution: CangjieVersionResolution, fallbackSourceSet: String): KnowledgeMetadata {
    let metadata = KnowledgeMetadata()
    metadata.targetVersion = resolution.targetVersion
    metadata.versionResolutionId = resolution.versionResolutionId
    metadata.sourceSet = fallbackSourceSet
    if (resolution.sources.size > 0) {
        let source = resolution.sources[0]
        metadata.repo = source.sourceRepo
        metadata.commit = source.resolvedCommit
        metadata.sourceSet = source.sourceSet
        metadata.docVersion = source.targetVersion
    }
    metadata
}
