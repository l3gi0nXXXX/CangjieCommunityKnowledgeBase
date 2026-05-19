package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.unittest.*
import std.unittest.testmacro.*

@Test
public class CkbBaselineTest {
    @TestCase
    public func defaultSourceScopeCoversPhase10Sources(): Unit {
        let kb = newOfflineKnowledgeBase()
        let status = cangjie_knowledge_status(kb)

        @Expect(status.sourceScope.repoScope, "all-public-repos")
        @Expect(status.sourceScope.organizations.size, 3)
        @Expect(status.sourceScope.organizations[0], "cangjie")
        @Expect(status.sourceScope.organizations[1], "cangjie-sig")
        @Expect(status.sourceScope.organizations[2], "cangjie-tpc")
        @Expect(status.sourceScope.websiteUrls[0], "https://cangjie-lang.cn/")
        @Expect(status.sourceScope.docsUrls[0], "https://docs.cangjie-lang.cn/docs/1.0.0/")
        @Expect(status.sourceScope.stdSources.size, 2)
        @Expect(status.sourceScope.includesIssuePrHistory, true)
        @Expect(status.sourceScope.includesGovernedWebCandidates, true)
        @Expect(status.sourceScope.excludesPrivateRepos, true)
    }

    @TestCase
    public func storageDoctorReportsLayeredPathsWithoutAbsoluteMirrorPath(): Unit {
        let kb = newOfflineKnowledgeBase()
        let doctor = renderDoctor(cangjie_knowledge_status(kb))

        @Expect(doctor.contains("data/raw"), true)
        @Expect(doctor.contains("data/normalized"), true)
        @Expect(doctor.contains("data/metadata"), true)
        @Expect(doctor.contains("data/indexes"), true)
        @Expect(doctor.contains("data/derived"), true)
        @Expect(doctor.contains("data/cache"), true)
        @Expect(doctor.contains("/Users/l3gi0n"), false)
        @Expect(doctor.contains("localPathRedacted=true"), true)
    }

    @TestCase
    public func evidenceApisReturnTypedEvidenceAndReviewFlags(): Unit {
        let kb = newOfflineKnowledgeBase()

        let doc = cangjie_doc_search(kb, "func named parameters", 5)
        let source = cangjie_source_search(kb, "HttpClient", 5)
        let website = cangjie_website_search(kb, "download tools", 5)
        let candidate = cangjie_web_candidate_search(kb, "third party tutorial", 5)
        let pack = cangjie_evidence_pack(kb, "func HttpClient download tutorial", 2)

        @Expect(doc.records.size > 0, true)
        @Expect(source.records.size > 0, true)
        @Expect(website.records.size > 0, true)
        @Expect(candidate.records.size > 0, true)
        @Expect(candidate.records[0].requiresReview, true)
        @Expect(pack.knowledgeVersion.contains("ckb-"), true)
        @Expect(pack.docEvidence.size > 0, true)
        @Expect(pack.sourceEvidence.size > 0, true)
        @Expect(pack.websiteEvidence.size > 0, true)
        @Expect(pack.webCandidateEvidence.size > 0, true)
        @Expect(pack.webCandidateEvidence[0].requiresReview, true)
    }

    @TestCase
    public func hybridSearchFiltersCandidatesByDefaultAndCanTruncate(): Unit {
        let kb = newOfflineKnowledgeBase()
        let hybrid = cangjie_hybrid_search(kb, "tutorial", 5)
        let candidate = cangjie_web_candidate_search(kb, "tutorial", 1)
        let truncated = cangjie_hybrid_search(kb, "Cangjie", 1)

        @Expect(hybrid.records.size, 0)
        @Expect(candidate.records.size, 1)
        @Expect(candidate.records[0].metadata.reviewState, ReviewStates.CANDIDATE)
        @Expect(truncated.truncated, true)
    }

    @TestCase
    public func failedCandidateIndexDoesNotReplaceActiveVersion(): Unit {
        let kb = newOfflineKnowledgeBase()
        let before = cangjie_knowledge_status(kb).activeKnowledgeVersion
        let ok = kb.publishIndex(true)
        let after = cangjie_knowledge_status(kb)

        @Expect(ok, false)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(after.failedCandidateVersion.contains("candidate"), true)
        @Expect(cangjie_source_search(kb, "HttpClient", 5).records.size > 0, true)
    }

    @TestCase
    public func schedulerSlaUsesFakeClockAndFailureBackoff(): Unit {
        let clock = FakeClock(0)
        let scheduler = Scheduler(clock)
        @Expect(scheduler.dueTaskNames().contains("repo_list_6h"), true)
        @Expect(scheduler.dueTaskNames().contains("active_item_sync_10m"), true)

        scheduler.markSuccess("active_item_sync_10m")
        @Expect(scheduler.dueTaskNames().contains("active_item_sync_10m"), false)
        clock.advance(10)
        @Expect(scheduler.dueTaskNames().contains("active_item_sync_10m"), true)

        scheduler.markFailure("active_repo_fetch_30m")
        @Expect(scheduler.entries[4].nextRunAt, 15)
        scheduler.markFailure("active_repo_fetch_30m")
        @Expect(scheduler.entries[4].nextRunAt, 25)
        scheduler.markFailure("active_repo_fetch_30m")
        @Expect(scheduler.entries[4].nextRunAt, 70)
        @Expect(scheduler.entries[4].degraded, true)
    }

    @TestCase
    public func schedulerEncodesRequiredR8R9SlaWindows(): Unit {
        let scheduler = Scheduler(FakeClock(0))

        @Expect(intervalFor(scheduler, "active_item_sync_10m"), 10)
        @Expect(intervalFor(scheduler, "active_repo_fetch_30m"), 30)
        @Expect(intervalFor(scheduler, "website_probe_6h"), 360)
        @Expect(intervalFor(scheduler, "docs_probe_6h"), 360)
        @Expect(intervalFor(scheduler, "website_full_daily"), 1440)
        @Expect(intervalFor(scheduler, "weekly_full_rebuild"), 10080)
        @Expect(intervalFor(scheduler, "web_candidate_recrawl_30d"), 43200)
    }

    @TestCase
    public func scopedRefreshPoliciesApplyCooldownAndCandidateReview(): Unit {
        let service = ScopedRefreshService()
        let active = "ckb-20260519-000100-active"

        let useActive = service.apply(FreshnessPolicies.USE_ACTIVE, "cangjie/stdx", "main", 0, active)
        let recent = service.apply(FreshnessPolicies.ENSURE_RECENT, "cangjie/stdx", "main", 10, active)
        let limited = service.apply(FreshnessPolicies.ENSURE_REF, "cangjie/stdx", "feature", 12, active)
        let candidate = service.apply(FreshnessPolicies.FORCE_CANDIDATE, "cangjie/stdx", "feature", 20, active)

        @Expect(useActive.status, "active")
        @Expect(recent.status, "fresh")
        @Expect(limited.status, "refresh_limited")
        @Expect(limited.blocked, true)
        @Expect(candidate.status, "candidate")
        @Expect(candidate.requiresReview, true)
    }

    @TestCase
    public func offlineCurationLifecycleRequiresSourceReferences(): Unit {
        let queue = CurationQueue()
        let emptyRefs = ArrayList<SourceReference>()
        let noRefs = queue.enqueueRepoSummary("cangjie/stdx", emptyRefs)
        @Expect(queue.start(noRefs.taskId), true)
        @Expect(queue.complete(noRefs.taskId, "summary without references"), false)

        let refs = ArrayList<SourceReference>()
        refs.add(SourceReference("source-http-client", "cangjie/stdx:src/http/client.cj#HttpClient", "ckb-20260519-000100-active"))
        let task = queue.enqueueRepoSummary("cangjie/stdx", refs)
        @Expect(task.status, "pending")
        @Expect(queue.start(task.taskId), true)
        @Expect(queue.complete(task.taskId, "HttpClient summary"), true)
        @Expect(task.status, "succeeded")
        @Expect(task.sourceReferences.size, 1)
    }

    @TestCase
    public func sourceAdapterDefaultsToOfflineAndFakeRunnerIsInjectable(): Unit {
        let disabled = SourceAdapter()
        let blocked = disabled.fetchGitCodeRepo("cangjie/stdx")
        @Expect(blocked.ok, false)
        @Expect(blocked.status, "network_disabled")

        let fake = FakeSourceFetchRunner()
        let adapter = SourceAdapter(runner: fake)
        let source = adapter.fetchGitCodeSource("cangjie/stdx", "main", "src/http/client.cj")
        @Expect(source.ok, true)
        @Expect(source.body.contains("HttpClient"), true)
        @Expect(fake.calls.size, 1)
        @Expect(fake.calls[0].kind, SourceKinds.GITCODE_SOURCE)
    }

    @TestCase
    public func sourceRequestBuildersUseProductionApiSpecsAndNormalizeResponses(): Unit {
        let builder = SourceRequestBuilder()
        let source = builder.gitCodeSource("cangjie/stdx", "main", "src/http/client.cj")
        let issues = builder.gitCodeIssueHistory("cangjie/cangjie")
        let docs = builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/")
        let normalizer = SourceResponseNormalizer()
        let result = SourceFetchResult()
        result.statusCode = 206
        result.body = "partial source"

        let normalized = normalizer.normalize(source, result)

        @Expect(source.method, "GET")
        @Expect(source.url.contains("/api/v5/projects/cangjie/stdx/repository/files/src/http/client.cj/raw?ref=main"), true)
        @Expect(source.accept, "text/plain")
        @Expect(source.authHint.contains("redacted"), true)
        @Expect(issues.url.contains("state=all"), true)
        @Expect(issues.perPage, 100)
        @Expect(docs.accept, "text/html")
        @Expect(normalized.ok, true)
        @Expect(normalized.status, "ok")
        @Expect(normalized.normalizedType, SourceKinds.GITCODE_SOURCE)
        @Expect(normalized.sourceUrl, source.url)
    }

    @TestCase
    public func sourceSyncPlannerCoversThreeOrgsDocsWebsiteHistoryAndCandidates(): Unit {
        let scope = SourceScope()
        let plan = SourceSyncPlanner().productionPlan(scope)
        var orgs: Int64 = 0
        var websites: Int64 = 0
        var docs: Int64 = 0
        var issueHistory: Int64 = 0
        var prHistory: Int64 = 0
        var candidates: Int64 = 0
        for (request in plan.requests) {
            if (request.kind == SourceKinds.GITCODE_ORG) {
                orgs += 1
            }
            if (request.kind == SourceKinds.CANGJIE_WEBSITE) {
                websites += 1
            }
            if (request.kind == SourceKinds.CANGJIE_DOCS) {
                docs += 1
            }
            if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY) {
                issueHistory += 1
            }
            if (request.kind == SourceKinds.GITCODE_PR_HISTORY) {
                prHistory += 1
            }
            if (request.kind == SourceKinds.WEB_CANDIDATE) {
                candidates += 1
            }
        }

        @Expect(orgs, 3)
        @Expect(websites, scope.websiteUrls.size)
        @Expect(docs, scope.docsUrls.size)
        @Expect(issueHistory, 1)
        @Expect(prHistory, 1)
        @Expect(candidates, 1)
        @Expect(plan.requests.size >= 11, true)
    }

    @TestCase
    public func fileStoragePersistsRawNormalizedMetadataIndexDerivedAndCache(): Unit {
        let kb = newOfflineKnowledgeBase()
        let store = FileKnowledgeStore("target/ckb-test-storage")
        kb.persist(store)
        let rebuild = ckbRebuildIndex(kb, store)

        let refs = ArrayList<SourceReference>()
        refs.add(SourceReference("doc-syntax", "https://docs.cangjie-lang.cn/docs/1.0.0/language/functions", "ckb-20260519-000100-active"))
        let task = CurationTask()
        task.taskId = "curation-storage"
        task.kind = "repo_summary"
        task.repo = "cangjie/stdx"
        task.status = "succeeded"
        task.sourceReferences = refs
        task.derivedKnowledge = "derived with source references"
        store.saveDerived(task)
        store.saveCache("query func", "cached")

        @Expect(rebuild.ok, true)
        @Expect(store.has("raw/records.ckb"), true)
        @Expect(store.has("normalized/records.ckb"), true)
        @Expect(store.has("metadata/status.ckb"), true)
        @Expect(store.has("index/active.ckb"), true)
        @Expect(store.has("derived/curation-storage.ckb"), true)
        @Expect(store.has("cache/query func.txt"), true)
        @Expect(store.loadRaw().size, kb.rawRecordCount())
        @Expect(store.loadNormalized().size, kb.normalizedRecordCount())
    }

    @TestCase
    public func statusAndMetadataExposeDeterministicIndexManifest(): Unit {
        let kb = newOfflineKnowledgeBase()
        let store = FileKnowledgeStore("target/ckb-test-index-manifest")
        kb.persist(store)
        let status = cangjie_knowledge_status(kb)
        var textSeen = false
        var vectorSeen = false
        var symbolSeen = false
        var graphSeen = false
        for (entry in status.indexManifest.entries) {
            if (entry.kind == IndexKinds.TEXT) {
                textSeen = true
            }
            if (entry.kind == IndexKinds.VECTOR) {
                vectorSeen = true
            }
            if (entry.kind == IndexKinds.SYMBOL) {
                symbolSeen = true
            }
            if (entry.kind == IndexKinds.GRAPH) {
                graphSeen = true
            }
            @Expect(entry.deterministic, true)
            @Expect(entry.candidateIsolated, true)
        }

        @Expect(status.storage.textIndexCount > 0, true)
        @Expect(status.storage.vectorIndexCount > 0, true)
        @Expect(status.storage.symbolIndexCount > 0, true)
        @Expect(status.storage.graphIndexCount > 0, true)
        @Expect(textSeen, true)
        @Expect(vectorSeen, true)
        @Expect(symbolSeen, true)
        @Expect(graphSeen, true)
        @Expect(store.has("metadata/status.ckb"), true)
    }

    @TestCase
    public func syncOnceIngestsAllSourceFamiliesWithoutNetworkByDefault(): Unit {
        let kb = newOfflineKnowledgeBase()
        let fake = FakeSourceFetchRunner()
        let store = FileKnowledgeStore("target/ckb-test-sync")
        let text = ckbSyncOnce(kb, SourceAdapter(runner: fake), store)
        let query = QueryService(kb)
        let candidates = query.query("web_candidate", "tutorial", 10)

        @Expect(text.contains("org=ok"), true)
        @Expect(text.contains("requests="), true)
        @Expect(fake.calls.size >= 11, true)
        @Expect(kb.rawRecordCount() >= 14, true)
        @Expect(candidates.records.size > 0, true)
        @Expect(candidates.records[0].requiresReview, true)
        @Expect(store.has("raw/records.ckb"), true)
    }

    @TestCase
    public func queryServiceAppliesTrustReviewAndCandidateFilters(): Unit {
        let kb = newOfflineKnowledgeBase()
        let service = QueryService(kb)
        let officialDocs = service.query("doc", "func", 5, trustLevel: TrustLevels.OFFICIAL, reviewState: ReviewStates.TRUSTED)
        let blockedCandidates = service.query("hybrid", "tutorial", 5, includeCandidates: false)
        let allowedCandidates = service.query("web_candidate", "tutorial", 5)
        let noCandidateEvidence = service.evidence("tutorial", 5, includeCandidates: false)

        @Expect(officialDocs.records.size > 0, true)
        @Expect(blockedCandidates.records.size, 0)
        @Expect(allowedCandidates.records.size > 0, true)
        @Expect(noCandidateEvidence.webCandidateEvidence.size, 0)
    }

    @TestCase
    public func schemaListsMcpToolsAndHttpLikeRoutes(): Unit {
        @Expect(CkbSchema.mcpTools().contains("cangjie.evidence_pack"), true)
        @Expect(CkbSchema.mcpTools().contains("cangjie.status"), true)
        @Expect(CkbSchema.httpLikeRoutes().contains("POST /query"), true)
        @Expect(CkbSchema.httpLikeRoutes().contains("POST /rebuild-index"), true)
    }
}

private func intervalFor(scheduler: Scheduler, name: String): Int64 {
    for (entry in scheduler.entries) {
        if (entry.name == name) {
            return entry.intervalMinutes
        }
    }
    -1
}
