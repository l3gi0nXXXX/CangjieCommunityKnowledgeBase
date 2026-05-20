package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.fs.{File, Path}
import std.unittest.*
import std.unittest.testmacro.*

class SourceAnalysisFakeRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()
    public var rawStatusCode: Int64 = 200
    public var contentsStatusCode: Int64 = 200
    public var body: String = "func targetSymbol() { println(\"ok\") }"
    public var sourceUrlSuffix: String = ""

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        let statusCode = if (request.purpose == "source_raw") { this.rawStatusCode } else { this.contentsStatusCode }
        result.ok = statusCode >= 200 && statusCode < 300
        result.statusCode = statusCode
        result.status = if (result.ok) { "ok" } else { "not_found" }
        result.body = if (result.ok) { this.body } else { "" }
        result.commit = "fake-analysis-commit"
        result.sourceUrl = request.url + this.sourceUrlSuffix
        result.normalizedType = request.kind
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result
    }
}

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

        let invalid = adapter.fetchGitCodeSource("cangjie/stdx/extra", "main", "src/http/client.cj")
        @Expect(invalid.ok, false)
        @Expect(invalid.status, "invalid_repo_path")
        @Expect(invalid.sourceUrl, "")
        @Expect(fake.calls.size, 1)
    }

    @TestCase
    public func sourceRequestBuildersUseProductionApiSpecsAndNormalizeResponses(): Unit {
        let config = CkbRuntimeConfig()
        let builder = SourceRequestBuilder()
        let org = builder.gitCodeOrgRepos("cangjie")
        let repo = builder.gitCodeRepo("cangjie/stdx")
        let cangjieRepo = builder.gitCodeRepo("cangjie/cangjie")
        let source = builder.gitCodeSource("cangjie/stdx", "main", "src/http/client.cj")
        let cangjieSource = builder.gitCodeSource("cangjie/cangjie", "main", "src/main.cj")
        let issues = builder.gitCodeIssueHistory("cangjie/cangjie")
        let pulls = builder.gitCodePrHistory("cangjie/cangjie")
        let invalidRepo = builder.gitCodeRepo("cangjie/stdx/extra")
        let invalidPath = builder.gitCodeSource("cangjie/stdx", "main", "../secret.txt")
        let encodedTraversalPath = builder.gitCodeSource("cangjie/stdx", "main", "src/%2e%2e/secret.txt")
        let docs = builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/")
        let normalizer = SourceResponseNormalizer()
        let result = SourceFetchResult()
        result.statusCode = 206
        result.body = "partial source"

        let normalized = normalizer.normalize(source, result)

        @Expect(config.gitCodeBaseUrl, "https://api.gitcode.com/api/v5")
        @Expect(org.url, "https://api.gitcode.com/api/v5/orgs/cangjie/repos?type=public&page=1&per_page=100")
        @Expect(repo.url, "https://api.gitcode.com/api/v5/repos/cangjie/stdx?ref=main")
        @Expect(cangjieRepo.url, "https://api.gitcode.com/api/v5/repos/cangjie/cangjie?ref=main")
        @Expect(source.method, "GET")
        @Expect(source.url, "https://api.gitcode.com/api/v5/repos/cangjie/stdx/contents/src/http/client.cj?ref=main")
        @Expect(cangjieSource.url, "https://api.gitcode.com/api/v5/repos/cangjie/cangjie/contents/src/main.cj?ref=main")
        @Expect(source.accept, "text/plain")
        @Expect(source.authHint.contains("redacted"), true)
        @Expect(issues.url, "https://api.gitcode.com/api/v5/repos/cangjie/cangjie/issues?state=all&page=1&per_page=100")
        @Expect(pulls.url, "https://api.gitcode.com/api/v5/repos/cangjie/cangjie/pulls?state=all&page=1&per_page=100")
        @Expect(source.url.contains("/projects/"), false)
        @Expect(pulls.url.contains("merge_requests"), false)
        @Expect(issues.perPage, 100)
        @Expect(invalidRepo.status, "invalid_repo_path")
        @Expect(invalidRepo.diagnostic, "invalid_repo_path")
        @Expect(invalidRepo.url, "")
        @Expect(invalidRepo.repo, "")
        @Expect(invalidPath.status, "invalid_source_path")
        @Expect(invalidPath.url, "")
        @Expect(invalidPath.path, "")
        @Expect(encodedTraversalPath.status, "invalid_source_path")
        @Expect(encodedTraversalPath.url, "")
        @Expect(docs.accept, "text/html")
        @Expect(normalized.ok, true)
        @Expect(normalized.status, "ok")
        @Expect(normalized.normalizedType, SourceKinds.GITCODE_SOURCE)
        @Expect(normalized.sourceUrl, source.url)
    }

    @TestCase
    public func sourceAnalysisSchemaAndClassifierCoverSrc0Src1Triggers(): Unit {
        let schema = CkbSchema.mcpTools()
        @Expect(schema.contains("source_analysis"), true)
        @Expect(schema.contains("repo,ref,query,issueUrl,prUrl,changedFiles,candidatePaths,allowCloneFallback,maxFiles,maxBytes,timeoutMillis"), true)

        let classifier = SourceAnalysisTriggerClassifier()
        let summary = SourceAnalysisRequest()
        summary.query = "please summarize this issue"
        @Expect(classifier.classify(summary).shouldAnalyze, false)

        let filePath = SourceAnalysisRequest()
        filePath.query = "compile error in src/foo/bar.cj:12"
        let fileDecision = classifier.classify(filePath)
        @Expect(fileDecision.shouldAnalyze, true)
        @Expect(fileDecision.triggerReasons.contains(SourceAnalysisTriggerReasons.FILE_PATH_MENTIONED), true)
        @Expect(fileDecision.triggerReasons.contains(SourceAnalysisTriggerReasons.COMPILE_ERROR), true)

        let stack = SourceAnalysisRequest()
        stack.query = "panic stack trace at module.func src/main.cj:44"
        let stackDecision = classifier.classify(stack)
        @Expect(stackDecision.shouldAnalyze, true)
        @Expect(stackDecision.triggerReasons.contains(SourceAnalysisTriggerReasons.STACK_TRACE), true)

        let changed = SourceAnalysisRequest()
        changed.changedFiles.add("src/lib.cj")
        let changedDecision = classifier.classify(changed)
        @Expect(changedDecision.shouldAnalyze, true)
        @Expect(changedDecision.triggerReasons.contains(SourceAnalysisTriggerReasons.PR_DIFF_REVIEW), true)

        let insufficient = SourceAnalysisRequest()
        insufficient.query = "need answer"
        let insufficientDecision = classifier.classify(insufficient, hasSourceEvidence: false)
        @Expect(insufficientDecision.shouldAnalyze, true)
        @Expect(insufficientDecision.triggerReasons.contains(SourceAnalysisTriggerReasons.INSUFFICIENT_SOURCE_EVIDENCE), true)
        @Expect(insufficientDecision.degraded, true)
    }

    @TestCase
    public func sourceAnalysisApiRawReadsChangedFilesWithoutClone(): Unit {
        let request = SourceAnalysisRequest()
        request.repo = "cangjie/stdx"
        request.ref = "main"
        request.query = "review changed files"
        request.changedFiles.add("src/a.cj")
        request.changedFiles.add("src/b.cj")
        request.maxFiles = 1
        request.allowCloneFallback = false
        let runner = SourceAnalysisFakeRunner()

        let result = ckbSourceAnalysis(request, runner: runner)

        @Expect(result.sourceAcquisition, SourceAnalysisAcquisition.API_RAW)
        @Expect(result.filesRead.size, 1)
        @Expect(result.filesRead[0].path, "src/a.cj")
        @Expect(result.filesRead[0].bodyHash, stableSummaryHash(runner.body))
        @Expect(result.citations[0], "https://gitcode.com/cangjie/stdx/-/blob/main/src/a.cj")
        @Expect(runner.calls.size, 1)
        @Expect(runner.calls[0].purpose, "source_raw")
        @Expect(result.diagnostic.contains("clone"), false)
    }

    @TestCase
    public func sourceAnalysisFallsBackFromRawToContentsAndRedactsOutput(): Unit {
        let request = SourceAnalysisRequest()
        request.repo = "cangjie/stdx"
        request.ref = "main"
        request.query = "source_analysis src/http/client.cj"
        request.allowCloneFallback = false
        let runner = SourceAnalysisFakeRunner()
        runner.rawStatusCode = 404
        runner.contentsStatusCode = 200
        runner.sourceUrlSuffix = "?access_token=secret-token"

        let result = ckbSourceAnalysis(request, runner: runner)
        let rendered = renderSourceAnalysis(result)

        @Expect(result.sourceAcquisition, SourceAnalysisAcquisition.API_CONTENTS)
        @Expect(result.filesRead.size, 1)
        @Expect(runner.calls.size, 2)
        @Expect(runner.calls[0].purpose, "source_raw")
        @Expect(runner.calls[1].purpose, "source_snapshot")
        @Expect(rendered.contains("secret-token"), false)
        @Expect(rendered.contains("[redacted]"), true)
    }

    @TestCase
    public func sourceAnalysisDegradesWithoutCloneFallbackAndBlocksPrivateRepos(): Unit {
        let request = SourceAnalysisRequest()
        request.repo = "cangjie/stdx"
        request.ref = "main"
        request.query = "source_analysis src/missing.cj"
        request.allowCloneFallback = false
        let runner = SourceAnalysisFakeRunner()
        runner.rawStatusCode = 404
        runner.contentsStatusCode = 404

        let result = ckbSourceAnalysis(request, runner: runner, hasSourceEvidence: false)

        @Expect(result.degraded, true)
        @Expect(result.diagnostic.contains("clone_fallback_disabled"), true)
        @Expect(result.sourceAcquisition, SourceAnalysisAcquisition.NONE)
        @Expect(runner.calls.size, 2)

        let privateRequest = SourceAnalysisRequest()
        privateRequest.repo = "cangjie/private"
        privateRequest.query = "source_analysis src/main.cj"
        privateRequest.repoVisibility = RepoVisibility.PRIVATE
        let blockedRunner = SourceAnalysisFakeRunner()
        let blocked = ckbSourceAnalysis(privateRequest, runner: blockedRunner)
        @Expect(blocked.degraded, true)
        @Expect(blocked.diagnostic, "blocked_non_public_repo")
        @Expect(blockedRunner.calls.size, 0)
    }

    @TestCase
    public func syncLiveDoesNotInvokeSourceAnalysisRawPath(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        let options = LiveSyncOptions()
        options.dryRun = true
        options.maxItems = 1
        let runner = SourceAnalysisFakeRunner()

        let text = ckbSyncLive(kb, config, options, runner: runner, store: FileKnowledgeStore("target/ckb-test-source-analysis-sync-live"))
        var rawCalls: Int64 = 0
        for (call in runner.calls) {
            if (call.purpose == "source_raw") {
                rawCalls += 1
            }
        }

        @Expect(text.contains("source_analysis"), false)
        @Expect(rawCalls, 0)
    }

    @TestCase
    public func gitCodeRepoVisibilityOnlyAllowsExplicitPublicRepos(): Unit {
        let publicRepo = GitCodeRepoMetadata()
        publicRepo.visibility = RepoVisibility.PUBLIC
        let privateRepo = GitCodeRepoMetadata()
        privateRepo.visibility = RepoVisibility.PRIVATE
        let internalRepo = GitCodeRepoMetadata()
        internalRepo.visibility = RepoVisibility.INTERNAL
        let unknownRepo = GitCodeRepoMetadata()
        unknownRepo.visibility = RepoVisibility.UNKNOWN

        @Expect(RepoVisibility.PUBLIC, "public")
        @Expect(RepoVisibility.PRIVATE, "private")
        @Expect(RepoVisibility.INTERNAL, "internal")
        @Expect(RepoVisibility.UNKNOWN, "unknown")
        @Expect(deriveRepoVisibility(true, true, true), RepoVisibility.PRIVATE)
        @Expect(deriveRepoVisibility(false, true, true), RepoVisibility.INTERNAL)
        @Expect(deriveRepoVisibility(false, false, true), RepoVisibility.PUBLIC)
        @Expect(deriveRepoVisibility(false, false, false), RepoVisibility.UNKNOWN)
        @Expect(isRepoAllowedForKnowledge(publicRepo), true)
        @Expect(isRepoAllowedForKnowledge(privateRepo), false)
        @Expect(isRepoAllowedForKnowledge(internalRepo), false)
        @Expect(isRepoAllowedForKnowledge(unknownRepo), false)
    }

    @TestCase
    public func gitCodeOrgRepoListParserBuildsPathsFromNamespaceAndPath(): Unit {
        let body = "[{\"id\":101,\"full_name\":\"Display Name With Spaces\",\"name\":\"stdx-display\",\"path\":\"stdx\",\"description\":\"仓颉 HTTP 客户端\",\"default_branch\":\"main\",\"visibility\":\"public\",\"web_url\":\"https://gitcode.com/cangjie/stdx\",\"namespace\":{\"name\":\"仓颉组织\",\"path\":\"cangjie\"}},{\"id\":\"102\",\"full_name\":\"bad owner/bad repo\",\"name\":\"private-display\",\"path\":\"private-repo\",\"default_branch\":\"dev\",\"private\":true,\"visibility\":\"public\",\"web_url\":\"https://gitcode.com/cangjie/private-repo\",\"namespace\":{\"path\":\"cangjie\"}},{\"id\":103,\"name\":\"internal-repo\",\"defaultBranch\":\"trunk\",\"internal\":true,\"namespace\":{\"path\":\"cangjie-sig\"}},{\"id\":104,\"path\":\"mystery\",\"visibility\":\"friends\",\"namespace\":{\"path\":\"cangjie\"}},{\"id\":105,\"path\":\"broken\",\"visibility\":\"public\",\"namespace\":{\"path\":\"bad owner\"}}]"

        let repos = parseGitCodeOrgReposJson(body)

        @Expect(repos.size, 4)
        @Expect(repos[0].org, "cangjie")
        @Expect(repos[0].owner, "cangjie")
        @Expect(repos[0].repo, "stdx")
        @Expect(repos[0].fullName, "cangjie/stdx")
        @Expect(repos[0].fullName.contains("Display Name With Spaces"), false)
        @Expect(repos[0].defaultBranch, "main")
        @Expect(repos[0].rawId, "101")
        @Expect(repos[0].sourceUrl, "https://gitcode.com/cangjie/stdx")
        @Expect(repos[0].public, true)
        @Expect(repos[0].private, false)
        @Expect(repos[0].internal, false)
        @Expect(repos[0].visibility, RepoVisibility.PUBLIC)
        @Expect(isRepoAllowedForKnowledge(repos[0]), true)
        @Expect(repos[1].visibility, RepoVisibility.PRIVATE)
        @Expect(isRepoAllowedForKnowledge(repos[1]), false)
        @Expect(repos[2].repo, "internal-repo")
        @Expect(repos[2].defaultBranch, "trunk")
        @Expect(repos[2].visibility, RepoVisibility.INTERNAL)
        @Expect(isRepoAllowedForKnowledge(repos[2]), false)
        @Expect(repos[3].visibility, RepoVisibility.UNKNOWN)
        @Expect(repos[3].public, false)
        @Expect(isRepoAllowedForKnowledge(repos[3]), false)
    }

    @TestCase
    public func gitCodeOrgRepoListParserSurvivesUtf8FieldsBeforeAndAfterTargetKeys(): Unit {
        let body = "[{\"display_name\":\"仓颉开源社区 {说明}\",\"id\":301,\"path\":\"repo-one\",\"namespace\":{\"display_name\":\"仓颉组织\",\"path\":\"cangjie\"},\"default_branch\":\"main\",\"visibility\":\"public\",\"description\":\"支持中文说明和括号 [] {}\"},{\"display_name\":\"私有仓库\",\"id\":302,\"path\":\"private-one\",\"namespace\":{\"path\":\"cangjie\"},\"private\":true,\"description\":\"这个字段不应影响 private 判定\"}]"

        let repos = parseGitCodeOrgReposJson(body)

        @Expect(repos.size, 2)
        @Expect(repos[0].fullName, "cangjie/repo-one")
        @Expect(repos[0].defaultBranch, "main")
        @Expect(repos[0].visibility, RepoVisibility.PUBLIC)
        @Expect(isRepoAllowedForKnowledge(repos[0]), true)
        @Expect(repos[1].fullName, "cangjie/private-one")
        @Expect(repos[1].visibility, RepoVisibility.PRIVATE)
        @Expect(isRepoAllowedForKnowledge(repos[1]), false)
    }

    @TestCase
    public func gitCodeRepoMetadataParserDoesNotDefaultMalformedVisibilityToPublic(): Unit {
        let unknown = parseGitCodeRepoMetadataJson("{\"id\":201,\"path\":\"ambiguous\",\"visibility\":\"team-only\",\"namespace\":{\"path\":\"cangjie\"}}")
        let missing = parseGitCodeRepoMetadataJson("{\"id\":202,\"path\":\"missing-visibility\",\"namespace\":{\"path\":\"cangjie\"}}")

        @Expect(unknown.fullName, "cangjie/ambiguous")
        @Expect(unknown.visibility, RepoVisibility.UNKNOWN)
        @Expect(unknown.public, false)
        @Expect(isRepoAllowedForKnowledge(unknown), false)
        @Expect(missing.fullName, "cangjie/missing-visibility")
        @Expect(missing.visibility, RepoVisibility.UNKNOWN)
        @Expect(missing.public, false)
        @Expect(isRepoAllowedForKnowledge(missing), false)
    }

    @TestCase
    public func sourceSyncPlannerCoversThreeOrgsDocsWebsiteHistoryAndCandidates(): Unit {
        let scope = SourceScope()
        let plan = SourceSyncPlanner().productionPlan(scope)
        var orgs: Int64 = 0
        var websites: Int64 = 0
        var docs: Int64 = 0
        var gitCodeRepoScoped: Int64 = 0
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
            if (request.kind == SourceKinds.GITCODE_REPO || request.kind == SourceKinds.GITCODE_TREE || request.kind == SourceKinds.GITCODE_SOURCE || request.kind == SourceKinds.GITCODE_ISSUE_HISTORY || request.kind == SourceKinds.GITCODE_PR_HISTORY || request.kind == SourceKinds.GITCODE_COMMENT_HISTORY) {
                gitCodeRepoScoped += 1
            }
            if (request.kind == SourceKinds.WEB_CANDIDATE) {
                candidates += 1
            }
        }

        @Expect(orgs, 3)
        @Expect(websites, scope.websiteUrls.size)
        @Expect(docs, scope.docsUrls.size)
        @Expect(gitCodeRepoScoped, 0)
        @Expect(candidates, 1)
        @Expect(plan.requests.size, 3 + scope.websiteUrls.size + scope.docsUrls.size + 1)
    }

    @TestCase
    public func repoScopedPlanOnlyAllowsPublicRepos(): Unit {
        let publicRepo = parseGitCodeRepoMetadataJson("{\"id\":1,\"path\":\"pub\",\"default_branch\":\"dev\",\"public\":true,\"namespace\":{\"path\":\"cangjie\"}}")
        let privateRepo = parseGitCodeRepoMetadataJson("{\"id\":2,\"path\":\"priv\",\"default_branch\":\"main\",\"private\":true,\"namespace\":{\"path\":\"cangjie\"}}")
        let internalRepo = parseGitCodeRepoMetadataJson("{\"id\":3,\"path\":\"int\",\"default_branch\":\"main\",\"internal\":true,\"namespace\":{\"path\":\"cangjie\"}}")
        let unknownRepo = parseGitCodeRepoMetadataJson("{\"id\":4,\"path\":\"unknown\",\"default_branch\":\"main\",\"namespace\":{\"path\":\"cangjie\"}}")
        let repos = ArrayList<GitCodeRepoMetadata>()
        repos.add(publicRepo)
        repos.add(privateRepo)
        repos.add(internalRepo)
        repos.add(unknownRepo)

        let plan = SourceSyncPlanner().repoScopedPlan(repos)
        var publicRequests: Int64 = 0
        var blockedRequests: Int64 = 0

        for (request in plan.requests) {
            if (request.repo == "cangjie/pub") {
                publicRequests += 1
                @Expect(request.repoVisibility, RepoVisibility.PUBLIC)
            }
            if (request.repo == "cangjie/priv" || request.repo == "cangjie/int" || request.repo == "cangjie/unknown") {
                blockedRequests += 1
            }
        }

        @Expect(publicRequests, 4)
        @Expect(blockedRequests, 0)
        @Expect(plan.requests[0].kind, SourceKinds.GITCODE_TREE)
        @Expect(plan.requests[0].url.contains("/git/trees/dev"), true)
    }

    @TestCase
    public func sourceCandidateSelectorPrefersCjThenReadmeAndDocs(): Unit {
        let body = "{\"tree\":[{\"type\":\"blob\",\"path\":\"README.md\",\"name\":\"仓颉 说明\"},{\"type\":\"blob\",\"path\":\"docs/guide.md\"},{\"type\":\"blob\",\"path\":\"target/generated.cj\"},{\"type\":\"blob\",\"path\":\"src/main.cj\"},{\"type\":\"blob\",\"path\":\"src/lib.png\"},{\"type\":\"tree\",\"path\":\"src\"}]}"

        let selected = SourceCandidateSelector().selectFromTree(body, maxFiles: 3)

        @Expect(selected.size, 3)
        @Expect(selected[0], "src/main.cj")
        @Expect(selected[1], "README.md")
        @Expect(selected[2], "docs/guide.md")
    }

    @TestCase
    public func sourceCandidateSelectorSurvivesUtf8TreeMetadata(): Unit {
        let body = "{\"tree\":[{\"type\":\"blob\",\"display_name\":\"仓颉主入口 {源码}\",\"path\":\"src/main.cj\"},{\"type\":\"blob\",\"path\":\"docs/guide.md\",\"description\":\"中文文档 [] {}\"},{\"type\":\"tree\",\"path\":\"src\",\"name\":\"源码目录\"},{\"type\":\"blob\",\"path\":\"README.md\",\"name\":\"项目说明\"}]}"

        let selected = SourceCandidateSelector().selectFromTree(body, maxFiles: 3)

        @Expect(selected.size, 3)
        @Expect(selected[0], "src/main.cj")
        @Expect(selected[1], "docs/guide.md")
        @Expect(selected[2], "README.md")
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
    public func activeSnapshotRestoreUsesPersistedIndexAcrossObjects(): Unit {
        let store = FileKnowledgeStore("target/ckb-test-restore-p3")
        let first = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(first, store)

        let loaded = newKnowledgeBaseFromStore(store)
        let status = cangjie_knowledge_status(loaded.kb)
        let pack = cangjie_evidence_pack(loaded.kb, "HttpClient", 3)

        @Expect(rebuild.ok, true)
        @Expect(rebuild.activeVersion, "ckb-20260519-000200-active")
        @Expect(loaded.source, "persisted")
        @Expect(status.activeStateSource, "persisted")
        @Expect(status.activeKnowledgeVersion, "ckb-20260519-000200-active")
        @Expect(pack.knowledgeVersion, "ckb-20260519-000200-active")
        @Expect(pack.graphContext.knowledgeVersion, "ckb-20260519-000200-active")
    }

    @TestCase
    public func activeSnapshotRejectsMissingVersionAndMismatchedMetadata(): Unit {
        let missing = FileKnowledgeStore("target/ckb-test-restore-missing")
        let missingSnapshot = missing.loadActiveSnapshot()
        let store = FileKnowledgeStore("target/ckb-test-restore-mismatch")
        let kb = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(kb, store)
        File.writeTo(Path("target/ckb-test-restore-mismatch/metadata/status.ckb"), "active=wrong-active\n".toArray())
        let mismatched = store.loadActiveSnapshot()

        @Expect(missingSnapshot.valid, false)
        @Expect(missingSnapshot.diagnostic, "missing_active_version")
        @Expect(rebuild.ok, true)
        @Expect(mismatched.valid, false)
        @Expect(mismatched.diagnostic, "metadata_active_mismatch")
    }

    @TestCase
    public func activeSnapshotRejectsMalformedActiveIndex(): Unit {
        let root = "target/ckb-test-restore-malformed-index"
        let store = FileKnowledgeStore(root)
        store.ensureLayout()
        File.writeTo(Path("${root}/index/active.version"), "ckb-20260519-000200-active\n".toArray())
        File.writeTo(Path("${root}/index/active.ckb"), "not|a|normalized|record\n".toArray())

        let snapshot = store.loadActiveSnapshot()

        @Expect(snapshot.valid, false)
        @Expect(snapshot.diagnostic, "malformed_active_index")
        @Expect(snapshot.activeIndex.size, 0)
    }

    @TestCase
    public func invalidSnapshotFactoryFallsBackToOfflineBaseline(): Unit {
        let loaded = newKnowledgeBaseFromStore(FileKnowledgeStore("target/ckb-test-restore-invalid-fallback"))
        let status = cangjie_knowledge_status(loaded.kb)
        let source = cangjie_source_search(loaded.kb, "HttpClient", 3)

        @Expect(loaded.source, "offline_baseline")
        @Expect(loaded.diagnostic, "missing_active_version")
        @Expect(status.activeKnowledgeVersion, "ckb-20260519-000100-active")
        @Expect(status.activeStateSource, "offline_baseline")
        @Expect(status.restoreDiagnostic, "missing_active_version")
        @Expect(source.records.size > 0, true)
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
        @Expect(fake.calls.size >= 8, true)
        @Expect(kb.rawRecordCount() >= 14, true)
        @Expect(candidates.records.size > 0, true)
        @Expect(candidates.records[0].requiresReview, true)
        @Expect(store.has("raw/records.ckb"), true)
    }

    @TestCase
    public func liveApplyWritesSourceTypedRawNormalizedAndMetadata(): Unit {
        let kb = newOfflineKnowledgeBase()
        let fake = FakeSourceFetchRunner()
        let store = FileKnowledgeStore("target/ckb-test-live-apply")
        let options = LiveApplyOptions()
        options.apply = true
        options.maxItems = 20

        let result = ckbSyncLiveApply(kb, SourceAdapter(runner: fake), store, options)
        let raw = store.loadRaw()
        let normalized = store.loadNormalized()

        @Expect(result.ok, true)
        @Expect(result.candidateVersion.contains("candidate"), true)
        @Expect(result.activeVersion.contains("active"), true)
        @Expect(store.has("raw/doc/doc-syntax.ckb"), true)
        @Expect(store.has("raw/repo/source-http-client.ckb"), true)
        @Expect(store.has("raw/community/community-issue-1.ckb"), true)
        @Expect(store.has("raw/web_candidate/web-candidate-blog.ckb"), true)
        @Expect(store.has("metadata/status.ckb"), true)
        @Expect(raw.size, result.rawCount)
        @Expect(normalized.size, result.normalizedCount)
        @Expect(raw[0].metadata.sourceType != "", true)
        @Expect(raw[0].metadata.sourceUrl != "", true)
        @Expect(raw[0].metadata.crawlAt != "", true)
        @Expect(raw[0].contentHash.contains("hash-"), true)
        @Expect(raw[0].metadata.contentSize > 0, true)
        @Expect(raw[0].metadata.knowledgeVersion.contains("active"), true)
        @Expect(raw[0].metadata.candidateVersion.contains("candidate"), true)
    }

    @TestCase
    public func liveNormalizerEmitsVerifiableRecordKinds(): Unit {
        let kb = newOfflineKnowledgeBase()
        let store = FileKnowledgeStore("target/ckb-test-live-normalized")
        let options = LiveApplyOptions()
        options.apply = true
        let result = ckbSyncLiveApply(kb, SourceAdapter(runner: FakeSourceFetchRunner()), store, options)
        let normalized = store.loadNormalized()
        var documentSeen = false
        var codeSeen = false
        var commentSeen = false
        var candidateSeen = false

        for (record in normalized) {
            if (record.recordKind == "document_chunk") {
                documentSeen = documentSeen || (record.metadata.sourceUrl != "" && record.title != "" && record.chunk != "")
            }
            if (record.recordKind == "code_entity") {
                codeSeen = codeSeen || (record.metadata.repo != "" && record.metadata.path != "" && record.metadata.symbol != "")
            }
            if (record.recordKind == "comment_record") {
                commentSeen = commentSeen || (record.metadata.repo != "" && record.citation != "")
            }
            if (record.recordKind == "web_candidate") {
                candidateSeen = candidateSeen || (record.requiresReview && record.metadata.reviewState == ReviewStates.CANDIDATE)
            }
        }

        @Expect(result.ok, true)
        @Expect(documentSeen, true)
        @Expect(codeSeen, true)
        @Expect(commentSeen, true)
        @Expect(candidateSeen, true)
    }

    @TestCase
    public func liveCandidateFailureDoesNotPersistActiveIndex(): Unit {
        let kb = newOfflineKnowledgeBase()
        let before = cangjie_knowledge_status(kb).activeKnowledgeVersion
        let store = FileKnowledgeStore("target/ckb-test-live-failed-candidate")
        let options = LiveApplyOptions()
        options.apply = true
        options.simulateValidationFailure = true

        let result = ckbSyncLiveApply(kb, SourceAdapter(runner: FakeSourceFetchRunner()), store, options)
        let after = cangjie_knowledge_status(kb)

        @Expect(result.ok, false)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(after.failedCandidateVersion.contains("candidate"), true)
        @Expect(store.has("raw/candidate/${after.candidateKnowledgeVersion}/records.ckb"), true)
        @Expect(store.has("index/active.ckb"), false)
    }

    @TestCase
    public func failedCandidateApplyDoesNotOverwritePersistedActiveAcrossObjects(): Unit {
        let store = FileKnowledgeStore("target/ckb-test-live-failed-isolation")
        let first = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(first, store)
        let restored = newKnowledgeBaseFromStore(store)
        let options = LiveApplyOptions()
        options.apply = true
        options.simulateValidationFailure = true

        let failed = ckbSyncLiveApply(restored.kb, SourceAdapter(runner: FakeSourceFetchRunner()), store, options)
        let next = newKnowledgeBaseFromStore(store)
        let status = cangjie_knowledge_status(next.kb)
        let pack = cangjie_evidence_pack(next.kb, "HttpClient", 3)

        @Expect(rebuild.ok, true)
        @Expect(failed.ok, false)
        @Expect(failed.failedVersion.contains("candidate"), true)
        @Expect(next.source, "persisted")
        @Expect(status.activeKnowledgeVersion, "ckb-20260519-000200-active")
        @Expect(status.failedCandidateVersion.contains("candidate"), true)
        @Expect(pack.knowledgeVersion, "ckb-20260519-000200-active")
    }

    @TestCase
    public func liveApplyLimitsCarrySinceAndTruncateRequests(): Unit {
        let kb = newOfflineKnowledgeBase()
        let fake = FakeSourceFetchRunner()
        let store = FileKnowledgeStore("target/ckb-test-live-limits")
        let options = LiveApplyOptions()
        options.apply = true
        options.maxRepos = 0
        options.maxFilesPerRepo = 0
        options.maxItems = 2
        options.since = "2026-05-01T00:00:00Z"

        let result = ckbSyncLiveApply(kb, SourceAdapter(runner: fake), store, options)
        var gitCodeSeen = false
        for (request in fake.calls) {
            if (request.kind == SourceKinds.GITCODE_ORG || request.kind == SourceKinds.GITCODE_REPO || request.kind == SourceKinds.GITCODE_SOURCE || request.kind == SourceKinds.GITCODE_ISSUE_HISTORY || request.kind == SourceKinds.GITCODE_PR_HISTORY) {
                gitCodeSeen = true
            }
        }

        @Expect(result.ok, true)
        @Expect(result.requests <= 2, true)
        @Expect(result.truncated, true)
        @Expect(result.since, "2026-05-01T00:00:00Z")
        @Expect(gitCodeSeen, false)
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
    public func deterministicEmbeddingProviderIsStableAndProductionProviderDegradesOffline(): Unit {
        let texts = ArrayList<String>()
        texts.add("func HttpClient")
        let fake = DeterministicEmbeddingProvider()
        let first = fake.embed(texts, "deterministic-token-v1", 8)
        let second = fake.embed(texts, "deterministic-token-v1", 8)

        let config = EmbeddingConfig()
        config.provider = "production-http"
        config.configured = false
        let production = ProductionEmbeddingProvider(config)
        let degraded = production.embed(texts, "remote-model", 8)

        @Expect(first.status.state, EmbeddingProviderState.READY)
        @Expect(first.vectors.size, 1)
        @Expect(first.vectors[0].size, 8)
        @Expect(first.requested, 1)
        @Expect(first.succeeded, 1)
        @Expect(first.failed, 0)
        @Expect(first.vectors[0][1], second.vectors[0][1])
        @Expect(degraded.status.state, EmbeddingProviderState.DEGRADED)
        @Expect(degraded.status.degradedReason.contains("missing_config"), true)
        @Expect(degraded.requested, 1)
        @Expect(degraded.failed, 1)
        @Expect(degraded.vectors.size, 0)
    }

    @TestCase
    public func runtimeEmbeddingConfigSupportsDeterministicAndProductionDegradedWithoutSecrets(): Unit {
        let noCreds = CkbRuntimeConfig()
        noCreds.embeddingProvider = "production-http"
        noCreds.embeddingModel = "remote-embedding"
        noCreds.embeddingDimensions = 64
        noCreds.embeddingEndpoint = "https://embedding.invalid/v1"
        noCreds.embeddingBatchSize = 32
        noCreds.embeddingTimeoutMillis = 4321
        noCreds.embeddingRetryCount = 4
        let production = embeddingProviderFromRuntime(noCreds)
        let productionStatus = production.status()

        let local = CkbRuntimeConfig()
        local.embeddingProvider = "deterministic"
        local.embeddingDimensions = 12
        let deterministic = embeddingProviderFromRuntime(local)
        let texts = ArrayList<String>()
        texts.add("func HttpClient")
        texts.add("download tools")
        let batch = deterministic.embed(texts, "deterministic-token-v1", 12)

        @Expect(productionStatus.state, EmbeddingProviderState.DEGRADED)
        @Expect(productionStatus.degradedReason, "production_embedding_missing_config")
        @Expect(productionStatus.endpointConfigured, true)
        @Expect(productionStatus.tokenConfigured, false)
        @Expect(productionStatus.batchSize, 32)
        @Expect(productionStatus.timeoutMillis, 4321)
        @Expect(productionStatus.retryCount, 4)
        @Expect(batch.status.state, EmbeddingProviderState.READY)
        @Expect(batch.vectors.size, 2)
        @Expect(batch.requested, 2)
        @Expect(batch.succeeded, 2)
    }

    @TestCase
    public func localVectorStoreUpsertsSearchesAndFallsBackWhenDown(): Unit {
        let kb = newOfflineKnowledgeBase()
        let semantic = cangjie_hybrid_search(kb, "define function", 3)
        let status = cangjie_knowledge_status(kb)

        let downKb = KnowledgeBase(FakeClock(0), DeterministicEmbeddingProvider(), LocalVectorStore(false), LocalGraphStore())
        downKb.bootstrapOffline()
        let fallback = cangjie_hybrid_search(downKb, "define function", 3)

        @Expect(status.storage.vectorBackend, "local-file")
        @Expect(status.storage.vectorState, EmbeddingProviderState.READY)
        @Expect(status.storage.vectorDimension, 16)
        @Expect(status.storage.vectorIndexCount > 0, true)
        @Expect(kb.activeVectorRecords()[0].metadata.sourceId != "", true)
        @Expect(kb.activeVectorRecords()[0].metadata.knowledgeVersion.contains("active"), true)
        @Expect(kb.activeVectorRecords()[0].metadata.trustLevel != "", true)
        @Expect(kb.activeVectorRecords()[0].metadata.reviewState != "", true)
        @Expect(semantic.records.size > 0, true)
        @Expect(semantic.vectorUsed, true)
        @Expect(fallback.records.size > 0, true)
        @Expect(fallback.degraded, true)
        @Expect(fallback.fallbackReason, "vector_store_unavailable")
    }

    @TestCase
    public func localVectorStoreKeepsActiveAndCandidateCollectionsIsolated(): Unit {
        let kb = newOfflineKnowledgeBase()
        let activeRecords = kb.activeVectorRecords()
        let candidateRecords = ArrayList<VectorRecord>()
        let candidate = VectorRecord()
        candidate.id = "candidate-only"
        candidate.title = "candidate only"
        candidate.chunk = "candidate vector"
        candidate.citation = "candidate://only"
        candidate.metadata = activeRecords[0].metadata
        candidate.vector = activeRecords[0].vector
        candidateRecords.add(candidate)

        let store = LocalVectorStore()
        let activeStatus = store.upsert("active", activeRecords)
        let candidateStatus = store.upsert("candidate", candidateRecords)
        let filters = VectorSearchFilters()
        filters.knowledgeVersion = activeRecords[0].metadata.knowledgeVersion
        let activeSearch = store.search("active", activeRecords[0].vector, filters, 20)
        var candidateLeaked = false
        for (item in activeSearch) {
            if (item.id == "candidate-only") {
                candidateLeaked = true
            }
        }
        store.clear("candidate")
        let activeAfterClear = store.status("active")
        let candidateAfterClear = store.status("candidate")

        @Expect(activeStatus.count > 0, true)
        @Expect(candidateStatus.count, 1)
        @Expect(candidateLeaked, false)
        @Expect(activeAfterClear.count, activeRecords.size)
        @Expect(candidateAfterClear.count, 0)
    }

    @TestCase
    public func localVectorFilesBackupRestoreAndRecoveredActiveSurvivesProductionProviderDegraded(): Unit {
        let root = "target/ckb-test-vector-restore-prod"
        let store = FileKnowledgeStore(root)
        let first = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(first, store)
        let backedUp = store.backupVectorCollection("active", "before-clear")
        let empty = ArrayList<VectorRecord>()
        store.saveVectorCollection(empty, "active")
        let restoredFile = store.restoreVectorBackup("active", "before-clear")

        let config = CkbRuntimeConfig()
        config.embeddingProvider = "production-http"
        config.embeddingModel = "remote-embedding"
        config.embeddingDimensions = 16
        config.embeddingEndpoint = "https://embedding.invalid/v1"
        let loaded = newKnowledgeBaseFromStoreWithRuntime(store, config)
        let status = cangjie_knowledge_status(loaded.kb)
        let rendered = renderQuery(cangjie_evidence_pack(loaded.kb, "HttpClient", 3))

        @Expect(rebuild.ok, true)
        @Expect(backedUp, true)
        @Expect(restoredFile, true)
        @Expect(loaded.source, "persisted")
        @Expect(status.storage.vectorState, EmbeddingProviderState.READY)
        @Expect(status.storage.vectorIndexCount > 0, true)
        @Expect(rendered.contains("knowledgeVersion=ckb-20260519-000200-active"), true)
        @Expect(rendered.contains("HttpClient"), true)
    }

    @TestCase
    public func evidencePackCarriesBudgetedGraphContextWithActiveVersion(): Unit {
        let kb = newOfflineKnowledgeBase()
        let pack = cangjie_evidence_pack(kb, "HttpClient", 1)
        let query = GraphQuery()
        query.symbol = "HttpClient"
        query.budget = 2
        query.knowledgeVersion = pack.knowledgeVersion
        let neighbors = kb.graphNeighbors(query)
        let status = cangjie_knowledge_status(kb)

        @Expect(pack.hasGraphContext, true)
        @Expect(pack.graphContext.knowledgeVersion, pack.knowledgeVersion)
        @Expect(pack.graphContext.edges.size <= 2, true)
        @Expect(pack.graphContext.truncated, true)
        @Expect(neighbors.edges.size > 0, true)
        @Expect(neighbors.knowledgeVersion, pack.knowledgeVersion)
        @Expect(status.storage.graphBackend, "local-graph")
        @Expect(status.storage.graphNodeCount > 0, true)
        @Expect(status.storage.graphEdgeCount > 0, true)
    }

    @TestCase
    public func rebuildIndexPersistsLocalVectorAndGraphBackendFiles(): Unit {
        let kb = newOfflineKnowledgeBase()
        let store = FileKnowledgeStore("target/ckb-test-live34-index")
        let result = ckbRebuildIndex(kb, store)

        @Expect(result.ok, true)
        @Expect(store.has("index/vector-active.ckb"), true)
        @Expect(store.has("index/graph-nodes.ckb"), true)
        @Expect(store.has("index/graph-edges.ckb"), true)
        @Expect(store.has("metadata/status.ckb"), true)
    }

    @TestCase
    public func schemaListsMcpToolsAndHttpLikeRoutes(): Unit {
        let tools = CkbSchema.mcpTools()
        let routes = CkbSchema.httpLikeRoutes()

        @Expect(tools.contains("cangjie.health"), true)
        @Expect(tools.contains("cangjie.status"), true)
        @Expect(tools.contains("cangjie.query"), true)
        @Expect(tools.contains("cangjie.evidence"), true)
        @Expect(tools.contains("cangjie.sync"), true)
        @Expect(tools.contains("cangjie.rebuild"), true)
        @Expect(tools.contains("cangjie.evidence_pack"), true)
        @Expect(tools.contains("activeKnowledgeVersion"), true)
        @Expect(tools.contains("citations"), true)
        @Expect(tools.contains("requiresReview"), true)
        @Expect(tools.contains("ckb.auth_degraded"), true)
        @Expect(tools.contains("PRIVATE-TOKEN"), true)
        @Expect(tools.contains("Authorization"), true)
        @Expect(tools.contains("Cookie"), true)
        @Expect(tools.contains("officialApi=https://api.gitcode.com/api/v5"), true)
        @Expect(tools.contains("authHeader=private-token"), true)
        @Expect(tools.contains("tokenFile=tokenFile"), true)
        @Expect(tools.contains("single PAT line"), true)
        @Expect(tools.contains("transportDiagnostic"), true)
        @Expect(tools.contains("anonymous dry-run"), true)
        @Expect(tools.contains("limited apply"), true)
        @Expect(tools.contains("fake-live-token"), false)
        @Expect(routes.contains("GET /health"), true)
        @Expect(routes.contains("GET /status"), true)
        @Expect(routes.contains("POST /query"), true)
        @Expect(routes.contains("POST /evidence"), true)
        @Expect(routes.contains("POST /sync"), true)
        @Expect(routes.contains("POST /rebuild-index"), true)
        @Expect(routes.contains("redactedSourceStatus"), true)
        @Expect(routes.contains("authHeaderStrategy"), true)
        @Expect(routes.contains("transportDiagnostic"), true)
    }

    @TestCase
    public func integrationDocsDefineBoundariesWithoutRealCredentials(): Unit {
        let integration = String.fromUtf8(File.readFrom(Path("../docs/metis-gitcodemonitor-integration.md")))
        let checklist = String.fromUtf8(File.readFrom(Path("../docs/manual-acceptance-checklist.md")))
        let readme = String.fromUtf8(File.readFrom(Path("../README.md")))
        let ignore = String.fromUtf8(File.readFrom(Path("../.gitignore")))
        let docs = integration + "\n" + checklist + "\n" + readme

        @Expect(integration.contains("GET /health"), true)
        @Expect(integration.contains("POST /query"), true)
        @Expect(integration.contains("POST /evidence"), true)
        @Expect(integration.contains("POST /sync"), true)
        @Expect(integration.contains("POST /rebuild-index"), true)
        @Expect(integration.contains("activeKnowledgeVersion"), true)
        @Expect(integration.contains("requiresReview=true"), true)
        @Expect(integration.contains("GitCodeMonitor should go through Metis"), true)
        @Expect(checklist.contains("Real Source Sync"), true)
        @Expect(checklist.contains("Backup and Restore"), true)
        @Expect(checklist.contains("Exception Recovery"), true)
        @Expect(docs.contains("gitcode.baseUrl=https://api.gitcode.com/api/v5"), true)
        @Expect(docs.contains("gitcode.authMode=token"), true)
        @Expect(docs.contains("gitcode.authHeader=private-token"), true)
        @Expect(docs.contains("gitcode.tokenFile=tokenFile"), true)
        @Expect(docs.contains("one GitCode PAT line"), true)
        @Expect(docs.contains("token="), true)
        @Expect(docs.contains("transport diagnostics"), true)
        @Expect(docs.contains("anonymous dry-run"), true)
        @Expect(docs.contains("limited apply"), true)
        @Expect(docs.contains("fake-live-token"), false)
        @Expect(docs.contains("gitcode_x"), false)
        @Expect(docs.contains("Authorization: Bearer"), false)
        @Expect(docs.contains("Cookie: "), false)
        @Expect(docs.contains("/Users/l3gi0n/.metis"), false)
        @Expect(ignore.contains("tokenFile"), true)
        @Expect(ignore.contains("ckb-live.conf"), true)
        @Expect(ignore.contains("*.token"), true)
        @Expect(ignore.contains("*.local.conf"), true)
    }

    @TestCase
    public func runtimeConfigDefaultsToOfflineAndRedactsSensitiveText(): Unit {
        let config = loadCkbRuntimeConfig("")
        let doctor = renderRuntimeDoctor(config)
        let redacted = redactSensitive("PRIVATE-TOKEN: private-token-secret\nAuthorization: Bearer fake-token\nCookie=session=abc https://gitcode.com/api?access_token=secret&x=1 mirror=/Users/l3gi0n/private")

        @Expect(config.networkEnabled, false)
        @Expect(config.gitCodeAuthHeader, "private-token")
        @Expect(config.gitCodeAccessTokenQuery, false)
        @Expect(doctor.contains("network=disabled"), true)
        @Expect(doctor.contains("gitcode.authHeader=private-token"), true)
        @Expect(doctor.contains("gitcode.accessTokenQuery=disabled"), true)
        @Expect(doctor.contains("gitcode.token=absent"), true)
        @Expect(redacted.contains("private-token-secret"), false)
        @Expect(redacted.contains("fake-token"), false)
        @Expect(redacted.contains("session=abc"), false)
        @Expect(redacted.contains("secret"), false)
        @Expect(redacted.contains("/Users/l3gi0n"), false)
        @Expect(redacted.contains("[local-path-redacted]"), true)
    }

    @TestCase
    public func curlTransportDiagnosticsClassifyAndRedactStderr(): Unit {
        let timeout = diagnoseCurlTransportError(28, "curl: (28) Operation timed out after 1000 milliseconds")
        let dns = diagnoseCurlTransportError(6, "curl: (6) Could not resolve host: gitcode.com")
        let tls = diagnoseCurlTransportError(60, "curl: (60) SSL certificate problem")
        let proxy = diagnoseCurlTransportError(5, "curl: (5) Could not resolve proxy: 127.0.0.1")
        let refused = diagnoseCurlTransportError(7, "curl: (7) Failed to connect to 127.0.0.1 port 9: Connection refused")
        let curlExit = diagnoseCurlTransportError(22, "curl: (22) The requested URL returned error: 502")
        let unknown = diagnoseCurlTransportError(0, "unexpected transport state")
        let sensitive = diagnoseCurlTransportError(6, "curl: (6) Could not resolve host: gitcode.com\nAuthorization: Bearer live-token-secret\nCookie: SESSION=cookie-secret\nretry token=token-secret path=/Users/l3gi0n/private/ckb-live.conf extra=abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")

        @Expect(timeout.transportErrorClass, "timeout")
        @Expect(dns.transportErrorClass, "dns")
        @Expect(tls.transportErrorClass, "tls")
        @Expect(proxy.transportErrorClass, "proxy")
        @Expect(refused.transportErrorClass, "connection_refused")
        @Expect(curlExit.transportErrorClass, "curl_exit")
        @Expect(unknown.transportErrorClass, "unknown_transport")
        @Expect(sensitive.transportErrorClass, "dns")
        @Expect(sensitive.curlExitCode, 6)
        @Expect(sensitive.transportDiagnostic.size <= 160, true)
        @Expect(sensitive.transportDiagnostic.contains("live-token-secret"), false)
        @Expect(sensitive.transportDiagnostic.contains("cookie-secret"), false)
        @Expect(sensitive.transportDiagnostic.contains("token-secret"), false)
        @Expect(sensitive.transportDiagnostic.contains("/Users/l3gi0n"), false)
        @Expect(sensitive.transportDiagnostic.contains("Authorization"), true)
        @Expect(sensitive.transportDiagnostic.contains("Cookie"), true)
        @Expect(sensitive.transportDiagnostic.contains("[local-path-redacted]"), true)
    }

    @TestCase
    public func runtimeConfigLoadsFixtureWithoutExposingTokenOrLocalPath(): Unit {
        let path = "target/ckb-live-config.fixture"
        File.writeTo(Path(path), """
network.enabled=true
gitcode.baseUrl=https://api.gitcode.com/api/v5?access_token=fake-live-token
gitcode.authMode=token
gitcode.authHeader=authorization
gitcode.tokenRef=fake-live-token
gitcode.tokenFile=/Users/l3gi0n/.metis/gitcode-token
website.enabled=true
docs.enabled=true
index.backend=local-vector
embedding.provider=production-http
embedding.model=remote-embedding
embedding.dimensions=128
embedding.endpoint=https://embedding.invalid/v1?access_token=fake-live-token
embedding.tokenFile=/Users/l3gi0n/.metis/embedding-token
embedding.batchSize=24
embedding.timeoutMillis=2345
embedding.retryCount=5
vector.backend=local-file
vector.activeCollection=prod-active
vector.candidateCollection=prod-candidate
network.timeoutMillis=1234
network.retryCount=3
network.proxy=http://user:pass@127.0.0.1:7897
network.envProxyEnabled=true
network.noProxy=api.gitcode.com,docs.cangjie-lang.cn
network.insecureSkipTlsVerify=false
network.caFile=/etc/ssl/cert.pem
network.allowPrivateNetwork=true
network.allowedHosts=docs.example.org
""".toArray())

        let config = loadCkbRuntimeConfig(path)
        let summary = config.redactedSummary()

        @Expect(config.networkEnabled, true)
        @Expect(config.websiteEnabled, true)
        @Expect(config.docsEnabled, true)
        @Expect(config.gitCodeBaseUrl.contains("access_token"), false)
        @Expect(config.gitCodeAuthHeader, "authorization")
        @Expect(config.gitCodeAccessTokenQuery, false)
        @Expect(config.timeoutMillis, 1234)
        @Expect(config.retryCount, 3)
        @Expect(config.networkProxy, "http://user:pass@127.0.0.1:7897")
        @Expect(config.networkEnvProxyEnabled, true)
        @Expect(config.networkNoProxy, "api.gitcode.com,docs.cangjie-lang.cn")
        @Expect(config.networkInsecureSkipTlsVerify, false)
        @Expect(config.networkCaFile, "/etc/ssl/cert.pem")
        @Expect(config.networkAllowPrivateNetwork, true)
        @Expect(config.networkAllowedHosts, "docs.example.org")
        @Expect(config.embeddingProvider, "production-http")
        @Expect(config.embeddingModel, "remote-embedding")
        @Expect(config.embeddingDimensions, 128)
        @Expect(config.embeddingBatchSize, 24)
        @Expect(config.embeddingTimeoutMillis, 2345)
        @Expect(config.embeddingRetryCount, 5)
        @Expect(config.vectorActiveCollection, "prod-active")
        @Expect(config.vectorCandidateCollection, "prod-candidate")
        @Expect(summary.contains("gitcode.token=present"), true)
        @Expect(summary.contains("gitcode.authHeader=authorization"), true)
        @Expect(summary.contains("gitcode.accessTokenQuery=disabled"), true)
        @Expect(summary.contains("network.proxy=http://[redacted]@127.0.0.1:7897"), true)
        @Expect(summary.contains("network.envProxy=enabled"), true)
        @Expect(summary.contains("network.noProxy=api.gitcode.com,docs.cangjie-lang.cn"), true)
        @Expect(summary.contains("network.insecureSkipTlsVerify=disabled"), true)
        @Expect(summary.contains("network.caFile=present"), true)
        @Expect(summary.contains("/etc/ssl/cert.pem"), false)
        @Expect(summary.contains("user:pass"), false)
        @Expect(summary.contains("embedding.endpoint=present"), true)
        @Expect(summary.contains("embedding.token=present"), true)
        @Expect(summary.contains("fake-live-token"), false)
        @Expect(summary.contains("/Users/l3gi0n"), false)
    }

    @TestCase
    public func syncLiveRequiresModeAndNetworkGatePreventsFetches(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        let fake = FakeSourceFetchRunner()
        let noMode = LiveSyncOptions()
        let dryRun = LiveSyncOptions()
        dryRun.dryRun = true

        let usage = ckbSyncLive(kb, config, noMode, runner: fake)
        let blocked = ckbSyncLive(kb, config, dryRun, runner: fake)

        @Expect(usage.contains("usage error"), true)
        @Expect(blocked.contains("network=disabled"), true)
        @Expect(blocked.contains("requests=0"), true)
        @Expect(fake.calls.size, 0)
    }

    @TestCase
    public func syncLiveDryRunSummarizesShapesAndDoesNotWriteRawData(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.websiteEnabled = true
        config.docsEnabled = true
        config.gitCodeAuthMode = "token"
        config.gitCodeTokenRef = "fake-live-token"
        let options = LiveSyncOptions()
        options.dryRun = true
        let fake = ScriptedSourceFetchRunner()
        let store = FileKnowledgeStore("target/ckb-live-dry-run-store")

        let text = ckbSyncLive(kb, config, options, runner: fake, store: store)

        @Expect(text.contains("mode=dry-run"), true)
        @Expect(text.contains("repoDiscovery orgs=3"), true)
        @Expect(text.contains("repoIncluded cangjie/repo-one visibility=public defaultBranch=dev"), true)
        @Expect(text.contains("repoExcluded cangjie/private-one visibility=private"), true)
        @Expect(text.contains("repoExcluded cangjie/internal-one visibility=internal"), true)
        @Expect(text.contains("repoExcluded cangjie/unknown-one visibility=unknown"), true)
        @Expect(text.contains("repoFetch kind=gitcode_tree repo=cangjie/repo-one visibility=public"), true)
        @Expect(text.contains("repoFetch kind=gitcode_issue_history repo=cangjie/repo-one visibility=public"), true)
        @Expect(text.contains("repoFetch kind=gitcode_pr_history repo=cangjie/repo-one visibility=public"), true)
        @Expect(text.contains("repoFetch kind=gitcode_comment_history repo=cangjie/repo-one visibility=public"), true)
        @Expect(text.contains("repo=cangjie/private-one visibility=public"), false)
        @Expect(text.contains("repo=cangjie/internal-one visibility=public"), false)
        @Expect(text.contains("repo=cangjie/unknown-one visibility=public"), false)
        @Expect(text.contains("shape=repo-list"), true)
        @Expect(text.contains("shape=html-entry"), true)
        @Expect(text.contains("shape=history-list"), true)
        @Expect(text.contains("shape=source-tree"), true)
        @Expect(text.contains("shape=source-snapshot"), true)
        @Expect(text.contains("auth=token"), true)
        @Expect(text.contains("authHeader=private-token"), true)
        @Expect(text.contains("gitcode.accessTokenQuery=disabled"), true)
        @Expect(text.contains("httpStatus=200"), true)
        @Expect(text.contains("bodyHash="), true)
        @Expect(text.contains("errorClass=none"), true)
        @Expect(text.contains("rawWritten=false"), true)
        @Expect(text.contains("fake-live-token"), false)
        @Expect(text.contains("access_token"), false)
        @Expect(store.has("raw/records.ckb"), false)
    }

    @TestCase
    public func syncLiveDryRunSurvivesUtf8GitCodeDiscoveryAndTreePayloads(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.websiteEnabled = true
        config.docsEnabled = true
        config.gitCodeAuthMode = "token"
        config.gitCodeTokenRef = "fake-live-token"
        let options = LiveSyncOptions()
        options.dryRun = true
        options.maxRepos = 1
        options.maxFilesPerRepo = 2
        options.maxItems = 12
        let store = FileKnowledgeStore("target/ckb-live-utf8-dry-run-store")

        let text = ckbSyncLive(kb, config, options, runner: ScriptedSourceFetchRunner(), store: store)

        @Expect(text.contains("repoIncluded cangjie/repo-one visibility=public defaultBranch=dev"), true)
        @Expect(text.contains("repoFetch kind=gitcode_tree repo=cangjie/repo-one visibility=public"), true)
        @Expect(text.contains("repoFetch kind=gitcode_source repo=cangjie/repo-one visibility=public"), true)
        @Expect(text.contains("repoExcluded cangjie/private-one visibility=private"), true)
        @Expect(text.contains("summary"), true)
        @Expect(text.contains("rawWritten=false"), true)
        @Expect(text.contains("fake-live-token"), false)
        @Expect(store.has("raw/records.ckb"), false)
    }

    @TestCase
    public func syncLiveApplyPersistsOnlyPublicRepoVisibility(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let options = LiveSyncOptions()
        options.apply = true
        options.maxRepos = 1
        options.maxFilesPerRepo = 1
        let store = FileKnowledgeStore("target/ckb-live-public-apply")

        let text = ckbSyncLive(kb, config, options, runner: ScriptedSourceFetchRunner(), store: store)
        let raw = store.loadRaw()
        var publicGitCodeRecords: Int64 = 0
        var privateRecords: Int64 = 0

        for (record in raw) {
            if (record.metadata.repo == "cangjie/repo-one") {
                publicGitCodeRecords += 1
                @Expect(record.metadata.repoVisibility, RepoVisibility.PUBLIC)
            }
            if (record.metadata.repo == "cangjie/private-one" || record.metadata.repo == "cangjie/internal-one" || record.metadata.repo == "cangjie/unknown-one") {
                privateRecords += 1
            }
        }

        @Expect(text.contains("activePromoted=true"), true)
        @Expect(publicGitCodeRecords > 0, true)
        @Expect(privateRecords, 0)
    }

    @TestCase
    public func syncLiveSummaryIncludesTransportDiagnosticsOnlyForTransportFailures(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let options = LiveSyncOptions()
        options.dryRun = true
        options.maxItems = 1
        let fake = FakeSourceFetchRunner()
        fake.statusCode = 0
        fake.status = "transport_error"
        fake.body = ""
        fake.transportErrorClass = "dns"
        fake.transportDiagnostic = "native dns lookup failed for gitcode.com"

        let text = ckbSyncLive(kb, config, options, runner: fake, store: FileKnowledgeStore("target/ckb-transport-summary"))

        @Expect(text.contains("status=transport_error"), true)
        @Expect(text.contains("transportClass=dns"), true)
        @Expect(text.contains("transportDiagnostic=native dns lookup failed for gitcode.com"), true)
        @Expect(text.contains("curlExitCode"), false)

        fake.status = "timeout"
        fake.transportErrorClass = "timeout"
        fake.transportDiagnostic = "native request timed out"
        let timeoutText = ckbSyncLive(kb, config, options, runner: fake, store: FileKnowledgeStore("target/ckb-timeout-summary"))

        @Expect(timeoutText.contains("status=timeout"), true)
        @Expect(timeoutText.contains("transportClass=timeout"), true)
        @Expect(timeoutText.contains("transportDiagnostic=native request timed out"), true)
        @Expect(timeoutText.contains("curlExitCode"), false)
    }

    @TestCase
    public func httpRunnerReadsTokenFileAndInjectsPrivateTokenHeader(): Unit {
        let tokenPath = "target/ckb-test-token-file.fixture"
        File.writeTo(Path(tokenPath), "file-token-secret\n".toArray())
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.gitCodeAuthMode = "token"
        config.gitCodeTokenFile = tokenPath
        let executor = FakeHttpExecutor(200, "{}", "application/json", "http_200", 0)

        let fetch = HttpSourceFetchRunner(config, executor: executor).fetch(SourceRequestBuilder().gitCodeOrgRepos("cangjie"))

        @Expect(fetch.ok, true)
        @Expect(executor.calls, 1)
        @Expect(executor.seenHeaders.size, 1)
        @Expect(executor.seenHeaders[0], "PRIVATE-TOKEN: file-token-secret")
        @Expect(config.redactedSummary().contains("file-token-secret"), false)
    }

    @TestCase
    public func httpRunnerDoesNotSendGitCodeAuthToWebsiteOrDocsRequests(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.gitCodeAuthMode = "token"
        config.gitCodeTokenRef = "gitcode-secret-token"
        let websiteExecutor = FakeHttpExecutor(200, "<html></html>", "text/html", "http_200", 0)
        let docsExecutor = FakeHttpExecutor(200, "<html></html>", "text/html", "http_200", 0)
        let builder = SourceRequestBuilder()

        let website = HttpSourceFetchRunner(config, executor: websiteExecutor).fetch(builder.website("https://cangjie-lang.cn/"))
        let docs = HttpSourceFetchRunner(config, executor: docsExecutor).fetch(builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/"))

        @Expect(website.ok, true)
        @Expect(docs.ok, true)
        @Expect(websiteExecutor.seenHeaders.size, 0)
        @Expect(docsExecutor.seenHeaders.size, 0)
    }

    @TestCase
    public func httpRunnerUsesTokenRefAndCookieModesWithoutLeakingDryRunOutput(): Unit {
        let tokenConfig = CkbRuntimeConfig()
        tokenConfig.networkEnabled = true
        tokenConfig.gitCodeAuthMode = "token"
        tokenConfig.gitCodeAuthHeader = "authorization"
        tokenConfig.gitCodeTokenRef = "ref-token-secret"
        let tokenExecutor = FakeHttpExecutor(200, "{}", "application/json", "http_200", 0)

        let tokenFetch = HttpSourceFetchRunner(tokenConfig, executor: tokenExecutor).fetch(SourceRequestBuilder().gitCodeRepo("cangjie/stdx"))

        let cookieConfig = CkbRuntimeConfig()
        cookieConfig.networkEnabled = true
        cookieConfig.gitCodeAuthMode = "cookie"
        cookieConfig.gitCodeAuthHeader = "both"
        cookieConfig.gitCodeTokenRef = "SESSION=cookie-secret; Path=/"
        let cookieExecutor = FakeHttpExecutor(200, "{}", "application/json", "http_200", 0)

        let cookieFetch = HttpSourceFetchRunner(cookieConfig, executor: cookieExecutor).fetch(SourceRequestBuilder().gitCodeRepo("cangjie/stdx"))
        let dryRun = LiveSyncOptions()
        dryRun.dryRun = true
        let text = ckbSyncLive(newOfflineKnowledgeBase(), cookieConfig, dryRun, runner: FakeSourceFetchRunner(), store: FileKnowledgeStore("target/ckb-cookie-dry-run"))

        @Expect(tokenFetch.ok, true)
        @Expect(tokenExecutor.seenHeaders.size, 1)
        @Expect(tokenExecutor.seenHeaders[0], "Authorization: Bearer ref-token-secret")
        @Expect(cookieFetch.ok, true)
        @Expect(cookieExecutor.seenHeaders.size, 1)
        @Expect(cookieExecutor.seenHeaders[0], "Cookie: SESSION=cookie-secret; Path=/")
        @Expect(text.contains("auth=cookie-present"), true)
        @Expect(text.contains("authHeader=both"), true)
        @Expect(text.contains("cookie-secret"), false)
        @Expect(text.contains("Cookie:"), false)
    }

    @TestCase
    public func httpRunnerCanSendBothGitCodeTokenHeaders(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.gitCodeAuthMode = "token"
        config.gitCodeAuthHeader = "both"
        config.gitCodeTokenRef = "both-token-secret"
        let executor = FakeHttpExecutor(200, "{}", "application/json", "http_200", 0)

        let fetch = HttpSourceFetchRunner(config, executor: executor).fetch(SourceRequestBuilder().gitCodeRepo("cangjie/stdx"))

        @Expect(fetch.ok, true)
        @Expect(executor.calls, 1)
        @Expect(executor.seenHeaders.size, 2)
        @Expect(executor.seenHeaders[0], "PRIVATE-TOKEN: both-token-secret")
        @Expect(executor.seenHeaders[1], "Authorization: Bearer both-token-secret")
    }

    @TestCase
    public func missingTokenFileDegradesBeforeHttpRequestWithDiagnostic(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.gitCodeAuthMode = "token"
        config.gitCodeTokenFile = "target/ckb-missing-token.fixture"
        let executor = FakeHttpExecutor(200, "{}", "application/json", "http_200", 0)

        let fetch = HttpSourceFetchRunner(config, executor: executor).fetch(SourceRequestBuilder().gitCodeOrgRepos("cangjie"))
        let dryRun = LiveSyncOptions()
        dryRun.dryRun = true
        let text = ckbSyncLive(newOfflineKnowledgeBase(), config, dryRun, runner: HttpSourceFetchRunner(config, executor: FakeHttpExecutor(200, "{}", "application/json", "http_200", 0)), store: FileKnowledgeStore("target/ckb-missing-token-dry-run"))

        @Expect(fetch.ok, false)
        @Expect(fetch.status, "auth_degraded")
        @Expect(fetch.body, "missing_token_file")
        @Expect(executor.calls, 0)
        @Expect(text.contains("auth=token-missing"), true)
        @Expect(text.contains("authDiagnostic=missing_token_file"), true)
        @Expect(text.contains("errorClass=auth"), true)
        @Expect(text.contains("ckb-missing-token.fixture"), false)
    }

    @TestCase
    public func httpRunnerNetworkDisabledNeverCallsExecutor(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = false
        config.gitCodeAuthMode = "token"
        config.gitCodeTokenRef = "disabled-token-secret"
        let executor = FakeHttpExecutor(200, "{}", "application/json", "http_200", 0)

        let fetch = HttpSourceFetchRunner(config, executor: executor).fetch(SourceRequestBuilder().gitCodeOrgRepos("cangjie"))

        @Expect(fetch.ok, false)
        @Expect(fetch.status, "network_disabled")
        @Expect(executor.calls, 0)
    }

    @TestCase
    public func syncLiveApplyWritesCandidatePromotesActiveAndFailureKeepsOldActive(): Unit {
        let successStore = FileKnowledgeStore("target/ckb-sync-live-apply-success")
        let successKb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.websiteEnabled = true
        config.docsEnabled = true
        let apply = LiveSyncOptions()
        apply.apply = true
        apply.maxItems = 3

        let success = ckbSyncLive(successKb, config, apply, runner: FakeSourceFetchRunner(), store: successStore)

        let failStore = FileKnowledgeStore("target/ckb-sync-live-apply-failure")
        let failKb = newOfflineKnowledgeBase()
        let before = cangjie_knowledge_status(failKb).activeKnowledgeVersion
        let fail = LiveSyncOptions()
        fail.apply = true
        fail.maxItems = 3
        fail.simulateValidationFailure = true

        let failed = ckbSyncLive(failKb, config, fail, runner: FakeSourceFetchRunner(), store: failStore)
        let after = cangjie_knowledge_status(failKb)

        @Expect(success.contains("activePromoted=true"), true)
        @Expect(successStore.has("raw/records.ckb"), true)
        @Expect(successStore.has("normalized/records.ckb"), true)
        @Expect(successStore.has("raw/candidate/${cangjie_knowledge_status(successKb).candidateKnowledgeVersion}/records.ckb"), true)
        @Expect(successStore.has("index/active.ckb"), true)
        @Expect(failed.contains("activePromoted=false"), true)
        @Expect(after.activeKnowledgeVersion, before)
        @Expect(after.failedCandidateVersion.contains("candidate"), true)
        @Expect(failStore.has("raw/candidate/${after.candidateKnowledgeVersion}/records.ckb"), true)
        @Expect(failStore.has("index/active.ckb"), false)
    }

    @TestCase
    public func cliLikeRebuildThenIndependentEvidenceUsesPersistedActive(): Unit {
        let store = FileKnowledgeStore("target/ckb-test-cli-p5")
        let rebuildKb = newKnowledgeBaseFromStore(store).kb
        let rebuild = ckbRebuildIndex(rebuildKb, store)

        let evidenceKb = newKnowledgeBaseFromStore(store).kb
        let rendered = renderQuery(cangjie_evidence_pack(evidenceKb, "HttpClient", 3))

        @Expect(rebuild.ok, true)
        @Expect(rendered.contains("knowledgeVersion=ckb-20260519-000200-active"), true)
        @Expect(rendered.contains("graphContext"), true)
        @Expect(rendered.contains("ckb-20260519-000100-active"), false)
    }

    @TestCase
    public func httpSourceFetchRunnerMapsHttpStatusRetryAndTimeout(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let request = SourceRequestBuilder().gitCodeOrgRepos("cangjie")
        request.retryCount = 1

        let unauthorized = HttpSourceFetchRunner(config, executor: FakeHttpExecutor(401, "{}", "application/json", "http_401", 0)).fetch(request)
        let missing = HttpSourceFetchRunner(config, executor: FakeHttpExecutor(404, "{}", "application/json", "http_404", 0)).fetch(request)
        let limited = HttpSourceFetchRunner(config, executor: FakeHttpExecutor(429, "{}", "application/json", "http_429", 30)).fetch(request)
        let timeoutExecutor = FakeHttpExecutor(0, "", "", "timeout", 0)
        timeoutExecutor.transportErrorClass = "timeout"
        timeoutExecutor.transportDiagnostic = "native request timed out"
        let timeout = HttpSourceFetchRunner(config, executor: timeoutExecutor).fetch(request)

        @Expect(unauthorized.status, "auth_degraded")
        @Expect(missing.status, "not_found")
        @Expect(limited.status, "rate_limited")
        @Expect(limited.retryAfterSeconds, 30)
        @Expect(limited.attempts, 2)
        @Expect(timeout.status, "timeout")
        @Expect(timeout.transportErrorClass, "timeout")
        @Expect(timeout.transportDiagnostic, "native request timed out")
        @Expect(timeout.curlExitCode, 0)
    }

    @TestCase
    public func nativeHttpTransportResolvesProxyRoutesAndRedactsCredentials(): Unit {
        let direct = CkbNativeHttpTransportConfig("", false, "", false, false, "", 10000)
        let proxied = CkbNativeHttpTransportConfig("http://user:pass@127.0.0.1:7897", false, "", false, false, "", 10000)
        let httpsProxy = CkbNativeHttpTransportConfig("https://user:pass@127.0.0.1:7897", false, "", false, false, "", 10000)
        let noProxy = CkbNativeHttpTransportConfig("http://user:pass@127.0.0.1:7897", false, "api.gitcode.com", false, false, "", 10000)

        let directRoute = ckbNativeHttpResolveRoute("https://api.gitcode.com/api/v5/orgs/cangjie/repos", direct)
        let tunnelRoute = ckbNativeHttpResolveRoute("https://api.gitcode.com/api/v5/orgs/cangjie/repos", proxied)
        let httpProxyRoute = ckbNativeHttpResolveRoute("http://gitcode.com/cangjie/stdx", proxied)
        let unsupportedRoute = ckbNativeHttpResolveRoute("https://api.gitcode.com/api/v5/orgs/cangjie/repos", httpsProxy)
        let noProxyRoute = ckbNativeHttpResolveRoute("https://api.gitcode.com/api/v5/orgs/cangjie/repos", noProxy)
        let directPlan = ckbNativeHttpDescribeBuildPlan("https://api.gitcode.com/api/v5/orgs/cangjie/repos", direct)
        let tunnelPlan = ckbNativeHttpDescribeBuildPlan("https://api.gitcode.com/api/v5/orgs/cangjie/repos", proxied)
        let httpProxyPlan = ckbNativeHttpDescribeBuildPlan("http://gitcode.com/cangjie/stdx", proxied)

        @Expect(directRoute.mode, "direct")
        @Expect(tunnelRoute.mode, "httpConnectTunnel")
        @Expect(httpProxyRoute.mode, "httpProxy")
        @Expect(tunnelRoute.redactedProxy.contains("user:pass"), false)
        @Expect(tunnelRoute.redactedProxy.contains("[redacted]@127.0.0.1:7897"), true)
        @Expect(unsupportedRoute.mode, "unsupportedHttpsProxy")
        @Expect(unsupportedRoute.error.contains("true HTTPS proxy is not implemented"), true)
        @Expect(noProxyRoute.mode, "direct")
        @Expect(directPlan.route.mode, "direct")
        @Expect(directPlan.useConnector, false)
        @Expect(directPlan.useTls, true)
        @Expect(tunnelPlan.route.mode, "httpConnectTunnel")
        @Expect(tunnelPlan.useConnector, true)
        @Expect(tunnelPlan.useTls, true)
        @Expect(httpProxyPlan.route.mode, "httpProxy")
        @Expect(httpProxyPlan.useConnector, false)
        @Expect(httpProxyPlan.useHttpProxy, true)
        @Expect(httpProxyPlan.useTls, false)
    }

    @TestCase
    public func nativeHttpTransportBlocksUnsafeUrlsAndClassifiesExceptions(): Unit {
        let config = CkbNativeHttpTransportConfig("", false, "", false, false, "", 10000)
        let extended = CkbNativeHttpTransportConfig("", false, "", false, false, "docs.example.org", 10000)

        @Expect(ckbNativeHttpValidateUrl("file:///tmp/a", config), "blocked non-http url")
        @Expect(ckbNativeHttpValidateUrl("https://127.0.0.1/secret", config).contains("private-network"), true)
        @Expect(ckbNativeHttpValidateUrl("https://evil.example.com/", config).contains("blocked host"), true)
        @Expect(ckbNativeHttpValidateUrl("https://api.gitcode.com/api/v5/orgs/cangjie/repos", config), "")
        @Expect(ckbNativeHttpValidateUrl("https://guide.docs.example.org/cangjie", extended), "")

        @Expect(ckbNativeHttpClassifyException("operation timed out").transportErrorClass, "timeout")
        @Expect(ckbNativeHttpClassifyException("could not resolve host").transportErrorClass, "dns")
        @Expect(ckbNativeHttpClassifyException("Failed to resolve address example.invalid").transportErrorClass, "dns")
        @Expect(ckbNativeHttpClassifyException("nodename nor servname provided, or not known").transportErrorClass, "dns")
        @Expect(ckbNativeHttpClassifyException("Name or service not known").transportErrorClass, "dns")
        @Expect(ckbNativeHttpClassifyException("TLS handshake failed (client): certificate verify failed (134), TLS alert unknown CA(F)").transportErrorClass, "tls_unknown_ca")
        @Expect(ckbNativeHttpClassifyException("TLS certificate verify failed").transportErrorClass, "tls_unknown_ca")
        @Expect(ckbNativeHttpClassifyException("certificate hostname mismatch").transportErrorClass, "tls_hostname_mismatch")
        @Expect(ckbNativeHttpClassifyException("certificate has expired").transportErrorClass, "tls_expired_certificate")
        @Expect(ckbNativeHttpClassifyException("Can not load openssl library or function CRYPTO_get_ex_new_index.").transportErrorClass, "tls_runtime")
        @Expect(ckbNativeHttpClassifyException("TLS handshake failed").transportErrorClass, "tls_handshake_failed")
        @Expect(ckbNativeHttpClassifyException("proxy CONNECT failed").transportErrorClass, "proxy")
        @Expect(ckbNativeHttpClassifyException("connection refused").transportErrorClass, "connection_refused")
        @Expect(ckbNativeHttpClassifyException("Authorization: Bearer secret-token").transportDiagnostic.contains("secret-token"), false)
    }

    @TestCase
    public func serviceCommandLoopExposesHealthStatusQueryEvidenceSyncAndRestart(): Unit {
        let store = FileKnowledgeStore("target/ckb-test-service-a4")
        let kb = newKnowledgeBaseFromStore(store).kb
        let rebuild = ckbRebuildIndex(kb, store)
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        config.gitCodeTokenRef = "secret-service-token"
        let fake = FakeSourceFetchRunner()
        let service = CkbCommandLoopService(config, store, sourceRunner: fake)

        let start = service.start()
        let health = service.handleLine("health").text
        let status = service.handleLine("status").text
        let query = service.handleLine("query HttpClient").text
        let evidence = service.handleLine("evidence func syntax").text
        let sync = service.handleLine("sync").text
        let restart = service.handleLine("restart").text
        let afterRestart = service.handleLine("health").text
        let stop = service.handleLine("stop")

        @Expect(rebuild.ok, true)
        @Expect(start.contains("service_started"), true)
        @Expect(health.contains("protocol=ckb-stdio-v1"), true)
        @Expect(status.contains("activeStateSource=persisted"), true)
        @Expect(query.contains("citation"), true)
        @Expect(evidence.contains("graphContext"), true)
        @Expect(sync.contains("summary"), true)
        @Expect(restart.contains("service_restarted"), true)
        @Expect(afterRestart.contains("ckb-20260519-000200-active") || afterRestart.contains("ckb-20260519-000100-active"), true)
        @Expect(stop.shouldStop, true)
        @Expect("${start}${health}${status}${query}${evidence}${sync}${restart}${stop.text}".contains("secret-service-token"), false)
    }

    @TestCase
    public func schedulerExecutorCheckpointsSuccessRetryAndDegradedState(): Unit {
        let clock = FakeClock(0)
        let scheduler = Scheduler(clock)
        let runner = ScriptedSchedulerTaskRunner()
        let executor = SchedulerExecutor(scheduler, runner)

        runner.ok = true
        runner.status = "fixture_ok"
        runner.cursor = "cursor-1"
        runner.since = "10"
        runner.activeVersion = "ckb-20260519-000100-active"
        runner.candidateVersion = "ckb-20260519-000100-candidate"
        let success = executor.runDue(limit: 1)

        runner.ok = false
        runner.status = "fixture_down"
        let firstFailure = executor.runDue(limit: 1)
        clock.advance(5)
        let secondFailure = executor.runDue(limit: 1)
        clock.advance(15)
        let thirdFailure = executor.runDue(limit: 1)

        @Expect(success.ran, 1)
        @Expect(success.succeeded, 1)
        @Expect(scheduler.entries[0].lastCursor, "cursor-1")
        @Expect(scheduler.entries[0].lastSince, "10")
        @Expect(scheduler.entries[0].activeVersion, "ckb-20260519-000100-active")
        @Expect(firstFailure.failed, 1)
        @Expect(secondFailure.failed, 1)
        @Expect(thirdFailure.failed, 1)
        @Expect(scheduler.entries[3].failureCount, 3)
        @Expect(scheduler.entries[3].degraded, true)
        @Expect(scheduler.entries[3].nextRunAt, 80)
    }

    @TestCase
    public func schedulerCheckpointsPersistAcrossKnowledgeBaseReload(): Unit {
        let store = FileKnowledgeStore("target/ckb-test-scheduler-persist")
        store.saveScheduler(ArrayList<ScheduleEntry>())
        let kb = newKnowledgeBaseFromStore(store).kb
        kb.scheduler.entries[0].nextRunAt = 0
        let runner = ScriptedSchedulerTaskRunner()
        runner.ok = true
        runner.status = "fixture_ok"
        runner.cursor = "cursor-persisted"
        runner.since = "20"
        runner.activeVersion = "ckb-20260519-000100-active"
        runner.candidateVersion = "ckb-20260519-000100-candidate"
        let executor = SchedulerExecutor(kb.scheduler, runner)

        let result = executor.runDue(limit: 1)
        store.saveScheduler(kb.scheduler.entries)
        let loaded = newKnowledgeBaseFromStore(store)
        let status = cangjie_knowledge_status(loaded.kb)

        @Expect(result.succeeded, 1)
        @Expect(status.schedules[0].lastCursor, "cursor-persisted")
        @Expect(status.schedules[0].lastSince, "20")
        @Expect(status.schedules[0].lastStatus, "fixture_ok")
    }

    @TestCase
    public func backupRestoreActiveSnapshotAndRejectCorruptedBackup(): Unit {
        let sourceStore = FileKnowledgeStore("target/ckb-test-backup-source")
        let sourceKb = newKnowledgeBaseFromStore(sourceStore).kb
        let rebuild = ckbRebuildIndex(sourceKb, sourceStore)
        let backupPath = "target/ckb-test-backup-copy"
        let restoredStore = FileKnowledgeStore("target/ckb-test-backup-restored")

        let backup = sourceStore.backupActiveSnapshot(backupPath)
        let missingPath = sourceStore.backupActiveSnapshot("")
        let restore = restoredStore.restoreActiveSnapshotBackup(backupPath)
        let loaded = newKnowledgeBaseFromStore(restoredStore)
        let pack = cangjie_evidence_pack(loaded.kb, "HttpClient", 3)
        File.writeTo(Path("${backupPath}/index/active.ckb"), "corrupted|snapshot\n".toArray())
        let corrupted = FileKnowledgeStore("target/ckb-test-backup-corrupted-target").restoreActiveSnapshotBackup(backupPath)

        @Expect(rebuild.ok, true)
        @Expect(backup.ok, true)
        @Expect(missingPath.diagnostic, "missing_backup_path")
        @Expect(backup.activeVersion, "ckb-20260519-000200-active")
        @Expect(restore.ok, true)
        @Expect(loaded.source, "persisted")
        @Expect(pack.knowledgeVersion, "ckb-20260519-000200-active")
        @Expect(corrupted.ok, false)
        @Expect(corrupted.diagnostic, "malformed_active_index")
        @Expect(renderBackupRestore(backup).contains("/Users/l3gi0n"), false)
    }
}

class ScriptedSchedulerTaskRunner <: SchedulerTaskRunner {
    public var ok: Bool = true
    public var status: String = "fixture_ok"
    public var cursor: String = ""
    public var since: String = ""
    public var activeVersion: String = ""
    public var candidateVersion: String = ""

    public init() {}

    public func runTask(name: String, since: String): SchedulerTaskResult {
        let result = SchedulerTaskResult()
        result.ok = this.ok
        result.status = this.status
        result.cursor = this.cursor
        result.since = this.since
        result.activeVersion = this.activeVersion
        result.candidateVersion = this.candidateVersion
        result
    }
}

class ScriptedSourceFetchRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()

    public init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        result.ok = true
        result.status = "ok"
        result.statusCode = 200
        result.sourceUrl = request.url
        result.normalizedType = request.kind
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.repoVisibility = request.repoVisibility
        result.contentType = if (request.accept == "text/html") { "text/html" } else { "application/json" }
        result.body = this.bodyFor(request)
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result.attempts = 1
        result
    }

    private func bodyFor(request: SourceFetchRequest): String {
        if (request.kind == SourceKinds.GITCODE_ORG) {
            if (request.repo == "cangjie") {
                return "[{\"id\":1,\"display_name\":\"仓颉公开仓库\",\"path\":\"repo-one\",\"description\":\"中文说明 {真实响应}\",\"default_branch\":\"dev\",\"public\":true,\"namespace\":{\"display_name\":\"仓颉组织\",\"path\":\"cangjie\"},\"web_url\":\"https://gitcode.com/cangjie/repo-one\",\"access_token\":\"fake-live-token\"},{\"id\":2,\"display_name\":\"仓颉私有仓库\",\"path\":\"private-one\",\"default_branch\":\"main\",\"private\":true,\"namespace\":{\"path\":\"cangjie\"}},{\"id\":3,\"path\":\"internal-one\",\"default_branch\":\"main\",\"internal\":true,\"namespace\":{\"path\":\"cangjie\"}},{\"id\":4,\"path\":\"unknown-one\",\"default_branch\":\"main\",\"namespace\":{\"path\":\"cangjie\"}}]"
            }
            return "[]"
        }
        if (request.kind == SourceKinds.GITCODE_TREE) {
            return "{\"tree\":[{\"type\":\"blob\",\"path\":\"src/main.cj\",\"name\":\"仓颉主入口\"},{\"type\":\"blob\",\"path\":\"README.md\",\"description\":\"中文 README [] {}\"},{\"type\":\"blob\",\"path\":\"target/generated.cj\"}]}"
        }
        if (request.kind == SourceKinds.GITCODE_SOURCE) {
            return "public func repoOneMain(): Unit { println(\"repo one\") }"
        }
        if (request.kind == SourceKinds.GITCODE_ISSUE_HISTORY) {
            return "[{\"number\":\"1\",\"title\":\"issue\",\"body\":\"public issue\"}]"
        }
        if (request.kind == SourceKinds.GITCODE_PR_HISTORY) {
            return "[{\"number\":\"2\",\"title\":\"pull\",\"body\":\"public pull\"}]"
        }
        if (request.kind == SourceKinds.GITCODE_COMMENT_HISTORY) {
            return "[{\"id\":3,\"body\":\"public comment\"}]"
        }
        if (request.kind == SourceKinds.CANGJIE_WEBSITE || request.kind == SourceKinds.CANGJIE_DOCS) {
            return "<html>Cangjie public documentation</html>"
        }
        "fixture body"
    }
}

class FakeHttpExecutor <: HttpRequestExecutor {
    let code: Int64
    let body: String
    let contentType: String
    let status: String
    let retryAfter: Int64
    public var calls: Int64 = 0
    public var seenHeaders: ArrayList<String> = ArrayList<String>()
    public var transportErrorClass: String = ""
    public var transportDiagnostic: String = ""
    public var curlExitCode: Int64 = 0

    init(code: Int64, body: String, contentType: String, status: String, retryAfter: Int64) {
        this.code = code
        this.body = body
        this.contentType = contentType
        this.status = status
        this.retryAfter = retryAfter
    }

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        this.calls += 1
        for (header in request.headers) {
            this.seenHeaders.add(header)
        }
        let response = HttpExecutionResponse()
        response.statusCode = this.code
        response.body = this.body
        response.contentType = this.contentType
        response.status = this.status
        response.retryAfterSeconds = this.retryAfter
        response.transportErrorClass = this.transportErrorClass
        response.transportDiagnostic = this.transportDiagnostic
        response.curlExitCode = this.curlExitCode
        response
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
