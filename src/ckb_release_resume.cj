package cangjie_community_knowledge_base

import std.collection.ArrayList
import stdx.encoding.json.*

class CkbReleaseResumeSchema {
    static let VERSION: String = "p5-release-resume-v2"
    static let TASK_NAME: String = "cangjie_release_full_sync"
}

class CkbReleaseArtifactKinds {
    static let REF: String = "ref"
    static let TREE_PAGE: String = "tree_page"
    static let CONTENT: String = "content"
    static let SOURCE_COMPLETE: String = "source_complete"
}

class CkbScheduledFetchRunKey {
    var taskName: String = CkbReleaseResumeSchema.TASK_NAME
    var profile: String = ""
    var sourceIdentity: String = ""
    var originalRef: String = ""
    var resolvedCommit: String = ""
    var selectorVersion: String = ""
    var planEvidenceHash: String = ""
    var planningIdentityHash: String = ""
    var runIdentityHash: String = ""
    var acquisitionId: String = ""

    init() {}
}

class CkbScheduledContentArtifact {
    var valid: Bool = false
    var status: String = "not_found"
    var diagnostic: String = ""
    var kind: String = ""
    var relativePath: String = ""
    var planningIdentityHash: String = ""
    var runIdentityHash: String = ""
    var sourceIdentity: String = ""
    var resolvedCommit: String = ""
    var selectorVersion: String = ""
    var planEvidenceHash: String = ""
    var ordinal: Int64 = 0
    var logicalPath: String = ""
    var method: String = ""
    var contentType: String = ""
    var payload: String = ""
    var payloadHash: String = ""
    var payloadBytes: Int64 = 0
    var evidenceHash: String = ""
    var fetchEvidencePayload: String = ""
    var fetchEvidenceHash: String = ""
    var priorFetchEvidencePayload: String = ""
    var priorFetchEvidenceHash: String = ""

    init() {}
}

class CkbReleaseResumeCheckpoint {
    var valid: Bool = false
    var status: String = "not_found"
    var diagnostic: String = ""
    var phase: String = ""
    var sourceOrdinal: Int64 = 0
    var nextPage: Int64 = 1
    var currentPathHash: String = ""
    var refArtifactPath: String = ""
    var sourceCompleteArtifactPath: String = ""
    var plannedPaths: ArrayList<String> = ArrayList<String>()
    var completedPaths: ArrayList<String> = ArrayList<String>()
    var pageArtifactPaths: ArrayList<String> = ArrayList<String>()
    var contentArtifactPaths: ArrayList<String> = ArrayList<String>()
    var artifactEvidenceHashes: ArrayList<String> = ArrayList<String>()
    var evidenceHash: String = ""

    init() {}
}

class CkbReleaseAcquisitionState {
    var valid: Bool = false
    var status: String = "not_found"
    var diagnostic: String = ""
    var state: String = "missing"
    var planningIdentityHash: String = ""
    var runIdentityHash: String = ""
    var candidateVersion: String = ""
    var activeVersion: String = ""
    var evidenceHash: String = ""

    init() {}
}

func ckbReleaseScheduledFetchRunKey(profile: CkbScheduleTaskProfile, source: CkbReleaseSourcePlan, planEvidenceHash: String, resolvedCommit!: String = ""): CkbScheduledFetchRunKey {
    let key = CkbScheduledFetchRunKey()
    key.profile = profile.profile
    key.sourceIdentity = source.canonicalIdentity
    key.originalRef = source.originalRef
    key.resolvedCommit = resolvedCommit.trimAscii()
    key.selectorVersion = source.selectorVersion
    key.planEvidenceHash = planEvidenceHash
    let planning = "schema=${CkbReleaseResumeSchema.VERSION}|task=${key.taskName}|profile=${key.profile}|source=${key.sourceIdentity}|ref=${key.originalRef}|selector=${key.selectorVersion}|plan=${key.planEvidenceHash}"
    key.planningIdentityHash = ckbReleaseEvidenceHash(planning)
    key.acquisitionId = "p5-acq-${key.planningIdentityHash}"
    key.runIdentityHash = ckbReleaseEvidenceHash("${planning}|commit=${key.resolvedCommit}")
    key
}

func ckbReleaseRunKeyWithCommit(key: CkbScheduledFetchRunKey, resolvedCommit: String): CkbScheduledFetchRunKey {
    let out = CkbScheduledFetchRunKey()
    out.taskName = key.taskName
    out.profile = key.profile
    out.sourceIdentity = key.sourceIdentity
    out.originalRef = key.originalRef
    out.resolvedCommit = resolvedCommit.trimAscii()
    out.selectorVersion = key.selectorVersion
    out.planEvidenceHash = key.planEvidenceHash
    out.planningIdentityHash = key.planningIdentityHash
    out.acquisitionId = key.acquisitionId
    let planning = "schema=${CkbReleaseResumeSchema.VERSION}|task=${out.taskName}|profile=${out.profile}|source=${out.sourceIdentity}|ref=${out.originalRef}|selector=${out.selectorVersion}|plan=${out.planEvidenceHash}"
    out.runIdentityHash = ckbReleaseEvidenceHash("${planning}|commit=${out.resolvedCommit}")
    out
}

func ckbReleaseAcquisitionRoot(key: CkbScheduledFetchRunKey): String {
    "metadata/release-acquisitions/${key.acquisitionId}"
}

func ckbReleaseArtifactRelativePath(key: CkbScheduledFetchRunKey, kind: String, ordinal!: Int64 = 0, logicalPath!: String = ""): String {
    let root = ckbReleaseAcquisitionRoot(key)
    if (kind == CkbReleaseArtifactKinds.REF) { return "${root}/ref.json" }
    if (kind == CkbReleaseArtifactKinds.TREE_PAGE) { return "${root}/pages/page-${ordinal}.json" }
    if (kind == CkbReleaseArtifactKinds.CONTENT) { return "${root}/contents/${ckbReleaseEvidenceHash(logicalPath)}.json" }
    "${root}/source-complete.json"
}

func ckbWriteReleaseContentArtifact(store: FileKnowledgeStore, key: CkbScheduledFetchRunKey, kind: String, payload: String, ordinal!: Int64 = 0, logicalPath!: String = "", method!: String = "", contentType!: String = "", fetch!: SourceFetchResult = SourceFetchResult(), priorFetchEvidencePayload!: String = ""): CkbScheduledContentArtifact {
    let artifact = CkbScheduledContentArtifact()
    artifact.kind = kind
    artifact.relativePath = ckbReleaseArtifactRelativePath(key, kind, ordinal: ordinal, logicalPath: logicalPath)
    artifact.planningIdentityHash = key.planningIdentityHash
    artifact.runIdentityHash = key.runIdentityHash
    artifact.sourceIdentity = key.sourceIdentity
    artifact.resolvedCommit = key.resolvedCommit
    artifact.selectorVersion = key.selectorVersion
    artifact.planEvidenceHash = key.planEvidenceHash
    artifact.ordinal = ordinal
    artifact.logicalPath = logicalPath
    artifact.method = method
    artifact.contentType = contentType
    artifact.payload = payload
    artifact.payloadHash = ckbReleaseEvidenceHash(payload)
    artifact.payloadBytes = payload.size
    artifact.fetchEvidencePayload = ckbReleaseFetchEvidencePayload(fetch)
    artifact.fetchEvidenceHash = ckbReleaseEvidenceHash(artifact.fetchEvidencePayload)
    artifact.priorFetchEvidencePayload = priorFetchEvidencePayload
    artifact.priorFetchEvidenceHash = if (priorFetchEvidencePayload == "") { "" } else { ckbReleaseEvidenceHash(priorFetchEvidencePayload) }
    artifact.evidenceHash = ckbReleaseArtifactEvidenceHash(artifact)
    store.writeLinesAtomically(artifact.relativePath, ckbReleaseArtifactJson(artifact))
    artifact.valid = true
    artifact.status = "ok"
    artifact
}

func ckbLoadReleaseContentArtifact(store: FileKnowledgeStore, expectedKey: CkbScheduledFetchRunKey, kind: String, ordinal!: Int64 = 0, logicalPath!: String = ""): CkbScheduledContentArtifact {
    let artifact = CkbScheduledContentArtifact()
    artifact.kind = kind
    artifact.relativePath = ckbReleaseArtifactRelativePath(expectedKey, kind, ordinal: ordinal, logicalPath: logicalPath)
    let text = try {
        store.readText(artifact.relativePath)
    } catch (_: Exception) {
        artifact.status = "invalid_response_encoding"
        artifact.diagnostic = "release_artifact_invalid_response_encoding:${kind}"
        return artifact
    }
    if (text == "") { return artifact }
    let object = try {
        JsonValue.fromStr(text).asObject()
    } catch (_: Exception) {
        artifact.status = "malformed_json"
        artifact.diagnostic = "release_artifact_malformed_json:${kind}"
        return artifact
    }
    if (ckbResumeJsonString(object, "schemaVersion") != CkbReleaseResumeSchema.VERSION || ckbResumeJsonString(object, "kind") != kind) {
        artifact.status = "artifact_schema_mismatch"
        artifact.diagnostic = "release_artifact_schema_mismatch:${kind}"
        return artifact
    }
    artifact.planningIdentityHash = ckbResumeJsonString(object, "planningIdentityHash")
    artifact.runIdentityHash = ckbResumeJsonString(object, "runIdentityHash")
    artifact.sourceIdentity = ckbResumeJsonString(object, "sourceIdentity")
    artifact.resolvedCommit = ckbResumeJsonString(object, "resolvedCommit")
    artifact.selectorVersion = ckbResumeJsonString(object, "selectorVersion")
    artifact.planEvidenceHash = ckbResumeJsonString(object, "planEvidenceHash")
    artifact.ordinal = ckbResumeJsonInt(object, "ordinal", -1)
    artifact.logicalPath = ckbResumeJsonString(object, "logicalPath")
    artifact.method = ckbResumeJsonString(object, "method")
    artifact.contentType = ckbResumeJsonString(object, "contentType")
    artifact.payload = ckbResumeJsonString(object, "payload")
    artifact.payloadHash = ckbResumeJsonString(object, "payloadHash")
    artifact.payloadBytes = ckbResumeJsonInt(object, "payloadBytes", -1)
    artifact.fetchEvidencePayload = ckbResumeJsonString(object, "fetchEvidencePayload")
    artifact.fetchEvidenceHash = ckbResumeJsonString(object, "fetchEvidenceHash")
    artifact.priorFetchEvidencePayload = ckbResumeJsonString(object, "priorFetchEvidencePayload")
    artifact.priorFetchEvidenceHash = ckbResumeJsonString(object, "priorFetchEvidenceHash")
    artifact.evidenceHash = ckbResumeJsonString(object, "evidenceHash")
    let hydratedEvidence = SourceFetchResult()
    if (!ckbHydrateReleaseFetchEvidence(artifact.fetchEvidencePayload, hydratedEvidence)) {
        artifact.status = "malformed_json"
        artifact.diagnostic = "release_artifact_fetch_evidence_malformed:${kind}"
        return artifact
    }
    if ((artifact.priorFetchEvidencePayload == "") != (artifact.priorFetchEvidenceHash == "") ||
        (artifact.priorFetchEvidencePayload != "" && artifact.priorFetchEvidenceHash != ckbReleaseEvidenceHash(artifact.priorFetchEvidencePayload))) {
        artifact.status = "artifact_hash_mismatch"
        artifact.diagnostic = "release_artifact_prior_fetch_hash_mismatch:${kind}"
        return artifact
    }
    if (artifact.priorFetchEvidencePayload != "") {
        let prior = SourceFetchResult()
        if (!ckbHydrateReleaseFetchEvidence(artifact.priorFetchEvidencePayload, prior)) {
            artifact.status = "malformed_json"
            artifact.diagnostic = "release_artifact_prior_fetch_malformed:${kind}"
            return artifact
        }
    }
    if (kind == CkbReleaseArtifactKinds.CONTENT && ((artifact.method == "contents") != (artifact.priorFetchEvidencePayload != ""))) {
        artifact.status = "artifact_identity_mismatch"
        artifact.diagnostic = "release_artifact_fallback_sequence_mismatch"
        return artifact
    }
    let actualKey = ckbReleaseRunKeyWithCommit(expectedKey, artifact.resolvedCommit)
    if (artifact.planningIdentityHash != expectedKey.planningIdentityHash || artifact.sourceIdentity != expectedKey.sourceIdentity || artifact.selectorVersion != expectedKey.selectorVersion || artifact.planEvidenceHash != expectedKey.planEvidenceHash || artifact.runIdentityHash != actualKey.runIdentityHash || (expectedKey.resolvedCommit != "" && artifact.resolvedCommit != expectedKey.resolvedCommit)) {
        artifact.status = "artifact_identity_mismatch"
        artifact.diagnostic = "release_artifact_identity_mismatch:${kind}"
        return artifact
    }
    if (artifact.ordinal != ordinal || artifact.logicalPath != logicalPath || artifact.payloadBytes != artifact.payload.size || artifact.payloadHash != ckbReleaseEvidenceHash(artifact.payload) || artifact.fetchEvidencePayload == "" || artifact.fetchEvidenceHash != ckbReleaseEvidenceHash(artifact.fetchEvidencePayload) || artifact.evidenceHash != ckbReleaseArtifactEvidenceHash(artifact)) {
        artifact.status = "artifact_hash_mismatch"
        artifact.diagnostic = "release_artifact_hash_mismatch:${kind}"
        return artifact
    }
    artifact.valid = true
    artifact.status = "ok"
    artifact
}

func ckbSaveReleaseResumeCheckpoint(store: FileKnowledgeStore, key: CkbScheduledFetchRunKey, checkpoint: CkbReleaseResumeCheckpoint): Unit {
    checkpoint.evidenceHash = ckbReleaseCheckpointEvidenceHash(key, checkpoint)
    let text = StringBuilder()
    text.append("{\"schemaVersion\":\"${CkbReleaseResumeSchema.VERSION}\"")
    text.append(",\"planningIdentityHash\":\"${key.planningIdentityHash}\"")
    text.append(",\"runIdentityHash\":\"${key.runIdentityHash}\"")
    text.append(",\"selectorVersion\":\"${ckbScheduledFetchJsonEscape(key.selectorVersion)}\"")
    text.append(",\"planEvidenceHash\":\"${ckbScheduledFetchJsonEscape(key.planEvidenceHash)}\"")
    text.append(",\"resolvedCommit\":\"${ckbScheduledFetchJsonEscape(key.resolvedCommit)}\"")
    text.append(",\"phase\":\"${ckbScheduledFetchJsonEscape(checkpoint.phase)}\"")
    text.append(",\"sourceOrdinal\":${checkpoint.sourceOrdinal}")
    text.append(",\"nextPage\":${checkpoint.nextPage}")
    text.append(",\"currentPathHash\":\"${checkpoint.currentPathHash}\"")
    text.append(",\"refArtifactPath\":\"${ckbScheduledFetchJsonEscape(checkpoint.refArtifactPath)}\"")
    text.append(",\"sourceCompleteArtifactPath\":\"${ckbScheduledFetchJsonEscape(checkpoint.sourceCompleteArtifactPath)}\"")
    text.append(",\"plannedPaths\":${ckbScheduledFetchPathsJson(checkpoint.plannedPaths)}")
    text.append(",\"completedPaths\":${ckbScheduledFetchPathsJson(checkpoint.completedPaths)}")
    text.append(",\"pageArtifactPaths\":${ckbScheduledFetchPathsJson(checkpoint.pageArtifactPaths)}")
    text.append(",\"contentArtifactPaths\":${ckbScheduledFetchPathsJson(checkpoint.contentArtifactPaths)}")
    text.append(",\"artifactEvidenceHashes\":${ckbScheduledFetchPathsJson(checkpoint.artifactEvidenceHashes)}")
    text.append(",\"evidenceHash\":\"${checkpoint.evidenceHash}\"}")
    store.writeLinesAtomically("${ckbReleaseAcquisitionRoot(key)}/checkpoint.json", text.toString())
}

func ckbLoadReleaseResumeCheckpoint(store: FileKnowledgeStore, key: CkbScheduledFetchRunKey): CkbReleaseResumeCheckpoint {
    let checkpoint = CkbReleaseResumeCheckpoint()
    let text = try { store.readText("${ckbReleaseAcquisitionRoot(key)}/checkpoint.json") } catch (_: Exception) {
        checkpoint.status = "invalid_response_encoding"
        checkpoint.diagnostic = "release_checkpoint_invalid_response_encoding"
        return checkpoint
    }
    if (text == "") { return checkpoint }
    let object = try { JsonValue.fromStr(text).asObject() } catch (_: Exception) {
        checkpoint.status = "malformed_json"
        checkpoint.diagnostic = "release_checkpoint_malformed_json"
        return checkpoint
    }
    if (ckbResumeJsonString(object, "schemaVersion") != CkbReleaseResumeSchema.VERSION || ckbResumeJsonString(object, "planningIdentityHash") != key.planningIdentityHash || ckbResumeJsonString(object, "runIdentityHash") != key.runIdentityHash || ckbResumeJsonString(object, "selectorVersion") != key.selectorVersion || ckbResumeJsonString(object, "planEvidenceHash") != key.planEvidenceHash || ckbResumeJsonString(object, "resolvedCommit") != key.resolvedCommit) {
        checkpoint.status = "checkpoint_identity_mismatch"
        checkpoint.diagnostic = "release_checkpoint_identity_mismatch"
        return checkpoint
    }
    checkpoint.phase = ckbResumeJsonString(object, "phase")
    checkpoint.sourceOrdinal = ckbResumeJsonInt(object, "sourceOrdinal", 0)
    checkpoint.nextPage = ckbResumeJsonInt(object, "nextPage", 1)
    checkpoint.currentPathHash = ckbResumeJsonString(object, "currentPathHash")
    checkpoint.refArtifactPath = ckbResumeJsonString(object, "refArtifactPath")
    checkpoint.sourceCompleteArtifactPath = ckbResumeJsonString(object, "sourceCompleteArtifactPath")
    if (!ckbResumeJsonStringArray(object, "plannedPaths", checkpoint.plannedPaths) || !ckbResumeJsonStringArray(object, "completedPaths", checkpoint.completedPaths) || !ckbResumeJsonStringArray(object, "pageArtifactPaths", checkpoint.pageArtifactPaths) || !ckbResumeJsonStringArray(object, "contentArtifactPaths", checkpoint.contentArtifactPaths) || !ckbResumeJsonStringArray(object, "artifactEvidenceHashes", checkpoint.artifactEvidenceHashes)) {
        checkpoint.status = "malformed_json"
        checkpoint.diagnostic = "release_checkpoint_array_malformed"
        return checkpoint
    }
    checkpoint.evidenceHash = ckbResumeJsonString(object, "evidenceHash")
    if (checkpoint.evidenceHash != ckbReleaseCheckpointEvidenceHash(key, checkpoint)) {
        checkpoint.status = "checkpoint_hash_mismatch"
        checkpoint.diagnostic = "release_checkpoint_hash_mismatch"
        return checkpoint
    }
    checkpoint.valid = true
    checkpoint.status = "ok"
    checkpoint
}

func ckbReleaseAcquisitionCanResume(store: FileKnowledgeStore, key: CkbScheduledFetchRunKey): Bool {
    let state = ckbLoadReleaseAcquisitionState(store, key)
    state.status == "not_found" || (state.valid && state.state == "active")
}

func ckbMarkReleaseAcquisitionState(store: FileKnowledgeStore, key: CkbScheduledFetchRunKey, state: String, candidateVersion!: String = "", activeVersion!: String = ""): Unit {
    let evidence = ckbReleaseEvidenceHash("${key.planningIdentityHash}|${key.runIdentityHash}|${state}|${candidateVersion}|${activeVersion}")
    let text = "{\"schemaVersion\":\"${CkbReleaseResumeSchema.VERSION}\",\"planningIdentityHash\":\"${key.planningIdentityHash}\",\"runIdentityHash\":\"${key.runIdentityHash}\",\"state\":\"${ckbScheduledFetchJsonEscape(state)}\",\"candidateVersion\":\"${ckbScheduledFetchJsonEscape(candidateVersion)}\",\"activeVersion\":\"${ckbScheduledFetchJsonEscape(activeVersion)}\",\"evidenceHash\":\"${evidence}\"}"
    store.writeLinesAtomically("${ckbReleaseAcquisitionRoot(key)}/state.json", text)
}

func ckbLoadReleaseAcquisitionState(store: FileKnowledgeStore, key: CkbScheduledFetchRunKey): CkbReleaseAcquisitionState {
    let state = CkbReleaseAcquisitionState()
    let relative = "${ckbReleaseAcquisitionRoot(key)}/state.json"
    let text = try { store.readText(relative) } catch (_: Exception) {
        state.status = "invalid_response_encoding"
        state.diagnostic = "release_acquisition_state_invalid_response_encoding"
        return state
    }
    if (text == "") {
        if (store.has(relative)) {
            state.status = "state_empty"
            state.diagnostic = "release_acquisition_state_empty"
        }
        return state
    }
    let object = try { JsonValue.fromStr(text).asObject() } catch (_: Exception) {
        state.status = "malformed_json"
        state.diagnostic = "release_acquisition_state_malformed_json"
        return state
    }
    if (ckbResumeJsonString(object, "schemaVersion") != CkbReleaseResumeSchema.VERSION) {
        state.status = "state_schema_mismatch"
        state.diagnostic = "release_acquisition_state_schema_mismatch"
        return state
    }
    state.planningIdentityHash = ckbResumeJsonString(object, "planningIdentityHash")
    state.runIdentityHash = ckbResumeJsonString(object, "runIdentityHash")
    state.state = ckbResumeJsonString(object, "state")
    state.candidateVersion = ckbResumeJsonString(object, "candidateVersion")
    state.activeVersion = ckbResumeJsonString(object, "activeVersion")
    state.evidenceHash = ckbResumeJsonString(object, "evidenceHash")
    let expected = ckbReleaseEvidenceHash("${state.planningIdentityHash}|${state.runIdentityHash}|${state.state}|${state.candidateVersion}|${state.activeVersion}")
    let identityMatches = state.planningIdentityHash == key.planningIdentityHash &&
        (key.resolvedCommit == "" || state.runIdentityHash == key.runIdentityHash)
    let knownState = state.state == "active" || state.state == "consumed"
    state.valid = identityMatches && knownState && state.runIdentityHash != "" && state.evidenceHash == expected
    if (state.valid) {
        state.status = "ok"
    } else {
        state.status = if (!identityMatches) { "state_identity_mismatch" } else if (!knownState) { "state_value_invalid" } else { "state_hash_mismatch" }
        state.diagnostic = "release_acquisition_${state.status}"
    }
    state
}

private func ckbReleaseArtifactEvidenceHash(artifact: CkbScheduledContentArtifact): String {
    ckbReleaseEvidenceHash("${CkbReleaseResumeSchema.VERSION}|${artifact.kind}|${artifact.planningIdentityHash}|${artifact.runIdentityHash}|${artifact.sourceIdentity}|${artifact.resolvedCommit}|${artifact.selectorVersion}|${artifact.planEvidenceHash}|${artifact.ordinal}|${artifact.logicalPath}|${artifact.method}|${artifact.contentType}|${artifact.payloadHash}|${artifact.payloadBytes}|${artifact.fetchEvidenceHash}|${artifact.priorFetchEvidenceHash}")
}

private func ckbReleaseArtifactJson(artifact: CkbScheduledContentArtifact): String {
    "{\"schemaVersion\":\"${CkbReleaseResumeSchema.VERSION}\",\"kind\":\"${artifact.kind}\",\"planningIdentityHash\":\"${artifact.planningIdentityHash}\",\"runIdentityHash\":\"${artifact.runIdentityHash}\",\"sourceIdentity\":\"${ckbScheduledFetchJsonEscape(artifact.sourceIdentity)}\",\"resolvedCommit\":\"${ckbScheduledFetchJsonEscape(artifact.resolvedCommit)}\",\"selectorVersion\":\"${ckbScheduledFetchJsonEscape(artifact.selectorVersion)}\",\"planEvidenceHash\":\"${ckbScheduledFetchJsonEscape(artifact.planEvidenceHash)}\",\"ordinal\":${artifact.ordinal},\"logicalPath\":\"${ckbScheduledFetchJsonEscape(artifact.logicalPath)}\",\"method\":\"${ckbScheduledFetchJsonEscape(artifact.method)}\",\"contentType\":\"${ckbScheduledFetchJsonEscape(artifact.contentType)}\",\"payload\":\"${ckbScheduledFetchJsonEscape(artifact.payload)}\",\"payloadHash\":\"${artifact.payloadHash}\",\"payloadBytes\":${artifact.payloadBytes},\"fetchEvidencePayload\":\"${ckbScheduledFetchJsonEscape(artifact.fetchEvidencePayload)}\",\"fetchEvidenceHash\":\"${artifact.fetchEvidenceHash}\",\"priorFetchEvidencePayload\":\"${ckbScheduledFetchJsonEscape(artifact.priorFetchEvidencePayload)}\",\"priorFetchEvidenceHash\":\"${artifact.priorFetchEvidenceHash}\",\"evidenceHash\":\"${artifact.evidenceHash}\"}"
}

func ckbReleaseFetchEvidencePayload(fetch: SourceFetchResult): String {
    "{\"ok\":${if (fetch.ok) { 1 } else { 0 }},\"status\":\"${ckbScheduledFetchJsonEscape(fetch.status)}\",\"statusCode\":${fetch.statusCode},\"commit\":\"${ckbScheduledFetchJsonEscape(fetch.commit)}\",\"sourceUrl\":\"${ckbScheduledFetchJsonEscape(fetch.sourceUrl)}\",\"normalizedType\":\"${ckbScheduledFetchJsonEscape(fetch.normalizedType)}\",\"etag\":\"${ckbScheduledFetchJsonEscape(fetch.etag)}\",\"lastModified\":\"${ckbScheduledFetchJsonEscape(fetch.lastModified)}\",\"truncated\":${if (fetch.truncated) { 1 } else { 0 }},\"contentType\":\"${ckbScheduledFetchJsonEscape(fetch.contentType)}\",\"bytes\":${fetch.bytes},\"bodyHash\":\"${fetch.bodyHash}\",\"retryAfterSeconds\":${fetch.retryAfterSeconds},\"attempts\":${fetch.attempts},\"transportErrorClass\":\"${ckbScheduledFetchJsonEscape(fetch.transportErrorClass)}\",\"transportDiagnostic\":\"${ckbScheduledFetchJsonEscape(utf8SafePrefix(redactSensitive(fetch.transportDiagnostic), 240))}\",\"curlExitCode\":${fetch.curlExitCode},\"repo\":\"${ckbScheduledFetchJsonEscape(fetch.repo)}\",\"ref\":\"${ckbScheduledFetchJsonEscape(fetch.ref)}\",\"path\":\"${ckbScheduledFetchJsonEscape(fetch.path)}\",\"repoVisibility\":\"${ckbScheduledFetchJsonEscape(fetch.repoVisibility)}\"}"
}

func ckbHydrateReleaseFetchEvidence(payload: String, fetch: SourceFetchResult): Bool {
    let object = try { JsonValue.fromStr(payload).asObject() } catch (_: Exception) { return false }
    fetch.ok = ckbResumeJsonInt(object, "ok", 0) == 1
    fetch.status = ckbResumeJsonString(object, "status")
    fetch.statusCode = ckbResumeJsonInt(object, "statusCode", 0)
    fetch.commit = ckbResumeJsonString(object, "commit")
    fetch.sourceUrl = ckbResumeJsonString(object, "sourceUrl")
    fetch.normalizedType = ckbResumeJsonString(object, "normalizedType")
    fetch.etag = ckbResumeJsonString(object, "etag")
    fetch.lastModified = ckbResumeJsonString(object, "lastModified")
    fetch.truncated = ckbResumeJsonInt(object, "truncated", 0) == 1
    fetch.contentType = ckbResumeJsonString(object, "contentType")
    fetch.bytes = ckbResumeJsonInt(object, "bytes", 0)
    fetch.bodyHash = ckbResumeJsonString(object, "bodyHash")
    fetch.retryAfterSeconds = ckbResumeJsonInt(object, "retryAfterSeconds", 0)
    fetch.attempts = ckbResumeJsonInt(object, "attempts", 0)
    fetch.transportErrorClass = ckbResumeJsonString(object, "transportErrorClass")
    fetch.transportDiagnostic = ckbResumeJsonString(object, "transportDiagnostic")
    fetch.curlExitCode = ckbResumeJsonInt(object, "curlExitCode", 0)
    fetch.repo = ckbResumeJsonString(object, "repo")
    fetch.ref = ckbResumeJsonString(object, "ref")
    fetch.path = ckbResumeJsonString(object, "path")
    fetch.repoVisibility = ckbResumeJsonString(object, "repoVisibility")
    fetch.status != ""
}

private func ckbReleaseCheckpointEvidenceHash(key: CkbScheduledFetchRunKey, checkpoint: CkbReleaseResumeCheckpoint): String {
    ckbReleaseEvidenceHash("${key.planningIdentityHash}|${key.runIdentityHash}|${checkpoint.phase}|${checkpoint.sourceOrdinal}|${checkpoint.nextPage}|${checkpoint.currentPathHash}|${checkpoint.refArtifactPath}|${checkpoint.sourceCompleteArtifactPath}|${ckbScheduledFetchPathsJson(checkpoint.plannedPaths)}|${ckbScheduledFetchPathsJson(checkpoint.completedPaths)}|${ckbScheduledFetchPathsJson(checkpoint.pageArtifactPaths)}|${ckbScheduledFetchPathsJson(checkpoint.contentArtifactPaths)}|${ckbScheduledFetchPathsJson(checkpoint.artifactEvidenceHashes)}")
}

private func ckbResumeJsonString(object: JsonObject, key: String): String {
    match (object.get(key)) {
        case Some(value) => try { value.asString().getValue() } catch (_: Exception) { "" }
        case None => ""
    }
}

private func ckbResumeJsonInt(object: JsonObject, key: String, fallback: Int64): Int64 {
    match (object.get(key)) {
        case Some(value) => try { value.asInt().getValue() } catch (_: Exception) { fallback }
        case None => fallback
    }
}

private func ckbResumeJsonStringArray(object: JsonObject, key: String, out: ArrayList<String>): Bool {
    try {
        let values = match (object.get(key)) {
            case Some(value) => value.asArray().getItems()
            case None => return false
        }
        for (value in values) { out.add(value.asString().getValue()) }
        true
    } catch (_: Exception) {
        false
    }
}
