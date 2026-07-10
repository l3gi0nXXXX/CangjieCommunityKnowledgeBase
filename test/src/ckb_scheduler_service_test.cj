package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{Directory, File, Path, exists}
import std.process.*
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
    public func p4U1DocsFullSyncFetchesOnlyDocsAndEvalSupportSources(): Unit {
        let root = "target/p4-u1-docs-source-boundary"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.docsEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f5ScheduledManifest())
        let runner = S1S2PaginatedGitCodeRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_docs_full_weekly")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(s1s2RunnerSawRepo(runner, "Cangjie/cangjie_docs"), true)
        @Expect(s1s2RunnerSawRepo(runner, "Cangjie/cangjie_runtime"), false)
        @Expect(s1s2RunnerSawRepo(runner, "Cangjie/cangjie_stdx"), false)
        @Expect(s1s2RunnerSawRepo(runner, "Cangjie/cangjie_tools"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "scheduled_source_boundary:profile=cangjie_docs_full_sync"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_ref_record_resolved:docs:Cangjie/cangjie_docs"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_ref_record_resolved:tools:Cangjie/cangjie_tools"), false)
    }

    @TestCase
    public func p4U5DocsFullSyncResumesTreePageCheckpoint(): Unit {
        let root = "target/p4-u5-docs-fetch-checkpoint"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.docsEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f5ScheduledManifest())
        store.writeLinesAtomically(
            "metadata/scheduled-fetch-checkpoints/cangjie_docs_full_sync-docs-Cangjie_cangjie_docs.ckb",
            "profile=cangjie_docs_full_sync\nsourceSet=docs\nsourceFamily=docs\nrepo=Cangjie/cangjie_docs\nref=release-1.0.0\nresolvedCommit=${f7GenericResolvedCommit()}\nphase=tree_pages\nnextPage=2\ncurrentPath=\nselectedPaths=\ncompletedPaths=\nupdatedAtMillis=1\n"
        )
        let runner = S1S2PaginatedGitCodeRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_docs_full_weekly")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(s1s2RunnerSawRepoTreePage(runner, "Cangjie/cangjie_docs", 1), false)
        @Expect(s1s2RunnerSawRepoTreePage(runner, "Cangjie/cangjie_docs", 2), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "scheduled_fetch_checkpoint_resume:cangjie_docs_full_sync:docs:Cangjie/cangjie_docs:phase=tree_pages|nextPage=2"), true)
        @Expect(store.readText("metadata/scheduled-fetch-checkpoints/cangjie_docs_full_sync-docs-Cangjie_cangjie_docs.ckb").contains("phase=completed"), true)
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
    public func p5S1E2EBOperationalFailureSurvivesContractPersistenceAndLanding(): Unit {
        let root = "target/p5-s1-e2e-b-operational-status"
        s1s2EnsureEmptyDir(root)
        let store = FileKnowledgeStore(root)
        store.saveCangjieVersionManifest(f5ScheduledManifest())
        let provider = P5S1ToggleFailEmbeddingProvider()
        let kb = KnowledgeBase(FakeClock(1000), provider, LocalVectorStore(), LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        kb.bootstrapOffline()
        kb.persist(store)
        provider.fail = true
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let runner = CkbSchedulerTaskRunner(kb, config, store, sourceRunner: FakeSourceFetchRunner())
        let executor = SchedulerExecutor(kb.scheduler, runner, FileSchedulerProgressSink(store), 0)
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = executor.runTaskNames(tasks, force: true)
        store.saveScheduler(kb.scheduler.entries)
        var persistedStatus = ""
        for (entry in store.loadScheduler()) {
            if (entry.name == "cangjie_release_full_sync") {
                persistedStatus = entry.lastStatus
            }
        }
        let reloaded = CkbCommandLoopService(config, store, sourceRunner: FakeSourceFetchRunner())
        _ = reloaded.start()
        let landing = collectCkbLandingStatus(reloaded)
        var landingDiagnostic = ""
        for (capability in landing.capabilities) {
            if (capability.id == "F5-routine-update-scheduler") {
                landingDiagnostic = capability.diagnostic
            }
        }

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(result.taskRecords.size, 1)
        @Expect(result.taskRecords[0].ok, false)
        @Expect(result.taskRecords[0].status, "candidate_vector_failed")
        @Expect(result.taskRecords[0].status.startsWith("task_not_ok:"), false)
        @Expect(ruDiagnosticsContain(result.validationDiagnostics, "routine_contract_degraded:task_not_ok:candidate_vector_failed"), true)
        @Expect(ruDiagnosticsContain(result.validationDiagnostics, "candidate_vector_failed"), true)
        @Expect(persistedStatus, "candidate_vector_failed")
        @Expect(landingDiagnostic, "candidate_vector_failed:cangjie_release_full_sync")
        @Expect(result.taskRecords[0].stageDurations.size >= 3, true)
        @Expect(ruDiagnosticsContain(result.taskRecords[0].stageDurations, "stage=candidate_vector_finished|durationMillis="), true)
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
        // F2-U1: branch list resolves release/1.0 to a commit before tree fetch.
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
    public func tP2B01SlashRefAndEscapedSlashTreePathFetchContent(): Unit {
        // T-P2-B01: release/1.0 is resolved safely and GitCode tree JSON escaped slashes become normal source paths.
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("target/t-p2-b01-slash-ref-escaped-path")
        store.saveCangjieVersionManifest(f7OfficialManifestSlashRefNoEval())
        let runner = F7SlashRefTreeOkRunner()
        runner.escapedSlashTreePath = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/${f7SlashRefResolvedCommit()}?"), true)
        @Expect(f7RunnerSawUrlFragment(runner, "/git/trees/release/1.0?"), false)
        @Expect(f7RunnerSawSourcePath(runner, "Cangjie/cangjie_tools", "docs/std/stdx/tools/eval-support/README.md"), true)
        @Expect(f7RunnerSawSourcePath(runner, "Cangjie/cangjie_tools", "target/generated/ignored.md"), false)
        @Expect(f7RunnerSawUrlFragment(runner, "/raw/docs/std/stdx/tools/eval-support/README.md?ref=${f7SlashRefResolvedCommit()}"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "required_source_failed"), false)
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
        @Expect(summaries[0].primaryFailure != "", true)
        @Expect(summaries[0].primaryFailure.contains("scheduled_readiness_failed"), false)
        @Expect(summaries[0].primaryFailure.contains("profile_stage_budget"), false)
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
        @Expect(summaries[0].primaryFailure != "", true)
        @Expect(summaries[0].primaryFailure.contains("scheduled_readiness_failed"), false)
        @Expect(summaries[0].primaryFailure.contains("profile_stage_budget"), false)
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
    public func p7Ut005SchedulerFailureSummaryPrefersSpecificReadinessFailure(): Unit {
        let result = SchedulerExecutorResult()
        result.details = "task cangjie_version_branch_refresh ok=false status=scheduled_readiness_failed\n"
        result.validationDiagnostics.add("cangjie_version_branch_refresh:profile_stage_budget:profile=cangjie_version_branch_refresh|fetchBudgetMs=70000")
        result.validationDiagnostics.add("cangjie_version_branch_refresh:readiness:manifest_blocking_source_failed:tools:Cangjie/cangjie_tools:transport_error")
        result.validationDiagnostics.add("cangjie_version_branch_refresh:fetch:profile=cangjie_version_branch_refresh|kind=gitcode_tree|purpose=source_tree|repo=Cangjie/cangjie_tools|ok=false|status=transport_error|errorClass=timeout")

        let summaries = ckbSchedulerFailureSummaries(result)

        @Expect(summaries.size, 1)
        @Expect(summaries[0].status, "scheduled_readiness_failed")
        @Expect(summaries[0].primaryFailure.contains("manifest_blocking_source_failed:tools"), true)
        @Expect(summaries[0].primaryFailure.contains("profile_stage_budget"), false)
        @Expect(f7SummaryListContains(summaries[0].failedSources, "status=transport_error"), true)
    }

    @TestCase
    public func p7Ut004RoutineContractPassedDoesNotCreateFailedSummary(): Unit {
        let result = SchedulerExecutorResult()
        result.validationDiagnostics.add("docs_probe_30d:routine_contract:{\"taskName\":\"docs_probe_30d\",\"ok\":true,\"status\":\"passed\",\"diagnostic\":\"routine_contract_passed\",\"missingArtifacts\":[]}")

        let summaries = ckbSchedulerFailureSummaries(result)

        @Expect(summaries.size, 0)
    }

    @TestCase
    public func p7Pos009SchedulerTaskRecordsRenderMachineReadableJson(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.docsEnabled = true
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/p7-pos-task-records-json"), sourceRunner: FakeSourceFetchRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("docs_probe_30d")

        let result = service.runSchedulerTasks(tasks, true)
        let tasksJson = ckbSchedulerRunTaskRecordsJson(result.taskRecords)

        @Expect(result.ran, 1)
        @Expect(result.taskRecords.size, 1)
        @Expect(result.taskRecords[0].taskName, "docs_probe_30d")
        @Expect(tasksJson.startsWith("["), true)
        @Expect(tasksJson.contains("\"taskName\":\"docs_probe_30d\""), true)
        @Expect(tasksJson.contains("\"durationMillis\""), true)
        @Expect(tasksJson.contains("\"primaryFailure\""), true)
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
    public func s1Ut001Pos001PaginatedTreeFindsSecondPageCandidateAndManifest(): Unit {
        // UT-S1-001, POS-S1-001: page 1 directories, page 2 README candidate via fake runner.
        let root = "target/s1-ut001-pos001-paginated-tree"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(store.has("metadata/cangjie-version-manifest.ckb"), true)
        @Expect(s1s2RunnerSawTreePage(runner, 2), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "pagesScanned=2"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "source_tree_empty"), false)
    }

    @TestCase
    public func tP2U01ToolsTreeContinuesPastFirstTenDirectoryPages(): Unit {
        // F2-B1: cangjie_tools has directories on pages 1..10 and a documentation file on page 11.
        let root = "target/t-p2-u01-tools-page11"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.toolsCandidateAfterTenDirectoryPages = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(s1s2RunnerSawRepoTreePage(runner, "Cangjie/cangjie_tools", 11), true)
        @Expect(s1s2RunnerSawSourcePath(runner, "Cangjie/cangjie_tools", "docs/tools/cjpm_manual.md"), true)
        @Expect(s1s2RunnerSawSourcePath(runner, "Cangjie/cangjie_tools", "target/generated/ignored.md"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "tools_required_source"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "Cangjie/cangjie_tools:pagesScanned=11"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "source_tree_empty_after_pages"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "source_tree_no_candidate"), false)
    }

    @TestCase
    public func tP2U02ToolsTreePage9TransportBecomesContentWarning(): Unit {
        // P2-CUR-U1: tools ref is resolved, then source_tree page 9 times out as optional content sample.
        let root = "target/t-p2-u02-tools-page9-transport"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.directoriesOnly = true
        runner.failToolsTreePage9Transport = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(result.details.contains("version_manifest_refreshed_with_content_warnings"), true)
        @Expect(s1s2RunnerSawRepoTreePage(runner, "Cangjie/cangjie_tools", 9), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_ref_record_resolved:tools:Cangjie/cangjie_tools"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "content_warning_source_failed:tools:Cangjie/cangjie_tools:transport_error"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_source_content_sample_degraded:tools:Cangjie/cangjie_tools:transport_error"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_blocking_source_failed:tools:Cangjie/cangjie_tools:transport_error"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_write_verified:"), true)
        @Expect(result.taskRecords.size, 1)
        @Expect(result.taskRecords[0].primaryFailure, "")
    }

    @TestCase
    public func tP2U03VersionRefreshFetchesAllRefsBeforeSamples(): Unit {
        // P2-CUR-U4: branch/ref metadata is fetched for all manifest sources before tree/raw samples.
        let root = "target/t-p2-u03-metadata-first"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.failContentSamples = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(s1s2RunnerAllBranchFetchesBeforeSamples(runner), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_ref_record_resolved:docs:Cangjie/cangjie_docs"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_ref_record_resolved:std:Cangjie/cangjie_runtime"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_ref_record_resolved:stdx:Cangjie/cangjie_stdx"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_ref_record_resolved:tools:Cangjie/cangjie_tools"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_write_verified:"), true)
    }

    @TestCase
    public func tP2N01AllDirectoryPagesReportNoCandidate(): Unit {
        // F2-N1: directories followed by an empty tree page are a clear no-candidate result, not a first-page failure.
        let root = "target/s1-bnd001-directory-pages"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.directoriesOnly = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(result.details.contains("version_manifest_refreshed_with_content_warnings"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "source_tree_no_candidate"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "content_warning_source_failed"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_write_verified:"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "source_tree_empty_after_pages"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "pagesScanned=3"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "directories="), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "candidates=0"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "stop=empty_page"), true)
    }

    @TestCase
    public func s1Neg001SecondTreePage500BlocksRequiredSource(): Unit {
        // NEG-S1-001: page 2 HTTP 500 is a failed request and required source does not silently succeed.
        let root = "target/s1-neg001-tree-page2-500"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.failTreePage2 = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(result.details.contains("scheduled_readiness_failed"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "gitcode_tree_page_failed"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "status=server_error"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), false)
    }

    @TestCase
    public func s2Ut001ContentSampleFailureStillSavesManifest(): Unit {
        // UT-S2-001: ref/tree metadata resolved, content sample fails, manifest exists without offline baseline.
        let root = "target/s2-ut001-content-fail-manifest"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.failContentSamples = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)
        let manifest = store.loadCangjieVersionManifest()

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(result.details.contains("version_manifest_refreshed_with_content_warnings"), true)
        @Expect(store.has("metadata/cangjie-version-manifest.ckb"), true)
        @Expect(cangjieManifestHasOfflineBaseline(manifest), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_write_verified:"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "manifest_source_content_sample_degraded"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "content_warning_source_failed"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "content_blocking_source_failed"), false)
    }

    @TestCase
    public func s2Ut002SourceEventResolvedCheckpointDiffersFromIngested(): Unit {
        // UT-S2-002: resolved source-event checkpoint is saved even when content ingestion is not complete.
        let root = "target/s2-ut002-source-event-checkpoint"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.failContentSamples = true
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_source_event_sync")

        let result = service.runSchedulerTasks(tasks, true)
        let checkpoint = String.fromUtf8(File.readFrom(Path(root).join("store/metadata/repository-event-latest.ckb")))

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(store.has("metadata/repository-event-latest.ckb"), true)
        @Expect(checkpoint.contains("resolvedWatermark="), true)
        @Expect(checkpoint.contains("ingestedWatermark=not_ingested"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "repository_event_checkpoint_degraded:"), true)
    }

    @TestCase
    public func s2Bnd001RefFailureLeavesFreshnessNotReady(): Unit {
        // BND-S2-001: one source ref cannot resolve; no ready manifest is written and freshness stays degraded.
        let root = "target/s2-bnd001-ref-failure-freshness"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.failRefRepo = "Cangjie/cangjie_stdx"
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let refreshTasks = ArrayList<String>()
        refreshTasks.add("cangjie_version_branch_refresh")
        let freshnessTasks = ArrayList<String>()
        freshnessTasks.add("cangjie_freshness_daily")

        let refresh = service.runSchedulerTasks(refreshTasks, true)
        let freshness = service.runSchedulerTasks(freshnessTasks, true)

        @Expect(refresh.failed, 1)
        @Expect(f7SchedulerDiagnosticsContain(refresh, "manifest_blocking_source_failed:stdx"), true)
        @Expect(f7SchedulerDiagnosticsContain(refresh, "version_manifest_saved:"), false)
        @Expect(freshness.failed, 1)
        @Expect(f7SchedulerDiagnosticsContain(freshness, "manifest_offline_baseline_for_freshness"), true)
        @Expect(f7SchedulerDiagnosticsContain(freshness, "manifest_ready_for_freshness"), false)
    }

    @TestCase
    public func s2Bnd002RefFailurePrimaryFailureSkipsStageBudget(): Unit {
        // P2-CUR-U6: task record primaryFailure points at readiness root cause, not profile_stage_budget.
        let root = "target/s2-bnd002-ref-failure-primary"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(defaultCangjieVersionManifest())
        let runner = S1S2PaginatedGitCodeRunner()
        runner.failRefRepo = "Cangjie/cangjie_stdx"
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.failed, 1)
        @Expect(result.taskRecords.size, 1)
        @Expect(result.taskRecords[0].primaryFailure.contains("readiness:manifest_blocking_source_failed:stdx"), true)
        @Expect(result.taskRecords[0].primaryFailure.contains("profile_stage_budget"), false)
    }

    @TestCase
    public func s2Pos001FreshnessRunsAfterResolvedVersionRefresh(): Unit {
        // F3-P1/F3-E2E: version refresh writes a non-offline manifest/baseline and immediate freshness is not stale.
        let root = "target/s2-pos001-refresh-then-freshness"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let refreshTasks = ArrayList<String>()
        refreshTasks.add("cangjie_version_branch_refresh")
        let freshnessTasks = ArrayList<String>()
        freshnessTasks.add("cangjie_freshness_daily")

        let refresh = service.runSchedulerTasks(refreshTasks, true)
        let freshness = service.runSchedulerTasks(freshnessTasks, true)
        let artifact = store.loadCangjieCorpusFreshness()

        @Expect(refresh.succeeded, 1)
        @Expect(freshness.ran, 1)
        @Expect(freshness.failed, 0)
        @Expect(artifact.sources.size >= 4, true)
        @Expect(f7SchedulerDiagnosticsContain(freshness, "manifest_ready_for_freshness"), true)
        @Expect(f7SchedulerDiagnosticsContain(freshness, "version_manifest_contains_offline_baseline"), false)
        @Expect(f7SchedulerDiagnosticsContain(freshness, "staleness=stale"), false)
    }

    @TestCase
    public func tP2P01AllRequiredSourcesCanPromoteWithEvalSupport(): Unit {
        // F2-P1: docs/std/stdx/tools/eval-support all resolve, so readiness allows promotion.
        let fixture = f7WriteFullRootFixture("target/t-p2-p01-eval-fixture")
        let root = "target/t-p2-p01-all-required-sources"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.firstInitEvalRoot = fixture.evalRoot
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f5ScheduledManifest())
        let runner = S1S2PaginatedGitCodeRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_release_full_sync")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(f7SchedulerDiagnosticsContain(result, "required_source_failed"), false)
        @Expect(f7SchedulerDiagnosticsContain(result, "eval_support_local_existing:"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_saved:"), true)
    }

    @TestCase
    public func f3U1FreshnessArtifactRoundTripsFreshSourceHashes(): Unit {
        // F3-U1: manifest and freshness artifact commit/hash equality remains fresh after load.
        let root = "target/f3-u1-freshness-artifact-roundtrip"
        s1s2EnsureEmptyDir(root)
        let store = FileKnowledgeStore("${root}/store")
        let report = f3FreshnessReportFromManifest(f5ScheduledManifest())

        store.saveCangjieCorpusFreshness(report)
        let loaded = store.loadCangjieCorpusFreshness()

        @Expect(loaded.ok, true)
        @Expect(loaded.degraded, false)
        @Expect(loaded.sources.size, report.sources.size)
        @Expect(f3FreshnessSourceHasState(loaded, CangjieSourceSets.TOOLS, "fresh", "fresh"), true)
        @Expect(f3FreshnessSourceHasHash(loaded, CangjieSourceSets.TOOLS, "sha256:fresh-tools", "fresh-tools"), true)
    }

    @TestCase
    public func f3B1MissingIndexedAtDegradesOnlyThatFreshnessSource(): Unit {
        // F3-B1: a source with commit/hash but no indexedAt is diagnosed without changing other source staleness.
        let root = "target/f3-b1-missing-indexed-at"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let manifest = f5ScheduledManifest()
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(manifest)
        store.saveCangjieCorpusFreshness(f3FreshnessReportFromManifestWithMissingIndexedAt(manifest, CangjieSourceSets.TOOLS))
        let service = CkbCommandLoopService(config, store, sourceRunner: F5FreshnessUpToDateRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_freshness_daily")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(f7SchedulerDiagnosticsContain(result, "freshness_source_missing_indexedAt:sourceSet=tools"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "sourceSet=docs"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "sourceSet=docs|sourceFamily=docs|repo=Cangjie/cangjie_docs|ref=release-1.0.0|status=fresh|staleness=fresh"), true)
    }

    @TestCase
    public func f3N1ChangedToolsHashReportsOldAndNewFreshnessHash(): Unit {
        // P3-S1/P3-S2: changed tools source hash is a stale signal with old/new hash diagnostics, not a failed task.
        let root = "target/f3-n1-tools-hash-changed"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let manifest = f5ScheduledManifest()
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(manifest)
        store.saveCangjieCorpusFreshness(f3FreshnessReportFromManifest(manifest))
        let service = CkbCommandLoopService(config, store, sourceRunner: F3ToolsHashChangedFreshnessRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_freshness_daily")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.succeeded, 1)
        @Expect(result.failed, 0)
        @Expect(result.degraded, 0)
        @Expect(result.details.contains("freshness_probe_completed_with_stale_sources"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "freshness_source_hash_changed:sourceSet=tools"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "oldHash=sha256:fresh-tools"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "newCommit=changed-tools"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "sourceSet=tools|sourceFamily=tools|repo=Cangjie/cangjie_tools|ref=release-1.0.0|status=stale_signal|staleness=stale"), true)
        @Expect(result.taskRecords[0].lastProgress.contains("staleSignals=1"), true)
        @Expect(ckbSchedulerFailureSummaries(result).size, 0)
    }

    @TestCase
    public func s2Neg001InvalidUtf8ManifestFreshnessDegradesWithoutThrowing(): Unit {
        // NEG-S2-001: invalid UTF-8 manifest produces an explicit degraded diagnostic instead of an exception.
        let root = "target/s2-neg001-invalid-utf8-manifest"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.ensureLayout()
        File.writeTo(Path(root).join("store/metadata/cangjie-version-manifest.ckb"), [UInt8(255), UInt8(254), UInt8(253)])
        let service = CkbCommandLoopService(config, store, sourceRunner: S1S2PaginatedGitCodeRunner())
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_freshness_daily")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 1)
        @Expect(result.failed, 1)
        @Expect(result.details.contains("freshness_probe_degraded"), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "version_manifest_invalid_encoding"), true)
        let summaries = ckbSchedulerFailureSummaries(result)
        @Expect(summaries.size > 0, true)
        @Expect(summaries[0].primaryFailure.contains("version_manifest_invalid_encoding"), true)
    }

    @TestCase
    public func s6E2E004LargeRepoFixtureNoSourceTreeEmptyAcrossRoutineTasks(): Unit {
        // F2-E2E: temp store + fake GitCode covers docs/std/stdx/tools/eval-support without source_tree_empty.
        let root = "target/s6-e2e004-large-repo-page1-dirs"
        s1s2EnsureEmptyDir(root)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let store = FileKnowledgeStore("${root}/store")
        store.saveCangjieVersionManifest(f7OfficialManifestNoEval())
        let runner = S1S2PaginatedGitCodeRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: runner)
        _ = service.start()
        let tasks = ArrayList<String>()
        tasks.add("cangjie_version_branch_refresh")
        tasks.add("cangjie_release_full_sync")
        tasks.add("cangjie_source_event_sync")

        let result = service.runSchedulerTasks(tasks, true)

        @Expect(result.ran, 3)
        @Expect(result.failed, 0)
        @Expect(result.succeeded, 3)
        @Expect(store.has("metadata/cangjie-version-manifest.ckb"), true)
        @Expect(store.has("metadata/repository-event-latest.ckb"), true)
        @Expect(s1s2RunnerSawTreePage(runner, 2), true)
        @Expect(f7SchedulerDiagnosticsContain(result, "source_tree_empty"), false)
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
    public func s4Ut002BenchmarkProofDeadlineDiagnosticIncludesCompletedAndTotal(): Unit {
        let diagnostic = ckbBenchmarkGapQueryProofDeadlineDiagnostic(ckbCoreNowMillis() - 1, 2, 5)

        @Expect(diagnostic.contains("benchmark_gap_query_proof_timeout"), true)
        @Expect(diagnostic.contains("completed=2"), true)
        @Expect(diagnostic.contains("total=5"), true)
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

    @TestCase
    public func tP3U01FetchDeadlineDoesNotCallRunnerAndAddsStableDiagnostic(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let runner = DeadlineCountingFetchRunner()
        let task = CkbSchedulerTaskRunner(newOfflineKnowledgeBase(), config, FileKnowledgeStore("target/t-p3-u01-fetch-deadline"), sourceRunner: runner).runTask("docs_probe_30d", "0", ckbCoreNowMillis() - 1)

        @Expect(task.ok, false)
        @Expect(task.status.contains("fetch_degraded:timeout") || task.status.contains("task_not_ok:fetch_degraded:timeout"), true)
        @Expect(ruDiagnosticsContain(task.validationDiagnostics, "fetch_deadline_exceeded"), true)
        @Expect(ruDiagnosticsContain(task.validationDiagnostics, "errorClass=timeout"), true)
        @Expect(runner.calls, 0)
    }

    @TestCase
    public func tP3B01WorkerArtifactClassifierMapsStdxTimeout(): Unit {
        let classified = ckbClassifyWorkerArtifact("", "stdx.net HttpTimeoutException: read response timeout")

        @Expect(classified, "native_http_timeout")
    }

    @TestCase
    public func tP3B02WorkerArtifactClassifierMapsOutOfMemoryBeforeGenericArtifacts(): Unit {
        let classified = ckbClassifyWorkerArtifact("", "An exception has occurred: Out of memory")

        @Expect(classified, "worker_out_of_memory")
    }

    @TestCase
    public func tP3B03WorkerArtifactClassifierMapsDynamicLibraryFailureBeforeTimeout(): Unit {
        let classified = ckbClassifyWorkerArtifact("", "dyld[1]: Library not loaded: @rpath/libstdx.net.http.dylib image not found timeout")

        @Expect(classified, "worker_dynamic_library_missing")
    }

    @TestCase
    public func tP5B01ActiveVectorInvariantBlocksSuccessfulTaskWhenCountsMismatch(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let vectorStore = F7StatusVectorStore(EmbeddingProviderState.READY, "", 16, count: 1)
        let kb = KnowledgeBase(FakeClock(0), DeterministicEmbeddingProvider(), vectorStore, LocalGraphStore())
        kb.configureVectorCollections("ckb_active", "ckb_candidate")
        kb.bootstrapOffline()
        _ = kb.verifyAndApplyVectorStoreStatus("ckb_active", 1)

        let task = CkbSchedulerTaskRunner(kb, config, FileKnowledgeStore("target/t-p5-b01-active-vector-invariant"), sourceRunner: FakeSourceFetchRunner()).runTask("docs_probe_30d", "0", ckbCoreNowMillis() + 60000)

        @Expect(task.ok, false)
        @Expect(task.status.contains("active_vector_invariant_failed") || task.status.contains("task_not_ok:active_vector_invariant_failed"), true)
        @Expect(ruDiagnosticsContain(task.validationDiagnostics, "active_vector_count_mismatch"), true)
    }

    @TestCase
    public func tP6B01BenchmarkGapCurationRejectsInvalidEncodingAndTooManyRecords(): Unit {
        let invalidRoot = "target/t-p6-b01-gap-invalid-encoding"
        s1s2EnsureEmptyDir(invalidRoot)
        let invalidPath = "${invalidRoot}/gap-curation-input.jsonl"
        File.writeTo(Path(invalidPath), [UInt8(255), UInt8(254), UInt8(253)])
        let invalidConfig = CkbRuntimeConfig()
        invalidConfig.benchmarkGapCurationInputPath = invalidPath
        let invalidService = CkbCommandLoopService(invalidConfig, FileKnowledgeStore("${invalidRoot}/store"))
        _ = invalidService.start()
        let invalidTasks = ArrayList<String>()
        invalidTasks.add("cangjie_benchmark_gap_curation")

        let invalid = invalidService.runSchedulerTasks(invalidTasks, true)

        @Expect(invalid.failed, 1)
        @Expect(invalid.details.contains("benchmark_gap_curation_input_invalid_encoding"), true)

        let limitRoot = "target/t-p6-b01-gap-record-limit"
        s1s2EnsureEmptyDir(limitRoot)
        var text = ""
        for (i in 0..201) {
            text += "{\"caseId\":\"CJ-HUMANEVAL-LIMIT-${i}\",\"benchmark\":\"Cangjie-HumanEval\",\"taskText\":\"Use ArrayList.add for visible input ${i}.\",\"visibleTestExcerpt\":\"assert solve([1,2]) == 3\",\"compilerOutput\":\"compile_error\",\"missingKnowledge\":\"G-ARRAYLIST\",\"interfaceId\":\"KI-02\",\"contentFamily\":\"KC-02\",\"updateMechanism\":\"KU-11\",\"targetVersion\":\"1.0.0\",\"officialCitation\":\"https://docs.cangjie-lang.cn/docs/1.0.0/libs/std/collection\"}\n"
        }
        let limitPath = "${limitRoot}/gap-curation-input.jsonl"
        File.writeTo(Path(limitPath), text.toArray())
        let limitConfig = CkbRuntimeConfig()
        limitConfig.benchmarkGapCurationInputPath = limitPath
        let limitService = CkbCommandLoopService(limitConfig, FileKnowledgeStore("${limitRoot}/store"))
        _ = limitService.start()
        let limitTasks = ArrayList<String>()
        limitTasks.add("cangjie_benchmark_gap_curation")

        let limited = limitService.runSchedulerTasks(limitTasks, true)

        @Expect(limited.failed, 1)
        @Expect(limited.details.contains("benchmark_gap_curation_record_limit_exceeded"), true)
        @Expect(f7SchedulerDiagnosticsContain(limited, "benchmark_gap_input_gate:accepted=201"), true)
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

    @TestCase
    public func ruP0PreflightUsesMetadataCountsWithoutLoadingFullActiveSnapshot(): Unit {
        let root = "target/ru-p0-preflight-lightweight-metadata"
        s1s2EnsureEmptyDir(root)
        let config = f7QdrantRoutineConfig()
        let embedding = DeterministicEmbeddingProvider(embeddingConfigFromRuntime(config))
        f7WriteFile(Path(root).join("metadata/status.ckb"), "active=ckb-active\ncandidate=ckb-candidate\nfailed=\nactiveStateSource=test\nrawCount=10\nnormalizedCount=10\nindexCount=10\nvectorIndexCount=10\nvectorBackend=qdrant\nvectorState=ready\nvectorActiveCollection=ckb_active\nvectorCandidateCollection=ckb_candidate\nvectorDimension=3\n")
        f7WriteFile(Path(root).join("metadata/active-snapshot.manifest"), "txId=tx-active\nactive=ckb-active\nvectorActiveCollection=ckb_active\ncommitted=true\n")
        f7WriteFile(Path(root).join("transactions/tx-active/COMMIT"), "ok\n")

        let result = ckbRoutineRuntimePreflightWithBootstrap(config, root, "4096M", "/opt/homebrew/opt/openssl@3/lib", F7StatusVectorStore(EmbeddingProviderState.READY, "", 3, count: 10), embedding)

        @Expect(result.ok, true)
        @Expect(ruDiagnosticsContain(result.diagnostics, "active_snapshot_invalid"), false)
        @Expect(ruDiagnosticsContain(result.diagnostics, "qdrant_active_count_mismatch"), false)
    }

    @TestCase
    public func p1CurrentPreRunGateRejectsWeeklyFullRebuildWhenEffectiveActiveCountMismatches(): Unit {
        let root = "target/p1-current-pre-run-gate-count-mismatch"
        let config = f7QdrantRoutineConfig()
        let embedding = DeterministicEmbeddingProvider(embeddingConfigFromRuntime(config))
        let kb = KnowledgeBase(FakeClock(0), embedding, LocalVectorStore(), LocalGraphStore())
        kb.configureVectorCollections("ckb_active_reconcile_ready", "ckb_candidate")
        kb.bootstrapOffline()
        let store = FileKnowledgeStore(root)
        _ = ckbRebuildIndex(kb, store)
        let taskNames = ArrayList<String>()
        taskNames.add("weekly_full_rebuild")

        let gate = ckbSchedulerPreRunGate(config, store, F7StatusVectorStore(EmbeddingProviderState.READY, "", 3, count: 1), taskNames)

        @Expect(gate.ok, false)
        @Expect(ruDiagnosticsContain(gate.diagnostics, "scheduler_pre_run_gate_failed:qdrant_active_count_mismatch:1:"), true)
        @Expect(ruDiagnosticsContain(gate.diagnostics, "ckb_active_reconcile_ready"), true)
    }

    @TestCase
    public func p4N4PreRunGateRejectsDocsFullWeeklyWhenEffectiveActiveCountMismatches(): Unit {
        let root = "target/p4-docs-pre-run-gate-count-mismatch"
        let config = f7QdrantRoutineConfig()
        let embedding = DeterministicEmbeddingProvider(embeddingConfigFromRuntime(config))
        let kb = KnowledgeBase(FakeClock(0), embedding, LocalVectorStore(), LocalGraphStore())
        kb.configureVectorCollections("ckb_active_reconcile_ready", "ckb_candidate")
        kb.bootstrapOffline()
        let store = FileKnowledgeStore(root)
        _ = ckbRebuildIndex(kb, store)
        let taskNames = ArrayList<String>()
        taskNames.add("cangjie_docs_full_weekly")

        let gate = ckbSchedulerPreRunGate(config, store, F7StatusVectorStore(EmbeddingProviderState.READY, "", 3, count: 1), taskNames)
        let blocked = ckbSchedulerPreRunGateFailureResult(gate, taskNames, true)

        @Expect(gate.ok, false)
        @Expect(ruDiagnosticsContain(gate.diagnostics, "scheduler_pre_run_gate_failed:qdrant_active_count_mismatch:1:"), true)
        @Expect(blocked.details.contains("task cangjie_docs_full_weekly ok=false status=scheduler_pre_run_gate_failed"), true)
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

private func s1s2RunnerSawTreePage(runner: S1S2PaginatedGitCodeRunner, page: Int64): Bool {
    for (call in runner.calls) {
        if (call.kind == SourceKinds.GITCODE_TREE && call.page == page) {
            return true
        }
    }
    false
}

private func s1s2RunnerSawRepoTreePage(runner: S1S2PaginatedGitCodeRunner, repo: String, page: Int64): Bool {
    for (call in runner.calls) {
        if (call.kind == SourceKinds.GITCODE_TREE && call.repo == repo && call.page == page) {
            return true
        }
    }
    false
}

private func s1s2RunnerSawRepo(runner: S1S2PaginatedGitCodeRunner, repo: String): Bool {
    for (call in runner.calls) {
        if (call.repo == repo) {
            return true
        }
    }
    false
}

private func s1s2RunnerSawSourcePath(runner: S1S2PaginatedGitCodeRunner, repo: String, path: String): Bool {
    for (call in runner.calls) {
        if (call.kind == SourceKinds.GITCODE_SOURCE && call.repo == repo && call.path == path) {
            return true
        }
    }
    false
}

private func s1s2RunnerAllBranchFetchesBeforeSamples(runner: S1S2PaginatedGitCodeRunner): Bool {
    var sawSample = false
    for (call in runner.calls) {
        if (call.kind == SourceKinds.GITCODE_TREE || call.kind == SourceKinds.GITCODE_SOURCE) {
            sawSample = true
        } else if (sawSample && call.kind == SourceKinds.GITCODE_BRANCH) {
            return false
        }
    }
    true
}

private func s1s2EnsureEmptyDir(path: String): Unit {
    if (exists(Path(path))) {
        _ = launch("/bin/rm", ["-rf", path]).wait()
    }
    Directory.create(Path(path), recursive: true)
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

private func f3FreshnessReportFromManifest(manifest: CangjieVersionManifest): CangjieCorpusFreshnessReport {
    f3FreshnessReportFromManifestWithMissingIndexedAt(manifest, "")
}

private func f3FreshnessReportFromManifestWithMissingIndexedAt(manifest: CangjieVersionManifest, missingIndexedAtSourceSet: String): CangjieCorpusFreshnessReport {
    let report = CangjieCorpusFreshnessReport()
    report.ok = true
    report.degraded = false
    report.targetVersion = manifest.defaultTargetVersion
    for (source in manifest.sources) {
        let item = CangjieCorpusFreshnessSource()
        item.sourceSet = source.sourceSet
        item.sourceFamily = source.sourceFamily
        item.sourceRepo = source.sourceRepo
        item.sourceRef = source.sourceRef
        item.refKind = source.refKind
        item.resolvedCommit = source.resolvedCommit
        item.contentHash = source.contentHash
        item.targetVersion = source.targetVersion
        item.crawlAt = "scheduled:test"
        item.indexedAt = if (source.sourceSet == missingIndexedAtSourceSet) { "" } else { source.resolvedCommit }
        item.staleness = "fresh"
        item.status = "fresh"
        report.sources.add(item)
    }
    report
}

private func f3FreshnessSourceHasState(report: CangjieCorpusFreshnessReport, sourceSet: String, staleness: String, status: String): Bool {
    for (source in report.sources) {
        if (source.sourceSet == sourceSet && source.staleness == staleness && source.status == status) {
            return true
        }
    }
    false
}

private func f3FreshnessSourceHasHash(report: CangjieCorpusFreshnessReport, sourceSet: String, contentHash: String, resolvedCommit: String): Bool {
    for (source in report.sources) {
        if (source.sourceSet == sourceSet && source.contentHash == contentHash && source.resolvedCommit == resolvedCommit) {
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

    public func upsertBatchWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
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

    public func recreateWithDeadline(collection: String, vectors: ArrayList<VectorRecord>, deadlineAtMillis: Int64): VectorStoreStatus {
        this.status(collection)
    }

    public func backup(collection: String): VectorBackup {
        let backup = VectorBackup()
        backup.collection = collection
        backup.valid = false
        backup.diagnostic = this.reason
        backup
    }

    public func backupWithDeadline(collection: String, deadlineAtMillis: Int64): VectorBackup {
        this.backup(collection)
    }

    public func restore(backup: VectorBackup): VectorStoreStatus {
        this.status(backup.collection)
    }
}

private class P5S1ToggleFailEmbeddingProvider <: EmbeddingProvider {
    private let delegate: DeterministicEmbeddingProvider = DeterministicEmbeddingProvider()
    public var fail: Bool = false

    public init() {}

    public func embed(texts: ArrayList<String>, model: String, dimensions: Int64): EmbeddingBatch {
        if (!this.fail) {
            return this.delegate.embed(texts, model, dimensions)
        }
        let batch = EmbeddingBatch()
        batch.requested = texts.size
        batch.failed = texts.size
        batch.status = this.status()
        batch.status.state = EmbeddingProviderState.DOWN
        batch.status.degradedReason = "ollama_timeout"
        batch.lastDiagnostic = "ollama_timeout"
        batch
    }

    public func embedWithDeadline(texts: ArrayList<String>, model: String, dimensions: Int64, deadlineAtMillis: Int64): EmbeddingBatch {
        this.embed(texts, model, dimensions)
    }

    public func status(): EmbeddingStatus {
        this.delegate.status()
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

private class DeadlineCountingFetchRunner <: SourceFetchRunner {
    public var calls: Int64 = 0

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls += 1
        let result = SourceFetchResult()
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        result.sourceUrl = request.url
        result.normalizedType = request.kind
        result.body = "deadline runner should not be called"
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

private class F3ToolsHashChangedFreshnessRunner <: SourceFetchRunner {
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
        result.lastModified = "2026-07-09T00:00:00Z"
        if (request.repo == "Cangjie/cangjie_tools") {
            result.commit = "changed-tools"
            result.body = "changed tools source hash"
        } else {
            result.commit = f3ExpectedFreshnessCommit(request)
            result.body = "unchanged freshness ${request.kind} ${request.repo}"
        }
        result.bodyHash = stableSummaryHash(result.body)
        result
    }
}

private func f3ExpectedFreshnessCommit(request: SourceFetchRequest): String {
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

private class S1S2PaginatedGitCodeRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()
    public var directoriesOnly: Bool = false
    public var failTreePage2: Bool = false
    public var failToolsTreePage9Transport: Bool = false
    public var failContentSamples: Bool = false
    public var failRefRepo: String = ""
    public var toolsCandidateAfterTenDirectoryPages: Bool = false

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
        if (request.kind == SourceKinds.GITCODE_BRANCH && this.failRefRepo == request.repo) {
            result.ok = false
            result.status = "gitcode_ref_fixture_failed"
            result.statusCode = 500
            result.body = result.status
        } else if (request.kind == SourceKinds.GITCODE_BRANCH && request.purpose == "branch_ref") {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.commit = f7GenericResolvedCommit()
            result.body = "{\"name\":\"${request.ref}\",\"commit\":{\"id\":\"${f7GenericResolvedCommit()}\",\"sha\":\"${f7GenericResolvedCommit()}\"}}"
        } else if (request.kind == SourceKinds.GITCODE_BRANCH) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.commit = f7GenericResolvedCommit()
            result.body = f7GenericBranchListBody()
        } else if (request.kind == SourceKinds.GITCODE_TREE && this.failToolsTreePage9Transport && request.repo == "Cangjie/cangjie_tools" && request.page == 9) {
            result.ok = false
            result.status = "transport_error"
            result.statusCode = 0
            result.transportErrorClass = "timeout"
            result.transportDiagnostic = "native request timed out"
            result.body = "tools tree page 9 timeout"
        } else if (request.kind == SourceKinds.GITCODE_TREE && this.failTreePage2 && request.page == 2) {
            result.ok = false
            result.status = "server_error"
            result.statusCode = 500
            result.body = "tree page 2 failed"
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.commit = f7GenericResolvedCommit()
            result.body = this.treeBody(request)
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && this.failContentSamples) {
            result.ok = false
            result.status = "content_sample_unavailable"
            result.statusCode = 503
            result.contentType = "text/plain"
            result.body = result.status
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.path.endsWith(".cj")) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = f7GenericResolvedCommit()
            result.contentType = "text/plain"
            result.body = "package scheduled\npublic func scheduled_${stableSummaryHash(request.path)}(): Unit {}\n"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = f7GenericResolvedCommit()
            result.contentType = "text/markdown"
            result.body = "# Scheduled source\nArrayList.add HashMap String.contains cjpm test Cangjie docs tutorial\n"
        } else if (request.kind == SourceKinds.CANGJIE_DOCS) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = f7GenericResolvedCommit()
            result.contentType = "text/html"
            result.body = "<html><body>Cangjie docs ArrayList HashMap</body></html>"
        } else {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = f7GenericResolvedCommit()
            result.contentType = "text/plain"
            result.body = "scheduled ${request.kind} ${request.repo}"
        }
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result
    }

    private func treeBody(request: SourceFetchRequest): String {
        if (this.failToolsTreePage9Transport && request.repo == "Cangjie/cangjie_tools" && request.page < 9) {
            return "{\"tree\":[{\"path\":\"tools/page-${request.page}\",\"type\":\"tree\"},{\"path\":\"docs/page-${request.page}\",\"type\":\"tree\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
        }
        if (this.toolsCandidateAfterTenDirectoryPages && request.repo == "Cangjie/cangjie_tools") {
            if (request.page <= 10) {
                return "{\"tree\":[{\"path\":\"tools/page-${request.page}\",\"type\":\"tree\"},{\"path\":\"docs/page-${request.page}\",\"type\":\"tree\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
            }
            if (request.page == 11) {
                return "{\"tree\":[{\"path\":\"target/generated/ignored.md\",\"type\":\"blob\"},{\"path\":\"docs/tools/cjpm_manual.md\",\"type\":\"blob\"},{\"path\":\"src/tools/generated_runner.cj\",\"type\":\"blob\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
            }
            return "{\"tree\":[],\"sha\":\"${f7GenericResolvedCommit()}\"}"
        }
        if (this.directoriesOnly) {
            if (request.page <= 2) {
                return "{\"tree\":[{\"path\":\"runtime\",\"type\":\"tree\"},{\"path\":\"docs\",\"type\":\"tree\"},{\"path\":\"tools\",\"type\":\"tree\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
            }
            return "{\"tree\":[],\"sha\":\"${f7GenericResolvedCommit()}\"}"
        }
        if (request.page == 1) {
            return "{\"tree\":[{\"path\":\"runtime\",\"type\":\"tree\"},{\"path\":\"docs\",\"type\":\"tree\"},{\"path\":\"tools\",\"type\":\"tree\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
        }
        if (request.page == 2) {
            if (request.repo == "Cangjie/cangjie_docs") {
                return "{\"tree\":[{\"path\":\"docs/guide.md\",\"type\":\"blob\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
            }
            if (request.repo == "Cangjie/cangjie_runtime") {
                return "{\"tree\":[{\"path\":\"README.md\",\"type\":\"blob\"},{\"path\":\"cjpm.toml\",\"type\":\"blob\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
            }
            if (request.repo == "Cangjie/cangjie_stdx") {
                return "{\"tree\":[{\"path\":\"doc/http.md\",\"type\":\"blob\"},{\"path\":\"src/stdx/http/client.cj\",\"type\":\"blob\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
            }
            if (request.repo == "Cangjie/cangjie_tools") {
                return "{\"tree\":[{\"path\":\"tools/README.md\",\"type\":\"blob\"},{\"path\":\"tools/runner.cj\",\"type\":\"blob\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
            }
            return "{\"tree\":[{\"path\":\"README.md\",\"type\":\"blob\"}],\"sha\":\"${f7GenericResolvedCommit()}\"}"
        }
        "{\"tree\":[],\"sha\":\"${f7GenericResolvedCommit()}\"}"
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
    public var escapedSlashTreePath: Bool = false

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
        } else if (request.kind == SourceKinds.GITCODE_TREE && this.escapedSlashTreePath && request.repo == "Cangjie/cangjie_tools") {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.commit = f7SlashRefResolvedCommit()
            result.body = "{\"tree\":[{\"path\":\"target\\/generated\\/ignored.md\",\"type\":\"blob\"},{\"path\":\"docs\\/std\\/stdx\\/tools\\/eval-support\\/README.md\",\"type\":\"blob\"}],\"sha\":\"${result.commit}\"}"
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

private func f7RunnerSawSourcePath(runner: F7SlashRefTreeOkRunner, repo: String, path: String): Bool {
    for (call in runner.calls) {
        if (call.kind == SourceKinds.GITCODE_SOURCE && call.repo == repo && call.path == path) {
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
