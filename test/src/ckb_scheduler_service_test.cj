package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbSchedulerServiceF5Test {
    @TestCase
    public func f5Ut01SchedulerTaskIngestsCandidateAndPromotesActive(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.docsEnabled = true
        let store = FileKnowledgeStore("target/f5-ut-scheduler-ingest")
        let service = CkbCommandLoopService(config, store, sourceRunner: FakeSourceFetchRunner())
        _ = service.start()
        let before = service.statusSnapshot().activeKnowledgeVersion
        let tasks = ArrayList<String>()
        tasks.add("cangjie_docs_full_weekly")

        let result = service.runSchedulerTasks(tasks, true)
        let after = service.statusSnapshot()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.details.contains("candidate_validated_promoted"), true)
        @Expect(result.details.contains("candidateValidation status=candidate_validation_passed"), true)
        @Expect(result.validationSummaries.size > 0, true)
        @Expect(result.validationEvidenceHashes.size > 0, true)
        @Expect(after.candidateKnowledgeVersion.contains("ckb-scheduled-"), true)
        @Expect(after.activeKnowledgeVersion.endsWith("-active"), true)
        @Expect(after.activeKnowledgeVersion != "", true)
        @Expect(store.has("normalized/candidate/${after.candidateKnowledgeVersion}.ckb"), true)
    }

    @TestCase
    public func f5Ut02CandidateOverlayPreservesActiveTypedRecordsAndReplacesDeltaIdentity(): Unit {
        let kb = newOfflineKnowledgeBase()
        let active = kb.activeRecordSnapshot()
        let replacement = f5OverlayRecord(active[0].sourceId, "replacement-doc", "Replacement active-safe doc. Do not use append.")
        let delta = ArrayList<NormalizedRecord>()
        delta.add(replacement)

        let overlay = kb.activeRecordSnapshotOverlay(delta)
        let candidateVersion = kb.stageCandidateRecords("f5-overlay-candidate", overlay)
        let validation = validateCandidateServingIndex(kb.candidateRecordSnapshot(), candidateVersion)

        @Expect(overlay.size, active.size)
        @Expect(f5RecordChunkContains(overlay, "Replacement active-safe doc"), true)
        @Expect(validation.ok, true)
        @Expect(validation.exactSymbolHits > 0, true)
        @Expect(validation.docSectionHits > 0, true)
    }

    @TestCase
    public func f5Ut03AdminOperationGateRejectsConcurrentMutation(): Unit {
        let gate = CkbAdminOperationGate()

        let first = gate.enter("scheduler")
        let second = gate.enter("repository_sync")
        let ownerWhileBusy = gate.currentOperation()
        gate.leave("repository_sync")
        let ownerAfterWrongLeave = gate.currentOperation()
        gate.leave("scheduler")
        let third = gate.enter("repository_sync")

        @Expect(first, true)
        @Expect(second, false)
        @Expect(ownerWhileBusy, "scheduler")
        @Expect(ownerAfterWrongLeave, "scheduler")
        @Expect(third, true)
        gate.leave("repository_sync")
    }

    @TestCase
    public func f5Pos02AdminSchedulerRunResponseIncludesValidationDiagnostics(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.docsEnabled = true
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/f5-pos-admin-scheduler-validation"), sourceRunner: FakeSourceFetchRunner())
        _ = service.start()

        let response = ckbApiHandle(service, "POST", "/v1/admin/scheduler/run", "{\"taskNames\":[\"cangjie_docs_full_weekly\"],\"force\":true}", ["Authorization: Bearer admin"])

        @Expect(response.contains("\"validationSummaries\""), true)
        @Expect(response.contains("candidateValidation status=candidate_validation_passed"), true)
        @Expect(response.contains("\"validationDiagnostics\""), true)
        @Expect(response.contains("\"validationEvidenceHashes\""), true)
    }

    @TestCase
    public func f5Bnd01FreshnessProbeMarksStaleAndFailedSourcesDegraded(): Unit {
        let runner = F5FreshnessProbeRunner()

        let report = probeCangjieCorpusFreshness(defaultCangjieVersionManifest(), runner)

        @Expect(report.ok, false)
        @Expect(report.degraded, true)
        @Expect(f5HasStaleness(report, "stale"), true)
        @Expect(f5HasStaleness(report, "failed"), true)
        @Expect(report.diagnostics.size > 0, true)
    }

    @TestCase
    public func f5Pos01HttpStartupTickPersistsSchedulerAndRepositoryEventSync(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.schedulerLoopIntervalMillis = 600000
        let store = FileKnowledgeStore("target/f5-pos-scheduler-loop")
        let service = CkbCommandLoopService(config, store, sourceRunner: FakeSourceFetchRunner())
        _ = service.start()

        let started = startCkbSchedulerLoop(service, config)
        let event = GitCodeRepositoryChangedEvent()
        event.contractVersion = "gcm-ckb-repository-change-v1"
        event.provider = "gitcode"
        event.eventType = "merge_request"
        event.reason = "pr_merged"
        event.repo = "cangjie/stdx"
        event.ref = "main"
        event.prNumber = 77
        event.changedFiles.add("repo_list.md")
        event.changedFiles.add("src/http/client.cj")
        let accepted = service.acceptGitCodeRepositoryChangedEvent(event)
        let liveStatus = service.statusSnapshot()
        let reloaded = CkbCommandLoopService(config, store, sourceRunner: FakeSourceFetchRunner())
        _ = reloaded.start()
        let restoredStatus = reloaded.statusSnapshot()

        @Expect(started.status, "scheduler_started")
        @Expect(started.tick.ran > 0, true)
        @Expect(started.tick.succeeded > 0, true)
        @Expect(f5AnyScheduleLastRequestCount(liveStatus) > 0, true)
        @Expect(f5AnyScheduleLastSuccess(restoredStatus) > 0, true)
        @Expect(store.has("metadata/scheduler.ckb"), true)
        @Expect(accepted.status, "accepted")
        @Expect(accepted.diagnostic.contains("queued_in_memory"), false)
        @Expect(store.has("metadata/repo-list.ckb"), true)
    }

    @TestCase
    public func f5Neg01ValidationFailureMarksCandidateAndKeepsActive(): Unit {
        let kb = newOfflineKnowledgeBase()
        let before = kb.status().activeKnowledgeVersion
        let records = ArrayList<NormalizedRecord>()

        let validation = validateCandidateServingIndex(records, "f5-bad-candidate")
        if (!validation.ok) {
            kb.markCandidateValidationFailed("f5-bad-candidate")
        }
        let after = kb.status()

        @Expect(validation.ok, false)
        @Expect(validation.exactSymbolHits, 0)
        @Expect(f5ValidationHasDiagnostic(validation, "exact_symbol_coverage_missing"), true)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(after.failedCandidateVersion, "f5-bad-candidate")
    }

    @TestCase
    public func f7Pos01BenchmarkGapSchedulerReadsGateJsonlAndPromotesCandidate(): Unit {
        let root = "target/f7-scheduler-gap-curation"
        if (!exists(Path(root))) {
            Directory.create(Path(root), recursive: true)
        }
        let inputPath = "${root}/gap-curation-input.jsonl"
        File.writeTo(Path(inputPath), "{\"caseId\":\"CJ-HUMANEVAL-004\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Use ArrayList.add for visible input.\",\"visibleTestExcerpt\":\"assert solve([1,2]) == 3\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n".toArray())
        let config = CkbRuntimeConfig()
        config.benchmarkGapCurationInputPath = inputPath
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(config, store)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_benchmark_gap_curation")

        let result = service.runSchedulerTasks(tasks, true)
        let status = service.statusSnapshot()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.details.contains("benchmark_gap_candidate_promoted"), true)
        @Expect(status.activeKnowledgeVersion.endsWith("-active"), true)
        @Expect(store.has("index/active.ckb"), true)
    }

    @TestCase
    public func f7Bnd01BenchmarkGapSchedulerFailsWithoutConfiguredInput(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/f7-scheduler-gap-missing-input"))
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_benchmark_gap_curation")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(result.details.contains("benchmark_gap_curation_input_missing"), true)
    }
}

private class F5FreshnessProbeRunner <: SourceFetchRunner {
    var calls: Int64 = 0

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls += 1
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.lastModified = "2026-07-06T00:00:00Z"
        if (this.calls == 2) {
            result.ok = false
            result.status = "http_500"
            result.statusCode = 500
            return result
        }
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        result.commit = "changed-${this.calls}"
        result.body = "changed freshness body ${this.calls}"
        result.bodyHash = stableSummaryHash(result.body)
        result
    }
}

private func f5HasStaleness(report: CangjieCorpusFreshnessReport, staleness: String): Bool {
    for (source in report.sources) {
        if (source.staleness == staleness) {
            return true
        }
    }
    false
}

private func f5AnyScheduleLastSuccess(status: KnowledgeStatus): Int64 {
    var last: Int64 = -1
    for (entry in status.schedules) {
        if (entry.lastSuccessAt > last) {
            last = entry.lastSuccessAt
        }
    }
    last
}

private func f5AnyScheduleLastRequestCount(status: KnowledgeStatus): Int64 {
    var count: Int64 = 0
    for (entry in status.schedules) {
        if (entry.lastRequestCount > count) {
            count = entry.lastRequestCount
        }
    }
    count
}

private func f5ValidationHasDiagnostic(validation: CangjieCandidateValidationResult, diagnostic: String): Bool {
    for (item in validation.diagnostics) {
        if (item == diagnostic) {
            return true
        }
    }
    false
}

private func f5OverlayRecord(sourceId: String, title: String, chunk: String): NormalizedRecord {
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
    record.metadata.versionResolutionId = "f5-overlay-resolution"
    record.metadata.trustLevel = TrustLevels.OFFICIAL
    record.metadata.reviewState = ReviewStates.TRUSTED
    record
}

private func f5RecordChunkContains(records: ArrayList<NormalizedRecord>, text: String): Bool {
    for (record in records) {
        if (record.chunk.contains(text)) {
            return true
        }
    }
    false
}
