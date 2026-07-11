package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import stdx.crypto.digest.SHA256

public class CkbCandidateDurableSchema {
    static let VERSION: String = "p5-candidate-durable-v2"
    static let VECTOR_BATCH_SIZE: Int64 = 128
    static let VECTOR_LOOKUP_BATCH_SIZE: Int64 = 256
    static let QDRANT_CACHE_MAX_RECORDS: Int64 = 1024
    static let VECTOR_MAX_BUFFER_BYTES: Int64 = 8388608
}

public class CkbCandidateAcquisitionContext {
    var acquisitionId: String = ""
    var schedulerRunId: String = ""
    var taskId: String = ""
    var candidateVersion: String = ""
    var planHash: String = ""
    var recordsEvidenceHash: String = ""

    init() {}

    func valid(): Bool {
        this.acquisitionId != "" && this.schedulerRunId != "" && this.taskId != "" && this.candidateVersion != "" &&
            this.planHash != "" && this.recordsEvidenceHash != ""
    }
}

public class CkbCandidateCollectionOwner {
    var valid: Bool = false
    var status: String = "not_found"
    var diagnostic: String = ""
    var collection: String = ""
    var acquisitionId: String = ""
    var schedulerRunId: String = ""
    var taskId: String = ""
    var candidateVersion: String = ""
    var planHash: String = ""
    var recordsEvidenceHash: String = ""
    var state: String = "planned"
    var relativePath: String = ""
    var evidenceHash: String = ""

    init() {}
}

public class CkbVectorSpoolDescriptor {
    var valid: Bool = false
    var status: String = "not_started"
    var diagnostic: String = ""
    var acquisitionId: String = ""
    var candidateVersion: String = ""
    var planHash: String = ""
    var recordsEvidenceHash: String = ""
    var collection: String = ""
    var total: Int64 = 0
    var completed: Int64 = 0
    var reused: Int64 = 0
    var embedded: Int64 = 0
    var failed: Int64 = 0
    var batchSize: Int64 = CkbCandidateDurableSchema.VECTOR_BATCH_SIZE
    var peakBufferedRecords: Int64 = 0
    var peakBufferedBytes: Int64 = 0
    var checkpointRelativePath: String = ""
    var manifestRelativePath: String = ""
    var batchRelativePaths: ArrayList<String> = ArrayList<String>()
    var batchEvidenceHashes: ArrayList<String> = ArrayList<String>()
    var batchRecordCounts: ArrayList<String> = ArrayList<String>()
    var evidenceHash: String = ""

    init() {}
}

public class CkbVectorSpoolBatchLoadResult {
    var valid: Bool = false
    var status: String = "not_found"
    var diagnostic: String = ""
    var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    var evidenceHash: String = ""

    init() {}
}

public class CkbCandidateMaterializationResult {
    var ok: Bool = false
    var status: String = "not_started"
    var immutableReused: Bool = false
    var checkpointDegraded: Bool = false
    var rawCount: Int64 = 0
    var normalizedCount: Int64 = 0
    var batchCount: Int64 = 0
    var reusedBatchCount: Int64 = 0
    var writtenBatchCount: Int64 = 0
    var peakBufferedRecords: Int64 = 0
    var rawEvidenceHash: String = ""
    var normalizedEvidenceHash: String = ""
    var manifestEvidenceHash: String = ""
    var diagnostic: String = ""

    init() {}
}

public class CkbCandidateMaterializationCheckpoint {
    var valid: Bool = false
    var status: String = "not_found"
    var phase: String = ""
    var completedBatches: Int64 = 0
    var totalBatches: Int64 = 0
    var manifestEvidenceHash: String = ""
    var evidenceHash: String = ""

    init() {}
}

public class CkbOverlayBuildStats {
    var activeRecords: Int64 = 0
    var deltaRecords: Int64 = 0
    var removedRecords: Int64 = 0
    var outputRecords: Int64 = 0
    var processedRecords: Int64 = 0
    var peakAuxiliaryRecords: Int64 = 0
    var evidenceHash: String = ""

    init() {}
}

public class CkbValidatedServingIndexSummary {
    var valid: Bool = false
    var validationStatus: String = ""
    var recordsEvidenceHash: String = ""
    var activeVersion: String = ""
    var documentCount: Int64 = 0
    var servingDiagnostic: String = ""
    var validationEvidenceHash: String = ""
    var evidenceHash: String = ""

    init() {}
}

public class VectorLookupResult {
    var ok: Bool = false
    var status: String = "not_started"
    var records: ArrayList<VectorRecord> = ArrayList<VectorRecord>()
    var requested: Int64 = 0
    var found: Int64 = 0
    var peakBufferedRecords: Int64 = 0
    var diagnostic: String = ""

    init() {}
}

public func ckbCandidateContextEvidenceHash(context: CkbCandidateAcquisitionContext): String {
    ckbReleaseEvidenceHash("${CkbCandidateDurableSchema.VERSION}|${context.acquisitionId}|${context.schedulerRunId}|${context.taskId}|${context.candidateVersion}|${context.planHash}|${context.recordsEvidenceHash}")
}

public func ckbValidatedServingIndexSummaryEvidenceHash(summary: CkbValidatedServingIndexSummary): String {
    ckbReleaseEvidenceHash("p5-serving-summary-v1|${summary.valid}|${summary.validationStatus}|${summary.recordsEvidenceHash}|${summary.activeVersion}|${summary.documentCount}|${summary.servingDiagnostic}|${summary.validationEvidenceHash}")
}

public func ckbValidatedServingIndexSummaryMatches(summary: CkbValidatedServingIndexSummary,
    expectedRecordsEvidenceHash: String, expectedActiveVersion: String): Bool {
    summary.valid && summary.validationStatus == "candidate_validation_passed" &&
        summary.recordsEvidenceHash == expectedRecordsEvidenceHash &&
        summary.activeVersion == expectedActiveVersion && summary.documentCount > 0 &&
        ckbValidationEvidenceIsSha256(summary.validationEvidenceHash) &&
        summary.evidenceHash == ckbValidatedServingIndexSummaryEvidenceHash(summary)
}

public func ckbValidationEvidenceIsSha256(value: String): Bool {
    if (!value.startsWith("hsha256:")) { return false }
    let runes = value.toRuneArray()
    if (runes.size != 72) { return false }
    for (index in 8..runes.size) {
        let ch = runes[index]
        let digit = ch >= r'0' && ch <= r'9'
        let lowerHex = ch >= r'a' && ch <= r'f'
        if (!digit && !lowerHex) { return false }
    }
    true
}

public func ckbCandidateStableCollection(context: CkbCandidateAcquisitionContext): String {
    let seed = "${context.acquisitionId}|${context.candidateVersion}|${context.planHash}|${context.recordsEvidenceHash}"
    "ckb_candidate_stage_${ckbReleaseEvidenceHash(seed)}"
}

public func ckbCandidateAlternateCollection(context: CkbCandidateAcquisitionContext): String {
    let seed = "${context.acquisitionId}|${context.candidateVersion}|${context.planHash}|${context.recordsEvidenceHash}|alternate"
    "ckb_candidate_stage_${ckbReleaseEvidenceHash(seed)}"
}

public func ckbCandidateOwnerCollectionMatches(owner: CkbCandidateCollectionOwner): Bool {
    if (!owner.valid) { return false }
    let context = CkbCandidateAcquisitionContext()
    context.acquisitionId = owner.acquisitionId
    context.schedulerRunId = owner.schedulerRunId
    context.taskId = owner.taskId
    context.candidateVersion = owner.candidateVersion
    context.planHash = owner.planHash
    context.recordsEvidenceHash = owner.recordsEvidenceHash
    context.valid() && (owner.collection == ckbCandidateStableCollection(context) ||
        owner.collection == ckbCandidateAlternateCollection(context))
}

public func ckbCandidateRecordsEvidenceHash(records: ArrayList<NormalizedRecord>, stagedCandidateVersion!: String = ""): String {
    let digest = SHA256()
    ckbCandidateDigestField(digest, "${records.size}")
    for (record in records) {
        ckbCandidateDigestField(digest, record.sourceId)
        ckbCandidateDigestField(digest, record.recordKind)
        ckbCandidateDigestField(digest, record.title)
        ckbCandidateDigestField(digest, record.chunk)
        ckbCandidateDigestField(digest, record.citation)
        ckbCandidateDigestField(digest, "${record.score}")
        ckbCandidateDigestField(digest, "${record.requiresReview}")
        let metadata = record.metadata
        ckbCandidateDigestField(digest, metadata.sourceId)
        ckbCandidateDigestField(digest, metadata.sourceType)
        ckbCandidateDigestField(digest, metadata.sourceUrl)
        ckbCandidateDigestField(digest, metadata.repo)
        ckbCandidateDigestField(digest, metadata.path)
        ckbCandidateDigestField(digest, metadata.symbol)
        ckbCandidateDigestField(digest, metadata.commit)
        ckbCandidateDigestField(digest, metadata.docVersion)
        ckbCandidateDigestField(digest, metadata.targetVersion)
        ckbCandidateDigestField(digest, metadata.sourceSet)
        ckbCandidateDigestField(digest, metadata.versionResolutionId)
        ckbCandidateDigestField(digest, metadata.crawlAt)
        ckbCandidateDigestField(digest, metadata.indexedAt)
        ckbCandidateDigestField(digest, metadata.knowledgeVersion)
        ckbCandidateDigestField(digest, if (stagedCandidateVersion != "") { stagedCandidateVersion } else { metadata.candidateVersion })
        ckbCandidateDigestField(digest, "${metadata.contentSize}")
        ckbCandidateDigestField(digest, metadata.trustLevel)
        ckbCandidateDigestField(digest, metadata.reviewState)
        ckbCandidateDigestField(digest, metadata.license)
        ckbCandidateDigestField(digest, metadata.repoVisibility)
        ckbCandidateDigestField(digest, "${metadata.derivedFrom.size}")
        for (source in metadata.derivedFrom) { ckbCandidateDigestField(digest, source) }
    }
    ckbCandidateDigestHex(digest)
}

private func ckbCandidateDigestField(digest: SHA256, value: String): Unit {
    digest.write("${value.size}:".toArray())
    digest.write(value.toArray())
}

private func ckbCandidateDigestHex(digest: SHA256): String {
    let out = StringBuilder()
    for (byte in digest.finish()) {
        out.append(ckbCandidateHexNibble(byte / UInt8(16)))
        out.append(ckbCandidateHexNibble(byte % UInt8(16)))
    }
    out.toString()
}

private func ckbCandidateHexNibble(value: UInt8): String {
    if (value < UInt8(10)) { return "${value}" }
    if (value == UInt8(10)) { return "a" }; if (value == UInt8(11)) { return "b" }
    if (value == UInt8(12)) { return "c" }; if (value == UInt8(13)) { return "d" }
    if (value == UInt8(14)) { return "e" }
    "f"
}

public func ckbCandidateCollectionOwnerEvidenceHash(owner: CkbCandidateCollectionOwner): String {
    ckbReleaseEvidenceHash("${CkbCandidateDurableSchema.VERSION}|${owner.collection}|${owner.acquisitionId}|${owner.schedulerRunId}|${owner.taskId}|${owner.candidateVersion}|${owner.planHash}|${owner.recordsEvidenceHash}|${owner.state}")
}

public func ckbCandidateOwnerMatches(owner: CkbCandidateCollectionOwner, expected: CkbCandidateCollectionOwner): Bool {
    owner.valid && expected.valid &&
        owner.collection == expected.collection &&
        owner.acquisitionId == expected.acquisitionId &&
        owner.schedulerRunId == expected.schedulerRunId &&
        owner.taskId == expected.taskId &&
        owner.candidateVersion == expected.candidateVersion &&
        owner.planHash == expected.planHash &&
        owner.recordsEvidenceHash == expected.recordsEvidenceHash
}
