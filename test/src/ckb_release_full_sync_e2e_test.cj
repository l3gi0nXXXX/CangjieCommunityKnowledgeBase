package cangjie_community_knowledge_base_test

import std.collection.{ArrayList, HashMap, HashSet}
import std.convert.Parsable
import std.env.{getVariable}
import std.fs.{Directory, File, Path, exists}
import std.io.*
import std.process.*
import std.time.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.encoding.json.*
import stdx.net.http.*

private func p6S6Ledger(eventId: String, dedupeKey: String,
    state: String): CkbRepositoryEventLedger {
    let ledger = CkbRepositoryEventLedger()
    ledger.eventId = eventId
    ledger.dedupeKey = dedupeKey
    ledger.canonicalSha256 = s6Repeat("a", 64)
    ledger.state = state
    ledger.resolvedCommit = s6Repeat("b", 40)
    ledger.ingestedEvidenceHash = s6Repeat("c", 64)
    ledger.schedulerRunId = "run-ledger"
    ledger.transactionId = "tx-ledger"
    ledger.candidateVersion = "candidate-ledger"
    ledger.activeVersion = "active-ledger"
    ledger
}

@Test
public class CkbReleaseFullSyncS6E2ETest {
    @TestCase
    public func p6S7U01RepositoryEventTypedLogsAreSafeAndComplete(): Unit {
        let secret = "通知🙂 Authorization: Bearer token-secret /Users/private/中文" + s6Repeat("界", 300)
        let line = ckbRepositoryEventTypedLogJson("retryable", "event-raw-secret",
            "run-s7", 2, secret, "retryable", secret, 17, 3)
        @Expect(line.contains("\"event\":\"repository.event.retryable\""), true)
        @Expect(line.contains("\"eventIdHash\":"), true)
        @Expect(line.contains("\"runId\":\"run-s7\""), true)
        @Expect(line.contains("\"attempt\":2"), true)
        @Expect(line.contains("\"durationMs\":17"), true)
        @Expect(line.contains("\"requestCount\":3"), true)
        @Expect(line.contains("event-raw-secret"), false)
        @Expect(line.contains("token-secret"), false)
        @Expect(line.contains("/Users/private"), false)
        @Expect(line.contains("🙂"), true)
        @Expect(line.size < 1400, true)
    }

    @TestCase
    public func p6S7B01LegacyLatestIsAlwaysUnverifiedAndFailClosed(): Unit {
        let root = "target/p6-s7-b01-legacy"
        let store = FileKnowledgeStore(root)
        @Expect(store.repositoryEventLegacyMigrationStatus(), "legacy-unverified")
        store.writeLinesAtomically("metadata/repository-event-latest.ckb", "")
        @Expect(store.repositoryEventLegacyMigrationStatus(), "legacy-unverified")
        store.writeLinesAtomically("metadata/repository-event-latest.ckb", "status=active\nrepo=legacy\n")
        @Expect(store.repositoryEventLegacyMigrationStatus(), "legacy-unverified")
        File.writeTo(Path(root).join("metadata/repository-event-latest.ckb"),
            [UInt8(255), UInt8(254)])
        @Expect(store.repositoryEventLegacyMigrationStatus(), "legacy-unverified")
    }

    @TestCase
    public func p6S7P01AcceptedDuplicateClaimedAndCommittedShareIdentity(): Unit {
        let root = "target/p6-s7-p01-chain"
        if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
        let store = FileKnowledgeStore(root)
        let config = CkbRuntimeConfig()
        let service = CkbCommandLoopService(config, store)
        let event = GitCodeRepositoryChangedEvent()
        event.valid = true; event.eventId = "event-chain-中文🙂"; event.deliveryId = "delivery-chain"
        event.repo = "Cangjie/example"; event.ref = "main"; event.mergeCommitSha = s6Repeat("a", 40)
        event.changedFiles.add("src/中文🙂.cj")
        let accepted = service.acceptGitCodeRepositoryChangedEvent(event)
        let duplicate = service.acceptGitCodeRepositoryChangedEvent(event)
        let claimed = service.claimNextRepositoryEventForScheduler("run-s7", ckbCoreNowMillis(), leaseMillis: 30000)
        let committed = store.completeRepositoryEventReceipt(claimed.receipt.dedupeKey,
            "run-s7", claimed.receipt.revision, ckbCoreNowMillis())
        let logs = store.readText("metadata/repository-event-events.jsonl")
        @Expect(accepted.status, "accepted")
        @Expect(duplicate.status, "duplicate")
        @Expect(claimed.claimed, true)
        @Expect(committed.state, "committed")
        @Expect(logs.contains("repository.event.accepted"), true)
        @Expect(logs.contains("repository.event.duplicate"), true)
        @Expect(logs.contains("repository.event.claimed"), true)
        @Expect(logs.contains("repository.event.committed"), true)
        @Expect(logs.contains("event-chain-中文🙂"), false)
        @Expect(store.repositoryEventLegacyMigrationStatus(), "legacy-unverified")
    }

    @TestCase
    public func p6S7N01TypedLogRenderingCannotChangeCommittedBusinessState(): Unit {
        let root = "target/p6-s7-n01-isolation"
        if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
        let store = FileKnowledgeStore(root)
        let receipt = CkbRepositoryEventReceipt()
        receipt.valid = true; receipt.eventId = "event-isolated"; receipt.state = "committed"
        receipt.createdAtMillis = 10; receipt.updatedAtMillis = 20
        store.emitRepositoryEventTypedLog("committed", receipt,
            runId: "run-isolated", stage: "通知🙂", status: "committed")
        @Expect(receipt.state, "committed")
        @Expect(store.readText("metadata/repository-event-events.jsonl").contains(
            "repository.event.committed"), true)
    }

    @TestCase
    public func p6E2E01TypedChainAndLedgerContractAreJointlyObservable(): Unit {
        let log = ckbRepositoryEventTypedLogJson("committed", "event-e2e01",
            "run-e2e01", 1, "complete", "committed", "", 20, 4)
        let gates = ckbSchedulerTaskContractForName(
            "cangjie_source_event_sync").requiredValidationGates
        @Expect(log.contains("repository.event.committed"), true)
        @Expect(log.contains("event-e2e01"), false)
        @Expect(gates.contains("event_inbox_committed"), true)
        @Expect(gates.contains("active_transaction_verified"), true)
    }

    @TestCase
    public func p6E2E04InvalidEncodingAndSensitiveDiagnosticsStayClosed(): Unit {
        let store = FileKnowledgeStore("target/p6-e2e04-security")
        store.writeLinesAtomically("metadata/repository-event-latest.ckb", "status=legacy\n")
        let log = ckbRepositoryEventTypedLogJson("failed", "event-secret",
            "run-e2e04", 1, "validation", "failed",
            "Authorization: Bearer no-leak /tmp/private🙂", 1, 0)
        @Expect(store.repositoryEventLegacyMigrationStatus(), "legacy-unverified")
        @Expect(log.contains("no-leak"), false)
        @Expect(log.contains("/tmp/private"), false)
        @Expect(log.contains("repository.event.failed"), true)
    }

    @TestCase
    public func p6E2E05TerminalReceiptHasNoOwnedLeaseOrMutationOrphan(): Unit {
        let root = "target/p6-e2e05-cleanup"
        if (exists(Path(root))) { _ = launch("/bin/rm", ["-rf", root]).wait() }
        let store = FileKnowledgeStore(root)
        let event = GitCodeRepositoryChangedEvent()
        event.valid = true; event.eventId = "event-cleanup"; event.deliveryId = "delivery-cleanup"
        event.repo = "Cangjie/example"; event.ref = "main"; event.mergeCommitSha = s6Repeat("a", 40)
        event.changedFiles.add("src/cleanup.cj")
        let accepted = CkbCommandLoopService(CkbRuntimeConfig(), store)
            .acceptGitCodeRepositoryChangedEvent(event)
        let claimed = store.claimRepositoryEventReceipt(accepted.dedupeKey,
            "run-cleanup", ckbCoreNowMillis(), 30000)
        let committed = store.completeRepositoryEventReceipt(accepted.dedupeKey,
            "run-cleanup", claimed.receipt.revision, ckbCoreNowMillis())
        @Expect(committed.state, "committed")
        @Expect(committed.leaseOwner, "")
        @Expect(committed.leaseUntilMillis, 0)
        @Expect(store.dueRepositoryEventReceipts(ckbCoreNowMillis() + 60000).size, 0)
        @Expect(exists(Path(root).join("tmp")), false)
        @Expect(exists(Path(root).join("spool")), false)
    }

    @TestCase
    public func p6S6U01Ku10EnumeratesRepositoryEventRequiredGates(): Unit {
        let gates = ckbSchedulerTaskContractForName(
            "cangjie_source_event_sync").requiredValidationGates
        @Expect(gates.size, 5)
        @Expect(gates[0], "event_inbox_committed")
        @Expect(gates[1], "event_delta_reconciled")
        @Expect(gates[2], "candidate_validation_passed")
        @Expect(gates[3], "active_transaction_verified")
        @Expect(gates[4], "repository_event_checkpoint_verified")
    }

    @TestCase
    public func p6S6U02RepositoryEventLedgerCodecIsCanonical(): Unit {
        let store = FileKnowledgeStore("target/p6-s6-u02-ledger")
        let first = p6S6Ledger("event-中文🙂", "dedupe-u02", "committed")
        first.gates.add("repository_event_checkpoint_verified")
        first.gates.add("candidate_validation_passed")
        first.committedEvidenceHash = ckbRepositoryEventCommittedEvidenceHash(first)
        let saved = store.saveRepositoryEventLedger(first)
        let second = p6S6Ledger("event-中文🙂", "dedupe-u02-order", "committed")
        second.gates.add("candidate_validation_passed")
        second.gates.add("repository_event_checkpoint_verified")
        let firstEvidence = ckbRepositoryEventCommittedEvidenceHash(first)
        let secondEvidence = ckbRepositoryEventCommittedEvidenceHash(second)
        @Expect(saved.valid, true)
        @Expect(store.loadRepositoryEventLedger("dedupe-u02").eventId, "event-中文🙂")
        @Expect(firstEvidence, secondEvidence)
    }

    @TestCase
    public func p6S6B01FailedAttemptDoesNotOverwriteLastSuccess(): Unit {
        let store = FileKnowledgeStore("target/p6-s6-b01-last-success")
        let committed = p6S6Ledger("event-success", "dedupe-success", "committed")
        committed.gates.add("candidate_validation_passed")
        committed.committedEvidenceHash = ckbRepositoryEventCommittedEvidenceHash(committed)
        _ = store.saveRepositoryEventLedger(committed)
        let before = store.readText("metadata/repository-event-last-success.ckb")
        let retryable = p6S6Ledger("event-failed", "dedupe-failed", "retryable")
        _ = store.saveRepositoryEventLedger(retryable)
        @Expect(store.readText("metadata/repository-event-last-success.ckb"), before)
        @Expect(store.loadRepositoryEventLedger("dedupe-failed").state, "retryable")
    }

    @TestCase
    public func p6S6N02InvalidEncodingAndMalformedLedgerFailClosed(): Unit {
        let root = "target/p6-s6-n02-invalid-ledger"
        let store = FileKnowledgeStore(root)
        let ledger = p6S6Ledger("event-中文🙂", "dedupe-invalid", "retryable")
        _ = store.saveRepositoryEventLedger(ledger)
        let directory = Path(root).join("metadata/repository-event-ledger")
        var artifact = Path(root)
        for (entry in Directory.readFrom(directory)) {
            if (!entry.isDirectory() && entry.name.endsWith(".ckb")) {
                artifact = entry.path
            }
        }
        File.writeTo(artifact, [UInt8(255), UInt8(254), UInt8(253)])
        let invalid = store.loadRepositoryEventLedger("dedupe-invalid")
        @Expect(invalid.valid, false)
        @Expect(invalid.diagnostic, "invalid_response_encoding")

        File.writeTo(artifact, "schemaVersion=ckb-repository-event-ledger-v1\neventId=broken\n".toArray())
        let malformed = store.loadRepositoryEventLedger("dedupe-invalid")
        @Expect(malformed.valid, false)
        @Expect(malformed.diagnostic, "repository_event_ledger_checksum_mismatch")
    }

    @TestCase
    public func p6S6P01AlignedCommittedLedgerPassesKu10(): Unit {
        let store = FileKnowledgeStore("target/p6-s6-p01-aligned")
        let kb = newOfflineKnowledgeBase()
        _ = kb.persistActiveSnapshot(store)
        let pointer = store.loadActiveSnapshotPointer()
        let receipt = CkbRepositoryEventReceipt()
        receipt.valid = true; receipt.state = "committed"; receipt.eventId = "event-p01"; receipt.dedupeKey = "dedupe-p01"
        receipt.canonicalSha256 = s6Repeat("a", 64); receipt.resolvedCommit = s6Repeat("b", 40)
        let outcome = CkbRepositoryEventWorkerResult()
        outcome.state = "committed"; outcome.schedulerRunId = "run-p01"
        outcome.transactionId = pointer.txId; outcome.candidateVersion = "candidate-p01"
        outcome.activeVersion = pointer.activeVersion; outcome.validationEvidenceHash = s6Repeat("c", 64)
        outcome.validationGates.add("candidate_validation_passed")
        let ledger = store.materializeRepositoryEventCommittedLedger(receipt, outcome)
        let task = SchedulerTaskResult()
        task.ok = true; task.status = "candidate_validated_promoted"; task.since = receipt.eventId
        task.schedulerRunId = outcome.schedulerRunId; task.transactionId = outcome.transactionId
        task.candidateVersion = outcome.candidateVersion; task.activeVersion = outcome.activeVersion
        task.validationStatus = "candidate_validation_passed"
        task.validationEvidenceHash = outcome.validationEvidenceHash
        task.updatedDataKinds.add("repo_source"); task.updatedDataKinds.add("serving_feed")
        for (gate in ledger.gates) { task.validationGates.add(gate) }
        let validation = validateSchedulerTaskResultAgainstPersistedContract(store,
            CkbRuntimeConfig(), "cangjie_source_event_sync", task,
            s6Invariant("before"), s6Invariant(task.activeVersion))
        @Expect(ledger.valid, true)
        @Expect(validation.ok, true)
        @Expect(validation.diagnostic, "routine_contract_passed")
    }

    @TestCase
    public func p6S6N01StaleOrPartialLedgerFailsKu10(): Unit {
        let store = FileKnowledgeStore("target/p6-s6-n01-misaligned")
        let ledger = p6S6Ledger("event-n01", "dedupe-n01", "retryable")
        _ = store.saveRepositoryEventLedger(ledger)
        let task = SchedulerTaskResult()
        task.ok = true; task.status = "candidate_validated_promoted"; task.since = ledger.eventId
        task.schedulerRunId = "wrong-run"; task.transactionId = "wrong-tx"
        task.candidateVersion = "wrong-candidate"; task.activeVersion = "wrong-active"
        task.validationStatus = "candidate_validation_passed"
        task.validationEvidenceHash = s6Repeat("d", 64)
        task.updatedDataKinds.add("repo_source"); task.updatedDataKinds.add("serving_feed")
        task.validationGates.add("event_inbox_committed")
        task.validationGates.add("event_delta_reconciled")
        task.validationGates.add("candidate_validation_passed")
        task.validationGates.add("active_transaction_verified")
        task.validationGates.add("repository_event_checkpoint_verified")
        let validation = validateSchedulerTaskResultAgainstPersistedContract(store,
            CkbRuntimeConfig(), "cangjie_source_event_sync", task,
            s6Invariant("before"), s6Invariant("wrong-active"))
        @Expect(validation.ok, false)
        @Expect(validation.diagnostic,
            "required_artifact_missing:metadata/repository-event-ledger")
    }

    // P5-S6-U01
    @TestCase
    public func p5S6U01ExactGatesEvidenceCodecAndJsonAreContractBound(): Unit {
        let fixture = ckbS5ReleaseFixture("target/p5-s6-u01", 1)
        let task = fixture.task
        let before = s6Invariant("before-active")
        let after = s6Invariant(task.activeVersion)
        let passed = validateSchedulerTaskResultAgainstPersistedContract(
            fixture.store, fixture.config, "cangjie_release_full_sync", task,
            before, after)

        @Expect(task.ok, true)
        @Expect(task.status, "candidate_validated_promoted")
        @Expect(task.validationGates.size, 5)
        @Expect(passed.ok, true)
        @Expect(passed.diagnostic, "routine_contract_passed")
        @Expect(task.transactionId, fixture.store.loadActiveSnapshotPointer().txId)
        @Expect(task.manifestEvidenceHash,
            fixture.store.loadActiveSnapshotPointer().manifestHash)
        @Expect(task.freshnessEvidenceHash,
            fixture.store.loadActiveSnapshotPointer().freshnessHash)
        @Expect(task.sourceCoverageEvidenceHash.size, 64)
        @Expect(task.inventoryEvidenceHash.size, 64)

        let required = ckbSchedulerTaskContractForName(
            "cangjie_release_full_sync").requiredValidationGates
        for (missing in required) {
            let without = s6TaskWithoutGate(task, missing)
            let validation = validateSchedulerTaskResultAgainstPersistedContract(
                fixture.store, fixture.config, "cangjie_release_full_sync",
                without, before, after)
            @Expect(validation.ok, false)
            @Expect(validation.diagnostic, "${missing}_missing")
        }

        let legacy = ckbSchedulerTaskResultFromText(
            ckbSchedulerTaskResultText(task))
        legacy.validationGates.clear()
        legacy.validationStatus = "candidate_validation_passed"
        let legacyValidation = validateSchedulerTaskResultAgainstPersistedContract(
            fixture.store, fixture.config, "cangjie_release_full_sync", legacy,
            before, after)
        @Expect(legacyValidation.diagnostic,
            "candidate_validation_passed_missing")

        let mismatched = s6CloneTask(task)
        mismatched.sourceCoverageEvidenceHash = s6Repeat("0", 64)
        let stale = validateSchedulerTaskResultAgainstPersistedContract(
            fixture.store, fixture.config, "cangjie_release_full_sync",
            mismatched, before, after)
        @Expect(stale.ok, false)
        @Expect(stale.diagnostic, "required_artifact_stale_or_misaligned")

        let encoded = ckbSchedulerTaskResultText(task) +
            "futureField=ignored\nfutureList|ignored\n"
        let decoded = ckbSchedulerTaskResultFromText(encoded)
        @Expect(decoded.validationGates.size, 5)
        @Expect(decoded.transactionId, task.transactionId)
        @Expect(decoded.manifestEvidenceHash, task.manifestEvidenceHash)
        @Expect(decoded.freshnessEvidenceHash, task.freshnessEvidenceHash)
        @Expect(decoded.sourceCoverageEvidenceHash,
            task.sourceCoverageEvidenceHash)
        @Expect(decoded.inventoryEvidenceHash, task.inventoryEvidenceHash)

        let scheduler = Scheduler(FakeClock(1000))
        let names = ArrayList<String>()
        names.add("cangjie_release_full_sync")
        let run = SchedulerExecutor(scheduler, S6StaticTaskRunner(task)).runTaskNames(
            names, force: true)
        let json = ckbSchedulerRunOutputJson(run)
        @Expect(json.contains("\"validationGates\""), true)
        @Expect(json.contains("\"transactionId\":\"${task.transactionId}\""), true)
        @Expect(json.contains("\"manifestEvidenceHash\":\"${task.manifestEvidenceHash}\""), true)
        @Expect(json.contains("\"freshnessEvidenceHash\":\"${task.freshnessEvidenceHash}\""), true)
        @Expect(json.contains("\"sourceCoverageEvidenceHash\":\"${task.sourceCoverageEvidenceHash}\""), true)
        @Expect(json.contains("\"inventoryEvidenceHash\":\"${task.inventoryEvidenceHash}\""), true)
        for (gate in required) {
            @Expect(json.contains("\"${gate}\""), true)
        }
    }

    // P5-S6-U01 candidate business identity contract
    @TestCase
    public func p5S6U01CandidateBusinessEvidenceIsCanonicalAndFailClosed(): Unit {
        let baselineRaw = s6BusinessRawRecords(false)
        let baselineNormalized = s6BusinessNormalizedRecords(false)
        let baseline = ckbCandidateBusinessEvidence(baselineRaw,
            baselineNormalized)
        let reorderedRaw = s6BusinessRawRecords(true)
        let reorderedNormalized = s6BusinessNormalizedRecords(true)
        for (record in reorderedRaw) {
            record.metadata.knowledgeVersion = "不同-active-版本🙂"
            record.metadata.candidateVersion = "不同-candidate-版本🙂"
        }
        for (record in reorderedNormalized) {
            record.metadata.knowledgeVersion = "不同-active-版本🙂"
            record.metadata.candidateVersion = "不同-candidate-版本🙂"
        }
        let reordered = ckbCandidateBusinessEvidence(reorderedRaw,
            reorderedNormalized)
        @Expect(baseline.valid, true)
        @Expect(baseline.status, "candidate_business_evidence_valid")
        @Expect(ckbCandidateBusinessEvidenceMatches(baseline, reordered), true)
        let unicodeDerived = ckbMetadataDerivedFromDecode(
            "2:e788b6e69da5e6ba90f09f99822d31,e6aca1e69da5e6ba902d31")
        @Expect(unicodeDerived.status, "metadata_derived_valid")
        @Expect(unicodeDerived.values.size, 2)
        @Expect(unicodeDerived.values[0], "父来源🙂-1")
        @Expect(unicodeDerived.values[1], "次来源-1")
        let roundtripRoot = "target/p5-s6-u01-business-roundtrip"
        ckbReleaseTestEnsureEmptyDir(roundtripRoot)
        let roundtripStore = FileKnowledgeStore(roundtripRoot)
        for (record in baselineRaw) {
            record.metadata.knowledgeVersion = "roundtrip-active"
        }
        for (record in baselineNormalized) {
            record.metadata.knowledgeVersion = "roundtrip-active"
        }
        roundtripStore.saveRaw(baselineRaw)
        roundtripStore.saveNormalized(baselineNormalized)
        roundtripStore.saveActiveIndex(baselineNormalized, "roundtrip-active")
        let roundtripStatus = KnowledgeStatus()
        roundtripStatus.activeKnowledgeVersion = "roundtrip-active"
        roundtripStatus.candidateKnowledgeVersion = "roundtrip-candidate"
        roundtripStore.saveMetadata(roundtripStatus)
        let roundtrip = ckbCandidateBusinessEvidence(roundtripStore.loadRaw(),
            roundtripStore.loadNormalized())
        @Expect(ckbCandidateBusinessEvidenceMatches(baseline, roundtrip), true)
        @Expect(roundtripStore.loadRaw()[0].requiresReview, false)
        @Expect(roundtripStore.loadRaw()[1].requiresReview, true)
        @Expect(roundtripStore.loadNormalized()[0].requiresReview, false)
        @Expect(roundtripStore.loadNormalized()[1].requiresReview, true)
        @Expect(roundtripStore.loadRaw()[0].metadata.derivedFrom[0],
            "父来源🙂-1")
        @Expect(roundtripStore.loadNormalized()[0].metadata.derivedFrom[1],
            "次来源-1")

        let legacyRoot = "target/p5-s6-u01-business-legacy"
        ckbReleaseTestEnsureEmptyDir(legacyRoot)
        let legacyStore = FileKnowledgeStore(legacyRoot)
        legacyStore.writeLinesAtomically("raw/records.ckb",
            s6LegacyBusinessRawLine())
        legacyStore.writeLinesAtomically("normalized/records.ckb",
            s6LegacyBusinessNormalizedLine())
        legacyStore.writeLinesAtomically("index/active.version", "active\n")
        legacyStore.writeLinesAtomically("index/active.ckb",
            s6LegacyBusinessNormalizedLine())
        let legacyStatus = KnowledgeStatus()
        legacyStatus.activeKnowledgeVersion = "active"
        legacyStatus.candidateKnowledgeVersion = "candidate"
        legacyStore.saveMetadata(legacyStatus)
        @Expect(legacyStore.loadRaw().size, 1)
        @Expect(legacyStore.loadNormalized().size, 1)
        @Expect(legacyStore.loadRaw()[0].requiresReview, true)
        @Expect(legacyStore.loadNormalized()[0].requiresReview, true)
        @Expect(legacyStore.loadRaw()[0].metadata.derivedFrom.size, 0)
        @Expect(legacyStore.loadNormalized()[0].metadata.derivedFrom.size, 0)

        @Expect(ckbMetadataDerivedFromDecode("malformed").status,
            "metadata_derived_separator_missing")
        @Expect(ckbMetadataDerivedFromDecode("x:").status,
            "metadata_derived_count_invalid")
        @Expect(ckbMetadataDerivedFromDecode("0:aa").status,
            "metadata_derived_zero_count_payload_present")
        @Expect(ckbMetadataDerivedFromDecode("2:61").status,
            "metadata_derived_count_mismatch")
        @Expect(ckbMetadataDerivedFromDecode("1:zz").status,
            "metadata_derived_hex_invalid")
        @Expect(ckbMetadataDerivedFromDecode("1:ff").status,
            "metadata_derived_invalid_response_encoding")
        legacyStore.writeLinesAtomically("raw/records.ckb",
            s6LegacyBusinessRawLine().trimAscii() +
            "|1:zz|p5-record-v2|false\n")
        @Expect(legacyStore.loadRaw().size, 0)

        let mutations: Array<String> = [
            "raw.sourceId", "raw.title", "raw.content", "raw.contentHash",
            "raw.requiresReview", "raw.metadata.repo",
            "normalized.sourceId", "normalized.recordKind", "normalized.title",
            "normalized.chunk", "normalized.citation", "normalized.score",
            "normalized.requiresReview", "metadata.sourceId",
            "metadata.sourceType", "metadata.sourceUrl", "metadata.repo",
            "metadata.path", "metadata.symbol", "metadata.commit",
            "metadata.docVersion", "metadata.targetVersion",
            "metadata.sourceSet", "metadata.versionResolutionId",
            "metadata.crawlAt", "metadata.indexedAt", "metadata.contentSize",
            "metadata.trustLevel", "metadata.reviewState", "metadata.license",
            "metadata.repoVisibility", "metadata.derivedFrom"
        ]
        for (mutation in mutations) {
            let changed = s6BusinessEvidenceWithMutation(mutation)
            @Expect(changed.valid, true)
            @Expect(ckbCandidateBusinessEvidenceMatches(baseline, changed), false)
        }

        let duplicateRaw = s6BusinessRawRecords(false)
        duplicateRaw[1].sourceId = duplicateRaw[0].sourceId
        let duplicateRawEvidence = ckbCandidateBusinessEvidence(duplicateRaw,
            s6BusinessNormalizedRecords(false))
        @Expect(duplicateRawEvidence.valid, false)
        @Expect(duplicateRawEvidence.status,
            "candidate_business_raw_source_id_duplicate")

        let duplicateNormalized = s6BusinessNormalizedRecords(false)
        duplicateNormalized[1].sourceId = duplicateNormalized[0].sourceId
        let duplicateNormalizedEvidence = ckbCandidateBusinessEvidence(
            s6BusinessRawRecords(false), duplicateNormalized)
        @Expect(duplicateNormalizedEvidence.valid, false)
        @Expect(duplicateNormalizedEvidence.status,
            "candidate_business_normalized_source_id_duplicate")

        let emptyRawId = s6BusinessRawRecords(false)
        emptyRawId[0].sourceId = ""
        @Expect(ckbCandidateBusinessEvidence(emptyRawId,
            s6BusinessNormalizedRecords(false)).status,
            "candidate_business_raw_source_id_missing")
        let emptyNormalizedId = s6BusinessNormalizedRecords(false)
        emptyNormalizedId[0].sourceId = ""
        @Expect(ckbCandidateBusinessEvidence(
            s6BusinessRawRecords(false), emptyNormalizedId).status,
            "candidate_business_normalized_source_id_missing")
    }

    // P5-S6-B01
    @TestCase
    public func p5S6B01OnlyExactFiveSourceCurrentTransactionAndBoundedUtf8Pass(): Unit {
        let fixture = ckbS5ReleaseFixture("target/p5-s6-b01", 1)
        let task = fixture.task
        let pointer = fixture.store.loadActiveSnapshotPointer()
        let txCoverage = "transactions/${pointer.txId}/metadata/cangjie-release-coverage.ckb"
        let original = fixture.store.readText(txCoverage)
        fixture.store.writeLinesAtomically("metadata/s6-coverage-exact.ckb", original)
        fixture.store.writeLinesAtomically("metadata/s6-coverage-four.ckb",
            s6DropFirstSourceLine(original))
        fixture.store.writeLinesAtomically("metadata/s6-coverage-duplicate.ckb",
            s6DuplicateSourceSet(original))

        let exact = fixture.store.routineReleaseCoverageSummary(
            "metadata/s6-coverage-exact.ckb")
        let four = fixture.store.routineReleaseCoverageSummary(
            "metadata/s6-coverage-four.ckb")
        let duplicate = fixture.store.routineReleaseCoverageSummary(
            "metadata/s6-coverage-duplicate.ckb")
        @Expect(exact.valid, true)
        @Expect(exact.sourceCoverageEvidenceHash,
            task.sourceCoverageEvidenceHash)
        @Expect(exact.inventoryEvidenceHash, task.inventoryEvidenceHash)
        @Expect(four.valid, false)
        @Expect(duplicate.valid, false)

        let staleRoot = "target/p5-s6-b01-stale-live"
        ckbReleaseTestEnsureEmptyDir(staleRoot)
        let staleStore = FileKnowledgeStore("${staleRoot}/store")
        staleStore.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let stale = validateSchedulerTaskResultAgainstPersistedContract(
            staleStore, fixture.config, "cangjie_release_full_sync", task,
            s6Invariant("before"), s6Invariant(task.activeVersion))
        @Expect(stale.diagnostic, "required_artifact_stale_or_misaligned")

        let zeroDiagnostics = s6CloneTask(task)
        zeroDiagnostics.validationDiagnostics.clear()
        @Expect(ckbSchedulerTaskResultFromText(
            ckbSchedulerTaskResultText(zeroDiagnostics))
            .validationDiagnostics.size, 0)

        let maxDiagnostics = s6CloneTask(task)
        maxDiagnostics.validationDiagnostics.clear()
        for (i in 0..64) {
            maxDiagnostics.validationDiagnostics.add(
                "诊断🙂-${i}-Authorization: Bearer fixture-secret-/Users/private/" +
                s6Repeat("界", 300))
        }
        @Expect(ckbSchedulerTaskResultFromText(
            ckbSchedulerTaskResultText(maxDiagnostics))
            .validationDiagnostics.size, 64)

        let hostile = s6CloneTask(task)
        hostile.validationDiagnostics.clear()
        for (i in 0..65) {
            hostile.validationDiagnostics.add(
                "诊断🙂-${i}-Authorization: Bearer fixture-secret-/Users/private/" +
                s6Repeat("界", 300))
        }
        let hostileText = ckbSchedulerTaskResultText(hostile)
        let hostileParsed = ckbSchedulerTaskResultFromText(hostileText)
        @Expect(hostileParsed.validationDiagnostics.size, 64)
        @Expect(hostileText.contains("fixture-secret"), false)
        @Expect(hostileText.contains("/Users/private"), false)
        @Expect(String.fromUtf8(hostileText.toArray()), hostileText)

        let invalidRoot = "target/p5-s6-b01-invalid-worker"
        ckbReleaseTestEnsureEmptyDir(invalidRoot)
        let invalidStore = FileKnowledgeStore("${invalidRoot}/store")
        invalidStore.writeLinesAtomically("metadata/worker.ckb", "status=ok\n")
        File.writeTo(Path("${invalidRoot}/store/metadata/worker.ckb"),
            [UInt8(255), UInt8(254), UInt8(253)])
        let invalid = ckbReadSchedulerWorkerResultFile(
            "${invalidRoot}/store", "metadata/worker.ckb",
            "cangjie_release_full_sync", "0", 1, 100)
        @Expect(invalid.ok, false)
        @Expect(invalid.status,
            "task_worker_result_invalid_response_encoding")
        s6AssertSchedulerLoggingContract("target/p5-s6-b01-logging", task)
    }

    // P5-S6-P01
    @TestCase
    public func p5S6P01RealProcessWorkerWritesCleanConfirmedContractResult(): Unit {
        let root = "target/p5-s6-p01-process"
        ckbReleaseTestEnsureEmptyDir(root)
        let fixture = s6PrepareLocalMainFixture(root)
        let resultRelative = "metadata/scheduler-workers/p5-s6-p01.ckb"
        var child = S6ChildResult()
        try {
            child = s6LaunchMain(root, ["--config", fixture.configPath,
                "--store", fixture.storePath, "scheduler-task-worker", "--task",
                "cangjie_release_full_sync", "--scheduler-run-id",
                "p5-s6-p01-run", "--since", "0", "--deadline",
                "${ckbCoreNowMillis() + 435000}", "--result-rel",
                resultRelative])
        } finally {
            s6StopLocalServer(fixture.server)
        }
        let store = FileKnowledgeStore("${root}/store")
        let primary = ckbSchedulerTaskResultFromText(store.readText(resultRelative))
        let sidecar = ckbSchedulerTaskResultFromText(store.readText(
            "${resultRelative}.sidecar"))

        @Expect(child.exitCode, 0)
        @Expect(sidecar.ok, true)
        @Expect(sidecar.status, "candidate_validated_promoted")
        @Expect(sidecar.validationGates.size, 5)
        @Expect(primary.transactionId, sidecar.transactionId)
        @Expect(primary.manifestEvidenceHash, sidecar.manifestEvidenceHash)
        @Expect(primary.freshnessEvidenceHash, sidecar.freshnessEvidenceHash)
        @Expect(primary.sourceCoverageEvidenceHash,
            sidecar.sourceCoverageEvidenceHash)
        @Expect(primary.inventoryEvidenceHash, sidecar.inventoryEvidenceHash)
        let persistedValidation =
            validateSchedulerTaskResultAgainstPersistedContract(store,
                loadCkbRuntimeConfig(fixture.configPath),
                "cangjie_release_full_sync", sidecar,
                s6Invariant("before-p5-s6-p01"),
                s6Invariant(sidecar.activeVersion))
        @Expect(persistedValidation.ok, true)
        let taskNames = ArrayList<String>()
        taskNames.add("cangjie_release_full_sync")
        let finalized = SchedulerExecutor(Scheduler(FakeClock(1000)),
            S6StaticTaskRunner(sidecar), NoopSchedulerProgressSink(),
            440000).runTaskNames(taskNames, force: true)
        let schedulerJson = ckbSchedulerRunOutputJson(finalized)
        @Expect(finalized.businessOk, true)
        @Expect(finalized.finalizationOk, true)
        @Expect(finalized.failed, 0)
        @Expect(schedulerJson.contains("\"failedTasks\":[]"), true)
        @Expect(schedulerJson.contains("\"businessOk\":true"), true)
        @Expect(schedulerJson.contains("\"finalizationOk\":true"), true)
        @Expect(child.stdoutText, "")
        @Expect(child.stderrText, "")
        @Expect(s6PidExited(child.pid), true)
        @Expect(s6PidExited(fixture.server.pid), true)
        @Expect(s6TreeContainsName(Path(root), ".tmp-"), false)
        let reloaded = newKnowledgeBaseFromStore(store)
        @Expect(reloaded.source, "persisted")
        @Expect(QueryService(reloaded.kb).query("", "old-a-token", 10).records.size > 0, true)
    }

    // P5-S6-N01
    @TestCase
    public func p5S6N01ContractFailureAndObserverFailureStayIsolated(): Unit {
        let fixture = ckbS5ReleaseFixture("target/p5-s6-n01", 1)
        let bad = s6CloneTask(fixture.task)
        bad.inventoryEvidenceHash = s6Repeat("f", 64)
        let validation = validateSchedulerTaskResultAgainstPersistedContract(
            fixture.store, fixture.config, "cangjie_release_full_sync", bad,
            s6Invariant("before"), s6Invariant(bad.activeVersion))
        @Expect(validation.ok, false)
        @Expect(validation.diagnostic, "required_artifact_stale_or_misaligned")
        let contractRejected = s6CloneTask(bad)
        @Expect(contractRejected.ok, true)
        ckbApplySchedulerTaskContractValidation(contractRejected, validation,
            false)
        @Expect(contractRejected.ok, false)
        @Expect(contractRejected.status,
            "required_artifact_stale_or_misaligned")
        let rejectedNames = ArrayList<String>()
        rejectedNames.add("cangjie_release_full_sync")
        let rejectedRun = SchedulerExecutor(Scheduler(FakeClock(1000)),
            S6StaticTaskRunner(contractRejected), NoopSchedulerProgressSink(),
            440000).runTaskNames(rejectedNames, force: true)
        let rejectedJson = ckbSchedulerRunOutputJson(rejectedRun)
        @Expect(rejectedRun.businessOk, false)
        @Expect(rejectedRun.failed, 1)
        @Expect(rejectedJson.contains(
            "\"status\":\"required_artifact_stale_or_misaligned\""), true)
        @Expect(rejectedJson.contains(
            "\"primaryFailure\":\"required_artifact_stale_or_misaligned\""),
            true)

        let scheduler = Scheduler(FakeClock(1000))
        let names = ArrayList<String>()
        names.add("cangjie_release_full_sync")
        let run = SchedulerExecutor(scheduler, S6StaticTaskRunner(fixture.task),
            S6ThrowingProgressSink(), 440000).runTaskNames(names, force: true)
        let rendered = ckbSchedulerRunOutputJson(run)
        @Expect(run.businessOk, true)
        @Expect(run.failed, 0)
        @Expect(run.finalizationOk, false)
        @Expect(run.finalizationDiagnostics.size > 0, true)
        @Expect(rendered.contains("\"businessOk\":true"), true)
        @Expect(rendered.contains("\"finalizationOk\":false"), true)
        @Expect(rendered.contains("fixture-secret"), false)

        // CKB has one production scheduler projection boundary:
        // SchedulerProgressSink. There is no separate notification adapter.
        let projectionRoot = "target/p5-s6-n01-cli-projection"
        ckbReleaseTestEnsureEmptyDir(projectionRoot)
        let projectionStorePath = "${projectionRoot}/store"
        let projectionConfig = "${projectionRoot}/ckb.conf"
        File.writeTo(Path(projectionConfig),
            "network.enabled=false\nscheduler.enabled=false\n".toArray())
        let projectionStore = FileKnowledgeStore(projectionStorePath)
        projectionStore.ensureLayout()
        File.writeTo(Path(projectionStorePath).join(
            "metadata/scheduler-runs"),
            "blocked observer projection 中文🙂 fixture-secret".toArray())
        let projectionChild = s6LaunchMain(projectionRoot,
            ["--config", projectionConfig, "--store", projectionStorePath,
                "scheduler-run", "--task", "weekly_full_rebuild", "--force",
                "--json"])
        let projectionJson = projectionChild.stdoutText.trimAscii()
        @Expect(projectionChild.exitCode, 1)
        @Expect(projectionJson.startsWith("{"), true)
        @Expect(projectionJson.endsWith("}"), true)
        @Expect(projectionJson.contains("\"businessOk\":true"), true)
        @Expect(projectionJson.contains("\"finalizationOk\":false"), true)
        @Expect(projectionJson.contains("\"status\":\"rebuild_ok\""), true)
        @Expect(projectionJson.contains("fixture-secret"), false)
        @Expect(projectionChild.stderrText, "")
        @Expect(s6PidExited(projectionChild.pid), true)

        let humanRoot = "target/p5-s6-n01-human-renderer"
        ckbReleaseTestEnsureEmptyDir(humanRoot)
        let humanConfig = "${humanRoot}/ckb.conf"
        File.writeTo(Path(humanConfig),
            "network.enabled=false\nscheduler.enabled=false\n".toArray())
        let humanChild = s6LaunchMain(humanRoot,
            ["--config", humanConfig, "--store", "${humanRoot}/store",
                "scheduler-run", "--task", "weekly_full_rebuild", "--force"])
        let human = humanChild.stdoutText.trimAscii()
        @Expect(humanChild.exitCode, 0)
        @Expect(human.startsWith("scheduler ran=1 succeeded=1"), true)
        @Expect(human.contains("\"ok\""), false)
        @Expect(human.contains("\"tasks\""), false)
        @Expect(humanChild.stderrText, "")
        @Expect(s6PidExited(humanChild.pid), true)

        let failRoot = "target/p5-s6-n01-fetch-failure-child"
        ckbReleaseTestEnsureEmptyDir(failRoot)
        let child = s6LaunchWorkerChild(failRoot, 1, true, "p5-s6-n01")
        let store = FileKnowledgeStore("${failRoot}/store")
        @Expect(child.exitCode, 0)
        @Expect(child.task.ok, false)
        @Expect(child.task.status == "candidate_validated_promoted", false)
        @Expect(store.has("metadata/scheduler-workers/p5-s6-n01.ckb"), true)
        @Expect(store.has("metadata/scheduler-workers/p5-s6-n01.ckb.sidecar"), true)
        @Expect(child.stdoutText.contains("fixture-secret"), false)
        @Expect(child.stderrText.contains("fixture-secret"), false)
        @Expect(s6PidExited(child.pid), true)
        @Expect(s6TreeContainsName(Path(failRoot), ".tmp-"), false)

        let exceptionRoot = "target/p5-s6-n01-exception-child"
        ckbReleaseTestEnsureEmptyDir(exceptionRoot)
        let exceptionChild = s6LaunchWorkerChild(exceptionRoot, 1, false,
            "p5-s6-n01-exception", throwException: true)
        let exceptionStore = FileKnowledgeStore("${exceptionRoot}/store")
        let exceptionTask = ckbSchedulerTaskResultFromText(
            exceptionStore.readText(
                "metadata/scheduler-workers/p5-s6-n01-exception.ckb.sidecar"))
        let exceptionProgress = exceptionStore.readText(
            "metadata/scheduler-runs/p5-s6-n01-exception-run.jsonl")
        let exceptionFetchStarted = JsonValue.fromStr(
            s6JsonlEventSourceLine(exceptionProgress,
                "routine.fetch.started", CangjieSourceSets.DOCS)).asObject()
        let exceptionFetchFinished = JsonValue.fromStr(
            s6JsonlEventSourceLine(exceptionProgress,
                "routine.fetch.finished", CangjieSourceSets.DOCS)).asObject()
        @Expect(exceptionChild.exitCode == 0, false)
        @Expect(exceptionTask.ok, false)
        @Expect(exceptionTask.status, "task_exception")
        @Expect(exceptionTask.resultWrittenAtMillis > 0, true)
        @Expect(exceptionTask.validationDiagnostics.size > 0, true)
        @Expect(ckbSchedulerTaskResultText(exceptionTask).contains(
            "fixture-secret"), false)
        @Expect(s6JsonString(exceptionFetchFinished, "status"),
            "fetch_exception")
        @Expect(s6JsonString(exceptionFetchFinished, "level"), "error")
        @Expect(s6JsonString(exceptionFetchFinished, "errorCode") != "", true)
        @Expect(s6JsonString(exceptionFetchFinished, "bodyHash").size, 64)
        @Expect(s6JsonInt(exceptionFetchFinished, "atMillis") >=
            s6JsonInt(exceptionFetchStarted, "atMillis"), true)
        @Expect(s6PidExited(exceptionChild.pid), true)
        @Expect(s6TreeContainsName(Path(exceptionRoot), ".tmp-"), false)

        let flushRoot = "target/p5-s6-n01-flush-boundary"
        ckbReleaseTestEnsureEmptyDir(flushRoot)
        let flushConfig = "${flushRoot}/ckb.conf"
        File.writeTo(Path(flushConfig), "network.enabled=false\n".toArray())
        let flushResult = "metadata/scheduler-workers/flush-boundary.ckb"
        let flushChild = s6LaunchMain(flushRoot, ["--config", flushConfig,
            "--store", "${flushRoot}/store", "scheduler-task-worker", "--task",
            "cangjie_release_full_sync", "--scheduler-run-id",
            "p5-s6-n01-flush", "--since", "0", "--deadline", "1",
            "--result-rel", flushResult])
        let flushStore = FileKnowledgeStore("${flushRoot}/store")
        let flushed = ckbSchedulerTaskResultFromText(
            flushStore.readText("${flushResult}.sidecar"))
        @Expect(flushChild.exitCode, 1)
        @Expect(flushed.ok, false)
        @Expect(flushed.status, "bootstrap_deadline_exceeded")
        @Expect(flushed.resultWrittenAtMillis > 0, true)
        @Expect(flushed.resultFlushDurationMillis >= 0, true)
        @Expect(flushChild.stdoutText, "")
        @Expect(flushChild.stderrText, "")
        @Expect(s6PidExited(flushChild.pid), true)
        @Expect(s6TreeContainsName(Path(flushRoot), ".tmp-"), false)

        let noOpPointerBefore = fixture.store.loadActiveSnapshotPointer()
        _ = fixture.kb.deleteVectorCollection(
            noOpPointerBefore.vectorActiveCollection)
        let noOpVectorFailure = CkbSchedulerTaskRunner(fixture.kb,
            fixture.config, fixture.store,
            sourceRunner: CkbReleaseFullRunner(1)).runTask(
                "cangjie_release_full_sync", "0",
                ckbCoreNowMillis() + 435000)
        let noOpPointerAfter = fixture.store.loadActiveSnapshotPointer()
        @Expect(noOpVectorFailure.ok, false)
        @Expect(noOpVectorFailure.status,
            "release_idempotent_noop_verification_failed")
        @Expect(noOpVectorFailure.validationGates.size, 0)
        @Expect(noOpPointerAfter.valid, true)
        @Expect(noOpPointerAfter.txId, noOpPointerBefore.txId)
        @Expect(noOpPointerAfter.activeVersion,
            noOpPointerBefore.activeVersion)
        @Expect(noOpPointerAfter.vectorActiveCollection,
            noOpPointerBefore.vectorActiveCollection)
        @Expect(s6Joined(noOpVectorFailure.validationDiagnostics).contains(
            "release_idempotent_noop_verification_failed:reason=active_vector_not_ready_or_misaligned"),
            true)
        @Expect(s6OrphanCandidateCollectionCount(fixture.store,
            noOpPointerAfter.vectorActiveCollection), 0)
    }

    // P5-E2E01
    @TestCase
    public func p5E2E01ProcessWorkerParseFinalizeAndExplicitJsonPass(): Unit {
        let root = "target/p5-e2e01-process-json"
        ckbReleaseTestEnsureEmptyDir(root)
        let fixture = s6PrepareLocalMainFixture(root)
        var child = S6ChildResult()
        try {
            child = s6LaunchMain(root, ["--config", fixture.configPath,
                "--store", fixture.storePath, "scheduler-run", "--task",
                "cangjie_release_full_sync", "--force", "--json"])
        } finally {
            s6StopLocalServer(fixture.server)
        }
        let json = child.stdoutText.trimAscii()
        let store = FileKnowledgeStore(fixture.storePath)
        let jsonObject = JsonValue.fromStr(json).asObject()
        let workerArtifacts = s6ConfirmedWorkerArtifacts(store)
        let pointer = store.loadActiveSnapshotPointer()
        let transactionRoot = "transactions/${pointer.txId}"
        let coverage = store.routineReleaseCoverageSummary(
            "${transactionRoot}/metadata/cangjie-release-coverage.ckb")
        let progressPath = s6JsonString(jsonObject, "progressPath")
        let progress = store.readText(progressPath)
        let diagnosticsPath = progressPath.replace(".jsonl",
            "-diagnostics.jsonl")
        let diagnostics = store.readText(diagnosticsPath)
        let vectorProgress = s6ReadAllJsonl(
            Path(fixture.storePath).join("metadata/vector-reconcile-runs"))
        let orphanCollections = s6OrphanCandidateCollectionCount(store,
            pointer.vectorActiveCollection)
        let orphanProcesses = if (s6NoWorkerForStore(fixture.storePath)) { 0 } else { 1 }
        let activeManifestFreshnessAligned =
            s6ActiveManifestFreshnessAligned(store, pointer,
                workerArtifacts.sidecar)

        @Expect(child.exitCode, 0)
        @Expect(s6JsonBool(jsonObject, "ok"), true)
        @Expect(s6JsonBool(jsonObject, "businessOk"), true)
        @Expect(s6JsonBool(jsonObject, "finalizationOk"), true)
        @Expect(s6JsonInt(jsonObject, "ran"), 1)
        @Expect(s6JsonInt(jsonObject, "succeeded"), 1)
        @Expect(s6JsonInt(jsonObject, "failed"), 0)
        @Expect(s6JsonInt(jsonObject, "degraded"), 0)
        @Expect(json.startsWith("{"), true)
        @Expect(json.endsWith("}"), true)
        @Expect(json.contains("\"ok\":true"), true)
        @Expect(json.contains("\"businessOk\":true"), true)
        @Expect(json.contains("\"finalizationOk\":true"), true)
        @Expect(json.contains("\"failedTasks\":[]"), true)
        @Expect(json.contains("candidate_validated_promoted"), true)
        @Expect(json.contains("active_companion_transaction_verified"), true)
        @Expect(json.contains("\"ran\":1"), true)
        @Expect(json.contains("\"succeeded\":1"), true)
        @Expect(json.contains("\"failed\":0"), true)
        @Expect(json.contains("\"degraded\":0"), true)
        @Expect(json.contains("\"lockReleased\":true"), true)
        @Expect(child.stderrText, "")
        @Expect(workerArtifacts.valid, true)
        @Expect(workerArtifacts.primary.ok, true)
        @Expect(workerArtifacts.sidecar.ok, true)
        @Expect(workerArtifacts.primary.status,
            "candidate_validated_promoted")
        @Expect(workerArtifacts.sidecar.status,
            "candidate_validated_promoted")
        @Expect(workerArtifacts.primary.transactionId,
            workerArtifacts.sidecar.transactionId)
        @Expect(workerArtifacts.primary.manifestEvidenceHash,
            workerArtifacts.sidecar.manifestEvidenceHash)
        @Expect(workerArtifacts.primary.freshnessEvidenceHash,
            workerArtifacts.sidecar.freshnessEvidenceHash)
        @Expect(workerArtifacts.primary.sourceCoverageEvidenceHash,
            workerArtifacts.sidecar.sourceCoverageEvidenceHash)
        @Expect(workerArtifacts.primary.inventoryEvidenceHash,
            workerArtifacts.sidecar.inventoryEvidenceHash)
        @Expect(workerArtifacts.sidecar.validationGates.size, 5)
        @Expect(workerArtifacts.sidecar.resultWrittenAtMillis > 0, true)
        @Expect(workerArtifacts.outArtifactPresent, true)
        @Expect(workerArtifacts.errArtifactPresent, true)
        @Expect(workerArtifacts.outText, "")
        @Expect(workerArtifacts.errText, "")
        @Expect(pointer.valid, true)
        @Expect(pointer.companionMode,
            CkbActiveSnapshotCompanionMode.RELEASE)
        @Expect(pointer.txId, workerArtifacts.sidecar.transactionId)
        @Expect(pointer.manifestHash,
            workerArtifacts.sidecar.manifestEvidenceHash)
        @Expect(pointer.freshnessHash,
            workerArtifacts.sidecar.freshnessEvidenceHash)
        @Expect(store.has("${transactionRoot}/COMMIT"), true)
        @Expect(store.has(
            "${transactionRoot}/metadata/cangjie-version-manifest.ckb"), true)
        @Expect(store.has(
            "${transactionRoot}/metadata/cangjie-freshness.ckb"), true)
        @Expect(store.has(
            "${transactionRoot}/metadata/cangjie-release-coverage.ckb"), true)
        @Expect(coverage.valid, true)
        @Expect(coverage.sourceCoverageEvidenceHash,
            workerArtifacts.sidecar.sourceCoverageEvidenceHash)
        @Expect(coverage.inventoryEvidenceHash,
            workerArtifacts.sidecar.inventoryEvidenceHash)
        s6AssertStructuredJsonlBaseFields(progress)
        s6AssertStructuredJsonlBaseFields(diagnostics)
        s6AssertStructuredJsonlBaseFields(vectorProgress)
        s6AssertReleaseTypedLogSchema(progress, vectorProgress, pointer,
            s6JsonString(jsonObject, "runId"))
        s6AssertReleaseEventSequence(progress)
        @Expect(progress.contains("fixture-secret"), false)
        @Expect(progress.contains("Authorization"), false)
        @Expect(progress.contains("Bearer"), false)
        @Expect(progress.contains("/Users/"), false)
        @Expect(diagnostics.contains("fixture-secret"), false)
        @Expect(diagnostics.contains("Authorization"), false)
        @Expect(diagnostics.contains("Bearer"), false)
        @Expect(diagnostics.contains("/Users/"), false)
        @Expect(vectorProgress.contains("fixture-secret"), false)
        @Expect(vectorProgress.contains("Authorization"), false)
        @Expect(vectorProgress.contains("Bearer"), false)
        @Expect(vectorProgress.contains("/Users/"), false)
        @Expect(child.stdoutText.contains("fixture-secret"), false)
        @Expect(child.stdoutText.contains("Authorization"), false)
        @Expect(child.stdoutText.contains("Bearer"), false)
        @Expect(child.stdoutText.contains("/Users/"), false)
        @Expect(progress.contains("\"event\":\"scheduler.run.started\""), true)
        @Expect(progress.contains("\"event\":\"scheduler.task.started\""), true)
        @Expect(progress.contains("\"event\":\"scheduler.task.stage\""), true)
        @Expect(progress.contains("\"event\":\"scheduler.task.finished\""), true)
        @Expect(progress.contains("\"event\":\"scheduler.run.finished\""), true)
        @Expect(progress.contains("\"stage\":\"fetch\""), true)
        @Expect(progress.contains("\"stage\":\"ingest_started\""), true)
        @Expect(progress.contains("\"stage\":\"ingest_finished\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_materialization_started\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_materialization_finished\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_vector_started\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_vector_finished\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_validation_started\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_validation_finished\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_active_commit_started\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_active_commit_finished\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_active_snapshot_started\""), true)
        @Expect(progress.contains(
            "\"stage\":\"active_snapshot_tx_commit_after\""), true)
        @Expect(progress.contains(
            "\"stage\":\"active_snapshot_manifest_after\""), true)
        @Expect(progress.contains(
            "\"stage\":\"candidate_active_snapshot_finished\""), true)
        @Expect(diagnostics.contains("snapshot_transaction_committed:txId="), true)
        @Expect(diagnostics.contains(ckbReleaseEvidenceHash(pointer.txId)), true)
        @Expect(workerArtifacts.sidecar.bootstrapStartedAtMillis > 0, true)
        @Expect(workerArtifacts.sidecar.taskBodyStartedAtMillis >=
            workerArtifacts.sidecar.bootstrapStartedAtMillis, true)
        @Expect(workerArtifacts.sidecar.resultWrittenAtMillis >=
            workerArtifacts.sidecar.taskBodyEndedAtMillis, true)
        @Expect(vectorProgress.contains("\"event\":\"vector.build.started\""), true)
        @Expect(vectorProgress.contains("\"event\":\"vector.build.finished\""), true)
        @Expect(s6PidExited(child.pid), true)
        @Expect(s6PidExited(fixture.server.pid), true)
        @Expect(orphanProcesses, 0)
        @Expect(orphanCollections, 0)
        @Expect(activeManifestFreshnessAligned, true)
        @Expect(s6TreeContainsName(Path(root), ".launch"), false)
        @Expect(s6TreeContainsName(Path(root), ".tmp-"), false)

        let summary = "testId=P5-E2E01 exit=${child.exitCode} ran=1 " +
            "succeeded=1 failed=0 degraded=0\n" +
            "task=cangjie_release_full_sync status=${workerArtifacts.sidecar.status} " +
            "gates=${workerArtifacts.sidecar.validationGates.size}/5\n" +
            "sourceCoverage=docs,std,stdx,tools,eval-support\n" +
            "activeManifestFreshnessAligned=${activeManifestFreshnessAligned} " +
            "orphanProcesses=${orphanProcesses} " +
            "orphanCollections=${orphanCollections}\n"
        store.writeLinesAtomically("metadata/p5-e2e01-summary.txt", summary)
        let persistedSummary = store.readText("metadata/p5-e2e01-summary.txt")
        @Expect(persistedSummary.contains(
            "testId=P5-E2E01 exit=0 ran=1 succeeded=1 failed=0 degraded=0"), true)
        @Expect(persistedSummary.contains(
            "task=cangjie_release_full_sync status=candidate_validated_promoted gates=5/5"),
            true)
        @Expect(persistedSummary.contains(
            "sourceCoverage=docs,std,stdx,tools,eval-support"), true)
        @Expect(persistedSummary.contains(
            "activeManifestFreshnessAligned=true orphanProcesses=0 orphanCollections=0"),
            true)
        @Expect(persistedSummary.contains("fixture-secret"), false)
        @Expect(persistedSummary.contains("/Users/"), false)
    }

    // P5-E2E02
    @TestCase
    public func p5E2E02FailedChildKeepsOldActiveThenNextProcessCompletes(): Unit {
        let root = "target/p5-e2e02-durable-recovery"
        ckbReleaseTestEnsureEmptyDir(root)
        // The S4 durable cursor/process matrices and S5 transaction matrix are
        // independent test cases. Re-running them here retains their large
        // decoded vector batches while this child-process E2E starts, which
        // exceeds the serial 64MB test heap without adding an E2E assertion.

        let releaseRoot = "${root}/release"
        let baseline = s6LaunchWorkerChild(releaseRoot, 1, false,
            "p5-e2e02-base")
        let store = FileKnowledgeStore("${releaseRoot}/store")
        let beforePointer = store.loadActiveSnapshotPointer()
        let oldQueryBefore = QueryService(newKnowledgeBaseFromStore(store).kb)
            .query("", "old-a-token", 10)
        let failed = s6LaunchWorkerChild(releaseRoot, 2, true,
            "p5-e2e02-failed")
        let afterFailurePointer = store.loadActiveSnapshotPointer()
        let oldQueryAfterFailure = QueryService(newKnowledgeBaseFromStore(store).kb)
            .query("", "old-a-token", 10)
        let resumed = s6LaunchWorkerChild(releaseRoot, 2, false,
            "p5-e2e02-resumed")
        let afterResumePointer = store.loadActiveSnapshotPointer()
        let emptyRemoved = ArrayList<String>()
        let emptyInventoryEvidence = ckbReleaseEvidenceHash(
            "raw=${ckbReleaseRemovedIdsEvidenceHash(emptyRemoved)}|" +
            "normalized=${ckbReleaseRemovedIdsEvidenceHash(emptyRemoved)}")
        let resumedNoop = s6LaunchWorkerChild(releaseRoot, 2, false,
            "p5-e2e02-resumed-noop")
        let afterNoopPointer = store.loadActiveSnapshotPointer()
        let cleanRoot = "${root}/no-crash-baseline"
        let cleanBaseline = s6LaunchWorkerChild(cleanRoot, 1, false,
            "p5-e2e02-clean-base")
        let clean = s6LaunchWorkerChild(cleanRoot, 2, false,
            "p5-e2e02-clean")
        let cleanStore = FileKnowledgeStore("${cleanRoot}/store")
        let cleanPointer = cleanStore.loadActiveSnapshotPointer()
        let resumedSnapshot = store.loadActiveSnapshot()
        let cleanSnapshot = cleanStore.loadActiveSnapshot()

        @Expect(baseline.task.ok, true)
        s6AssertSuccessfulWorkerChildHarness(baseline)
        @Expect(oldQueryBefore.records.size > 0, true)
        @Expect(failed.task.ok, false)
        s6AssertSuccessfulWorkerChildHarness(failed)
        @Expect(afterFailurePointer.valid, true)
        @Expect(afterFailurePointer.txId, beforePointer.txId)
        @Expect(oldQueryAfterFailure.records.size > 0, true)
        @Expect(resumed.task.ok, true)
        s6AssertSuccessfulWorkerChildHarness(resumed)
        @Expect(afterResumePointer.valid, true)
        @Expect(afterResumePointer.txId == beforePointer.txId, false)
        @Expect(resumed.task.validationGates.size, 5)
        @Expect(resumed.task.inventoryEvidenceHash == emptyInventoryEvidence,
            false)
        @Expect(resumedNoop.task.ok, true)
        s6AssertSuccessfulWorkerChildHarness(resumedNoop)
        @Expect(resumedNoop.task.validationGates.size, 5)
        @Expect(resumedNoop.task.transactionId, resumed.task.transactionId)
        @Expect(afterNoopPointer.txId, afterResumePointer.txId)
        @Expect(afterNoopPointer.activeVersion,
            afterResumePointer.activeVersion)
        @Expect(afterNoopPointer.vectorActiveCollection,
            afterResumePointer.vectorActiveCollection)
        @Expect(resumedNoop.task.candidateVersion,
            resumed.task.candidateVersion)
        @Expect(resumedNoop.task.activeVersion, resumed.task.activeVersion)
        @Expect(resumedNoop.task.sourceCoverageEvidenceHash,
            resumed.task.sourceCoverageEvidenceHash)
        @Expect(resumedNoop.task.inventoryEvidenceHash,
            resumed.task.inventoryEvidenceHash)
        @Expect(s6Joined(resumedNoop.task.validationDiagnostics).contains(
            "release_idempotent_noop_verified"), true)
        @Expect(cleanBaseline.task.ok, true)
        s6AssertSuccessfulWorkerChildHarness(cleanBaseline)
        @Expect(clean.task.ok, true)
        s6AssertSuccessfulWorkerChildHarness(clean)
        @Expect(resumed.task.status, clean.task.status)
        @Expect(resumed.task.activeVersion, clean.task.activeVersion)
        @Expect(resumed.task.validationStatus, clean.task.validationStatus)
        @Expect(s6Joined(resumed.task.validationGates),
            s6Joined(clean.task.validationGates))
        @Expect(resumed.task.manifestEvidenceHash,
            clean.task.manifestEvidenceHash)
        @Expect(resumed.task.freshnessEvidenceHash,
            clean.task.freshnessEvidenceHash)
        @Expect(resumed.task.sourceCoverageEvidenceHash,
            clean.task.sourceCoverageEvidenceHash)
        @Expect(resumed.task.inventoryEvidenceHash,
            clean.task.inventoryEvidenceHash)
        @Expect(afterResumePointer.activeVersion, cleanPointer.activeVersion)
        @Expect(afterResumePointer.manifestHash, cleanPointer.manifestHash)
        @Expect(afterResumePointer.freshnessHash, cleanPointer.freshnessHash)
        @Expect(afterResumePointer.coverageHash, cleanPointer.coverageHash)
        @Expect(s6TextField(store.readText(
            "transactions/${afterResumePointer.txId}/COMMIT"), "payloadHash"),
            s6TextField(cleanStore.readText(
            "transactions/${cleanPointer.txId}/COMMIT"), "payloadHash"))
        @Expect(resumedSnapshot.rawRecords.size, cleanSnapshot.rawRecords.size)
        @Expect(resumedSnapshot.normalizedRecords.size,
            cleanSnapshot.normalizedRecords.size)
        @Expect(resumedSnapshot.activeIndex.size, cleanSnapshot.activeIndex.size)
        @Expect(resumedSnapshot.vectorRecords.size,
            cleanSnapshot.vectorRecords.size)
        @Expect(s6PidExited(baseline.pid), true)
        @Expect(s6PidExited(failed.pid), true)
        @Expect(s6PidExited(resumed.pid), true)
        @Expect(s6PidExited(resumedNoop.pid), true)
        @Expect(s6PidExited(cleanBaseline.pid), true)
        @Expect(s6PidExited(clean.pid), true)
        @Expect(s6TreeContainsName(Path(root), ".launch"), false)
        @Expect(s6TreeContainsName(Path(root), ".tmp-"), false)
        let reloaded = newKnowledgeBaseFromStore(store)
        @Expect(QueryService(reloaded.kb).query("", "new-a-token", 10).records.size > 0, true)
        @Expect(QueryService(reloaded.kb).query("", "old-a-token", 10).records.size, 0)
        @Expect(s6NoWorkerForStore("${releaseRoot}/store"), true)
        @Expect(s6NoWorkerForStore("${cleanRoot}/store"), true)
        @Expect(s6OrphanCandidateCollectionCount(store,
            afterResumePointer.vectorActiveCollection), 0)
        @Expect(s6OrphanCandidateCollectionCount(cleanStore,
            cleanPointer.vectorActiveCollection), 0)
        s6AssertCandidateOwnerLifecycle(store,
            afterResumePointer.vectorActiveCollection)
        s6AssertCandidateOwnerLifecycle(cleanStore,
            cleanPointer.vectorActiveCollection)
    }

    // P5-E2E03
    @TestCase
    public func p5E2E03TwoReleaseRunsAndFiveRepresentativeTasksStayGreen(): Unit {
        let root = "target/p5-e2e03-regression"
        ckbReleaseTestEnsureEmptyDir(root)
        let config = s6Config("${root}/eval")
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(ckbReleaseTestManifest())
        let embeddingProvider = S6CountingEmbeddingProvider()
        let kb = KnowledgeBase(FakeClock(0), embeddingProvider,
            LocalVectorStore(), LocalGraphStore())
        kb.bootstrapOffline()
        let firstTask = CkbSchedulerTaskRunner(kb, config, store,
            sourceRunner: CkbReleaseFullRunner(2)).runTask(
                "cangjie_release_full_sync", "0",
                ckbCoreNowMillis() + 435000)
        let firstSnapshot = store.loadActiveSnapshot()
        let firstPointer = store.loadActiveSnapshotPointer()
        let firstSourceEvidence = firstTask.sourceCoverageEvidenceHash
        let firstInventoryEvidence = firstTask.inventoryEvidenceHash
        let secondSourceRunner = CkbReleaseFullRunner(2)
        let embeddedBeforeSecond = embeddingProvider.embeddedItems
        let secondTask = CkbSchedulerTaskRunner(kb, config, store,
            sourceRunner: secondSourceRunner).runTask(
                "cangjie_release_full_sync", "0",
                ckbCoreNowMillis() + 435000)
        let embeddedDuringSecond = embeddingProvider.embeddedItems -
            embeddedBeforeSecond
        let secondSnapshot = store.loadActiveSnapshot()
        let secondPointer = store.loadActiveSnapshotPointer()
        let names = ArrayList<String>()
        names.add("weekly_full_rebuild")
        names.add("cangjie_freshness_daily")
        names.add("cangjie_version_branch_refresh")
        names.add("cangjie_docs_full_weekly")
        names.add("cangjie_release_full_sync")
        let sourceRunner = S6RepresentativeSourceRunner(2)
        let recordingRunner = S6RecordingTaskRunner(
            CkbSchedulerTaskRunner(kb, config, store,
                sourceRunner: sourceRunner), sourceRunner, embeddingProvider,
            store)
        let run = SchedulerExecutor(kb.scheduler,
            recordingRunner,
            FileSchedulerProgressSink(store), 440000).runTaskNames(
                names, force: true)
        let thirdSnapshot = store.loadActiveSnapshot()
        let machineJson = ckbSchedulerRunOutputJson(run)
        let pointer = store.loadActiveSnapshotPointer()
        let coverage = store.routineReleaseCoverageSummary(
            "transactions/${pointer.txId}/metadata/cangjie-release-coverage.ckb")

        @Expect(firstTask.ok, true)
        @Expect(firstTask.validationGates.size, 5)
        @Expect(secondTask.ok, true)
        @Expect(secondTask.status, "candidate_validated_promoted")
        @Expect(secondTask.validationGates.size, 5)
        @Expect(secondTask.sourceCoverageEvidenceHash, firstSourceEvidence)
        @Expect(secondTask.inventoryEvidenceHash, firstInventoryEvidence)
        @Expect(secondSourceRunner.networkCalls, 4)
        @Expect(embeddedDuringSecond, 0)
        @Expect(secondTask.transactionId, firstTask.transactionId)
        @Expect(secondTask.candidateVersion, firstTask.candidateVersion)
        @Expect(secondTask.activeVersion, firstTask.activeVersion)
        @Expect(firstPointer.txId, firstTask.transactionId)
        @Expect(secondPointer.txId, firstPointer.txId)
        @Expect(secondPointer.activeVersion, firstPointer.activeVersion)
        @Expect(secondPointer.vectorActiveCollection,
            firstPointer.vectorActiveCollection)
        @Expect(s6Joined(secondTask.validationDiagnostics).contains(
            "release_idempotent_noop_verified"), true)
        @Expect(firstSnapshot.rawRecords.size, secondSnapshot.rawRecords.size)
        @Expect(firstSnapshot.normalizedRecords.size,
            secondSnapshot.normalizedRecords.size)
        @Expect(firstSnapshot.activeIndex.size, secondSnapshot.activeIndex.size)
        @Expect(firstSnapshot.vectorRecords.size, secondSnapshot.vectorRecords.size)
        @Expect(run.taskNames.size, 5)
        @Expect(run.taskNames.contains("cangjie_release_full_sync"), true)
        @Expect(run.ran, 5)
        @Expect(run.failed, 0)
        @Expect(run.degraded, 0)
        @Expect(run.businessOk, true)
        @Expect(run.finalizationOk, true)
        @Expect(run.taskRecords.size, 5)
        for (record in run.taskRecords) { @Expect(record.ok, true) }
        @Expect(run.taskRecords[0].status, "rebuild_ok")
        @Expect(run.taskRecords[1].status,
            "freshness_probe_completed_with_stale_sources")
        @Expect(run.taskRecords[2].status,
            "version_manifest_refreshed")
        @Expect(run.taskRecords[3].status, "candidate_validated_promoted")
        @Expect(run.taskRecords[4].status, "candidate_validated_promoted")
        @Expect(run.taskRecords[4].validationGates.size, 5)
        @Expect(run.taskRecords[4].sourceCoverageEvidenceHash,
            firstSourceEvidence)
        @Expect(run.taskRecords[4].inventoryEvidenceHash,
            firstInventoryEvidence)
        @Expect(recordingRunner.releaseNetworkCallsDuringP5, 4)
        @Expect(recordingRunner.embeddedItemsDuringP5, 0)
        @Expect(recordingRunner.releaseCompanionModeBeforeP5,
            CkbActiveSnapshotCompanionMode.COPY_FORWARD)
        @Expect(run.taskRecords[4].transactionId,
            recordingRunner.releaseTxBeforeP5)
        @Expect(recordingRunner.lastReleaseTask.candidateVersion,
            recordingRunner.releaseCandidateBeforeP5)
        @Expect(recordingRunner.lastReleaseTask.activeVersion,
            recordingRunner.releaseActiveBeforeP5)
        @Expect(pointer.valid, true)
        @Expect(pointer.companionMode,
            CkbActiveSnapshotCompanionMode.COPY_FORWARD)
        @Expect(pointer.txId, recordingRunner.releaseTxBeforeP5)
        @Expect(pointer.txId, run.taskRecords[4].transactionId)
        @Expect(pointer.manifestHash,
            run.taskRecords[4].manifestEvidenceHash)
        @Expect(pointer.freshnessHash,
            run.taskRecords[4].freshnessEvidenceHash)
        @Expect(coverage.valid, true)
        @Expect(coverage.sourceCoverageEvidenceHash,
            run.taskRecords[4].sourceCoverageEvidenceHash)
        @Expect(coverage.inventoryEvidenceHash,
            run.taskRecords[4].inventoryEvidenceHash)
        @Expect(store.loadActiveCangjieVersionManifest().sources.size, 5)
        @Expect(store.loadActiveCangjieCorpusFreshness().sources.size, 5)
        @Expect(thirdSnapshot.valid, true)
        @Expect(thirdSnapshot.normalizedRecords.size,
            thirdSnapshot.activeIndex.size)
        @Expect(thirdSnapshot.vectorRecords.size, thirdSnapshot.activeIndex.size)
        @Expect(QueryService(newKnowledgeBaseFromStore(store).kb)
            .query("", "old-a-token", 10).records.size, 0)
        @Expect(QueryService(newKnowledgeBaseFromStore(store).kb)
            .query("", "new-a-token", 10).records.size > 0, true)
        @Expect(QueryService(newKnowledgeBaseFromStore(store).kb)
            .query("", "removed-b-token", 10).records.size, 0)
        @Expect(QueryService(newKnowledgeBaseFromStore(store).kb)
            .query("", "new-c-token", 10).records.size > 0, true)
        for (name in names) {
            @Expect(machineJson.contains("\"taskName\":\"${name}\""), true)
        }
        @Expect(machineJson.contains("\"failedTasks\":[]"), true)
        @Expect(machineJson.contains("\"businessOk\":true"), true)
        @Expect(machineJson.contains("\"finalizationOk\":true"), true)
        @Expect(run.details.contains("task weekly_full_rebuild"), true)
        @Expect(run.details.contains(
            "task cangjie_freshness_daily ok=true status=freshness_probe_completed_with_stale_sources"),
            true)
        @Expect(run.details.contains(
            "task cangjie_version_branch_refresh ok=true status=version_manifest_refreshed"),
            true)
        @Expect(run.details.contains(
            "task cangjie_docs_full_weekly ok=true status=candidate_validated_promoted"),
            true)
        @Expect(run.details.contains("\"ok\""), false)
        @Expect(run.details.contains("\"tasks\""), false)
        @Expect(s6ActiveManifestFreshnessAligned(store, pointer,
            recordingRunner.lastReleaseTask), true)
        @Expect(s6NoWorkerForStore("${root}/store"), true)
        @Expect(s6OrphanCandidateCollectionCount(store,
            pointer.vectorActiveCollection), 0)
        let vectorBuildRoot = Path("${root}/store/metadata/vector-builds")
        @Expect(s6TreeContainsName(vectorBuildRoot, "checkpoint.ckb"), false)
        @Expect(s6TreeContainsName(vectorBuildRoot, "manifest.ckb"), false)
        @Expect(s6TreeContainsName(vectorBuildRoot, "batches"), false)
        @Expect(s6TreeContainsName(Path(root), ".launch"), false)
        @Expect(s6TreeContainsName(Path(root), ".tmp-"), false)
    }

    @TestCase
    public func p5S6RealWorkerChildFixture(): Unit {
        if (getVariable("CKB_P5_S6_CHILD") != Some("1")) { return }
        let root = s6RequiredEnv("CKB_P5_S6_ROOT")
        let resultName = s6RequiredEnv("CKB_P5_S6_RESULT")
        let runId = s6RequiredEnv("CKB_P5_S6_RUN_ID")
        let generation = Int64.parse(s6RequiredEnv("CKB_P5_S6_GENERATION"))
        let shouldFail = getVariable("CKB_P5_S6_FAIL") == Some("1")
        let shouldThrow = getVariable("CKB_P5_S6_THROW") == Some("1")
        let store = FileKnowledgeStore("${root}/store")
        if (!store.has("metadata/cangjie-version-manifest.ckb")) {
            store.saveCangjieVersionManifest(ckbReleaseTestManifest())
        }
        let config = s6Config("${root}/eval")
        let restored = if (store.has("metadata/active-snapshot.manifest")) {
            newKnowledgeBaseFromStore(store).kb
        } else {
            newOfflineKnowledgeBase()
        }
        let schedulerProgress = FileSchedulerProgressSink(store)
        let schedulerRun = SchedulerExecutorResult()
        schedulerRun.runId = runId
        schedulerRun.startedAtMillis = ckbCoreNowMillis()
        schedulerProgress.onRunStarted(schedulerRun)
        schedulerProgress.onTaskStarted(runId,
            "cangjie_release_full_sync", 440000,
            ckbCoreNowMillis() + 440000)
        let sourceRunner: SourceFetchRunner = if (shouldThrow) {
            S6ThrowingReleaseRunner()
        } else if (shouldFail) {
            S6FailingReleaseRunner(generation)
        } else {
            CkbReleaseFullRunner(generation)
        }
        let task = ckbRunSchedulerTaskWorkerWithRunner(restored, config, store,
            sourceRunner, "cangjie_release_full_sync", "0",
            ckbCoreNowMillis() + 435000,
            "metadata/scheduler-workers/${resultName}.ckb",
            schedulerRunId: runId)
        schedulerProgress.onTaskFinished(runId,
            "cangjie_release_full_sync", task)
        schedulerRun.endedAtMillis = ckbCoreNowMillis()
        schedulerRun.ran = 1
        schedulerRun.succeeded = if (task.ok) { 1 } else { 0 }
        schedulerRun.failed = if (task.ok) { 0 } else { 1 }
        schedulerRun.businessOk = task.ok
        schedulerProgress.onRunFinished(schedulerRun)
        if (shouldFail || shouldThrow) {
            @Expect(task.ok, false)
            if (shouldThrow) {
                @Expect(task.status, "task_exception")
                let directDiagnostics = s6Joined(task.validationDiagnostics)
                @Expect(directDiagnostics.contains("fixture-secret"), false)
                @Expect(directDiagnostics.contains("Authorization"), false)
                @Expect(directDiagnostics.contains("/Users/private"), false)
                @Expect(directDiagnostics.contains("中文🙂"), true)
                // Keep the terminal sidecar, then make the launched child
                // process non-zero so the parent exercises failure cleanup.
                @Expect(false, true)
            }
        } else {
            @Expect(task.ok, true)
            @Expect(task.validationGates.size, 5)
        }
    }

    @TestCase
    public func p5S6LocalGitCodeServerFixture(): Unit {
        if (getVariable("CKB_P5_S6_SERVER") != Some("1")) { return }
        let root = s6RequiredEnv("CKB_P5_S6_SERVER_ROOT")
        let server = ServerBuilder().addr("127.0.0.1").port(0).build()
        let state = S6LocalGitCodeState()
        s6RegisterLocalGitCodeRepo(server, state, "Cangjie", "cangjie_docs",
            "docs/api.md", "# Stable API\nold-a-token ArrayList HashMap\n")
        s6RegisterLocalGitCodeRepo(server, state, "Cangjie", "cangjie_runtime",
            "src/runtime.cj", "package runtime_fixture\npublic func runtimeFixture(): Unit {}\n")
        s6RegisterLocalGitCodeRepo(server, state, "Cangjie", "cangjie_stdx",
            "src/stdx.cj", "package stdx_fixture\npublic func stdxFixture(): Unit {}\n")
        s6RegisterLocalGitCodeRepo(server, state, "Cangjie", "cangjie_tools",
            "tools/guide.md", "# cjpm test\ncjpm clean and cjpm build -i\n")
        spawn { server.serve() }
        for (_ in 0..400) {
            if (server.port > UInt16(0)) {
                File.writeTo(Path("${root}/server.port"),
                    "${server.port}\n".toArray())
                while (true) { sleep(Duration.second) }
            }
            sleep(Duration.millisecond * 10)
        }
        throw Exception("local server failed to bind")
    }
}

private func s6BusinessRawRecords(reverse: Bool): ArrayList<RawRecord> {
    let records = ArrayList<RawRecord>()
    if (reverse) {
        records.add(s6BusinessRawRecord(2))
        records.add(s6BusinessRawRecord(1))
    } else {
        records.add(s6BusinessRawRecord(1))
        records.add(s6BusinessRawRecord(2))
    }
    records
}

private func s6LegacyBusinessRawLine(): String {
    "legacy-id|legacy-title|legacy-content|legacy-hash|doc|" +
        "https://fixture.invalid/legacy|repo|commit|legacy.md|symbol|v1|" +
        "crawl|indexed|active|candidate|14|official|${ReviewStates.CANDIDATE}|" +
        "license|legacy-id|public|1.0.0|docs|resolution\n"
}

private func s6LegacyBusinessNormalizedLine(): String {
    "legacy-id|document_chunk|legacy-title|legacy-chunk|legacy-citation|0.0|doc|" +
        "https://fixture.invalid/legacy|repo|commit|legacy.md|symbol|v1|" +
        "crawl|indexed|active|candidate|12|official|${ReviewStates.CANDIDATE}|" +
        "license|legacy-id|public|1.0.0|docs|resolution\n"
}

private func s6BusinessNormalizedRecords(
    reverse: Bool): ArrayList<NormalizedRecord> {
    let records = ArrayList<NormalizedRecord>()
    if (reverse) {
        records.add(s6BusinessNormalizedRecord(2))
        records.add(s6BusinessNormalizedRecord(1))
    } else {
        records.add(s6BusinessNormalizedRecord(1))
        records.add(s6BusinessNormalizedRecord(2))
    }
    records
}

private func s6BusinessRawRecord(index: Int64): RawRecord {
    let record = RawRecord()
    record.sourceId = "business-${index}"
    record.title = "仓颉🙂 raw ${index}"
    record.content = "中文正文🙂-${index}\n完整业务内容"
    record.contentHash = ckbReleaseEvidenceHash(record.content)
    record.requiresReview = index == 2
    record.metadata = s6BusinessMetadata(index)
    record
}

private func s6BusinessNormalizedRecord(index: Int64): NormalizedRecord {
    let record = NormalizedRecord()
    record.sourceId = "business-${index}"
    record.recordKind = CangjieTypedRecordKinds.DOC_SECTION
    record.title = "仓颉🙂 normalized ${index}"
    record.chunk = "中文片段🙂-${index}\nArrayList.add"
    record.citation = "fixture://仓颉🙂/${index}"
    record.score = 0.25 + Float64(index)
    record.requiresReview = index == 2
    record.metadata = s6BusinessMetadata(index)
    record
}

private func s6BusinessMetadata(index: Int64): KnowledgeMetadata {
    let metadata = KnowledgeMetadata()
    metadata.sourceId = "business-${index}"
    metadata.sourceType = SourceTypes.DOC
    metadata.sourceUrl = "https://fixture.invalid/仓颉🙂/${index}"
    metadata.repo = "Cangjie/仓颉🙂-${index}"
    metadata.path = "docs/仓颉🙂-${index}.md"
    metadata.symbol = "仓颉.symbol.${index}"
    metadata.commit = "commit-${index}"
    metadata.docVersion = "v${index}"
    metadata.targetVersion = "1.0.${index}"
    metadata.sourceSet = CangjieSourceSets.DOCS
    metadata.versionResolutionId = "resolution-${index}"
    metadata.crawlAt = "scheduled:cangjie_release_full_sync"
    metadata.indexedAt = "scheduled:cangjie_release_full_sync"
    metadata.knowledgeVersion = "active-${index}"
    metadata.candidateVersion = "candidate-${index}"
    metadata.contentSize = 100 + index
    metadata.trustLevel = TrustLevels.OFFICIAL
    metadata.reviewState = ReviewStates.TRUSTED
    metadata.license = "license-${index}"
    metadata.repoVisibility = "public-${index}"
    metadata.derivedFrom = ["父来源🙂-${index}", "次来源-${index}"]
    metadata
}

private func s6BusinessEvidenceWithMutation(
    mutation: String): CkbCandidateBusinessEvidence {
    let raw = s6BusinessRawRecords(false)
    let normalized = s6BusinessNormalizedRecords(false)
    let rawRecord = raw[0]
    let record = normalized[0]
    let metadata = record.metadata
    if (mutation == "raw.sourceId") { rawRecord.sourceId = "raw-mutated" }
    else if (mutation == "raw.title") { rawRecord.title += "-变更🙂" }
    else if (mutation == "raw.content") { rawRecord.content += "-变更🙂" }
    else if (mutation == "raw.contentHash") { rawRecord.contentHash = "hash-mutated" }
    else if (mutation == "raw.requiresReview") {
        rawRecord.requiresReview = !rawRecord.requiresReview
    }
    else if (mutation == "raw.metadata.repo") {
        rawRecord.metadata.repo += "-变更🙂"
    }
    else if (mutation == "normalized.sourceId") { record.sourceId = "normalized-mutated" }
    else if (mutation == "normalized.recordKind") { record.recordKind = "kind-mutated" }
    else if (mutation == "normalized.title") { record.title += "-变更🙂" }
    else if (mutation == "normalized.chunk") { record.chunk += "-变更🙂" }
    else if (mutation == "normalized.citation") { record.citation += "-变更🙂" }
    else if (mutation == "normalized.score") { record.score += 1.0 }
    else if (mutation == "normalized.requiresReview") {
        record.requiresReview = !record.requiresReview
    }
    else if (mutation == "metadata.sourceId") { metadata.sourceId += "-变更" }
    else if (mutation == "metadata.sourceType") { metadata.sourceType += "-变更" }
    else if (mutation == "metadata.sourceUrl") { metadata.sourceUrl += "-变更🙂" }
    else if (mutation == "metadata.repo") { metadata.repo += "-变更🙂" }
    else if (mutation == "metadata.path") { metadata.path += "-变更🙂" }
    else if (mutation == "metadata.symbol") { metadata.symbol += "-变更🙂" }
    else if (mutation == "metadata.commit") { metadata.commit += "-变更" }
    else if (mutation == "metadata.docVersion") { metadata.docVersion += "-变更" }
    else if (mutation == "metadata.targetVersion") { metadata.targetVersion += "-变更" }
    else if (mutation == "metadata.sourceSet") { metadata.sourceSet += "-变更" }
    else if (mutation == "metadata.versionResolutionId") {
        metadata.versionResolutionId += "-变更"
    }
    else if (mutation == "metadata.crawlAt") { metadata.crawlAt += "-变更" }
    else if (mutation == "metadata.indexedAt") { metadata.indexedAt += "-变更" }
    else if (mutation == "metadata.contentSize") { metadata.contentSize += 1 }
    else if (mutation == "metadata.trustLevel") { metadata.trustLevel += "-变更" }
    else if (mutation == "metadata.reviewState") { metadata.reviewState += "-变更" }
    else if (mutation == "metadata.license") { metadata.license += "-变更" }
    else if (mutation == "metadata.repoVisibility") {
        metadata.repoVisibility += "-变更"
    }
    else if (mutation == "metadata.derivedFrom") {
        metadata.derivedFrom = [metadata.derivedFrom[1], metadata.derivedFrom[0]]
    }
    ckbCandidateBusinessEvidence(raw, normalized)
}

private class S6LocalGitCodeState {
    private let treeCalls = HashMap<String, Int64>()

    func treeBody(repo: String, path: String): String {
        let calls = match (this.treeCalls.get(repo)) {
            case Some(value) => value
            case None => 0
        }
        this.treeCalls[repo] = calls + 1
        if (calls == 0) {
            return "[{\"path\":\"${path}\",\"type\":\"blob\"}]"
        }
        "[]"
    }
}

private class S6LocalServerHandle {
    var pid: Int64 = 0
    var port: Int64 = 0
    var root: String = ""
    var waitForExit: () -> Int64 = { => 0 }

    init() {}
}

private class S6LocalMainFixture {
    var configPath: String = ""
    var storePath: String = ""
    var server: S6LocalServerHandle = S6LocalServerHandle()

    init() {}
}

private func s6RegisterLocalGitCodeRepo(server: Server,
    state: S6LocalGitCodeState, owner: String, repo: String, path: String,
    content: String): Unit {
    let prefix = "/api/v5/repos/${owner}/${repo}"
    let commit = "1111111111111111111111111111111111111111"
    server.distributor.register("${prefix}/branches", { ctx =>
        s6LocalHttpResponse(ctx,
            "[{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"${commit}\"}}]",
            "application/json")
    })
    server.distributor.register("${prefix}/branches/release-1.0.0", { ctx =>
        s6LocalHttpResponse(ctx,
            "{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"${commit}\"}}",
            "application/json")
    })
    server.distributor.register("${prefix}/git/trees/${commit}", { ctx =>
        s6LocalHttpResponse(ctx, state.treeBody("${owner}/${repo}", path),
            "application/json")
    })
    server.distributor.register("${prefix}/raw/${path}", { ctx =>
        s6LocalHttpResponse(ctx, content, if (path.endsWith(".cj")) {
            "text/plain"
        } else {
            "text/markdown"
        })
    })
}

private func s6LocalHttpResponse(ctx: HttpContext, body: String,
    contentType: String): Unit {
    ctx.responseBuilder.status(UInt16(200))
    ctx.responseBuilder.header("content-type", contentType)
    ctx.responseBuilder.body(body)
}

private func s6PrepareLocalMainFixture(root: String): S6LocalMainFixture {
    let fixture = S6LocalMainFixture()
    fixture.server = s6StartLocalServer(root)
    try {
        fixture.configPath = "${root}/ckb-local.conf"
        fixture.storePath = "${root}/store"
        let evalRoot = "${root}/eval"
        ckbReleaseTestWriteEvalFixture(evalRoot)
        let store = FileKnowledgeStore(fixture.storePath)
        store.saveCangjieVersionManifest(ckbReleaseTestManifest())
        var config = "network.enabled=true\n"
        config += "network.allowPrivateNetwork=true\n"
        config += "network.allowedHosts=127.0.0.1\n"
        config += "network.envProxyEnabled=false\n"
        config += "network.noProxy=127.0.0.1\n"
        config += "gitcode.baseUrl=http://127.0.0.1:${fixture.server.port}/api/v5\n"
        config += "embedding.provider=deterministic\n"
        config += "embedding.dimensions=16\n"
        config += "embedding.batchSize=8\n"
        config += "vector.backend=local-file\n"
        config += "vector.activeCollection=ckb_active\n"
        config += "vector.candidateCollection=ckb_candidate\n"
        config += "vector.dimensions=16\n"
        config += "firstInit.evalRoot=${evalRoot}\n"
        config += "firstInit.targetVersion=1.0.0\n"
        config += "benchmarkGap.targetVersion=1.0.0\n"
        File.writeTo(Path(fixture.configPath), config.toArray())
        return fixture
    } catch (e: Exception) {
        s6StopLocalServer(fixture.server)
        throw e
    }
}

private func s6StartLocalServer(root: String): S6LocalServerHandle {
    let handle = S6LocalServerHandle()
    handle.root = root
    var dyld = ""
    if (let Some(value) <- getVariable("DYLD_LIBRARY_PATH")) { dyld = value }
    let command = ckbSchedulerWorkerShellPreludeWithHeap(dyld, "") +
        "echo $$ > '${root}/server.pid'; " +
        "export CKB_P5_S6_SERVER='1'; " +
        "export CKB_P5_S6_SERVER_ROOT='${root}'; " +
        "exec target/release/unittest_bin/cangjie_community_knowledge_base_test " +
        "--filter='*CkbReleaseFullSyncS6E2ETest.p5S6LocalGitCodeServerFixture' " +
        "--no-color --no-progress > '${root}/server.stdout' 2> '${root}/server.stderr'"
    let process = launch("/bin/zsh", ["-c", command])
    handle.waitForExit = { => process.wait() }
    for (_ in 0..400) {
        if (exists(Path("${root}/server.pid"))) {
            handle.pid = s6ReadIntFile("${root}/server.pid")
        }
        if (exists(Path("${root}/server.port"))) {
            handle.port = s6ReadIntFile("${root}/server.port")
            if (handle.port > 0 && handle.pid > 0) { return handle }
        }
        sleep(Duration.millisecond * 10)
    }
    if (handle.pid > 0) { _ = launch("/bin/kill", ["-9", "${handle.pid}"]).wait() }
    _ = handle.waitForExit()
    for (_ in 0..100) {
        if (handle.pid == 0 || s6PidExited(handle.pid)) { break }
        sleep(Duration.millisecond * 10)
    }
    throw Exception("s6 local server did not become ready")
}

private func s6StopLocalServer(handle: S6LocalServerHandle): Unit {
    if (handle.pid > 0 && !s6PidExited(handle.pid)) {
        _ = launch("/bin/kill", ["-9", "${handle.pid}"]).wait()
    }
    _ = handle.waitForExit()
    for (_ in 0..100) {
        if (s6PidExited(handle.pid)) { return }
        sleep(Duration.millisecond * 10)
    }
}

private func s6LaunchMain(root: String, args: Array<String>): S6ChildResult {
    var dyld = ""
    if (let Some(value) <- getVariable("DYLD_LIBRARY_PATH")) { dyld = value }
    var command = ckbSchedulerWorkerShellPreludeWithHeap(dyld, "") +
        "unset CKB_SCHEDULER_TASK_WORKER; " +
        "echo $$ > '${root}/main.pid'; exec ../target/release/bin/main"
    for (arg in args) { command += " ${s6ShellQuote(arg)}" }
    let stdoutPath = "${root}/main.stdout"
    let stderrPath = "${root}/main.stderr"
    command += " > ${s6ShellQuote(stdoutPath)} 2> ${s6ShellQuote(stderrPath)}"
    let process = launch("/bin/zsh", ["-c", command],
        stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
    let result = S6ChildResult()
    result.exitCode = process.wait()
    result.stdoutText = s6ReadUtf8File(stdoutPath)
    result.stderrText = s6ReadUtf8File(stderrPath)
    result.pid = s6ReadIntFile("${root}/main.pid")
    result
}

private func s6ReadUtf8File(path: String): String {
    try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        "invalid_response_encoding"
    }
}

private func s6ShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}

private func s6ReadIntFile(path: String): Int64 {
    try {
        Int64.parse(String.fromUtf8(File.readFrom(Path(path))).trimAscii())
    } catch (_: Exception) { 0 }
}

private func s6HasConfirmedWorkerSidecar(store: FileKnowledgeStore): Bool {
    let root = store.root.join("metadata/scheduler-workers")
    if (!exists(root)) { return false }
    for (entry in Directory.readFrom(root)) {
        if (!entry.isRegular() || !entry.name.endsWith(".sidecar")) { continue }
        let task = try {
            ckbSchedulerTaskResultFromText(String.fromUtf8(File.readFrom(entry.path)))
        } catch (_: Exception) { SchedulerTaskResult() }
        if (task.ok && task.resultWrittenAtMillis > 0 &&
            task.validationGates.size == 5) { return true }
    }
    false
}

private class S6WorkerArtifacts {
    var valid: Bool = false
    var primary: SchedulerTaskResult = SchedulerTaskResult()
    var sidecar: SchedulerTaskResult = SchedulerTaskResult()
    var outArtifactPresent: Bool = false
    var errArtifactPresent: Bool = false
    var outText: String = ""
    var errText: String = ""

    init() {}
}

private func s6ConfirmedWorkerArtifacts(
    store: FileKnowledgeStore): S6WorkerArtifacts {
    let result = S6WorkerArtifacts()
    let root = store.root.join("metadata/scheduler-workers")
    if (!exists(root)) { return result }
    for (entry in Directory.readFrom(root)) {
        if (!entry.isRegular() || !entry.name.endsWith(".sidecar")) { continue }
        let primaryName = entry.name.replace(".sidecar", "")
        let primaryPath = root.join(primaryName)
        if (!exists(primaryPath)) { continue }
        try {
            result.primary = ckbSchedulerTaskResultFromText(
                String.fromUtf8(File.readFrom(primaryPath)))
            result.sidecar = ckbSchedulerTaskResultFromText(
                String.fromUtf8(File.readFrom(entry.path)))
            let relative = "metadata/scheduler-workers/${primaryName}"
            result.outArtifactPresent = store.has("${relative}.out")
            result.errArtifactPresent = store.has("${relative}.err")
            if (result.outArtifactPresent) {
                result.outText = store.readText("${relative}.out")
            }
            if (result.errArtifactPresent) {
                result.errText = store.readText("${relative}.err")
            }
            if (result.primary.status != "worker_started" &&
                result.sidecar.resultWrittenAtMillis > 0) {
                result.valid = true
                return result
            }
        } catch (_: Exception) { () }
    }
    result
}

private func s6ReadAllJsonl(root: Path): String {
    if (!exists(root)) { return "" }
    let out = StringBuilder()
    for (entry in Directory.readFrom(root)) {
        if (entry.isDirectory()) {
            out.append(s6ReadAllJsonl(entry.path))
        } else if (entry.isRegular() && entry.name.endsWith(".jsonl")) {
            try {
                out.append(String.fromUtf8(File.readFrom(entry.path)))
            } catch (_: Exception) {
                out.append("invalid_response_encoding\n")
            }
        }
    }
    out.toString()
}

private func s6OrphanCandidateCollectionCount(store: FileKnowledgeStore,
    activeCollection: String): Int64 {
    var count: Int64 = 0
    for (owner in store.listCandidateCollectionOwners()) {
        if (owner.state == "cleaned") {
            continue
        }
        if (owner.valid && owner.collection == activeCollection &&
            owner.state == "committed_active") {
            continue
        }
        count += 1
    }
    count
}

private func s6AssertCandidateOwnerLifecycle(store: FileKnowledgeStore,
    activeCollection: String): Unit {
    var activeCount: Int64 = 0
    var cleanedCount: Int64 = 0
    for (owner in store.listCandidateCollectionOwners()) {
        @Expect(owner.valid, true)
        if (owner.collection == activeCollection) {
            @Expect(owner.state, "committed_active")
            activeCount += 1
        } else {
            @Expect(owner.state, "cleaned")
            cleanedCount += 1
        }
    }
    @Expect(activeCount, 1)
    @Expect(cleanedCount > 0, true)
}

private func s6ActiveManifestFreshnessAligned(store: FileKnowledgeStore,
    pointer: CkbActiveSnapshotPointer,
    task: SchedulerTaskResult): Bool {
    s6ActiveManifestFreshnessAlignedFields(store, pointer,
        task.transactionId, task.activeVersion, task.candidateVersion,
        task.manifestEvidenceHash, task.freshnessEvidenceHash)
}

private func s6ActiveManifestFreshnessAlignedFields(
    store: FileKnowledgeStore, pointer: CkbActiveSnapshotPointer,
    transactionId: String, activeVersion: String,
    candidateVersion: String, manifestEvidenceHash: String,
    freshnessEvidenceHash: String): Bool {
    if (!pointer.valid ||
        (pointer.companionMode != CkbActiveSnapshotCompanionMode.RELEASE &&
            pointer.companionMode != CkbActiveSnapshotCompanionMode.COPY_FORWARD) ||
        pointer.txId != transactionId ||
        pointer.activeVersion != activeVersion ||
        pointer.manifestHash != manifestEvidenceHash ||
        pointer.freshnessHash != freshnessEvidenceHash) {
        return false
    }
    let manifest = store.loadActiveCangjieVersionManifest()
    let freshness = store.loadActiveCangjieCorpusFreshness()
    if (manifest.degraded || manifest.sources.size != 5 || !freshness.ok ||
        freshness.degraded || freshness.sources.size != 5 ||
        freshness.activeKnowledgeVersion != activeVersion ||
        freshness.candidateKnowledgeVersion != candidateVersion) {
        return false
    }
    let expected = HashSet<String>()
    expected.add(CangjieSourceSets.DOCS)
    expected.add(CangjieSourceSets.STD)
    expected.add(CangjieSourceSets.STDX)
    expected.add(CangjieSourceSets.TOOLS)
    expected.add(CangjieSourceSets.EVAL_SUPPORT)
    let manifestSets = HashSet<String>()
    let freshnessSets = HashSet<String>()
    for (source in manifest.sources) { manifestSets.add(source.sourceSet) }
    for (source in freshness.sources) { freshnessSets.add(source.sourceSet) }
    if (manifestSets.size != 5 || freshnessSets.size != 5) { return false }
    for (sourceSet in expected) {
        if (!manifestSets.contains(sourceSet) ||
            !freshnessSets.contains(sourceSet)) { return false }
        var matched = false
        for (manifestSource in manifest.sources) {
            if (manifestSource.sourceSet != sourceSet) { continue }
            for (freshnessSource in freshness.sources) {
                if (freshnessSource.sourceSet == sourceSet &&
                    freshnessSource.resolvedCommit ==
                        manifestSource.resolvedCommit &&
                    freshnessSource.contentHash == manifestSource.contentHash) {
                    matched = true
                }
            }
        }
        if (!matched) { return false }
    }
    true
}

private func s6JsonString(object: JsonObject, key: String): String {
    match (object.get(key)) {
        case Some(value) => try {
            value.asString().getValue()
        } catch (_: Exception) { "" }
        case None => ""
    }
}

private func s6JsonBool(object: JsonObject, key: String): Bool {
    match (object.get(key)) {
        case Some(value) => try {
            value.asBool().getValue()
        } catch (_: Exception) { false }
        case None => false
    }
}

private func s6JsonInt(object: JsonObject, key: String): Int64 {
    match (object.get(key)) {
        case Some(value) => try {
            value.asInt().getValue()
        } catch (_: Exception) { -1 }
        case None => -1
    }
}

private func s6NoWorkerForStore(storePath: String): Bool {
    launch("/bin/sh", ["-c",
        "ps -axo command | grep '[s]cheduler-task-worker' | grep -F '${storePath}' >/dev/null"]).wait() != 0
}

private class S6ChildResult {
    var exitCode: Int64 = -1
    var stdoutText: String = ""
    var stderrText: String = ""
    var pid: Int64 = 0
    var task: SchedulerTaskResult = SchedulerTaskResult()

    init() {}
}

private func s6AssertSuccessfulWorkerChildHarness(child: S6ChildResult): Unit {
    @Expect(child.exitCode, 0)
    @Expect(child.stdoutText.contains(
        "[ PASSED ] CASE: p5S6RealWorkerChildFixture"), true)
    @Expect(child.stdoutText.contains("FAILED: 0"), true)
    @Expect(child.stdoutText.contains("fixture-secret"), false)
    @Expect(child.stdoutText.contains("Authorization"), false)
    @Expect(child.stderrText, "")
}

private class S6StaticTaskRunner <: SchedulerTaskRunner {
    private let text: String

    init(task: SchedulerTaskResult) {
        this.text = ckbSchedulerTaskResultText(task)
    }

    public func runTask(name: String, since: String,
        deadlineAtMillis: Int64): SchedulerTaskResult {
        ckbSchedulerTaskResultFromText(this.text)
    }
}

private func s6AssertSchedulerLoggingContract(root: String,
    sourceTask: SchedulerTaskResult): Unit {
    ckbReleaseTestEnsureEmptyDir(root)
    let successStore = FileKnowledgeStore("${root}/success")
    let success = s6CloneTask(sourceTask)
    success.validationDiagnostics.add(
        "阶段完成中文🙂 " + s6Repeat("超长诊断中文🙂", 100) +
        " Authorization: Bearer fixture-secret /Users/private/secret")
    let names = ArrayList<String>()
    names.add("cangjie_release_full_sync")
    let successRun = SchedulerExecutor(Scheduler(FakeClock(1000)),
        S6StaticTaskRunner(success), FileSchedulerProgressSink(successStore),
        440000).runTaskNames(names, force: true)
    let progress = successStore.readText(successRun.progressPath)
    let diagnostics = successStore.readText(
        "metadata/scheduler-runs/${successRun.runId}-diagnostics.jsonl")
    s6AssertStructuredJsonlBaseFields(progress)
    s6AssertStructuredJsonlBaseFields(diagnostics)
    @Expect(progress.contains("\"event\":\"scheduler.run.started\""), true)
    @Expect(progress.contains("\"event\":\"scheduler.task.started\""), true)
    @Expect(progress.contains("\"event\":\"scheduler.task.stage\""), true)
    @Expect(progress.contains("\"event\":\"scheduler.task.finished\""), true)
    @Expect(progress.contains("\"event\":\"scheduler.run.finished\""), true)
    let startedLine = s6JsonlEventLine(progress, "scheduler.task.started")
    @Expect(startedLine.contains("\"timeBudgetMs\":440000"), true)
    @Expect(startedLine.contains("\"deadlineAtMillis\":0"), false)
    @Expect(progress.contains("\"businessOk\":true"), true)
    @Expect(progress.contains("\"finalizationOk\":true"), true)
    @Expect(diagnostics.contains("\"legacyEvent\":\"task_diagnostic\""), true)
    let unicodeDiagnosticLine = s6JsonlLineContaining(diagnostics,
        "阶段完成中文🙂")
    let unicodeDiagnostic = JsonValue.fromStr(unicodeDiagnosticLine).asObject()
    @Expect(s6JsonBool(unicodeDiagnostic, "diagnosticTruncated"), true)
    @Expect(unicodeDiagnosticLine.contains("fixture-secret"), false)
    @Expect(unicodeDiagnosticLine.contains("Authorization"), false)
    @Expect(unicodeDiagnosticLine.contains("Bearer"), false)
    @Expect(unicodeDiagnosticLine.contains("/Users/private"), false)
    @Expect(String.fromUtf8(unicodeDiagnosticLine.toArray()),
        unicodeDiagnosticLine)

    let timeoutStore = FileKnowledgeStore("${root}/timeout")
    let timeout = s6CloneTask(sourceTask)
    timeout.ok = false
    timeout.status = "task_timeout:cangjie_release_full_sync"
    timeout.lastStage = "candidate_vector_finished"
    timeout.lastProgress = "完成🙂=1,total=2"
    timeout.workerOutSnippet = "Authorization: Bearer fixture-secret"
    timeout.workerErrSnippet = "/Users/private/secret 中文🙂"
    let timeoutRun = SchedulerExecutor(Scheduler(FakeClock(1000)),
        S6StaticTaskRunner(timeout), FileSchedulerProgressSink(timeoutStore),
        440000).runTaskNames(names, force: true)
    let timeoutProgress = timeoutStore.readText(timeoutRun.progressPath)
    s6AssertStructuredJsonlBaseFields(timeoutProgress)
    @Expect(timeoutRun.businessOk, false)
    @Expect(timeoutProgress.contains(
        "\"event\":\"scheduler.task.timeout\""), true)
    @Expect(timeoutProgress.contains(
        "\"errorCode\":\"ckb.scheduler.task_timeout\""), true)
    @Expect(timeoutProgress.contains("\"lastStage\""), true)
    @Expect(timeoutProgress.contains("\"lastProgress\""), true)
    let timeoutLine = s6JsonlEventLine(timeoutProgress,
        "scheduler.task.timeout")
    @Expect(timeoutLine.contains("task_timeout:cangjie_release_full_sync"), true)
    @Expect(timeoutLine.contains("routine_contract_passed"), false)
    @Expect(timeoutLine.contains("Authorization"), false)
    @Expect(timeoutLine.contains("Bearer"), false)
    @Expect(timeoutProgress.contains("fixture-secret"), false)
    @Expect(timeoutProgress.contains("/Users/private"), false)

    let stageStore = FileKnowledgeStore("${root}/stage")
    let stageSink = FileCkbStagedRebuildStageSink(stageStore,
        schedulerRunId: "s6-stage-run",
        schedulerTaskName: "cangjie_release_full_sync")
    let stageProgress = CkbStagedRebuildStageProgress()
    stageProgress.stage = "candidate_validation_started"
    stageProgress.status = "running"
    stageProgress.diagnostic = s6Repeat("阶段中文🙂", 100)
    stageProgress.deadlineAtMillis = ckbCoreNowMillis() + 60000
    stageProgress.remainingMillis = 60000
    stageProgress.atMillis = ckbCoreNowMillis()
    stageSink.onStagedRebuildStage(stageProgress)
    let stageJson = stageStore.readText(
        "metadata/scheduler-runs/s6-stage-run.jsonl")
    s6AssertStructuredJsonlBaseFields(stageJson)
    @Expect(stageJson.contains("\"diagnosticTruncated\":true"), true)

    let vectorStore = FileKnowledgeStore("${root}/vector")
    let vectorSink = FileVectorBuildProgressSink(vectorStore,
        schedulerRunId: "s6-vector-run",
        schedulerTaskName: "cangjie_release_full_sync")
    let vectorProgress = VectorBuildProgress()
    vectorProgress.runId = "s6-vector-run"
    vectorProgress.collection = "s6-vector-collection"
    vectorProgress.targetCollection = "s6-vector-collection"
    vectorProgress.dimension = 16
    vectorProgress.state = EmbeddingProviderState.READY
    vectorProgress.diagnostic = s6Repeat("向量中文🙂", 100)
    vectorSink.onVectorBuildStarted(vectorProgress)
    let vectorJson = vectorStore.readText(vectorSink.currentProgressPath())
    s6AssertStructuredJsonlBaseFields(vectorJson)
    @Expect(vectorJson.contains("\"diagnosticTruncated\":true"), true)
}

private func s6AssertStructuredJsonlBaseFields(text: String): Unit {
    for (line in text.split("\n")) {
        if (line.trimAscii() == "") { continue }
        let object = JsonValue.fromStr(line).asObject()
        @Expect(s6JsonString(object, "time") != "", true)
        @Expect(s6JsonString(object, "level") != "", true)
        @Expect(s6JsonString(object, "subsystem") != "", true)
        @Expect(s6JsonString(object, "event") != "", true)
        @Expect(s6JsonString(object, "message") != "", true)
        @Expect(s6JsonString(object, "runId") != "", true)
        @Expect(s6JsonString(object, "status") != "", true)
        @Expect(s6JsonInt(object, "atMillis") >= 0, true)
        @Expect(line.contains("\"time\":"), true)
        @Expect(line.contains("\"level\":"), true)
        @Expect(line.contains("\"subsystem\":"), true)
        @Expect(line.contains("\"event\":"), true)
        @Expect(line.contains("\"message\":"), true)
        @Expect(line.contains("\"runId\":"), true)
        @Expect(line.contains("\"status\":"), true)
        @Expect(line.contains("\"atMillis\":"), true)
    }
}

private func s6AssertReleaseTypedLogSchema(progress: String,
    vectorProgress: String, pointer: CkbActiveSnapshotPointer,
    expectedRunId: String): Unit {
    var workerStarted: Int64 = 0
    var workerResultWritten: Int64 = 0
    var fetchStarted: Int64 = 0
    var fetchFinished: Int64 = 0
    var treePages: Int64 = 0
    var readiness: Int64 = 0
    var deltaBuilt: Int64 = 0
    var promotionStarted: Int64 = 0
    var promotionFinished: Int64 = 0
    var snapshotStarted: Int64 = 0
    var snapshotCommitted: Int64 = 0
    for (line in progress.split("\n")) {
        if (line.trimAscii() == "") { continue }
        let object = JsonValue.fromStr(line).asObject()
        let event = s6JsonString(object, "event")
        if (event.startsWith("scheduler.worker.") ||
            event.startsWith("routine.") ||
            event.startsWith("snapshot.transaction.")) {
            @Expect(s6JsonString(object, "runId"), expectedRunId)
            @Expect(s6JsonString(object, "taskName"),
                "cangjie_release_full_sync")
        }
        if (event == "scheduler.task.stage") {
            @Expect(s6JsonInt(object, "remainingMs") >= 0, true)
        } else if (event == "scheduler.task.finished") {
            @Expect(s6JsonInt(object, "bootstrapStartedAtMillis") > 0, true)
            @Expect(s6JsonInt(object, "taskBodyStartedAtMillis") >=
                s6JsonInt(object, "bootstrapStartedAtMillis"), true)
            @Expect(s6JsonInt(object, "taskBodyEndedAtMillis") >=
                s6JsonInt(object, "taskBodyStartedAtMillis"), true)
            @Expect(s6JsonInt(object, "bootstrapDurationMillis") >= 0, true)
        } else if (event == "scheduler.worker.started") {
            workerStarted += 1
            @Expect(s6JsonInt(object, "workerPid") > 0, true)
            s6AssertRelativeLogPath(s6JsonString(object,
                "workerResultPath"))
        } else if (event == "scheduler.worker.result_written") {
            workerResultWritten += 1
            @Expect(s6JsonString(object, "status") != "", true)
            s6AssertRelativeLogPath(s6JsonString(object,
                "workerResultPath"))
        } else if (event == "scheduler.worker.killed") {
            @Expect(false, true)
        } else if (event == "routine.fetch.started") {
            fetchStarted += 1
            @Expect(s6JsonString(object, "requestKind") != "", true)
            @Expect(s6JsonString(object, "repo") != "", true)
            @Expect(s6JsonString(object, "sourceSet") != "", true)
        } else if (event == "routine.fetch.finished") {
            fetchFinished += 1
            @Expect(s6JsonString(object, "requestKind") != "", true)
            @Expect(s6JsonString(object, "repo") != "", true)
            @Expect(s6JsonString(object, "sourceSet") != "", true)
            @Expect(s6JsonString(object, "status") != "", true)
            @Expect(s6JsonInt(object, "httpStatus") >= 0, true)
            @Expect(s6JsonString(object, "bodyHash").size, 64)
            @Expect(s6JsonInt(object, "retryCount") >= 0, true)
        } else if (event == "routine.tree.page_scanned") {
            treePages += 1
            @Expect(s6JsonString(object, "repo") != "", true)
            @Expect(s6JsonString(object, "sourceSet") != "", true)
            @Expect(s6JsonInt(object, "page") > 0, true)
            @Expect(s6JsonInt(object, "objectsSeen") >= 0, true)
            @Expect(s6JsonInt(object, "filesSeen") >= 0, true)
            @Expect(s6JsonInt(object, "directoriesSeen") >= 0, true)
            @Expect(s6JsonInt(object, "candidatesSeen") >= 0, true)
            @Expect(s6JsonString(object, "stopReason") != "", true)
        } else if (event == "routine.readiness.evaluated") {
            readiness += 1
            @Expect(s6JsonString(object, "status"), "ready")
            @Expect(s6JsonInt(object, "requiredFailedCount"), 0)
            @Expect(s6JsonInt(object, "optionalFailedCount") >= 0, true)
        } else if (event == "routine.ingest.delta_built") {
            deltaBuilt += 1
            @Expect(s6JsonString(object, "status"), "ok")
            @Expect(s6JsonInt(object, "deltaCount") > 0, true)
        } else if (event == "routine.candidate.promotion.started") {
            promotionStarted += 1
            @Expect(s6JsonString(object,
                "candidateKnowledgeVersion") != "", true)
        } else if (event == "routine.candidate.promotion.finished") {
            promotionFinished += 1
            @Expect(s6JsonString(object, "status"), "ok")
            @Expect(s6JsonString(object,
                "activeKnowledgeVersion"), pointer.activeVersion)
        } else if (event == "snapshot.transaction.started") {
            snapshotStarted += 1
            @Expect(s6JsonString(object, "txId"), pointer.txId)
            @Expect(s6JsonString(object,
                "activeKnowledgeVersion"), pointer.activeVersion)
        } else if (event == "snapshot.transaction.committed") {
            snapshotCommitted += 1
            @Expect(s6JsonString(object, "txId"), pointer.txId)
            @Expect(s6JsonString(object, "manifestPath"),
                "metadata/active-snapshot.manifest")
            @Expect(s6JsonString(object, "commitPath"),
                "transactions/${pointer.txId}/COMMIT")
            s6AssertRelativeLogPath(s6JsonString(object, "manifestPath"))
            s6AssertRelativeLogPath(s6JsonString(object, "commitPath"))
        }
    }
    @Expect(workerStarted, 1)
    @Expect(workerResultWritten, 1)
    @Expect(fetchStarted, 5)
    @Expect(fetchFinished, 5)
    @Expect(treePages >= 4, true)
    @Expect(readiness, 1)
    @Expect(deltaBuilt, 1)
    @Expect(promotionStarted, 1)
    @Expect(promotionFinished, 1)
    @Expect(snapshotStarted, 1)
    @Expect(snapshotCommitted, 1)
    for (sourceSet in [CangjieSourceSets.DOCS, CangjieSourceSets.STD,
        CangjieSourceSets.STDX, CangjieSourceSets.TOOLS,
        CangjieSourceSets.EVAL_SUPPORT]) {
        let startedLine = s6JsonlEventSourceLine(progress,
            "routine.fetch.started", sourceSet)
        let finishedLine = s6JsonlEventSourceLine(progress,
            "routine.fetch.finished", sourceSet)
        let startedObject = JsonValue.fromStr(startedLine).asObject()
        let finishedObject = JsonValue.fromStr(finishedLine).asObject()
        @Expect(s6JsonInt(startedObject, "atMillis") > 0, true)
        @Expect(s6JsonInt(finishedObject, "atMillis") >=
            s6JsonInt(startedObject, "atMillis"), true)
    }

    var vectorStarted: Int64 = 0
    var vectorFinished: Int64 = 0
    for (line in vectorProgress.split("\n")) {
        if (line.trimAscii() == "") { continue }
        let object = JsonValue.fromStr(line).asObject()
        let event = s6JsonString(object, "event")
        @Expect(s6JsonString(object, "runId"), expectedRunId)
        @Expect(s6JsonString(object, "taskName"),
            "cangjie_release_full_sync")
        if (event == "vector.build.started") {
            vectorStarted += 1
            @Expect(s6JsonString(object, "runId") != "", true)
            @Expect(s6JsonString(object, "collection") != "", true)
            @Expect(s6JsonInt(object, "total") >= 0, true)
            @Expect(s6JsonInt(object, "dimension") > 0, true)
        } else if (event == "vector.batch.started") {
            @Expect(s6JsonInt(object, "batchIndex") >= 0, true)
            @Expect(s6JsonInt(object, "inputBytes") >= 0, true)
            @Expect(s6JsonInt(object, "preparedBytes") >= 0, true)
        } else if (event == "vector.batch.finished") {
            @Expect(s6JsonInt(object, "batchIndex") >= 0, true)
            @Expect(s6JsonInt(object, "completed") >= 0, true)
            @Expect(s6JsonInt(object, "total") >= 0, true)
            @Expect(s6JsonString(object, "status") != "", true)
        } else if (event == "vector.build.finished") {
            vectorFinished += 1
            @Expect(s6JsonString(object, "runId") != "", true)
            @Expect(s6JsonString(object, "collection") != "", true)
            @Expect(s6JsonString(object, "status") != "", true)
            @Expect(s6JsonInt(object, "expectedCount"),
                s6JsonInt(object, "actualCount"))
            @Expect(s6JsonInt(object, "durationMs") >= 0, true)
        }
    }
    @Expect(vectorStarted, 1)
    @Expect(vectorFinished, 1)
}

private func s6AssertReleaseEventSequence(progress: String): Unit {
    let expected = ArrayList<String>()
    expected.add("scheduler.run.started|-|run_start")
    expected.add("scheduler.task.started|-|task_start")
    expected.add("scheduler.worker.started|-|worker_start")
    expected.add("routine.fetch.started|docs|routine_fetch")
    expected.add("routine.tree.page_scanned|docs|tree_page")
    expected.add("routine.fetch.finished|docs|routine_fetch")
    expected.add("routine.fetch.started|std|routine_fetch")
    expected.add("routine.tree.page_scanned|std|tree_page")
    expected.add("routine.fetch.finished|std|routine_fetch")
    expected.add("routine.fetch.started|stdx|routine_fetch")
    expected.add("routine.tree.page_scanned|stdx|tree_page")
    expected.add("routine.fetch.finished|stdx|routine_fetch")
    expected.add("routine.fetch.started|tools|routine_fetch")
    expected.add("routine.tree.page_scanned|tools|tree_page")
    expected.add("routine.fetch.finished|tools|routine_fetch")
    expected.add("routine.fetch.started|eval-support|routine_fetch")
    expected.add("routine.fetch.finished|eval-support|routine_fetch")
    expected.add("scheduler.task.stage|-|fetch")
    expected.add("scheduler.task.stage|-|ingest_started")
    expected.add("routine.readiness.evaluated|-|readiness")
    expected.add("routine.ingest.delta_built|-|ingest_delta_built")
    expected.add("routine.candidate.promotion.started|-|candidate_promotion")
    expected.add("snapshot.transaction.started|-|snapshot_transaction")
    expected.add("snapshot.transaction.committed|-|snapshot_transaction")
    expected.add("routine.candidate.promotion.finished|-|candidate_promotion")
    expected.add("scheduler.task.stage|-|ingest_finished")
    expected.add("scheduler.worker.result_written|-|worker_result")
    expected.add("scheduler.task.finished|-|task_finish")
    expected.add("scheduler.run.finished|-|run_finish")
    var matched: Int64 = 0
    for (line in progress.split("\n")) {
        if (line.trimAscii() == "" || matched >= expected.size) { continue }
        let object = JsonValue.fromStr(line).asObject()
        let sourceSet = s6JsonString(object, "sourceSet")
        let actual = "${s6JsonString(object, "event")}|" +
            "${if (sourceSet == "") { "-" } else { sourceSet }}|" +
            "${s6JsonString(object, "stage")}" 
        if (actual == expected[matched]) { matched += 1 }
    }
    @Expect(matched, expected.size)
}

private func s6AssertRelativeLogPath(path: String): Unit {
    @Expect(path != "", true)
    @Expect(path.startsWith("/"), false)
    @Expect(path.contains("/Users/"), false)
    @Expect(path.contains(".."), false)
}

private func s6JsonlEventLine(text: String, event: String): String {
    for (line in text.split("\n")) {
        if (line.contains("\"event\":\"${event}\"")) { return line }
    }
    ""
}

private func s6JsonlLineContaining(text: String, needle: String): String {
    for (line in text.split("\n")) {
        if (line.contains(needle)) { return line }
    }
    ""
}

private func s6JsonlEventSourceLine(text: String, event: String,
    sourceSet: String): String {
    for (line in text.split("\n")) {
        if (line.contains("\"event\":\"${event}\"") &&
            line.contains("\"sourceSet\":\"${sourceSet}\"")) {
            return line
        }
    }
    ""
}

private func s6Joined(values: ArrayList<String>): String {
    let out = StringBuilder()
    for (value in values) { out.append("${value}\n") }
    out.toString()
}

private func s6TextField(text: String, key: String): String {
    for (line in text.split("\n")) {
        let parts = line.split("=")
        if (parts.size == 2 && parts[0] == key) { return parts[1] }
    }
    ""
}

private class S6ThrowingProgressSink <: SchedulerProgressSink {
    public func onRunStarted(result: SchedulerExecutorResult): Unit {
        throw Exception("observer Authorization: Bearer fixture-secret")
    }
    public func onTaskStarted(runId: String, taskName: String,
        timeBudgetMillis: Int64, deadlineAtMillis: Int64): Unit {
        throw Exception("observer start failed")
    }
    public func onTaskFinished(runId: String, taskName: String,
        task: SchedulerTaskResult): Unit {
        throw Exception("observer finish failed")
    }
    public func onRunFinished(result: SchedulerExecutorResult): Unit {
        throw Exception("observer run finish failed")
    }
}

private class S6FailingReleaseRunner <: SourceFetchRunner {
    private let delegate: CkbReleaseFullRunner
    private var calls: Int64 = 0

    init(generation: Int64) {
        this.delegate = CkbReleaseFullRunner(generation)
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls += 1
        if (this.calls == 4) {
            let failed = SourceFetchResult()
            failed.ok = false
            failed.status = "server_error"
            failed.statusCode = 500
            failed.sourceUrl = request.url
            failed.repo = request.repo
            failed.ref = request.ref
            failed.path = request.path
            failed.normalizedType = request.kind
            failed.attempts = 1
            return failed
        }
        this.delegate.fetch(request)
    }
}

private class S6ThrowingReleaseRunner <: SourceFetchRunner {
    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        throw Exception(
            "injected child exception Authorization: Bearer fixture-secret " +
            "/Users/private/secret 中文🙂")
    }
}

private class S6RepresentativeSourceRunner <: SourceFetchRunner {
    private let release: CkbReleaseFullRunner
    private let fallback = FakeSourceFetchRunner()

    init(generation: Int64) {
        this.release = CkbReleaseFullRunner(generation)
    }

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        if (request.kind == SourceKinds.GITCODE_BRANCH ||
            request.kind == SourceKinds.GITCODE_TREE ||
            request.kind == SourceKinds.GITCODE_SOURCE) {
            return this.release.fetch(request)
        }
        this.fallback.fetch(request)
    }

    func releaseNetworkCalls(): Int64 {
        this.release.networkCalls
    }
}

private class S6RecordingTaskRunner <: SchedulerTaskRunner {
    private let delegate: SchedulerTaskRunner
    private let sourceRunner: S6RepresentativeSourceRunner
    private let embeddingProvider: S6CountingEmbeddingProvider
    private let store: FileKnowledgeStore
    var releaseNetworkCallsDuringP5: Int64 = -1
    var embeddedItemsDuringP5: Int64 = -1
    var releaseTxBeforeP5: String = ""
    var releaseCompanionModeBeforeP5: String = ""
    var releaseCandidateBeforeP5: String = ""
    var releaseActiveBeforeP5: String = ""
    var lastReleaseTask: SchedulerTaskResult = SchedulerTaskResult()

    init(delegate: SchedulerTaskRunner,
        sourceRunner: S6RepresentativeSourceRunner,
        embeddingProvider: S6CountingEmbeddingProvider,
        store: FileKnowledgeStore) {
        this.delegate = delegate
        this.sourceRunner = sourceRunner
        this.embeddingProvider = embeddingProvider
        this.store = store
    }

    public func runTask(name: String, since: String,
        deadlineAtMillis: Int64): SchedulerTaskResult {
        let before = this.sourceRunner.releaseNetworkCalls()
        let embeddedBefore = this.embeddingProvider.embeddedItems
        if (name == "cangjie_release_full_sync") {
            let pointer = this.store.loadActiveSnapshotPointer()
            let snapshot = this.store.loadActiveSnapshot()
            this.releaseTxBeforeP5 = pointer.txId
            this.releaseCompanionModeBeforeP5 = pointer.companionMode
            this.releaseCandidateBeforeP5 = snapshot.candidateVersion
            this.releaseActiveBeforeP5 = snapshot.activeVersion
        }
        let task = this.delegate.runTask(name, since, deadlineAtMillis)
        if (name == "cangjie_release_full_sync") {
            this.lastReleaseTask = task
            this.releaseNetworkCallsDuringP5 =
                this.sourceRunner.releaseNetworkCalls() - before
            this.embeddedItemsDuringP5 =
                this.embeddingProvider.embeddedItems - embeddedBefore
        }
        task
    }
}

private class S6CountingEmbeddingProvider <: EmbeddingProvider {
    private let delegate = DeterministicEmbeddingProvider()
    var embeddedItems: Int64 = 0

    public func embed(texts: ArrayList<String>, model: String,
        dimensions: Int64): EmbeddingBatch {
        this.embeddedItems += texts.size
        this.delegate.embed(texts, model, dimensions)
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String,
        dimensions: Int64, deadlineAtMillis: Int64): EmbeddingBatch {
        this.embeddedItems += texts.size
        this.delegate.embedWithDeadline(texts, model, dimensions,
            deadlineAtMillis)
    }

    public func status(): EmbeddingStatus { this.delegate.status() }
}

private func s6Config(evalRoot: String): CkbRuntimeConfig {
    let evalCaseRoot = Path(evalRoot).join("CJ-HUMANEVAL-P5-S3")
    if (!exists(evalCaseRoot.join("metadata.json"))) {
        ckbReleaseTestWriteEvalFixture(evalRoot)
    }
    let config = CkbRuntimeConfig()
    config.networkEnabled = true
    config.firstInitEvalRoot = evalRoot
    config.firstInitTargetVersion = "1.0.0"
    config.benchmarkGapTargetVersion = "1.0.0"
    config
}

private func s6LaunchWorkerChild(root: String, generation: Int64,
    shouldFail: Bool, resultName: String,
    throwException!: Bool = false): S6ChildResult {
    if (!exists(Path(root))) {
        Directory.create(Path(root), recursive: true)
    }
    var dyld = ""
    if (let Some(value) <- getVariable("DYLD_LIBRARY_PATH")) { dyld = value }
    let prelude = ckbSchedulerWorkerShellPreludeWithHeap(dyld, "")
    let stdoutPath = "${root}/${resultName}.stdout"
    let stderrPath = "${root}/${resultName}.stderr"
    let command = prelude +
        "echo $$ > '${root}/worker.pid'; " +
        "export CKB_P5_S6_CHILD='1'; " +
        "export CKB_P5_S6_ROOT='${root}'; " +
        "export CKB_P5_S6_RESULT='${resultName}'; " +
        "export CKB_P5_S6_RUN_ID='${resultName}-run'; " +
        "export CKB_P5_S6_GENERATION='${generation}'; " +
        "export CKB_P5_S6_FAIL='${if (shouldFail) { "1" } else { "0" }}'; " +
        "export CKB_P5_S6_THROW='${if (throwException) { "1" } else { "0" }}'; " +
        "exec target/release/unittest_bin/cangjie_community_knowledge_base_test " +
        "--filter='*CkbReleaseFullSyncS6E2ETest.p5S6RealWorkerChildFixture' " +
        "--no-color --no-progress > '${stdoutPath}' 2> '${stderrPath}'"
    let process = launch("/bin/zsh", ["-c", command],
        stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
    let result = S6ChildResult()
    result.exitCode = process.wait()
    result.stdoutText = s6ReadUtf8File(stdoutPath)
    result.stderrText = s6ReadUtf8File(stderrPath)
    result.pid = try {
        Int64.parse(String.fromUtf8(File.readFrom(Path("${root}/worker.pid"))).trimAscii())
    } catch (_: Exception) { 0 }
    let store = FileKnowledgeStore("${root}/store")
    let relative = "metadata/scheduler-workers/${resultName}.ckb.sidecar"
    if (store.has(relative)) {
        result.task = ckbSchedulerTaskResultFromText(store.readText(relative))
    }
    result
}

private func s6TaskWithoutGate(task: SchedulerTaskResult,
    missing: String): SchedulerTaskResult {
    let out = s6CloneTask(task)
    let gates = ArrayList<String>()
    for (gate in out.validationGates) {
        if (gate != missing) { gates.add(gate) }
    }
    out.validationGates.clear()
    for (gate in gates) { out.validationGates.add(gate) }
    out
}

private func s6CloneTask(task: SchedulerTaskResult): SchedulerTaskResult {
    ckbSchedulerTaskResultFromText(ckbSchedulerTaskResultText(task))
}

private func s6Invariant(activeVersion: String): CkbRoutineActiveInvariant {
    let invariant = CkbRoutineActiveInvariant()
    invariant.activeKnowledgeVersion = activeVersion
    invariant.rawCount = 1
    invariant.normalizedCount = 1
    invariant.indexCount = 1
    invariant.vectorState = EmbeddingProviderState.READY
    invariant.graphState = EmbeddingProviderState.READY
    invariant.evidenceHash = stableSummaryHash(activeVersion)
    invariant
}

private func s6RequiredEnv(name: String): String {
    if (let Some(value) <- getVariable(name)) { return value }
    throw Exception("missing s6 child environment ${name}")
}

private func s6ReadPipe(pipe: InputStream): String {
    try {
        StringReader<InputStream>(pipe).readToEnd()
    } catch (_: Exception) {
        "invalid_response_encoding"
    }
}

private func s6PidExited(pid: Int64): Bool {
    pid > 0 && launch("/bin/sh", ["-c", "kill -0 ${pid} 2>/dev/null"]).wait() != 0
}

private func s6TreeContainsName(root: Path, fragment: String): Bool {
    if (!exists(root)) { return false }
    for (entry in Directory.readFrom(root)) {
        if (entry.name.contains(fragment)) { return true }
        if (entry.isDirectory() && s6TreeContainsName(entry.path, fragment)) {
            return true
        }
    }
    false
}

private func s6DropFirstSourceLine(text: String): String {
    let out = StringBuilder()
    var dropped = false
    for (line in text.split("\n")) {
        if (!dropped && line.startsWith("source|")) {
            dropped = true
            continue
        }
        if (line != "") { out.append("${line}\n") }
    }
    out.toString()
}

private func s6DuplicateSourceSet(text: String): String {
    let out = StringBuilder()
    var replaced = false
    for (line in text.split("\n")) {
        var next = line
        if (!replaced && line.startsWith("source|") && line.contains("|std|")) {
            next = line.replace("|std|", "|docs|")
            replaced = true
        }
        if (next != "") { out.append("${next}\n") }
    }
    out.toString()
}

private func s6Repeat(value: String, count: Int64): String {
    let out = StringBuilder()
    for (_ in 0..count) { out.append(value) }
    out.toString()
}
