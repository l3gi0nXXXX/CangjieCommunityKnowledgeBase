package cangjie_community_knowledge_base_test

import std.collection.*
import std.fs.*
import std.unittest.*
import std.unittest.testmacro.*

func p8Hash(value: String): String { benchmarkGapSha256(value) }

func p8ReleaseKey(id: String): CkbScheduledFetchRunKey {
    let key = CkbScheduledFetchRunKey()
    key.acquisitionId = "p8-${id}"
    key.planningIdentityHash = p8Hash("planning-${id}")
    key.runIdentityHash = p8Hash("run-${id}")
    key
}

func p8Existing(
    kb: KnowledgeBase
): ArrayList<CkbCertifiedKnowledgeRecord> {
    r7CertifiedKnowledgeRecords(kb.activeRecordSnapshot())
}

func s3Record(sourceId: String, chunk: String): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = sourceId
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = "Synthetic general knowledge"
    record.chunk = chunk
    record.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/synthetic"
    record.metadata.sourceId = sourceId
    record.metadata.sourceType = SourceTypes.DOC
    record.metadata.sourceSet = CangjieSourceSets.DOCS
    record.metadata.path = "docs/synthetic.md"
    record.metadata.symbol = "Synthetic.general"
    record.metadata.targetVersion = "1.0.0"
    record.metadata.versionResolutionId = "s3-v1"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

func s3Contains(values: ArrayList<String>, fragment: String): Bool {
    for (value in values) { if (value.contains(fragment)) { return true } }
    false
}

func s3TempRoot(name: String): String {
    let root = "target/s3-contamination-${name}"
    s3Remove(root)
    Directory.create(Path(root), recursive: true)
    root
}

func s3Remove(root: String): Unit {
    if (exists(Path(root))) { remove(Path(root), recursive: true) }
}

private func p8GateRejectsMutation(
    proof: CkbProductionReleaseProof,
    path: Path,
    mutated: String
): Bool {
    let original = File.readFrom(path)
    if (mutated == String.fromUtf8(original)) { return false }
    File.writeTo(path, mutated.toArray())
    let rejected = !ckbStrictCertificationGateFromRunRoot(
        proof.p7RunRoot, proof.authorityManifestJsonl).ok
    File.writeTo(path, original)
    rejected
}

private func p8JsonStringValue(raw: String, key: String): String {
    let parts = raw.split("\"${key}\":\"")
    if (parts.size < 2) { return "" }
    let values = parts[1].split("\"")
    if (values.size < 1) { return "" }
    values[0]
}

private func p8MutateHash(raw: String, key: String, label: String): String {
    let value = p8JsonStringValue(raw, key)
    raw.replace("\"${key}\":\"${value}\"",
        "\"${key}\":\"${p8Hash(label)}\"")
}

private func p8RejectReplace(
    proof: CkbProductionReleaseProof,
    root: Path,
    name: String,
    from: String,
    to: String
): Bool {
    let path = root.join(name)
    let raw = String.fromUtf8(File.readFrom(path))
    p8GateRejectsMutation(proof, path, raw.replace(from, to))
}

private func p8RealRootMutationMatrixRejectsAll(
    proof: CkbProductionReleaseProof
): Bool {
    let root = Path(proof.p7RunRoot)
    var all = true
    let identity = root.join("certification-http-identity.json")
    let identityRaw = String.fromUtf8(File.readFrom(identity))
    all = p8GateRejectsMutation(proof, identity, identityRaw.replace(
        "ckb-certification-identity-v1",
        "ckb-certification-identity-v2")) && all
    all = p8GateRejectsMutation(proof, identity, p8MutateHash(
        identityRaw, "pointerIdentityHash", "wrong-pointer")) && all
    all = p8GateRejectsMutation(proof, identity, identityRaw.replace(
        "\"activeVersion\":",
        "\"activeVersion\":\"duplicate\",\"activeVersion\":")) && all
    let owner = root.join("certification-http-owner.json")
    let ownerRaw = String.fromUtf8(File.readFrom(owner))
    for (pair in [("binaryHash", "wrong-owner-binary"),
        ("launchSpecHash", "wrong-owner-launch"),
        ("commandHash", "wrong-owner-command")]) {
        all = p8GateRejectsMutation(proof, owner,
            p8MutateHash(ownerRaw, pair[0], pair[1])) && all
    }
    let stopped = root.join("certification-http-stopped.json")
    let stoppedRaw = String.fromUtf8(File.readFrom(stopped))
    let stopMethod = p8JsonStringValue(stoppedRaw, "stopMethod")
    all = p8GateRejectsMutation(proof, stopped, stoppedRaw.replace(
        "\"stopMethod\":\"${stopMethod}\"",
        "\"stopMethod\":\"invalid\"")) && all
    all = p8GateRejectsMutation(proof, stopped, stoppedRaw.replace(
        "\"aliveAfterStop\":false", "\"aliveAfterStop\":true")) && all
    let provenance = root.join("runner-provenance.json")
    let provenanceRaw = String.fromUtf8(File.readFrom(provenance))
    for (pair in [("runnerBinaryHash", "wrong-provenance-binary"),
        ("launchSpecHash", "wrong-provenance-launch"),
        ("commandHash", "wrong-provenance-command")]) {
        all = p8GateRejectsMutation(proof, provenance,
            p8MutateHash(provenanceRaw, pair[0], pair[1])) && all
    }
    let group = root.join(
        "cases/CJ-HUMANEVAL-145/D-ckb-mcp-http")
    all = p8GateRejectsMutation(proof,
        group.join("workspace/src/solution.cj"),
        String.fromUtf8(File.readFrom(
            group.join("workspace/src/solution.cj"))) +
            "\n// valid source tamper\n") && all
    all = p8RejectReplace(proof, group, "canonical-task-context.json",
        "\"taskId\":\"CJ-HUMANEVAL-145\"",
        "\"taskId\":\"CJ-HUMANEVAL-144\"") && all
    all = p8RejectReplace(proof, group, "claude-transcript.jsonl",
        "\"model\":\"GLM-5.2\"",
        "\"model\":\"GLM-5.2-tampered\"") && all
    let testLog = group.join("test.log")
    all = p8GateRejectsMutation(proof, testLog,
        String.fromUtf8(File.readFrom(testLog)) +
        "\nvalid text tamper\n") && all
    all = p8RejectReplace(proof, group, "sandbox-probe.json",
        "\"deniedOutsideWorkspace\":true",
        "\"deniedOutsideWorkspace\":false") && all
    all = p8RejectReplace(proof, group, "mcp-config.json",
        "ckb-cangjie-http", "ckb-cangjie-http-tampered") && all
    all = p8RejectReplace(proof, group, "runtime-policy.json",
        "\"modelTimeoutSeconds\":30",
        "\"modelTimeoutSeconds\":31") && all
    all = p8RejectReplace(proof, group, "paired-tool-evidence.json",
        "\"coveragePass\":true", "\"coveragePass\":false") && all
    all = p8RejectReplace(proof, group, "verifier-mount.json",
        "\"injectExitCode\":0", "\"injectExitCode\":1") && all
    all = p8RejectReplace(proof, group, "test-result.json",
        "\"unitPassAt1\":true", "\"unitPassAt1\":false") && all
    all = p8RejectReplace(proof, group, "attempt-evidence.json",
        "\"retryCount\":0", "\"retryCount\":1") && all
    all = p8RejectReplace(proof, group, "claude-attempts.jsonl",
        "\"sampleAttempt\":1", "\"sampleAttempt\":0") && all
    let retryGroup = root.join(
        "cases/CJ-HUMANEVAL-000/D-ckb-mcp-http")
    all = p8RejectReplace(proof, retryGroup,
        "workspace-restores.jsonl", "\"restored\":true",
        "\"restored\":false") && all
    all
}

public func s3IntegrationPollutedCandidateCannotChangeActiveVersion(
    fixture: R7RealRunnerFixture
): Unit {
    let root = s3TempRoot("production-901")
    let kb = r7CleanKnowledgeBase()
    let store = FileKnowledgeStore(Path(root).join("store").toString())
    @Expect(kb.persistActiveSnapshot(store).ok, true)
    @Expect(fixture.ok, true)
    if (!fixture.ok) { s3Remove(root); return }
    let activeBefore = kb.status().activeKnowledgeVersion
    let snapshotBefore = store.loadActiveSnapshot()
    let checksumBefore = ckbCertifiedNormalizedRecordsChecksum(
        snapshotBefore.normalizedRecords)
    let pointerBefore = ckbActiveSnapshotPointerIdentityHash(
        store.loadActiveSnapshotPointer())
    let authority = parseCangjieHumanEvalAuthorityManifest(
        fixture.proof.authorityManifestJsonl)
    @Expect(authority.ok, true)
    let authorityOnlyFragment = authority.rows[0].signature
    let polluted = s3Record("polluted-candidate-901",
        authorityOnlyFragment)
    @Expect(cangjieStudentRecordDiagnostic(polluted).ok, true)
    let pollutedRecords = ArrayList<NormalizedRecord>()
    for (record in kb.activeRecordSnapshot()) {
        pollutedRecords.add(record)
    }
    pollutedRecords.add(polluted)
    let ordinaryValidation = validateCandidateServingIndex(
        pollutedRecords, "s3-authority-aware-901-candidate")
    @Expect(ordinaryValidation.ok, true)
    let pollutedCertified = r7CertifiedKnowledgeRecords(pollutedRecords)
    let candidateVersion = "s3-authority-aware-901-candidate"
    let gate = CkbCertifiedProductionPreCommitGate(kb, candidateVersion,
        activeBefore, fixture.proof, pollutedCertified)
    let promotion = cangjiePromoteCandidateRecordsAfterValidationWithVersion(
        kb, store, candidateVersion, pollutedRecords,
        preCommitGate: gate,
        expectedBaseActiveVersion: activeBefore,
        expectedBaseActivePointerHash: pointerBefore)
    @Expect(promotion.ok, false)
    @Expect(promotion.validation.status,
        "student_knowledge_leakage_blocked")
    @Expect(s3Contains(promotion.validation.diagnostics,
        authorityOnlyFragment), false)
    @Expect(kb.status().activeKnowledgeVersion, activeBefore)
    let snapshotAfter = store.loadActiveSnapshot()
    @Expect(snapshotAfter.activeVersion, snapshotBefore.activeVersion)
    @Expect(ckbCertifiedNormalizedRecordsChecksum(
        snapshotAfter.normalizedRecords), checksumBefore)
    @Expect(ckbActiveSnapshotPointerIdentityHash(
        store.loadActiveSnapshotPointer()), pointerBefore)
    s3Remove(root)
}

public func p8IntegrationRunnerGeneratedArtifactsPublishAndTamperFailsClosed(
    fixture: R7RealRunnerFixture
): Unit {
    let kb = r7CleanKnowledgeBase()
    let existing = p8Existing(kb)
    let incoming = p8Existing(kb)
    let records = incoming
    let certifiedVersion = kb.status().activeKnowledgeVersion
    let candidateVersion = "${certifiedVersion}-candidate"
    @Expect(fixture.diagnostic, "ok")
    @Expect(fixture.ok, true)
    if (!fixture.ok) { return }
    @Expect(fixture.runnerExitCode, 0)
    let proof = fixture.proof
    let store = FileKnowledgeStore(
        "target/p8-e2e-${ckbCertifiedKnowledgeRecordsChecksum(records)}-${ckbCoreNowMillis()}".replace(
            ":", "-"))
    let key = p8ReleaseKey("e2e")
    let report = ckbPublishCertifiedKnowledgeWithReleaseState(kb, store,
        key, candidateVersion, certifiedVersion, existing, incoming, proof)
    let pointer = store.loadActiveSnapshotPointer()
    let reloaded = store.loadActiveSnapshot()
    @Expect(report.ok, true)
    @Expect(report.diagnostic, "ok")
    @Expect(pointer.valid, true)
    @Expect(pointer.activeVersion, kb.status().activeKnowledgeVersion)
    @Expect(reloaded.valid, true)
    @Expect(reloaded.normalizedRecords.size, records.size)
    @Expect(report.promotion.candidateVersion, candidateVersion)
    @Expect(proof.stdioQueryPayload, proof.httpQueryPayload)
    @Expect(report.evidenceHash.startsWith("sha256:"), true)
    @Expect(store.has("teacher-solutions"), false)
    @Expect(store.has("certification-transcript.jsonl"), false)
    let state = ckbLoadReleaseAcquisitionState(store, key)
    @Expect(state.valid, true)
    @Expect(state.state, "certified_active")
    @Expect(state.candidateVersion, candidateVersion)
    @Expect(state.certifiedVersion, certifiedVersion)
    @Expect(state.activeVersion, report.activeVersion)
    @Expect(state.certificationFingerprint, fixture.modelFingerprint)
    @Expect(p8RealRootMutationMatrixRejectsAll(proof), true)
    let tampered = Path(proof.p7RunRoot).join(
        "cases/CJ-HUMANEVAL-145/D-ckb-mcp-http/claude-transcript.jsonl")
    File.writeTo(tampered, "tampered".toArray())
    @Expect(ckbCertifiedProductionProofDiagnostic(proof, records),
        "p7_gate_artifact_mismatch")
}
