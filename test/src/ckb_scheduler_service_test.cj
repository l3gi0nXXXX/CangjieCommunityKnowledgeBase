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

        let report = probeCangjieCorpusFreshness(f5ScheduledManifest(), runner)

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
        @Expect(store.has("metadata/scheduler-loop.ckb"), true)
        @Expect(liveStatus.schedulerLoop.loopStatus, "running")
        @Expect(liveStatus.schedulerLoop.heartbeatFresh, true)
        @Expect(liveStatus.schedulerLoop.ran > 0, true)
        @Expect(f5AnyScheduleLastRequestCount(liveStatus) > 0, true)
        @Expect(restoredStatus.schedulerLoop.loopStatus, "running")
        @Expect(f5AnyScheduleLastSuccess(restoredStatus) > 0, true)
        @Expect(store.has("metadata/scheduler.ckb"), true)
        @Expect(accepted.status, "accepted")
        @Expect(accepted.diagnostic.contains("queued_in_memory"), false)
        @Expect(store.has("metadata/repo-list.ckb"), true)
        @Expect(store.has("metadata/repository-event-latest.ckb"), true)
    }

    @TestCase
    public func p5E2E001SchedulerCanStartAfterHttpReadyWithDeferredFirstTick(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.schedulerLoopIntervalMillis = 600000
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/p5-http-ready-scheduler"), sourceRunner: FakeSourceFetchRunner())
        _ = service.start()

        let started = startCkbSchedulerLoop(service, config, afterHttpReady: true, deferFirstTick: true)

        @Expect(started.ok, true)
        @Expect(started.status, "scheduler_started_after_http_ready")
        @Expect(started.readinessGate, "http_routes_registered")
        @Expect(started.firstTickDeferred, true)
        @Expect(started.tick.ran, 0)
        let status = service.statusSnapshot()
        @Expect(status.schedulerLoop.loopStatus, "running")
        @Expect(status.schedulerLoop.readinessGate, "http_routes_registered")
        @Expect(status.schedulerLoop.firstTickDeferred, true)
    }

    @TestCase
    public func p0cBnd001SchedulerDisabledPersistsLoopStatusAndDegradesHealth(): Unit {
        let config = CkbRuntimeConfig()
        config.schedulerEnabled = false
        let store = FileKnowledgeStore("target/p0c-disabled-loop")
        let service = CkbCommandLoopService(config, store, sourceRunner: FakeSourceFetchRunner())
        _ = service.start()

        let started = startCkbSchedulerLoop(service, config)
        let status = service.statusSnapshot()
        let health = ckbApiHandle(service, "GET", "/v1/health", "", [])

        @Expect(started.status, "scheduler_disabled")
        @Expect(store.has("metadata/scheduler-loop.ckb"), true)
        @Expect(status.schedulerLoop.loopStatus, "scheduler_disabled")
        @Expect(status.schedulerLoop.loopFailureCount > 0, true)
        @Expect(health.contains("\"schedulerLoop\""), true)
        @Expect(health.contains("\"degraded\":true"), true)
    }

    @TestCase
    public func p5Pos001FreshnessProbePersistsFreshnessArtifactWithoutPromotingActive(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p5-freshness-artifact")
        store.saveCangjieVersionManifest(f5ScheduledManifest())
        let service = CkbCommandLoopService(config, store, sourceRunner: F5FreshnessUpToDateRunner())
        _ = service.start()
        let before = service.statusSnapshot().activeKnowledgeVersion
        let tasks = ArrayList<String>()
        tasks.add("cangjie_freshness_daily")

        let result = service.runSchedulerTasks(tasks, true)
        let after = service.statusSnapshot()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(store.has("metadata/cangjie-freshness.ckb"), true)
    }

    @TestCase
    public func p7Pos001ReleaseRefreshPersistsVersionManifestArtifact(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-release-refresh-manifest")
        store.saveCangjieVersionManifest(f5ScheduledManifest())
        let service = CkbCommandLoopService(config, store, sourceRunner: FakeSourceFetchRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)
        let manifest = store.loadCangjieVersionManifest()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(store.has("metadata/cangjie-version-manifest.ckb"), true)
        @Expect(manifest.sources.size >= 4, true)
        @Expect(f5HasManifestRootKind(manifest, "scheduled:cangjie_release_full_sync"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), true)
    }

    @TestCase
    public func p7Pos002SourceEventSchedulerPersistsRepositoryEventArtifact(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-source-event-checkpoint")
        store.saveCangjieVersionManifest(f5ScheduledManifest())
        let service = CkbCommandLoopService(config, store, sourceRunner: FakeSourceFetchRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(store.has("metadata/repository-event-latest.ckb"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "repository_event_checkpoint_saved:"), true)
    }

    @TestCase
    public func p5Bnd001SchedulerFetchFailuresReturnStableDegradedStatuses(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.docsEnabled = true
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/p5-fetch-failures"), sourceRunner: F5DegradedFetchRunner())
        _ = service.start()
        let before = service.statusSnapshot().activeKnowledgeVersion
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)
        let after = service.statusSnapshot()

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(result.details.contains("fetch_degraded_candidate_not_promoted"), true)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(after.failedCandidateVersion == "" || after.failedCandidateVersion.contains("candidate"), true)
    }

    @TestCase
    public func p5Pos002AdminSyncHonorsSourceFamilyAndSourceRefFilters(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.docsEnabled = true
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/p5-sync-filters"), sourceRunner: FakeSourceFetchRunner())
        _ = service.start()

        let result = service.runSync(body: "{\"mode\":\"dry-run\",\"sourceSet\":\"docs\",\"sourceFamily\":\"docs\",\"sourceRef\":\"release-1.0.0\",\"maxItems\":3}")

        @Expect(result.status, "delta_sync_dry_run_ok")
        @Expect(result.degraded, false)
        @Expect(result.updatedDataKinds.contains("live_sync_docs_docs_ref"), true)
        @Expect(result.diagnostic.contains("sourceSet=docs"), true)
        @Expect(result.diagnostic.contains("sourceFamily=docs"), true)
        @Expect(result.diagnostic.contains("sourceRef=release-1.0.0"), true)
        @Expect(result.diagnostic.contains("source_filter_excludes_repo_discovery"), true)
    }

    @TestCase
    public func p5Pos003RepositoryItemsOnlyPersistsEventCheckpoint(): Unit {
        let store = FileKnowledgeStore("target/p5-repository-items-checkpoint")
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store, sourceRunner: FakeSourceFetchRunner())
        _ = service.start()

        let result = service.runRepositorySync(body: "{\"repo\":\"cangjie/stdx\",\"ref\":\"main\",\"profile\":\"items\",\"changedFiles\":[\"README.md\"],\"prNumber\":99}")

        @Expect(result.status, "ok")
        @Expect(result.diagnostic, "repository_items_delta_scheduled")
        @Expect(store.has("metadata/repository-event-latest.ckb"), true)
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
        @Expect(f7SchedulerDiagnosticsContain(result, "benchmark_gap_preview:CJ-HUMANEVAL-004:"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "benchmark_gap_preview:CJ-HUMANEVAL-004:") && f7SchedulerDiagnosticsContain(result, "ok=true"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "benchmark_gap_query_proof:CJ-HUMANEVAL-004:coveragePass=true"), true)
        @Expect(status.activeKnowledgeVersion.endsWith("-active"), true)
        @Expect(store.has("index/active.ckb"), true)

        let request = CangjieTaskKnowledgeRequest()
        request.taskId = "CJ-HUMANEVAL-004"
        request.benchmark = "Cangjie-HumanEval"
        request.taskText = "Use ArrayList.add for visible input."
        request.compilerOutput = "compile_error"
        request.expectedKnowledgeTags.add("G-ARRAYLIST")
        request.versionSelector = cangjieVersionSelector(targetVersion: "1.0.0", sourceSet: CangjieSourceSets.ALL)
        let pack = service.cangjieTaskKnowledgePack(request)
        @Expect(pack.coverage.coveragePass, true)
        @Expect(pack.citations.size > 0, true)
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

    @TestCase
    public func f7Neg01BenchmarkGapSchedulerRejectsBadMappingWithoutPromoting(): Unit {
        let root = "target/f7-scheduler-gap-bad-mapping"
        if (!exists(Path(root))) {
            Directory.create(Path(root), recursive: true)
        }
        let inputPath = "${root}/gap-curation-input.jsonl"
        File.writeTo(Path(inputPath), "{\"caseId\":\"CJ-HUMANEVAL-005\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Use ArrayList.add for visible input.\",\"visibleTestExcerpt\":\"assert solve([1,2]) == 3\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-04\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n".toArray())
        let config = CkbRuntimeConfig()
        config.benchmarkGapCurationInputPath = inputPath
        let service = CkbCommandLoopService(config, FileKnowledgeStore("${root}/store"))
        _ = service.start()
        let before = service.statusSnapshot().activeKnowledgeVersion
        let tasks = ArrayList<String>()
        tasks.add("cangjie_benchmark_gap_curation")

        let result = service.runSchedulerTasks(tasks, true)
        let after = service.statusSnapshot().activeKnowledgeVersion

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(result.details.contains("no_gap_records_accepted"), true)
        @Expect(result.details.contains("benchmark_gap_candidate_promoted"), false)
        @Expect(after, before)
    }
}

private func f7SchedulerDiagnosticsContain(result: SchedulerExecutorResult, needle: String): Bool {
    for (diagnostic in result.validationDiagnostics) {
        if (diagnostic.contains(needle)) {
            return true
        }
    }
    false
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

private class F5FreshnessUpToDateRunner <: SourceFetchRunner {
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
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        result.commit = this.expectedCommit(request)
        result.lastModified = "2026-07-06T00:00:00Z"
        result.body = "freshness probe ${request.kind} ${request.repo}"
        result.bodyHash = stableSummaryHash(result.body)
        result
    }

    private func expectedCommit(request: SourceFetchRequest): String {
        if (request.kind == SourceKinds.CANGJIE_DOCS) {
            return "fresh-docs"
        }
        if (request.repo == "Cangjie/cangjie_runtime") {
            return "fresh-std"
        }
        if (request.repo == "Cangjie/cangjie_stdx") {
            return "fresh-stdx"
        }
        if (request.repo == "Cangjie/cangjie_tools") {
            return "fresh-tools"
        }
        if (request.repo == "CangjieCommunityKnowledgeBase/Cangjie-HumanEval") {
            return "fresh-eval"
        }
        "fresh-unknown"
    }
}

private class F5DegradedFetchRunner <: SourceFetchRunner {
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
        result.ok = false
        if (this.calls == 1) {
            result.status = "timeout"
            result.transportErrorClass = "timeout"
            result.transportDiagnostic = "native request timed out"
        } else if (this.calls == 2) {
            result.status = "transport_error"
            result.transportErrorClass = "tls"
            result.transportDiagnostic = "TLS handshake failed"
        } else if (this.calls == 3) {
            result.status = "empty_body"
        } else if (this.calls == 4) {
            result.status = "malformed_json"
            result.body = "{not-json"
        } else {
            result.status = "transport_error"
            result.transportErrorClass = "dns"
            result.transportDiagnostic = "dns lookup failed"
        }
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

private func f5ScheduledManifest(): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = cangjieDefaultTargetVersion()
    f5AddManifestSource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs", "release-1.0.0", "fresh-docs")
    f5AddManifestSource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime", "release-1.0.0", "fresh-std")
    f5AddManifestSource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx", "release-1.0.0", "fresh-stdx")
    f5AddManifestSource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools", "release-1.0.0", "fresh-tools")
    f5AddManifestSource(manifest, CangjieSourceSets.EVAL_SUPPORT, "eval-support", "CangjieCommunityKnowledgeBase/Cangjie-HumanEval", "release-1.0.0", "fresh-eval")
    manifest
}

private func f5AddManifestSource(manifest: CangjieVersionManifest, sourceSet: String, sourceFamily: String, repo: String, ref: String, commit: String): Unit {
    let source = CangjieVersionSource()
    source.targetVersion = cangjieDefaultTargetVersion()
    source.sourceSet = sourceSet
    source.sourceFamily = sourceFamily
    source.sourceRepo = repo
    source.sourceRef = ref
    source.refKind = "branch"
    source.resolvedCommit = commit
    source.contentHash = "sha256:${commit}"
    source.rootKind = "scheduled:test"
    manifest.sources.add(source)
}

private func f5HasManifestRootKind(manifest: CangjieVersionManifest, rootKind: String): Bool {
    for (source in manifest.sources) {
        if (source.rootKind == rootKind) {
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
