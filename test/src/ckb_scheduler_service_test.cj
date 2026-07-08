package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbSchedulerServiceF5Test {
    @TestCase
    public func ruP0PreflightAcceptsLargeHeapExistingStoreAndMatchingVectorDimensions(): Unit {
        let root = "target/ru-p0-preflight-ok"
        if (!exists(Path(root))) {
            Directory.create(Path(root), recursive: true)
        }
        let config = CkbRuntimeConfig()
        config.vectorBackend = "qdrant"
        config.embeddingProvider = "ollama"
        config.embeddingModel = "bge-m3:latest"
        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.embeddingDimensions = 1024
        config.vectorDimensions = 1024

        let result = ckbRoutineRuntimePreflightWithVectorStore(config, root, "4GB", "/opt/homebrew/opt/openssl@3/lib", F7StatusVectorStore(EmbeddingProviderState.READY, "", 1024))

        @Expect(result.ok, true)
        @Expect(result.actualHeapMiB, 4096)
        @Expect(result.storeExists, true)
        @Expect(result.vectorReadiness, "ready")
    }

    @TestCase
    public func ruP0PreflightRejectsQdrantDownAndCollectionDimensionMismatch(): Unit {
        let root = "target/ru-p0-preflight-qdrant-down"
        if (!exists(Path(root))) {
            Directory.create(Path(root), recursive: true)
        }
        let config = CkbRuntimeConfig()
        config.vectorBackend = "qdrant"
        config.vectorEndpoint = "http://127.0.0.1:6333"
        config.embeddingProvider = "ollama"
        config.embeddingModel = "bge-m3:latest"
        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.embeddingDimensions = 1024
        config.vectorDimensions = 1024

        let down = ckbRoutineRuntimePreflightWithVectorStore(config, root, "4GB", "/opt/homebrew/opt/openssl@3/lib", F7StatusVectorStore(EmbeddingProviderState.DOWN, "connection_refused", 1024))
        let mismatch = ckbRoutineRuntimePreflightWithVectorStore(config, root, "4GB", "/opt/homebrew/opt/openssl@3/lib", F7StatusVectorStore(EmbeddingProviderState.READY, "", 768))

        @Expect(down.ok, false)
        @Expect(down.vectorReadiness, "degraded")
        @Expect(ruDiagnosticsContain(down.diagnostics, "qdrant_unreachable:connection_refused"), true)
        @Expect(mismatch.ok, false)
        @Expect(ruDiagnosticsContain(mismatch.diagnostics, "qdrant_collection_dimension_mismatch:1024:768"), true)
    }

    @TestCase
    public func ruP0PreflightRejectsMissingHeapSmallHeapMissingStoreAndVectorMismatch(): Unit {
        let config = CkbRuntimeConfig()
        config.vectorBackend = "qdrant"
        config.embeddingProvider = "ollama"
        config.embeddingModel = "bge-m3:latest"
        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.embeddingDimensions = 768
        config.vectorDimensions = 1024

        let missingHeap = ckbRoutineRuntimePreflight(config, "target/ru-p0-missing-store", "", "")
        let smallHeap = ckbRoutineRuntimePreflight(config, "target/ru-p0-missing-store", "256MB", "")

        @Expect(missingHeap.ok, false)
        @Expect(ruDiagnosticsContain(missingHeap.diagnostics, "missing_cjHeapSize"), true)
        @Expect(ruDiagnosticsContain(missingHeap.diagnostics, "store_not_found"), true)
        @Expect(ruDiagnosticsContain(missingHeap.diagnostics, "vector_dimension_mismatch"), true)
        @Expect(smallHeap.ok, false)
        @Expect(ruDiagnosticsContain(smallHeap.diagnostics, "heap_too_small"), true)
    }

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
    public func p7Pos003ReleaseRefreshUsesTreeFirstWhenRepoMetadataWouldFail(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-tree-first-release-refresh")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = F7GitCodeMetadata400TreeOkRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(f7RunnerSawKind(runner, SourceKinds.GITCODE_TREE), true)
        @Expect(f7RunnerSawKind(runner, SourceKinds.GITCODE_REPO), false)
        @Expect(store.has("metadata/cangjie-version-manifest.ckb"), true)
    }

    @TestCase
    public func p7Pos004EvalSupportUsesLocalProviderWhenRemoteWould404(): Unit {
        let fixture = f7WriteFullRootFixture("target/p7-eval-local-fixture")
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.firstInitEvalRoot = fixture.evalRoot
        config.firstInitTargetVersion = "1.0.0"
        let store = FileKnowledgeStore("target/p7-eval-local-provider")
        store.saveCangjieVersionManifest(f5ScheduledManifest())
        let service = CkbCommandLoopService(config, store, sourceRunner: F7GitCodeMetadata400TreeOkRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)
        let manifest = store.loadCangjieVersionManifest()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(f7SchedulerDiagnosticsContain(result, "eval_support_local_existing:"), true)
        @Expect(f7ManifestHasEvalLocalSource(manifest), true)
    }

    @TestCase
    public func p7Pos005SlashRefVersionBranchRefreshPersistsManifest(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-slash-ref-version-branch-refresh")
        store.saveCangjieVersionManifest(f7OfficialManifestSlashRefNoEval())
        let runner = F7SlashRefTreeOkRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)
        let manifest = store.loadCangjieVersionManifest()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(store.has("metadata/cangjie-version-manifest.ckb"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/branches?page=1&per_page=100"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/${f7SlashRefResolvedCommit()}?"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release%2F1.0?"), false)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release/1.0?"), false)
        @Expect(f7ManifestSourceRef(manifest, CangjieSourceSets.STD), "release/1.0")
        @Expect(f7ManifestResolvedCommit(manifest, CangjieSourceSets.STD), f7SlashRefResolvedCommit())
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), true)
    }

    @TestCase
    public func p7Pos006SlashRefReleaseFullSyncPersistsManifest(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-slash-ref-release-full-sync")
        store.saveCangjieVersionManifest(f7OfficialManifestSlashRefNoEval())
        let runner = F7SlashRefTreeOkRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)
        let manifest = store.loadCangjieVersionManifest()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(store.has("metadata/cangjie-version-manifest.ckb"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/branches?page=1&per_page=100"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/${f7SlashRefResolvedCommit()}?"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "?ref=${f7SlashRefResolvedCommit()}"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release%2F1.0?"), false)
        @Expect(f7RunnerSawUrlFragment(runner, "?ref=release%2F1.0"), false)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release/1.0?"), false)
        @Expect(f7ManifestSourceRef(manifest, CangjieSourceSets.STDX), "release/1.0")
        @Expect(f7ManifestResolvedCommit(manifest, CangjieSourceSets.STDX), f7SlashRefResolvedCommit())
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), true)
    }

    @TestCase
    public func p7Pos006bLegacyReleaseRefUsesSlashReleaseAliasWhenRemoteOmitsDashBranch(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-legacy-release-ref-alias")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = F7SlashRefTreeOkRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)
        let manifest = store.loadCangjieVersionManifest()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(f7RunnerSawUrlFragment(runner, "/branches?page=1&per_page=100"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "gitcode_ref_alias_used:Cangjie/cangjie_stdx:release-1.0.0:release/1.0"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/${f7SlashRefResolvedCommit()}?"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release-1.0.0?"), false)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release/1.0?"), false)
        @Expect(f7ManifestSourceRef(manifest, CangjieSourceSets.STDX), "release-1.0.0")
        @Expect(f7ManifestResolvedCommit(manifest, CangjieSourceSets.STDX), f7SlashRefResolvedCommit())
    }

    @TestCase
    public func p7Pos007SlashRefSourceEventSyncPersistsCheckpoint(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-slash-ref-source-event-sync")
        store.saveCangjieVersionManifest(f7OfficialManifestSlashRefNoEval())
        let runner = F7SlashRefTreeOkRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(store.has("metadata/repository-event-latest.ckb"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/branches?page=1&per_page=100"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/${f7SlashRefResolvedCommit()}?"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "?ref=${f7SlashRefResolvedCommit()}"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release%2F1.0?"), false)
        @Expect(f7RunnerSawUrlFragment(runner, "?ref=release%2F1.0"), false)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release/1.0?"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "repository_event_checkpoint_saved:"), true)
    }

    @TestCase
    public func p7Pos008SlashRefBranchEndpointFallbackUsesNativeSafeEncoding(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-slash-ref-branch-endpoint-fallback")
        store.saveCangjieVersionManifest(f7OfficialManifestSlashRefNoEval())
        let runner = F7SlashRefTreeOkRunner()
        runner.branchListOmitsRelease = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(f7RunnerSawUrlFragment(runner, "/branches/release%252F1.0"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/branches/release%2F1.0"), false)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/${f7SlashRefResolvedCommit()}?"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), true)
    }

    @TestCase
    public func p7Neg002SlashRefRemoteTreeFailureStillBlocksPromotion(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-slash-ref-remote-tree-failure")
        store.saveCangjieVersionManifest(f7OfficialManifestSlashRefNoEval())
        let runner = F7SlashRefTreeOkRunner()
        runner.failEncodedTree = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let before = service.statusSnapshot().activeKnowledgeVersion
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)
        let after = service.statusSnapshot()
        let summaries = ckbSchedulerFailureSummaries(result)

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(result.details.contains("scheduled_readiness_failed"), true)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(f7RunnerSawUrlFragment(runner, "/branches?page=1&per_page=100"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/${f7SlashRefResolvedCommit()}?"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release%2F1.0?"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), false)
        @Expect(summaries.size, 1)
        @Expect(summaries[0].taskName, "cangjie_release_full_sync")
        @Expect(summaries[0].primaryFailure.contains("scheduled_readiness_failed"), true)
        @Expect(f7SummaryListContains(summaries[0].failedSources, "remote_tree_unavailable"), true)
        @Expect(summaries[0].missingArtifacts.size, 0)
    }

    @TestCase
    public func p7Neg003MalformedBranchListBlocksSlashRefPromotion(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-slash-ref-malformed-branch-list")
        store.saveCangjieVersionManifest(f7OfficialManifestSlashRefNoEval())
        let runner = F7SlashRefTreeOkRunner()
        runner.malformedBranchList = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let before = service.statusSnapshot().activeKnowledgeVersion
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)
        let after = service.statusSnapshot()
        let summaries = ckbSchedulerFailureSummaries(result)

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(f7RunnerSawUrlFragment(runner, "/branches?page=1&per_page=100"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/${f7SlashRefResolvedCommit()}?"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), false)
        @Expect(summaries.size, 1)
        @Expect(summaries[0].primaryFailure.contains("scheduled_readiness_failed"), true)
        @Expect(f7SummaryListContains(summaries[0].failedSources, "gitcode_branch_list_malformed_json"), true)
    }

    @TestCase
    public func p7Neg003SchedulerFailureSummaryRedactsSensitiveDiagnostics(): Unit {
        let result = SchedulerExecutorResult()
        result.details = "task cangjie_release_full_sync ok=false status=scheduled_readiness_failed\n"
        result.validationDiagnostics.add("cangjie_release_full_sync:fetch:profile=cangjie_release_full_sync|ok=false|status=http_401|Authorization: Bearer secret-token|path=/Users/l3gi0n/private")

        let summaries = ckbSchedulerFailureSummaries(result)

        @Expect(summaries.size, 1)
        @Expect(summaries[0].failedSources.size, 1)
        @Expect(summaries[0].failedSources[0].contains("secret-token"), false)
        @Expect(summaries[0].failedSources[0].contains("/Users/l3gi0n/private"), false)
        @Expect(summaries[0].failedSources[0].contains("/Users/"), false)
    }

    @TestCase
    public func p7Bnd002FreshnessRecoversOfflineManifestFromFirstInitRoots(): Unit {
        let fixture = f7WriteFullRootFixture("target/p7-freshness-recovery-fixture")
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.firstInitDocsRoot = fixture.docsRoot
        config.firstInitStdRoot = fixture.stdRoot
        config.firstInitStdxRoot = fixture.stdxRoot
        config.firstInitEvalRoot = fixture.evalRoot
        config.firstInitTargetVersion = "1.0.0"
        let store = FileKnowledgeStore("target/p7-freshness-recovery")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let service = CkbCommandLoopService(config, store, sourceRunner: F7GitCodeMetadata400TreeOkRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_freshness_daily")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_recovered_for_freshness"), true)
        @Expect(cangjieManifestHasOfflineBaseline(store.loadCangjieVersionManifest()), false)
    }

    @TestCase
    public func p7Neg001TreeUnavailableFailsReadinessWithoutPromoting(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/p7-tree-unavailable")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let service = CkbCommandLoopService(config, store, sourceRunner: F7GitCodeMetadata400TreeUnavailableRunner())
        _ = service.start()
        let before = service.statusSnapshot().activeKnowledgeVersion
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)
        let after = service.statusSnapshot()

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(result.details.contains("scheduled_readiness_failed"), true)
        @Expect(after.activeKnowledgeVersion, before)
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
        @Expect(result.details.contains("scheduled_readiness_failed"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "fetch:profile=cangjie_release_full_sync"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "status=timeout"), true)
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
    public func ruP5BenchmarkGapSchedulerReadsStoreLocalInput(): Unit {
        let root = "target/ru-p5-store-local-gap"
        let metadata = Path(root).join("store/metadata")
        if (!exists(metadata)) {
            Directory.create(metadata, recursive: true)
        }
        File.writeTo(metadata.join("gap-curation-input.jsonl"), "{\"caseId\":\"CJ-HUMANEVAL-006\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Use ArrayList.add for visible input.\",\"visibleTestExcerpt\":\"assert solve([1,2]) == 3\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n".toArray())
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_benchmark_gap_curation")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.details.contains("benchmark_gap_candidate_promoted"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "benchmark_gap_query_proof:CJ-HUMANEVAL-006:coveragePass=true"), true)
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

@Test
public class CkbRoutinePreflightRepairHintTest {
    @TestCase
    public func ruP0PreflightClassifiesLegacyVectorMetadataAsRepairRequired(): Unit {
        let root = "target/ru-p0-preflight-legacy-vector-metadata"
        let config = f7QdrantRoutineConfig()
        let embedding = DeterministicEmbeddingProvider(embeddingConfigFromRuntime(config))
        let kb = KnowledgeBase(FakeClock(0), embedding, LocalVectorStore(), LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        kb.bootstrapOffline()
        let store = FileKnowledgeStore(root)
        _ = ckbRebuildIndex(kb, store)
        let activeCount = kb.status().storage.indexCount
        f7WriteFile(Path(root).join("metadata/status.ckb"), "active=${kb.status().activeKnowledgeVersion}\nvectorBackend=local-file\nvectorActiveCollection=active\nvectorCandidateCollection=candidate\nvectorDimension=16\n")

        let result = ckbRoutineRuntimePreflightWithBootstrap(config, root, "4096M", "/opt/homebrew/opt/openssl@3/lib", F7StatusVectorStore(EmbeddingProviderState.READY, "", 3, count: activeCount), embedding)

        @Expect(result.ok, false)
        @Expect(ruDiagnosticsContain(result.diagnostics, "repair_required:vector_reconcile:legacy_vector_metadata"), true)
        @Expect(ruDiagnosticsContain(result.diagnostics, "qdrant_active_not_ready:active"), false)
    }

    @TestCase
    public func ruP0PreflightClassifiesMissingManifestAsRepairRequired(): Unit {
        let root = "target/ru-p0-preflight-missing-manifest"
        let config = f7QdrantRoutineConfig()
        let embedding = DeterministicEmbeddingProvider(embeddingConfigFromRuntime(config))
        let kb = KnowledgeBase(FakeClock(0), embedding, LocalVectorStore(), LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        kb.bootstrapOffline()
        let store = FileKnowledgeStore(root)
        _ = ckbRebuildIndex(kb, store)
        f7WriteFile(Path(root).join("metadata/active-snapshot.manifest"), "")

        let result = ckbRoutineRuntimePreflightWithBootstrap(config, root, "4096M", "/opt/homebrew/opt/openssl@3/lib", F7StatusVectorStore(EmbeddingProviderState.READY, "", 3, count: kb.status().storage.indexCount), embedding)

        @Expect(result.ok, false)
        @Expect(ruDiagnosticsContain(result.diagnostics, "active_snapshot_manifest_missing"), true)
        @Expect(ruDiagnosticsContain(result.diagnostics, "repair_required:vector_reconcile:active_snapshot_manifest_missing"), true)
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

private func f7SummaryListContains(values: ArrayList<String>, needle: String): Bool {
    for (value in values) {
        if (value.contains(needle)) {
            return true
        }
    }
    false
}

private func ruDiagnosticsContain(values: ArrayList<String>, needle: String): Bool {
    for (value in values) {
        if (value.contains(needle)) {
            return true
        }
    }
    false
}

private class F7StatusVectorStore <: VectorStore {
    private let state: String
    private let reason: String
    private let dimension: Int64
    private let configuredCount: Int64

    init(state: String, reason: String, dimension: Int64, count!: Int64 = 0) {
        this.state = state
        this.reason = reason
        this.dimension = dimension
        this.configuredCount = count
    }

    public func upsert(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.status(collection)
    }

    public func upsertBatch(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.status(collection)
    }

    public func search(collection: String, queryVector: ArrayList<Float64>, filters: VectorSearchFilters, topK: Int64): ArrayList<VectorSearchResult> {
        ArrayList<VectorSearchResult>()
    }

    public func status(collection: String): VectorStoreStatus {
        let status = VectorStoreStatus()
        status.backend = "qdrant"
        status.collection = collection
        status.activeCollection = "ckb_active"
        status.candidateCollection = "ckb_candidate"
        status.dimension = this.dimension
        status.distance = "Cosine"
        status.state = this.state
        status.degradedReason = this.reason
        status.count = this.configuredCount
        status
    }

    public func clear(collection: String): VectorStoreStatus {
        this.status(collection)
    }

    public func deleteCollection(collection: String): VectorStoreStatus {
        this.status(collection)
    }

    public func ensureReadyCollection(collection: String): VectorStoreStatus {
        this.status(collection)
    }

    public func recreate(collection: String, vectors: ArrayList<VectorRecord>): VectorStoreStatus {
        this.status(collection)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = false
        backup.diagnostic = this.reason
        backup
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.status(backup.collection)
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

private class F7GitCodeMetadata400TreeOkRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        if (request.kind == SourceKinds.GITCODE_REPO) {
            result.ok = false
            result.status = "http_400"
            result.statusCode = 400
            result.body = "Invalid header parameter: private-token, required"
        } else if (request.kind == SourceKinds.GITCODE_BRANCH && request.purpose == "branch_ref") {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = "{\"name\":\"${request.ref}\",\"commit\":{\"id\":\"${f7GenericResolvedCommit()}\",\"sha\":\"${f7GenericResolvedCommit()}\"}}"
        } else if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = f7GenericBranchListBody()
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = "tree-${stableSummaryHash(request.repo)}"
            result.body = "{\"tree\":[{\"path\":\"src/scheduled_fixture.cj\",\"type\":\"blob\"},{\"path\":\"README.md\",\"type\":\"blob\"}],\"sha\":\"${result.commit}\"}"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.path.endsWith(".cj")) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = "source-${stableSummaryHash("${request.repo}:${request.path}")}"
            result.contentType = "text/plain"
            result.body = "package scheduled\npublic func scheduled_${stableSummaryHash(request.path)}(): Unit {}\n"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = "source-${stableSummaryHash("${request.repo}:${request.path}")}"
            result.contentType = "text/markdown"
            result.body = "# Scheduled source\nArrayList.add HashMap String.contains cjpm test\n"
        } else {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.body = "scheduled ${request.kind} ${request.repo}"
        }
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result
    }
}

private class F7GitCodeMetadata400TreeUnavailableRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        if (request.kind == SourceKinds.GITCODE_BRANCH && request.purpose == "branch_ref") {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = "{\"name\":\"${request.ref}\",\"commit\":{\"id\":\"${f7GenericResolvedCommit()}\",\"sha\":\"${f7GenericResolvedCommit()}\"}}"
            result.bodyHash = stableSummaryHash(result.body)
            return result
        }
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = f7GenericBranchListBody()
            result.bodyHash = stableSummaryHash(result.body)
            return result
        }
        result.ok = false
        result.status = if (request.kind == SourceKinds.GITCODE_REPO) { "http_400" } else { "source_tree_unavailable_fixture" }
        result.statusCode = if (request.kind == SourceKinds.GITCODE_REPO) { 400 } else { 503 }
        result.body = result.status
        result.bodyHash = stableSummaryHash(result.body)
        result
    }
}

private func f7GenericResolvedCommit(): String {
    "abcdef0123456789abcdef0123456789abcdef01"
}

private func f7GenericBranchListBody(): String {
    "[{\"name\":\"main\",\"commit\":{\"id\":\"${f7GenericResolvedCommit()}\",\"sha\":\"${f7GenericResolvedCommit()}\"}},{\"name\":\"release-1.0.0\",\"commit\":{\"id\":\"${f7GenericResolvedCommit()}\",\"sha\":\"${f7GenericResolvedCommit()}\"}},{\"name\":\"release-9.9.9\",\"commit\":{\"id\":\"${f7GenericResolvedCommit()}\",\"sha\":\"${f7GenericResolvedCommit()}\"}},{\"name\":\"release/1.0\",\"commit\":{\"id\":\"${f7GenericResolvedCommit()}\",\"sha\":\"${f7GenericResolvedCommit()}\"}}]"
}

private class F7SlashRefTreeOkRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()
    public var failEncodedTree: Bool = false
    public var malformedBranchList: Bool = false
    public var branchListOmitsRelease: Bool = false

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.normalizedType = request.kind
        result.attempts = 1
        if (request.ref == "release/1.0" && request.url.contains("release/1.0")) {
            return f7SlashRefFetchFailure(request, result, "unencoded_slash_ref")
        }
        if (request.kind == SourceKinds.GITCODE_BRANCH && request.purpose == "branch_list") {
            if (this.malformedBranchList) {
                result.ok = true
                result.status = "ok"
                result.statusCode = 200
                result.contentType = "application/json"
                result.body = "{\"not\":\"an-array\"}"
            } else if (this.branchListOmitsRelease) {
                result.ok = true
                result.status = "ok"
                result.statusCode = 200
                result.contentType = "application/json"
                result.body = "[${f7SlashRefBranchObjectBody("main")}]"
            } else {
                result.ok = true
                result.status = "ok"
                result.statusCode = 200
                result.contentType = "application/json"
                result.body = f7SlashRefBranchListBody()
            }
        } else if (request.kind == SourceKinds.GITCODE_BRANCH && request.purpose == "branch_ref") {
            if (!request.url.contains("/branches/release%252F1.0")) {
                return f7SlashRefFetchFailure(request, result, "native_unsafe_branch_ref")
            }
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = f7SlashRefBranchObjectBody("release/1.0")
        } else if (request.kind == SourceKinds.GITCODE_TREE && !request.url.contains("/git/trees/${f7SlashRefResolvedCommit()}?")) {
            return f7SlashRefFetchFailure(request, result, "tree_ref_not_resolved")
        } else if (request.kind == SourceKinds.GITCODE_TREE && this.failEncodedTree) {
            return f7SlashRefFetchFailure(request, result, "remote_tree_unavailable")
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = f7SlashRefResolvedCommit()
            result.body = "{\"tree\":[{\"path\":\"src/scheduled_fixture.cj\",\"type\":\"blob\"},{\"path\":\"README.md\",\"type\":\"blob\"}],\"sha\":\"${result.commit}\"}"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && !request.url.contains("?ref=${f7SlashRefResolvedCommit()}")) {
            return f7SlashRefFetchFailure(request, result, "source_ref_not_resolved")
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.path.endsWith(".cj")) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = f7SlashRefResolvedCommit()
            result.contentType = "text/plain"
            result.body = "package scheduled\npublic func scheduled_${stableSummaryHash(request.path)}(): Unit {}\n"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = f7SlashRefResolvedCommit()
            result.contentType = "text/markdown"
            result.body = "# Slash ref scheduled source\nArrayList.add HashMap String.contains cjpm test\n"
        } else {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = "other-${stableSummaryHash("${request.kind}:${request.url}")}"
            result.contentType = "text/plain"
            result.body = "slash ref scheduled ${request.kind} ${request.repo}"
        }
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result
    }
}

private func f7SlashRefResolvedCommit(): String {
    "0123456789abcdef0123456789abcdef01234567"
}

private func f7SlashRefBranchListBody(): String {
    "[${f7SlashRefBranchObjectBody("main")},${f7SlashRefBranchObjectBody("release/1.0")}]"
}

private func f7SlashRefBranchObjectBody(name: String): String {
    "{\"name\":\"${name}\",\"commit\":{\"id\":\"${f7SlashRefResolvedCommit()}\",\"sha\":\"${f7SlashRefResolvedCommit()}\"}}"
}

private func f7SlashRefFetchFailure(request: SourceFetchRequest, result: SourceFetchResult, status: String): SourceFetchResult {
    result.ok = false
    result.status = status
    result.statusCode = 404
    result.body = status
    result.bodyHash = stableSummaryHash(status)
    result
}

private class F7RootFixture {
    var docsRoot: String = ""
    var stdRoot: String = ""
    var stdxRoot: String = ""
    var evalRoot: String = ""

    init() {}
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

private func f7RunnerSawKind(runner: F7GitCodeMetadata400TreeOkRunner, kind: String): Bool {
    for (call in runner.calls) {
        if (call.kind == kind) {
            return true
        }
    }
    false
}

private func f7RunnerSawUrlFragment(runner: F7SlashRefTreeOkRunner, fragment: String): Bool {
    for (call in runner.calls) {
        if (call.url.contains(fragment)) {
            return true
        }
    }
    false
}

private func f7ManifestSourceRef(manifest: CangjieVersionManifest, sourceSet: String): String {
    for (source in manifest.sources) {
        if (source.sourceSet == sourceSet) {
            return source.sourceRef
        }
    }
    ""
}

private func f7ManifestResolvedCommit(manifest: CangjieVersionManifest, sourceSet: String): String {
    for (source in manifest.sources) {
        if (source.sourceSet == sourceSet) {
            return source.resolvedCommit
        }
    }
    ""
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

private func f7OfficialManifestSlashRefNoEval(): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = cangjieDefaultTargetVersion()
    f5AddManifestSource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs", "release/1.0", "fresh-docs")
    f5AddManifestSource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime", "release/1.0", "fresh-std")
    f5AddManifestSource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx", "release/1.0", "fresh-stdx")
    f5AddManifestSource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools", "release/1.0", "fresh-tools")
    manifest
}

private func f7OfficialManifestNoEval(): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = cangjieDefaultTargetVersion()
    f5AddManifestSource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs", "release-1.0.0", "fresh-docs")
    f5AddManifestSource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime", "release-1.0.0", "fresh-std")
    f5AddManifestSource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx", "release-1.0.0", "fresh-stdx")
    f5AddManifestSource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools", "release-1.0.0", "fresh-tools")
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

private func f7ManifestHasEvalLocalSource(manifest: CangjieVersionManifest): Bool {
    for (source in manifest.sources) {
        if (source.sourceSet == CangjieSourceSets.EVAL_SUPPORT && source.sourceRepo == "ckb-local://eval-support" && source.rootKind == "local-eval-support") {
            return true
        }
    }
    false
}

private func f7WriteFullRootFixture(root: String): F7RootFixture {
    let fixture = F7RootFixture()
    fixture.docsRoot = "${root}/docs"
    fixture.stdRoot = "${root}/std"
    fixture.stdxRoot = "${root}/stdx"
    fixture.evalRoot = "${root}/eval"
    f7WriteFile(Path(fixture.docsRoot).join("dev-guide/source_en/api/collections.md"), "# Collections\nArrayList.add and HashMap are collection APIs.\n")
    f7WriteFile(Path(fixture.stdRoot).join("src/std/collection/arraylist.cj"), "package std.collection\npublic class ArrayList<T> { public func add(value: T): Unit {} }\n")
    f7WriteFile(Path(fixture.stdxRoot).join("src/stdx/options/option.cj"), "package stdx.options\npublic enum Option<T> { Some | None }\n")
    let caseRoot = Path(fixture.evalRoot).join("CJ-HUMANEVAL-000")
    f7WriteFile(caseRoot.join("prompt.md"), "# Task\nUse EvalValue and EvalEntry.\n")
    f7WriteFile(caseRoot.join("metadata.json"), "{\"id\":\"CJ-HUMANEVAL-000\"}\n")
    f7WriteFile(caseRoot.join("starter/src/eval_support.cj"), "public class EvalValue {}\npublic class EvalEntry {}\n")
    f7WriteFile(caseRoot.join("tests/TestMain.cj"), "public func helper(): Unit {}\nmain() {}\n")
    f7WriteGitMetadata(fixture.docsRoot, "f7-docs-commit")
    f7WriteGitMetadata(fixture.stdRoot, "f7-std-commit")
    f7WriteGitMetadata(fixture.stdxRoot, "f7-stdx-commit")
    f7WriteGitMetadata(fixture.evalRoot, "f7-eval-commit")
    fixture
}

private func f7WriteFile(path: Path, text: String): Unit {
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, text.toArray())
}

private func f7WriteGitMetadata(root: String, commit: String): Unit {
    f7WriteFile(Path(root).join(".git/HEAD"), "ref: refs/heads/release-1.0.0\n")
    f7WriteFile(Path(root).join(".git/refs/heads/release-1.0.0"), commit)
}

private func f7QdrantRoutineConfig(): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.vectorBackend = "qdrant"
    config.vectorEndpoint = "http://127.0.0.1:6333"
    config.vectorActiveCollection = "ckb_active"
    config.vectorCandidateCollection = "ckb_candidate"
    config.vectorDimensions = 3
    config.vectorDistance = "Cosine"
    config.vectorAllowPrivateEndpoint = true
    config.embeddingProvider = "deterministic"
    config.embeddingModel = "deterministic"
    config.embeddingDimensions = 3
    config.embeddingEndpoint = "local://deterministic"
    config.embeddingAllowPrivateEndpoint = true
    config.embeddingBatchSize = 2
    config
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
