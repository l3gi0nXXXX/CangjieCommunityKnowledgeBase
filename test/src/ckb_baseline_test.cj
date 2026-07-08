package cangjie_community_knowledge_base_test

import std.collection.ArrayList
import std.env.getVariable
import std.fs.{Directory, File, Path, exists}
import std.process.*
import std.unittest.*
import std.unittest.testmacro.*

class SourceAnalysisFakeRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()
    public var rawStatusCode: Int64 = 200
    public var contentsStatusCode: Int64 = 200
    public var body: String = "func targetSymbol() { println(\"ok\") }"
    public var contentsBodyBase64: String = "ZnVuYyB0YXJnZXRTeW1ib2woKSB7IHByaW50bG4oXCJva1wiKSB9"
    public var sourceUrlSuffix: String = ""

    init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        let statusCode = if (request.sourceVariant == "raw" || request.purpose == "source_raw_snapshot") { this.rawStatusCode } else { this.contentsStatusCode }
        result.ok = statusCode >= 200 && statusCode < 300
        result.statusCode = statusCode
        result.status = if (result.ok) { "ok" } else { "not_found" }
        result.body = if (!result.ok) {
            ""
        } else if (request.sourceVariant == "contents" || request.purpose == "source_contents_snapshot") {
            "{\"type\":\"file\",\"encoding\":\"base64\",\"content\":\"${this.contentsBodyBase64}\",\"path\":\"${request.path}\",\"sha\":\"fake-analysis-commit\",\"html_url\":\"${request.url}${this.sourceUrlSuffix}\"}"
        } else {
            this.body
        }
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
        @Expect(doctor.contains("/Users/example"), false)
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
    public func ckg0Ut001EvidencePackBaselineStillHasTypedEvidence(): Unit {
        let kb = newOfflineKnowledgeBase()

        let pack = cangjie_evidence_pack(kb, "HttpClient", 3)

        @Expect(pack.knowledgeVersion.contains("ckb-"), true)
        @Expect(pack.sourceEvidence.size > 0, true)
        @Expect(pack.docEvidence.size > 0, true)
        @Expect(pack.citations.size > 0, true)
    }

    @TestCase
    public func ckg1Ut001CangjieKnowledgePackModelCarriesCitationFields(): Unit {
        let pack = CangjieKnowledgePack()
        let item = CangjieKnowledgeItem()
        item.kind = "syntax"
        item.title = "Option"
        item.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/language/option"
        item.knowledgeVersion = "ckb-test"
        pack.knowledgeVersion = "ckb-test"
        pack.targetVersion = "1.0.0"
        pack.citations.add(SourceReference("cangjie-syntax-option", item.citation, item.knowledgeVersion))
        pack.items.add(item)

        @Expect(pack.knowledgeVersion, "ckb-test")
        @Expect(pack.targetVersion, "1.0.0")
        @Expect(pack.citations.size, 1)
        @Expect(pack.items[0].citation.contains("docs.cangjie-lang.cn"), true)
    }

    @TestCase
    public func ckg1Bnd001TargetVersionNormalizationAndBudgetClampAreDeterministic(): Unit {
        @Expect(cangjieNormalizeTargetVersion(""), "1.0.0")
        @Expect(cangjieNormalizeTargetVersion("1.0.0"), "1.0.0")
        @Expect(cangjieNormalizeTargetVersion("../../"), "1.0.0")
        @Expect(cangjieNormalizeTargetVersion("1.0.0-alpha"), "1.0.0-alpha")
        @Expect(cangjieCapabilityClampBudget(0, 5, 20), 5)
        @Expect(cangjieCapabilityClampBudget(999, 5, 20), 20)
    }

    @TestCase
    public func ckbUtf8SafePrefixKeepsByteBudgetWithoutSplittingRunes(): Unit {
        @Expect(utf8SafePrefix("abcdef", 3), "abc")
        @Expect(utf8SafePrefix("仓颉🙂abc", 10), "仓颉🙂")
        @Expect(utf8SafePrefix("仓颉", 0), "")
        @Expect(utf8SafePrefix("仓颉", -1), "")
        @Expect(utf8SafePrefix("仓颉", 100), "仓颉")
    }

    @TestCase
    public func ckbUtf8SafeDiagnosticsKeepRedactionAndDoNotSplitRunes(): Unit {
        let diagnostic = ckbNativeHttpClassifyException("TLS 错误🙂 token=secret-token " + repeatText("仓颉🙂", 80))

        @Expect(diagnostic.transportDiagnostic.size <= 160, true)
        @Expect(diagnostic.transportDiagnostic.contains("TLS"), true)
        @Expect(diagnostic.transportDiagnostic.contains("secret-token"), false)
        @Expect(diagnostic.transportDiagnostic.contains("[redacted]"), true)
    }

    @TestCase
    public func ckg1Pos001OfflineFixtureCoversArrayListMainAndJson(): Unit {
        let kb = newOfflineKnowledgeBase()

        let arrayList = cangjie_hybrid_search(kb, "ArrayList", 5)
        let mainRule = cangjie_hybrid_search(kb, "main function", 5)
        let json = cangjie_hybrid_search(kb, "JSON", 5)

        @Expect(arrayList.records.size > 0, true)
        @Expect(mainRule.records.size > 0, true)
        @Expect(json.records.size > 0, true)
        @Expect(arrayList.records[0].metadata.reviewState != ReviewStates.CANDIDATE, true)
    }

    @TestCase
    public func ckg1Neg001WebCandidateDoesNotEnterDefaultExamples(): Unit {
        let kb = newOfflineKnowledgeBase()

        let pack = cangjie_examples(kb, "third party tutorial", maxExamples: 5)

        for (example in pack.examples) {
            @Expect(example.reviewState != ReviewStates.CANDIDATE, true)
            @Expect(example.trustLevel != TrustLevels.WEB_CANDIDATE, true)
        }
    }

    @TestCase
    public func ckg2Ut001KnowledgePackIsCitationBackedOffline(): Unit {
        let kb = newOfflineKnowledgeBase()

        let pack = cangjie_knowledge_pack(kb, "write JSON parser", 5)

        @Expect(pack.knowledgeVersion.contains("ckb-"), true)
        @Expect(pack.targetVersion, "1.0.0")
        @Expect(pack.citations.size > 0, true)
        @Expect(pack.items.size + pack.apiItems.size + pack.examples.size > 0, true)
    }

    @TestCase
    public func ckg2Bnd001KnowledgePackClampsOversizedBudget(): Unit {
        let kb = newOfflineKnowledgeBase()

        let pack = cangjie_knowledge_pack(kb, "ArrayList", 999)

        @Expect(pack.truncated, true)
        @Expect(pack.notes.contains("budget_clamped"), true)
    }

    @TestCase
    public func ckg2Bnd002MarkdownRenderingTruncatesUnicodeOnRuneBoundary(): Unit {
        let pack = CangjieKnowledgePack()
        let item = CangjieKnowledgeItem()
        pack.knowledgeVersion = "ckb-test"
        pack.targetVersion = "1.0.0"
        pack.task = "生成仓颉代码"
        item.kind = "syntax"
        item.title = "仓颉 UTF-8"
        item.content = repeatText("仓颉🙂知识片段", 1200)
        item.citation = "https://docs.cangjie-lang.cn/docs/1.0.0/"
        item.knowledgeVersion = "ckb-test"
        item.targetVersion = "1.0.0"
        pack.items.add(item)
        pack.citations.add(SourceReference("utf8", item.citation, "ckb-test"))

        let markdown = renderCangjieKnowledgePackMarkdown(pack)

        @Expect(markdown.contains("# Cangjie knowledge-pack"), true)
        @Expect(markdown.contains("truncated=true"), true)
        @Expect(markdown.size <= 12000, true)
    }

    @TestCase
    public func ckg2Pos001ApiSearchPrefersArrayListSymbol(): Unit {
        let kb = newOfflineKnowledgeBase()

        let pack = cangjie_api_search(kb, "ArrayList", module: "std.collection", symbol: "ArrayList", budget: 5)

        @Expect(pack.apiItems.size > 0, true)
        @Expect(pack.apiItems[0].symbol.contains("ArrayList"), true)
        @Expect(pack.apiItems[0].trustLevel == TrustLevels.OFFICIAL || pack.apiItems[0].reviewState == ReviewStates.REVIEWED, true)
    }

    @TestCase
    public func ckg2Pos002DiagnoseIsKnowledgeOnlyAndDoesNotExecuteCode(): Unit {
        let kb = newOfflineKnowledgeBase()

        let pack = cangjie_diagnose(kb, "func main() {}", "main function declaration error", budget: 5)

        @Expect(pack.executed, false)
        @Expect(pack.diagnostics.size > 0, true)
        @Expect(pack.diagnostics[0].executed, false)
        @Expect(pack.citations.size > 0, true)
    }

    @TestCase
    public func ckg2Neg001DefaultExamplesExcludeCandidateRecords(): Unit {
        let kb = newOfflineKnowledgeBase()

        let pack = CangjieCapabilityService(kb).examples("external tutorial", maxExamples: 5)

        for (example in pack.examples) {
            @Expect(example.requiresReview, false)
            @Expect(example.reviewState != ReviewStates.CANDIDATE, true)
        }
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
        @Expect(scheduler.dueTaskNames().contains("community_repo_discovery_30d"), true)
        @Expect(scheduler.dueTaskNames().contains("website_probe_weekly"), true)

        scheduler.markSuccess("website_probe_weekly")
        @Expect(scheduler.dueTaskNames().contains("website_probe_weekly"), false)
        clock.advance(10080)
        @Expect(scheduler.dueTaskNames().contains("website_probe_weekly"), true)

        scheduler.markFailure("docs_probe_30d")
        @Expect(scheduler.entries[1].nextRunAt, 10085)
        scheduler.markFailure("docs_probe_30d")
        @Expect(scheduler.entries[1].nextRunAt, 10095)
        scheduler.markFailure("docs_probe_30d")
        @Expect(scheduler.entries[1].nextRunAt, 10140)
        @Expect(scheduler.entries[1].degraded, true)
    }

    @TestCase
    public func schedulerEncodesServiceV1SlaWindows(): Unit {
        let scheduler = Scheduler(FakeClock(0))

        @Expect(intervalFor(scheduler, "community_repo_discovery_30d"), 43200)
        @Expect(intervalFor(scheduler, "docs_probe_30d"), 43200)
        @Expect(intervalFor(scheduler, "website_probe_weekly"), 10080)
        @Expect(intervalFor(scheduler, "website_full_weekly"), 10080)
        @Expect(intervalFor(scheduler, "web_candidate_weekly"), 10080)
        @Expect(intervalFor(scheduler, "weekly_full_rebuild"), 10080)
        @Expect(intervalFor(scheduler, "web_candidate_recrawl_30d"), 43200)
        @Expect(intervalFor(scheduler, "active_item_sync_10m"), -1)
        @Expect(intervalFor(scheduler, "active_repo_fetch_30m"), -1)
        @Expect(intervalFor(scheduler, "repo_list_6h"), -1)
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
        let sourceContents = builder.gitCodeSourceContents("Cangjie/community", "main", "README.md")
        let cangjieSource = builder.gitCodeSource("cangjie/cangjie", "main", "src/main.cj")
        let issues = builder.gitCodeIssueHistory("cangjie/cangjie")
        let pulls = builder.gitCodePrHistory("cangjie/cangjie")
        let communityReadme = builder.gitCodeSource("Cangjie/community", "main", "README.md")
        let nestedSource = builder.gitCodeSource("cangjie/stdx", "main", "docs/source_zh_cn/a.md")
        let slashRefRepo = builder.gitCodeRepo("Cangjie/cangjie_runtime", ref: "release/1.0")
        let slashRefTree = builder.gitCodeTree("Cangjie/cangjie_runtime", "release/1.0")
        let slashRefRaw = builder.gitCodeSource("Cangjie/cangjie_runtime", "release/1.0", "runtime/src/main.cj")
        let slashRefContents = builder.gitCodeSourceContents("Cangjie/cangjie_stdx", "release/1.0", "libs/stdx/README.md")
        let slashRefBranches = builder.gitCodeBranches("Cangjie/cangjie_runtime")
        let slashRefBranch = builder.gitCodeBranchNativeSafe("Cangjie/cangjie_runtime", "release/1.0")
        let resolvedCommit = "0123456789abcdef0123456789abcdef01234567"
        let resolvedTree = builder.gitCodeTreeWithFetchRef("Cangjie/cangjie_runtime", "release/1.0", resolvedCommit)
        let resolvedTreePage2 = builder.gitCodeTreePageWithFetchRef("Cangjie/cangjie_runtime", "release/1.0", resolvedCommit, page: 2, perPage: 50)
        let invalidTreePage = builder.gitCodeTreePageWithFetchRef("Cangjie/cangjie_runtime", "release/1.0", resolvedCommit, page: 0, perPage: 50)
        let resolvedRaw = builder.gitCodeSourceRawWithFetchRef("Cangjie/cangjie_runtime", "release/1.0", resolvedCommit, "runtime/src/main.cj")
        let plusRefTree = builder.gitCodeTree("Cangjie/cangjie_runtime", "feature/a+b")
        let invalidRepo = builder.gitCodeSource("bad repo/name", "main", "README.md")
        let invalidRepoMetadata = builder.gitCodeRepo("cangjie/stdx/extra")
        let invalidRef = builder.gitCodeSource("cangjie/stdx", "../main", "README.md")
        let emptyRef = builder.gitCodeSource("cangjie/stdx", "", "README.md")
        let spaceRef = builder.gitCodeTree("cangjie/stdx", "release 1.0")
        let unicodeRef = builder.gitCodeTree("cangjie/stdx", "发布/1.0")
        let colonRef = builder.gitCodeTree("cangjie/stdx", "release:1.0")
        let invalidPath = builder.gitCodeSource("cangjie/stdx", "main", "../secret.txt")
        let encodedTraversalPath = builder.gitCodeSource("cangjie/stdx", "main", "src/%2e%2e/secret.txt")
        let docs = builder.docs("https://docs.cangjie-lang.cn/docs/1.0.0/")
        let normalizer = SourceResponseNormalizer()
        let result = SourceFetchResult()
        result.statusCode = 206
        result.contentType = "text/plain"
        result.body = "partial source"

        let normalized = normalizer.normalize(source, result)

        @Expect(config.gitCodeBaseUrl, "https://api.gitcode.com/api/v5")
        @Expect(org.url, "https://api.gitcode.com/api/v5/orgs/cangjie/repos?type=public&page=1&per_page=100")
        @Expect(repo.url, "https://api.gitcode.com/api/v5/repos/cangjie/stdx?ref=main")
        @Expect(cangjieRepo.url, "https://api.gitcode.com/api/v5/repos/cangjie/cangjie?ref=main")
        @Expect(source.method, "GET")
        @Expect(source.url, "https://api.gitcode.com/api/v5/repos/cangjie/stdx/raw/src/http/client.cj?ref=main")
        @Expect(source.purpose, "source_raw_snapshot")
        @Expect(source.sourceVariant, "raw")
        @Expect(source.url.contains("/raw/"), true)
        @Expect(source.url.contains("/contents/"), false)
        @Expect(sourceContents.url, "https://api.gitcode.com/api/v5/repos/Cangjie/community/contents/README.md?ref=main")
        @Expect(sourceContents.purpose, "source_contents_snapshot")
        @Expect(sourceContents.sourceVariant, "contents")
        @Expect(sourceContents.accept, "application/json")
        @Expect(communityReadme.url, "https://api.gitcode.com/api/v5/repos/Cangjie/community/raw/README.md?ref=main")
        @Expect(nestedSource.url, "https://api.gitcode.com/api/v5/repos/cangjie/stdx/raw/docs/source_zh_cn/a.md?ref=main")
        @Expect(cangjieSource.url, "https://api.gitcode.com/api/v5/repos/cangjie/cangjie/raw/src/main.cj?ref=main")
        @Expect(slashRefRepo.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime?ref=release%2F1.0")
        @Expect(slashRefRepo.ref, "release/1.0")
        @Expect(slashRefTree.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime/git/trees/release%2F1.0?recursive=1&page=1&per_page=100")
        @Expect(slashRefTree.ref, "release/1.0")
        @Expect(slashRefRaw.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime/raw/runtime/src/main.cj?ref=release%2F1.0")
        @Expect(slashRefRaw.ref, "release/1.0")
        @Expect(slashRefContents.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_stdx/contents/libs/stdx/README.md?ref=release%2F1.0")
        @Expect(slashRefBranches.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime/branches?page=1&per_page=100")
        @Expect(slashRefBranches.kind, SourceKinds.GITCODE_BRANCH)
        @Expect(slashRefBranch.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime/branches/release%252F1.0")
        @Expect(slashRefBranch.ref, "release/1.0")
        @Expect(resolvedTree.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime/git/trees/0123456789abcdef0123456789abcdef01234567?recursive=1&page=1&per_page=100")
        @Expect(resolvedTree.ref, "release/1.0")
        @Expect(resolvedTreePage2.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime/git/trees/0123456789abcdef0123456789abcdef01234567?recursive=1&page=2&per_page=50")
        @Expect(resolvedTreePage2.page, 2)
        @Expect(resolvedTreePage2.perPage, 50)
        @Expect(invalidTreePage.diagnostic, "invalid_pagination")
        @Expect(resolvedRaw.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime/raw/runtime/src/main.cj?ref=0123456789abcdef0123456789abcdef01234567")
        @Expect(resolvedRaw.ref, "release/1.0")
        @Expect(plusRefTree.url, "https://api.gitcode.com/api/v5/repos/Cangjie/cangjie_runtime/git/trees/feature%2Fa%2Bb?recursive=1&page=1&per_page=100")
        @Expect(plusRefTree.ref, "feature/a+b")
        @Expect(source.accept.contains("application/json"), false)
        @Expect(source.accept.contains("text/plain"), true)
        @Expect(source.accept.contains("application/octet-stream"), true)
        let fallbackSource = builder.gitCodeSourceContents("cangjie/stdx", "main", "src/http/client.cj")
        @Expect(fallbackSource.url, "https://api.gitcode.com/api/v5/repos/cangjie/stdx/contents/src/http/client.cj?ref=main")
        @Expect(fallbackSource.accept, "application/json")
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
        @Expect(invalidRepoMetadata.status, "invalid_repo_path")
        @Expect(invalidRef.status, "invalid_ref")
        @Expect(invalidRef.url, "")
        @Expect(emptyRef.status, "invalid_ref")
        @Expect(emptyRef.url, "")
        @Expect(spaceRef.status, "invalid_ref")
        @Expect(spaceRef.url, "")
        @Expect(unicodeRef.status, "invalid_ref")
        @Expect(unicodeRef.url, "")
        @Expect(colonRef.status, "invalid_ref")
        @Expect(colonRef.url, "")
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
    public func rawSourceNormalizerKeepsTextAndRejectsUnsafeBodies(): Unit {
        let request = SourceRequestBuilder().gitCodeSource("Cangjie/community", "main", "README.md")
        let normalizer = SourceResponseNormalizer()

        let text = SourceFetchResult()
        text.statusCode = 200
        text.contentType = "text/markdown"
        text.body = "# README"
        let normalizedText = normalizer.normalize(request, text)
        @Expect(normalizedText.ok, true)
        @Expect(normalizedText.status, "ok")
        @Expect(normalizedText.normalizedType, SourceKinds.GITCODE_SOURCE)
        @Expect(normalizedText.body, "# README")
        @Expect(normalizedText.bytes, "# README".size)
        @Expect(normalizedText.bodyHash, stableSummaryHash("# README"))

        let octet = SourceFetchResult()
        octet.statusCode = 200
        octet.contentType = "application/octet-stream;charset=UTF-8"
        octet.body = "中文 body"
        let normalizedOctet = normalizer.normalize(request, octet)
        @Expect(normalizedOctet.ok, true)
        @Expect(normalizedOctet.body, "中文 body")
        @Expect(normalizedOctet.bytes, "中文 body".size)
        @Expect(normalizedOctet.bodyHash, stableSummaryHash("中文 body"))

        let image = SourceFetchResult()
        image.statusCode = 200
        image.contentType = "image/png"
        image.body = "PNG data"
        let normalizedImage = normalizer.normalize(request, image)
        @Expect(normalizedImage.ok, false)
        @Expect(normalizedImage.status, "unsupported_binary")
        @Expect(normalizedImage.body, "")

        let tooLarge = SourceFetchResult()
        tooLarge.statusCode = 200
        tooLarge.contentType = "text/plain"
        tooLarge.body = repeatText("a", SourceLimits.MAX_FILE_BYTES + 1)
        let normalizedLarge = normalizer.normalize(request, tooLarge)
        @Expect(normalizedLarge.ok, false)
        @Expect(normalizedLarge.status, "source_too_large")
        @Expect(normalizedLarge.truncated, true)
        @Expect(normalizedLarge.body, "")
    }

    @TestCase
    public func sourceResponseNormalizerTruncatesLargeUnicodeJsonSafely(): Unit {
        let request = SourceRequestBuilder().gitCodePrHistory("Cangjie/community")
        let normalizer = SourceResponseNormalizer()
        let exact = SourceFetchResult()
        exact.statusCode = 200
        exact.contentType = "application/json"
        exact.body = repeatText("a", 200000)

        let normalizedExact = normalizer.normalize(request, exact)

        @Expect(normalizedExact.ok, true)
        @Expect(normalizedExact.truncated, false)
        @Expect(normalizedExact.body.size, 200000)

        let unicode = SourceFetchResult()
        unicode.statusCode = 200
        unicode.contentType = "application/json"
        unicode.body = repeatText("仓颉🙂", 50000)

        let normalizedUnicode = normalizer.normalize(request, unicode)

        @Expect(normalizedUnicode.ok, true)
        @Expect(normalizedUnicode.truncated, true)
        @Expect(normalizedUnicode.body.size <= 200000, true)
        @Expect(normalizedUnicode.body.contains("仓颉"), true)
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
        @Expect(runner.calls[0].purpose, "source_raw_snapshot")
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
        @Expect(runner.calls[0].purpose, "source_raw_snapshot")
        @Expect(runner.calls[1].purpose, "source_contents_snapshot")
        @Expect(rendered.contains("secret-token"), false)
        @Expect(rendered.contains("[redacted]"), true)
    }

    @TestCase
    public func sourceAnalysisRawUnicodeBodyDoesNotCrashDuringRedactionOrExcerpt(): Unit {
        let request = SourceAnalysisRequest()
        request.repo = "Cangjie/community"
        request.ref = "main"
        request.query = "source_analysis README.md"
        request.allowCloneFallback = false
        let runner = SourceAnalysisFakeRunner()
        runner.body = "# 仓颉社区\n这是一个包含中文的 README，token=source-secret 后续文本用于验证 Rune 安全截断和脱敏。"
        runner.sourceUrlSuffix = "?access_token=url-secret&x=1"

        let result = ckbSourceAnalysis(request, runner: runner)
        let rendered = renderSourceAnalysis(result)

        @Expect(result.filesRead.size, 1)
        @Expect(result.filesRead[0].excerpt.contains("仓颉社区"), true)
        @Expect(rendered.contains("source-secret"), false)
        @Expect(rendered.contains("url-secret"), false)
        @Expect(rendered.contains("[redacted]"), true)
    }

    @TestCase
    public func sourceAnalysisRawLongUnicodeExcerptTruncatesOnRuneBoundary(): Unit {
        let request = SourceAnalysisRequest()
        request.repo = "Cangjie/community"
        request.ref = "main"
        request.query = "source_analysis README.md"
        request.allowCloneFallback = false
        let runner = SourceAnalysisFakeRunner()
        runner.body = "仓颉源码 token=source-secret " + repeatText("中文片段", 80)

        let result = ckbSourceAnalysis(request, runner: runner)
        let rendered = renderSourceAnalysis(result)

        @Expect(result.filesRead.size, 1)
        @Expect(result.filesRead[0].excerpt.contains("仓颉源码"), true)
        @Expect(result.filesRead[0].excerpt.contains("source-secret"), false)
        @Expect(result.filesRead[0].excerpt.contains("[redacted]"), true)
        @Expect(rendered.contains("source-secret"), false)
    }

    @TestCase
    public func sourceAnalysisContentsFallbackUnicodeBase64DoesNotCrashDuringRedactionOrExcerpt(): Unit {
        let request = SourceAnalysisRequest()
        request.repo = "Cangjie/community"
        request.ref = "main"
        request.query = "source_analysis README.md"
        request.allowCloneFallback = false
        let runner = SourceAnalysisFakeRunner()
        runner.rawStatusCode = 404
        runner.contentsStatusCode = 200
        runner.contentsBodyBase64 = "IyDku5PpookgY29udGVudHMKdG9rZW49Y29udGVudHMtc2VjcmV0IOS4reaWh+e7k+Wwvg=="
        runner.sourceUrlSuffix = "?access_token=url-secret&x=1"

        let result = ckbSourceAnalysis(request, runner: runner)
        let rendered = renderSourceAnalysis(result)

        @Expect(result.sourceAcquisition, SourceAnalysisAcquisition.API_CONTENTS)
        @Expect(result.filesRead.size, 1)
        @Expect(result.filesRead[0].excerpt.contains("仓颉 contents"), true)
        @Expect(rendered.contains("contents-secret"), false)
        @Expect(rendered.contains("url-secret"), false)
        @Expect(rendered.contains("[redacted]"), true)
    }

    @TestCase
    public func redactSensitiveHandlesUtf8BeforeAndAfterAllSensitiveForms(): Unit {
        let raw = "说明 https://gitcode.com/api?access_token=url-secret&x=1 中文 token=inline-secret 后续\n" +
            "PRIVATE-TOKEN: private-secret 中文\n" +
            "Authorization: Bearer auth-secret 中文\n" +
            "Cookie=session-secret 中文\n" +
            "proxy=https://用户:密码@proxy.example:7890/path 中文\n" +
            "mirror=/Users/测试目录/private file"

        let redacted = redactSensitive(raw)

        @Expect(redacted.contains("说明"), true)
        @Expect(redacted.contains("中文"), true)
        @Expect(redacted.contains("url-secret"), false)
        @Expect(redacted.contains("inline-secret"), false)
        @Expect(redacted.contains("private-secret"), false)
        @Expect(redacted.contains("auth-secret"), false)
        @Expect(redacted.contains("session-secret"), false)
        @Expect(redacted.contains("用户:密码"), false)
        @Expect(redacted.contains("测试目录"), false)
        @Expect(redacted.contains("[redacted]"), true)
        @Expect(redacted.contains("[local-path-redacted]"), true)
    }

    @TestCase
    public func redactSensitiveHandlesUtf8EncodedQueryAndRepeatedNeedles(): Unit {
        let raw = "中文前缀 token%3Dencoded-secret&next=1 中文中段 access_token=plain-secret#frag token=tail-secret"

        let redacted = redactSensitive(raw)

        @Expect(redacted.contains("中文前缀"), true)
        @Expect(redacted.contains("中文中段"), true)
        @Expect(redacted.contains("encoded-secret"), false)
        @Expect(redacted.contains("plain-secret"), false)
        @Expect(redacted.contains("tail-secret"), false)
        @Expect(redacted.contains("[redacted]"), true)
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
            if (call.purpose == "source_raw_snapshot") {
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
    public func s1Ut002SourceCandidateSelectorAllowsRuntimeMetadataOnly(): Unit {
        // UT-S1-002: runtime/std source with README and metadata but no .cj is still selectable.
        let source = CangjieVersionSource()
        source.sourceSet = CangjieSourceSets.STD
        source.sourceFamily = "stdlib"
        let profile = ckbSyncProfileForScheduleTask("cangjie_version_branch_refresh")
        let body = "{\"tree\":[{\"type\":\"tree\",\"path\":\"runtime\"},{\"type\":\"blob\",\"path\":\"README.md\"},{\"type\":\"blob\",\"path\":\"cjpm.toml\"},{\"type\":\"blob\",\"path\":\"target/generated.cj\"}]}"

        let selected = SourceCandidateSelector().selectFromTreeForSource(source, profile, body, maxFiles: 2)

        @Expect(selected.size, 2)
        @Expect(selected[0], "README.md")
        @Expect(selected[1], "cjpm.toml")
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
    public func activeSnapshotTransactionWritesManifestCommitAndLiveShadow(): Unit {
        let root = "target/ckb-test-snapshot-tx-commit"
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(kb, store)
        let metadata = store.loadMetadataStatus()
        let txId = metadata.snapshotManifestTxId
        let loaded = newKnowledgeBaseFromStore(store)

        @Expect(rebuild.ok, true)
        @Expect(txId != "", true)
        @Expect(store.has("transactions/${txId}/COMMIT"), true)
        @Expect(store.has("transactions/${txId}/index/active.ckb"), true)
        @Expect(store.has("transactions/${txId}/metadata/status.ckb"), true)
        @Expect(store.has("metadata/active-snapshot.manifest"), true)
        @Expect(store.has("index/active.ckb"), true)
        @Expect(loaded.source, "persisted")
        @Expect(loaded.diagnostic, "ok")
    }

    @TestCase
    public func activeSnapshotIgnoresUncommittedManifestTransaction(): Unit {
        let root = "target/ckb-test-snapshot-tx-uncommitted"
        let store = FileKnowledgeStore(root)
        let kb = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(kb, store)
        let oldVersion = store.loadActiveVersion()

        store.writeLinesAtomically("transactions/pending-tx/index/active.version", "ckb-broken-active\n")
        store.writeLinesAtomically("transactions/pending-tx/index/active.ckb", "broken\n")
        store.writeLinesAtomically("metadata/active-snapshot.manifest", "txId=pending-tx\nactive=ckb-broken-active\ncommitted=true\n")
        let snapshot = store.loadActiveSnapshot()

        @Expect(rebuild.ok, true)
        @Expect(snapshot.valid, true)
        @Expect(snapshot.activeVersion, oldVersion)
        @Expect(snapshot.diagnostic.contains("ignored_uncommitted_snapshot_tx:pending-tx"), true)
    }

    @TestCase
    public func activeSnapshotRejectsMissingVersionAndRecoversMismatchedMetadataAsDegraded(): Unit {
        let missing = FileKnowledgeStore("target/ckb-test-restore-missing")
        let missingSnapshot = missing.loadActiveSnapshot()
        let store = FileKnowledgeStore("target/ckb-test-restore-mismatch")
        let kb = newOfflineKnowledgeBase()
        let rebuild = ckbRebuildIndex(kb, store)
        _ = launch("/bin/rm", ["-f", Path("target/ckb-test-restore-mismatch/metadata/active-snapshot.manifest").toString()]).wait()
        File.writeTo(Path("target/ckb-test-restore-mismatch/metadata/status.ckb"), "active=wrong-active\n".toArray())
        let mismatched = store.loadActiveSnapshot()
        let loaded = newKnowledgeBaseFromStore(store)
        let status = cangjie_knowledge_status(loaded.kb)

        @Expect(missingSnapshot.valid, false)
        @Expect(missingSnapshot.diagnostic, "missing_active_version")
        @Expect(rebuild.ok, true)
        @Expect(mismatched.valid, true)
        @Expect(mismatched.degraded, true)
        @Expect(mismatched.diagnostic, "metadata_active_mismatch")
        @Expect(loaded.source, "persisted_degraded")
        @Expect(status.storage.indexCount, mismatched.activeIndex.size)
        @Expect(status.restoreDiagnostic.contains("metadata_active_mismatch"), true)
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
    public func runtimeFactoriesExposeOllamaAndQdrantConfigBranchesWithoutLocalFallback(): Unit {
        let config = CkbRuntimeConfig()
        config.embeddingProvider = "ollama"
        config.embeddingModel = "bge-m3:latest"
        config.embeddingDimensions = 1024
        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.embeddingAllowPrivateEndpoint = true
        config.vectorBackend = "qdrant"
        config.vectorDimensions = 1024
        config.vectorDistance = "Cosine"
        config.vectorTimeoutMillis = 9876
        config.vectorRetryCount = 3
        config.vectorAllowPrivateEndpoint = true
        config.vectorActiveCollection = "ckb_active"
        config.vectorCandidateCollection = "ckb_candidate"

        let embedding = embeddingProviderFromRuntime(config).status()
        let vector = vectorStoreFromRuntime(config).status("ckb_active")

        @Expect(embedding.provider, "ollama")
        @Expect(embedding.production, true)
        @Expect(embedding.endpointConfigured, true)
        @Expect(embedding.tokenConfigured, false)
        @Expect(embedding.dimensions, 1024)
        @Expect(embedding.state, EmbeddingProviderState.READY)
        @Expect(vector.backend, "qdrant")
        @Expect(vector.collection, "ckb_active")
        @Expect(vector.activeCollection, "ckb_active")
        @Expect(vector.candidateCollection, "ckb_candidate")
        @Expect(vector.dimension, 1024)
        @Expect(vector.state, EmbeddingProviderState.DEGRADED)
        @Expect(vector.degradedReason, "qdrant_vector_missing_config")
    }

    @TestCase
    public func runtimeFactoriesBlockPrivateAdapterEndpointsUnlessExplicitlyAllowed(): Unit {
        let config = CkbRuntimeConfig()
        config.embeddingProvider = "ollama"
        config.embeddingModel = "bge-m3:latest"
        config.embeddingDimensions = 1024
        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.vectorBackend = "qdrant"
        config.vectorEndpoint = "http://127.0.0.1:6333"
        config.vectorDimensions = 1024

        let embedding = embeddingProviderFromRuntime(config).status()
        let vector = vectorStoreFromRuntime(config).status("active")

        @Expect(embedding.provider, "ollama")
        @Expect(embedding.degradedReason, "embedding_private_endpoint_not_allowed")
        @Expect(vector.backend, "qdrant")
        @Expect(vector.degradedReason, "vector_private_endpoint_not_allowed")
    }

    @TestCase
    public func p4Neg001QdrantDimensionMismatchIsExplicitlyDegraded(): Unit {
        let config = CkbRuntimeConfig()
        config.embeddingProvider = "ollama"
        config.embeddingModel = "bge-m3:latest"
        config.embeddingDimensions = 1024
        config.embeddingEndpoint = "http://127.0.0.1:11434/api/embed"
        config.embeddingAllowPrivateEndpoint = true
        config.vectorBackend = "qdrant"
        config.vectorEndpoint = "http://127.0.0.1:6333"
        config.vectorAllowPrivateEndpoint = true
        config.vectorDimensions = 16

        let vector = vectorStoreFromRuntime(config).status("ckb_active")

        @Expect(vector.backend, "qdrant")
        @Expect(vector.state, EmbeddingProviderState.DEGRADED)
        @Expect(vector.degradedReason, "embedding_vector_dimension_mismatch")
    }

    @TestCase
    public func runtimeFactoriesRejectUnknownProductionProvidersWithoutDeterministicFallback(): Unit {
        let config = CkbRuntimeConfig()
        config.embeddingProvider = "unknown-provider"
        config.embeddingEndpoint = "https://embedding.invalid/v1"
        config.vectorBackend = "unknown-vector"
        config.vectorEndpoint = "https://vector.invalid"

        let embedding = embeddingProviderFromRuntime(config).status()
        let vector = vectorStoreFromRuntime(config).status("active")

        @Expect(embedding.provider, "unknown-provider")
        @Expect(embedding.state, EmbeddingProviderState.DEGRADED)
        @Expect(embedding.degradedReason, "unsupported_provider")
        @Expect(vector.backend, "unknown-vector")
        @Expect(vector.state, EmbeddingProviderState.DEGRADED)
        @Expect(vector.degradedReason, "unsupported_vector_backend")
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

        @Expect(tools.contains("ordinaryMcpReadOnlyTools"), true)
        @Expect(tools.contains("cangjie_knowledge_pack"), true)
        @Expect(tools.contains("cangjie_version_resolve"), true)
        @Expect(tools.contains("cangjie_task_knowledge_pack"), true)
        @Expect(tools.contains("cangjie_knowledge_coverage"), true)
        @Expect(tools.contains("cangjie_compile_diagnose_v2"), true)
        @Expect(tools.contains("cangjie.sync"), false)
        @Expect(tools.contains("cangjie.rebuild"), false)
        @Expect(tools.contains("cangjie.admin_scheduler_run"), false)
        @Expect(tools.contains("httpAdminRoutes"), true)
        @Expect(tools.contains("POST /v1/admin/scheduler/run"), true)
        @Expect(routes.contains("/v1/cangjie/task-knowledge-pack"), true)
        @Expect(routes.contains("/v1/cangjie/version/resolve"), true)
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
        let architecture = String.fromUtf8(File.readFrom(Path("../docs/architecture.md")))
        let production = String.fromUtf8(File.readFrom(Path("../docs/production-embedding-vector-db.md")))
        let readme = String.fromUtf8(File.readFrom(Path("../README.md")))
        let ignore = String.fromUtf8(File.readFrom(Path("../.gitignore")))
        let docs = integration + "\n" + checklist + "\n" + architecture + "\n" + production + "\n" + readme
        let workspaceMarker = "workspace" + "_cangjie"

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
        @Expect(docs.contains("/Users/example/.metis"), false)
        @Expect(docs.contains("/Users/"), false)
        @Expect(docs.contains(workspaceMarker), false)
        @Expect(docs.contains("cangjie100"), false)
        @Expect(ignore.contains("tokenFile"), true)
        @Expect(ignore.contains("ckb-live.conf"), true)
        @Expect(ignore.contains("*.token"), true)
        @Expect(ignore.contains("*.local.conf"), true)
    }

    @TestCase
    public func runtimeConfigDefaultsToOfflineAndRedactsSensitiveText(): Unit {
        let config = loadCkbRuntimeConfig("")
        let doctor = renderRuntimeDoctor(config)
        let redacted = redactSensitive("PRIVATE-TOKEN: private-token-secret\nAuthorization: Bearer fake-token\nCookie=session=abc https://gitcode.com/api?access_token=secret&x=1 mirror=/Users/example/private")

        @Expect(config.networkEnabled, false)
        @Expect(config.gitCodeAuthHeader, "private-token")
        @Expect(config.gitCodeAccessTokenQuery, false)
        @Expect(config.embeddingProvider, "deterministic")
        @Expect(config.embeddingAllowPrivateEndpoint, false)
        @Expect(config.vectorBackend, "local-file")
        @Expect(config.vectorDimensions, 16)
        @Expect(config.vectorDistance, "Cosine")
        @Expect(config.vectorAllowPrivateEndpoint, false)
        @Expect(doctor.contains("network=disabled"), true)
        @Expect(doctor.contains("gitcode.authHeader=private-token"), true)
        @Expect(doctor.contains("gitcode.accessTokenQuery=disabled"), true)
        @Expect(doctor.contains("gitcode.token=absent"), true)
        @Expect(doctor.contains("embedding.allowPrivateEndpoint=false"), true)
        @Expect(doctor.contains("vector.backend=local-file"), true)
        @Expect(doctor.contains("vector.endpoint=absent"), true)
        @Expect(doctor.contains("vector.allowPrivateEndpoint=false"), true)
        @Expect(redacted.contains("private-token-secret"), false)
        @Expect(redacted.contains("fake-token"), false)
        @Expect(redacted.contains("session=abc"), false)
        @Expect(redacted.contains("secret"), false)
        @Expect(redacted.contains("/Users/example"), false)
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
        let sensitive = diagnoseCurlTransportError(6, "curl: (6) Could not resolve host: gitcode.com\nAuthorization: Bearer live-token-secret\nCookie: SESSION=cookie-secret\nretry token=token-secret path=/Users/example/private/ckb-live.conf extra=abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz")

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
        @Expect(sensitive.transportDiagnostic.contains("/Users/example"), false)
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
gitcode.tokenFile=/Users/example/.metis/gitcode-token
website.enabled=true
docs.enabled=true
index.backend=local-vector
embedding.provider=production-http
embedding.model=remote-embedding
embedding.dimensions=128
embedding.endpoint=https://embedding.invalid/v1?access_token=fake-live-token
embedding.tokenFile=/Users/example/.metis/embedding-token
embedding.batchSize=24
embedding.timeoutMillis=2345
embedding.retryCount=5
embedding.allowPrivateEndpoint=true
vector.backend=qdrant
vector.endpoint=http://127.0.0.1:6333?api_key=fake-live-token
vector.activeCollection=prod-active
vector.candidateCollection=prod-candidate
vector.dimensions=1024
vector.distance=Cosine
vector.timeoutMillis=3456
vector.retryCount=6
vector.apiKeyFile=/Users/example/.metis/qdrant-token
vector.allowPrivateEndpoint=true
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
        @Expect(config.embeddingAllowPrivateEndpoint, true)
        @Expect(config.vectorBackend, "qdrant")
        @Expect(config.vectorEndpoint, "http://127.0.0.1:6333?api_key=fake-live-token")
        @Expect(config.vectorActiveCollection, "prod-active")
        @Expect(config.vectorCandidateCollection, "prod-candidate")
        @Expect(config.vectorDimensions, 1024)
        @Expect(config.vectorDistance, "Cosine")
        @Expect(config.vectorTimeoutMillis, 3456)
        @Expect(config.vectorRetryCount, 6)
        @Expect(config.vectorApiKeyFile, "/Users/example/.metis/qdrant-token")
        @Expect(config.vectorAllowPrivateEndpoint, true)
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
        @Expect(summary.contains("embedding.allowPrivateEndpoint=true"), true)
        @Expect(summary.contains("vector.backend=qdrant"), true)
        @Expect(summary.contains("vector.endpoint=present"), true)
        @Expect(summary.contains("vector.dimensions=1024"), true)
        @Expect(summary.contains("vector.distance=Cosine"), true)
        @Expect(summary.contains("vector.timeoutMillis=3456"), true)
        @Expect(summary.contains("vector.retryCount=6"), true)
        @Expect(summary.contains("vector.apiKey=present"), true)
        @Expect(summary.contains("vector.allowPrivateEndpoint=true"), true)
        @Expect(summary.contains("fake-live-token"), false)
        @Expect(summary.contains("/Users/example"), false)
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
        @Expect(text.contains("sourceVariant=raw"), true)
        @Expect(text.contains("source.maxFileBytes=${SourceLimits.MAX_FILE_BYTES}"), true)
        @Expect(text.contains("sourceMaxFileBytes=${SourceLimits.MAX_FILE_BYTES}"), true)
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
    public func syncLiveRawSourceSuccessDoesNotCallContentsFallback(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let options = LiveSyncOptions()
        options.dryRun = true
        options.maxRepos = 1
        options.maxFilesPerRepo = 1
        options.maxItems = 8
        let runner = ScriptedSourceFetchRunner()

        let text = ckbSyncLive(kb, config, options, runner: runner, store: FileKnowledgeStore("target/ckb-raw-no-fallback"))

        @Expect(text.contains("sourceVariant=raw"), true)
        @Expect(text.contains("contentsFallback=attempted"), false)
        @Expect(countCallsContaining(runner.calls, "/contents/"), 0)
    }

    @TestCase
    public func syncLiveRawFailureFallsBackToContentsBase64AndPreservesPublicMetadata(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let options = LiveSyncOptions()
        options.apply = true
        options.maxRepos = 1
        options.maxFilesPerRepo = 1
        options.maxItems = 8
        let runner = RawFailContentsSourceFetchRunner()
        let store = FileKnowledgeStore("target/ckb-contents-fallback-apply")

        let text = ckbSyncLive(kb, config, options, runner: runner, store: store)
        let source = cangjie_source_search(kb, "fallbackMain", 5)
        let pack = cangjie_evidence_pack(kb, "fallbackMain", 5)

        @Expect(text.contains("contentsFallback=attempted"), true)
        @Expect(text.contains("sourceVariant=contents"), true)
        @Expect(text.contains("fallback-token"), false)
        @Expect(countCallsContaining(runner.calls, "/raw/"), 1)
        @Expect(countCallsContaining(runner.calls, "/contents/"), 1)
        @Expect(source.records.size > 0, true)
        @Expect(source.records[0].chunk.contains("fallbackMain"), true)
        @Expect(source.records[0].metadata.repoVisibility, RepoVisibility.PUBLIC)
        @Expect(source.records[0].metadata.repo, "cangjie/repo-one")
        @Expect(source.records[0].metadata.path, "src/main.cj")
        @Expect(pack.sourceEvidence.size > 0, true)
        @Expect(store.loadRaw().size > 0, true)
    }

    @TestCase
    public func contentsFallbackRejectsMalformedEncodingAndPathMismatch(): Unit {
        let builder = SourceRequestBuilder()
        let normalizer = SourceResponseNormalizer()
        let request = builder.gitCodeSourceContents("cangjie/repo-one", "dev", "src/main.cj")
        request.repoVisibility = RepoVisibility.PUBLIC

        let missing = SourceFetchResult()
        missing.ok = true
        missing.statusCode = 200
        missing.body = "{\"type\":\"file\",\"encoding\":\"base64\",\"path\":\"src/main.cj\"}"
        let missingNormalized = normalizer.normalize(request, missing)
        @Expect(missingNormalized.ok, false)
        @Expect(missingNormalized.status, "malformed_contents_response")

        let plain = SourceFetchResult()
        plain.ok = true
        plain.statusCode = 200
        plain.body = "{\"type\":\"file\",\"encoding\":\"plain\",\"content\":\"hello\",\"path\":\"src/main.cj\"}"
        let plainNormalized = normalizer.normalize(request, plain)
        @Expect(plainNormalized.ok, false)
        @Expect(plainNormalized.status, "unsupported_contents_encoding")

        let mismatch = SourceFetchResult()
        mismatch.ok = true
        mismatch.statusCode = 200
        mismatch.body = "{\"type\":\"file\",\"encoding\":\"base64\",\"content\":\"IyBSRUFETUUK\",\"path\":\"README.md\"}"
        let mismatchNormalized = normalizer.normalize(request, mismatch)
        @Expect(mismatchNormalized.ok, false)
        @Expect(mismatchNormalized.status, "contents_path_mismatch")
    }

    @TestCase
    public func contentsFallbackObeysMaxItemsBudgetAndDoesNotFetchPrivateRepos(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let options = LiveSyncOptions()
        options.dryRun = true
        options.maxRepos = 1
        options.maxFilesPerRepo = 1
        options.maxItems = 3
        let runner = RawFailContentsSourceFetchRunner()

        let text = ckbSyncLive(kb, config, options, runner: runner, store: FileKnowledgeStore("target/ckb-contents-budget"))

        @Expect(text.contains("contentsFallback=skipped reason=max_items"), true)
        @Expect(countCallsContaining(runner.calls, "/contents/"), 0)
        @Expect(text.contains("repo=cangjie/private-one visibility=public"), false)
        @Expect(countCallsContaining(runner.calls, "private-one/raw/"), 0)
        @Expect(countCallsContaining(runner.calls, "private-one/contents/"), 0)
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
    public func syncLiveResolvesSlashDefaultBranchBeforeTreeAndSourceFetch(): Unit {
        let kb = newOfflineKnowledgeBase()
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let options = LiveSyncOptions()
        options.dryRun = true
        options.maxRepos = 1
        options.maxFilesPerRepo = 1
        options.maxItems = 8
        let runner = ScriptedSourceFetchRunner()
        runner.slashDefaultBranch = true

        let text = ckbSyncLive(kb, config, options, runner: runner, store: FileKnowledgeStore("target/ckb-live-slash-ref-dry-run"))

        @Expect(text.contains("repoIncluded cangjie/repo-one visibility=public defaultBranch=release/1.0"), true)
        @Expect(text.contains("repoRefResolved repo=cangjie/repo-one originalRef=release/1.0 effectiveRef=${scriptedResolvedCommit()}"), true)
        @Expect(countCallsContaining(runner.calls, "/branches?page=1&per_page=100"), 1)
        @Expect(countCallsContaining(runner.calls, "/git/trees/${scriptedResolvedCommit()}?"), 1)
        @Expect(countCallsContaining(runner.calls, "?ref=${scriptedResolvedCommit()}"), 1)
        @Expect(countCallsContaining(runner.calls, "/git/trees/release%2F1.0?"), 0)
        @Expect(countCallsContaining(runner.calls, "?ref=release%2F1.0"), 0)
        @Expect(countCallsContaining(runner.calls, "/git/trees/release/1.0?"), 0)
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
        @Expect(scheduler.entries[2].failureCount, 3)
        @Expect(scheduler.entries[2].degraded, true)
        @Expect(scheduler.entries[2].nextRunAt, 80)
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
        @Expect(renderBackupRestore(backup).contains("/Users/example"), false)
    }

    @TestCase
    public func sourceCloneWorkspaceManagerValidatesRootsAndUsesSafeIsolatedDirs(): Unit {
        let config = CkbRuntimeConfig()
        let defaultRoot = sourceAnalysisDefaultWorkspaceRoot()
        config.sourceAnalysisWorkspaceRoot = "/tmp/ckb-source-analysis-unit-manager"
        let manager = SourceCloneWorkspaceManager(config)

        let first = manager.prepare("Cangjie/community")
        let second = manager.prepare("Cangjie/community")
        let currentRoot = if (let Some(value) <- getVariable("PWD")) { value } else { "" }
        let projectRoot = validateSourceAnalysisWorkspaceRoot(currentRoot)

        @Expect(defaultRoot.endsWith("/ckb-source-analysis"), true)
        @Expect(effectiveSourceAnalysisWorkspaceRoot(CkbRuntimeConfig()).endsWith("/ckb-source-analysis"), true)
        @Expect(effectiveSourceAnalysisWorkspaceRoot(config), "/tmp/ckb-source-analysis-unit-manager")
        @Expect(validateSourceAnalysisWorkspaceRoot(""), "invalid_workspace_root")
        @Expect(validateSourceAnalysisWorkspaceRoot("relative/path"), "invalid_workspace_root")
        @Expect(validateSourceAnalysisWorkspaceRoot("/tmp/../secret"), "invalid_workspace_root")
        @Expect(projectRoot, "invalid_workspace_root")
        @Expect(first.ok, true)
        @Expect(second.ok, true)
        @Expect(first.runId != second.runId, true)
        @Expect(first.checkoutDisplay.contains("Cangjie__community"), true)
        @Expect(first.checkoutDisplay.contains("/tmp/"), false)
        @Expect(first.checkoutDisplay.contains("/Users/"), false)
        @Expect(manager.cleanup(first, false), "cleaned")
        @Expect(manager.cleanup(second, false), "cleaned")
        @Expect(exists(first.runDir), false)
    }

    @TestCase
    public func sourceAnalysisEnforcesPublicOnlyHostAllowlistDepthAndFailureCleanup(): Unit {
        let config = sourceAnalysisTestConfig("/tmp/ckb-source-analysis-unit-enforcement")
        config.sourceAnalysisCloneDepth = 3
        let privateRequest = sourceAnalysisTestRequest()
        privateRequest.visibility = RepoVisibility.PRIVATE
        let internalRequest = sourceAnalysisTestRequest()
        internalRequest.visibility = RepoVisibility.INTERNAL
        let unknownRequest = sourceAnalysisTestRequest()
        unknownRequest.visibility = RepoVisibility.UNKNOWN
        let badHostRequest = sourceAnalysisTestRequest()
        badHostRequest.cloneUrl = "https://evil.example/Cangjie/community.git"
        let okExecutor = FakeSourceCloneExecutor()
        let privatePack = cangjie_source_analysis(config, privateRequest, executor: okExecutor)
        let internalPack = cangjie_source_analysis(config, internalRequest, executor: okExecutor)
        let unknownPack = cangjie_source_analysis(config, unknownRequest, executor: okExecutor)
        let badHostPack = cangjie_source_analysis(config, badHostRequest, executor: okExecutor)

        let successExecutor = FakeSourceCloneExecutor()
        let successPack = cangjie_source_analysis(config, sourceAnalysisTestRequest(), executor: successExecutor)
        let timeoutExecutor = FakeSourceCloneExecutor()
        timeoutExecutor.status = "clone_timeout"
        let timeoutPack = cangjie_source_analysis(config, sourceAnalysisTestRequest(), executor: timeoutExecutor)
        let missingExecutor = FakeSourceCloneExecutor()
        missingExecutor.status = "git_unavailable"
        let missingPack = cangjie_source_analysis(config, sourceAnalysisTestRequest(), executor: missingExecutor)
        let retainedExecutor = FakeSourceCloneExecutor()
        retainedExecutor.status = "clone_failed"
        let retainRequest = sourceAnalysisTestRequest()
        retainRequest.retainFailedWorkspace = true
        let retainedPack = cangjie_source_analysis(config, retainRequest, executor: retainedExecutor)

        @Expect(privatePack.status, "non_public_repo_blocked")
        @Expect(internalPack.status, "non_public_repo_blocked")
        @Expect(unknownPack.status, "non_public_repo_blocked")
        @Expect(badHostPack.status, "invalid_clone_host")
        @Expect(okExecutor.calls, 0)
        @Expect(successExecutor.calls, 1)
        @Expect(successExecutor.lastDepth, 3)
        @Expect(successExecutor.lastCloneUrl, "https://gitcode.com/Cangjie/community.git")
        @Expect(successPack.cleanupStatus, "cleaned")
        @Expect(exists(Path(successExecutor.lastCheckoutPath)), false)
        @Expect(timeoutPack.status, "clone_timeout")
        @Expect(timeoutPack.cleanupStatus, "cleaned")
        @Expect(exists(Path(timeoutExecutor.lastCheckoutPath)), false)
        @Expect(missingPack.status, "git_unavailable")
        @Expect(missingPack.cleanupStatus, "cleaned")
        @Expect(retainedPack.cleanupStatus, "retained_by_config")
        @Expect(retainedPack.workspaceStatus.contains("/tmp/"), false)
        @Expect(exists(Path(retainedExecutor.lastCheckoutPath).parent), true)
        launch("rm", ["-rf", "/tmp/ckb-source-analysis-unit-enforcement"]).wait()
    }

    @TestCase
    public func sourceAnalysisPackSelectsFiltersTruncatesHashesCitationsAndRedactsPaths(): Unit {
        let config = sourceAnalysisTestConfig("/tmp/ckb-source-analysis-unit-pack")
        config.sourceAnalysisMaxFiles = 2
        config.sourceAnalysisMaxFileBytes = 40
        let request = sourceAnalysisTestRequest()
        request.changedFiles.add("src/main.cj")
        request.changedFiles.add("target/generated.cj")
        request.changedFiles.add("assets/logo.png")
        request.changedFiles.add("src/binary.txt")
        request.candidatePaths.add("docs/readme.md")
        request.candidatePaths.add("src/long.cj")
        request.selector = "please inspect src/selector.cj"
        let executor = FakeSourceCloneExecutor()

        let pack = cangjie_source_analysis(config, request, executor: executor)
        let rendered = renderSourceAnalysis(pack)

        @Expect(pack.ok, true)
        @Expect(pack.selectedFiles.size, 2)
        @Expect(pack.selectedFiles[0].path, "src/main.cj")
        @Expect(pack.selectedFiles[0].bodyHash != "", true)
        @Expect(pack.selectedFiles[0].citation, "Cangjie/community@abc123:src/main.cj")
        @Expect(pack.selectedFiles[1].path, "docs/readme.md")
        @Expect(pack.truncated, true)
        @Expect(pack.cleanupStatus, "cleaned")
        @Expect(rendered.contains("target/generated.cj"), false)
        @Expect(rendered.contains("assets/logo.png"), false)
        @Expect(rendered.contains("src/binary.txt"), false)
        @Expect(rendered.contains("/tmp/"), false)
        @Expect(rendered.contains("/Users/"), false)
        @Expect(exists(Path(executor.lastCheckoutPath)), false)
    }

    @TestCase
    public func sourceAnalysisMaxFileBytesTruncatesUnicodeOnRuneBoundary(): Unit {
        let config = sourceAnalysisTestConfig("/tmp/ckb-source-analysis-unit-unicode-budget")
        config.sourceAnalysisMaxFiles = 1
        config.sourceAnalysisMaxFileBytes = 9
        let request = sourceAnalysisTestRequest()
        request.changedFiles.add("src/main.cj")
        let executor = FakeSourceCloneExecutor()
        executor.mainBody = "仓颉🙂源码片段 token=source-secret " + repeatText("仓颉🙂", 20)

        let pack = cangjie_source_analysis(config, request, executor: executor)
        let rendered = renderSourceAnalysis(pack)

        @Expect(pack.ok, true)
        @Expect(pack.truncated, true)
        @Expect(pack.selectedFiles.size, 1)
        @Expect(pack.selectedFiles[0].truncated, true)
        @Expect(pack.selectedFiles[0].excerpt.contains("仓颉"), true)
        @Expect(pack.selectedFiles[0].excerpt.contains("source-secret"), false)
        @Expect(rendered.contains("source-secret"), false)
        @Expect(exists(Path(executor.lastCheckoutPath)), false)
    }
}

class FakeSourceCloneExecutor <: SourceCloneExecutor {
    public var calls: Int64 = 0
    public var status: String = "ok"
    public var lastDepth: Int64 = 0
    public var lastCloneUrl: String = ""
    public var lastCheckoutPath: String = ""
    public var mainBody: String = "public func main(): Unit { println(\"hello\") }\n"

    public init() {}

    public func clone(request: CloneExecutionRequest): CloneExecutionResult {
        this.calls += 1
        this.lastDepth = request.depth
        this.lastCloneUrl = request.cloneUrl
        this.lastCheckoutPath = request.checkoutPath
        let result = CloneExecutionResult()
        if (this.status != "ok") {
            result.status = this.status
            result.diagnostic = this.status
            return result
        }
        writeFixtureFile(request.checkoutPath, "src/main.cj", this.mainBody)
        writeFixtureFile(request.checkoutPath, "docs/readme.md", "# README\nCangjie source analysis docs.\n")
        writeFixtureFile(request.checkoutPath, "src/long.cj", "public func longBody(): Unit { println(\"abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwxyz\") }\n")
        writeFixtureFile(request.checkoutPath, "src/selector.cj", "public func selected(): Unit {}\n")
        writeFixtureFile(request.checkoutPath, "target/generated.cj", "public func generated(): Unit {}\n")
        writeFixtureFile(request.checkoutPath, "assets/logo.png", "not really png\n")
        writeFixtureFile(request.checkoutPath, "src/binary.txt", "abc\0def")
        result.ok = true
        result.status = "ok"
        result
    }
}

private func sourceAnalysisTestConfig(root: String): CkbRuntimeConfig {
    let config = CkbRuntimeConfig()
    config.sourceAnalysisEnabled = true
    config.sourceAnalysisWorkspaceRoot = root
    config
}

private func sourceAnalysisTestRequest(): SourceAnalysisRequest {
    let request = SourceAnalysisRequest()
    request.repo = "Cangjie/community"
    request.ref = "main"
    request.commit = "abc123"
    request.visibility = RepoVisibility.PUBLIC
    request
}

private func writeFixtureFile(root: String, relative: String, body: String): Unit {
    let path = Path(root).join(relative)
    if (!exists(path.parent)) {
        Directory.create(path.parent, recursive: true)
    }
    File.writeTo(path, body.toArray())
}

class ScriptedSchedulerTaskRunner <: SchedulerTaskRunner {
    public var ok: Bool = true
    public var status: String = "fixture_ok"
    public var cursor: String = ""
    public var since: String = ""
    public var activeVersion: String = ""
    public var candidateVersion: String = ""
    public var durationMillis: Int64 = 0
    public var requestCount: Int64 = 0
    public var updatedDataKinds: ArrayList<String> = ArrayList<String>()
    public var truncated: Bool = false
    public var timeBudgetMillis: Int64 = 0

    public init() {}

    public func runTask(name: String, since: String, deadlineAtMillis: Int64): SchedulerTaskResult {
        let result = SchedulerTaskResult()
        result.ok = this.ok
        result.status = this.status
        result.cursor = this.cursor
        result.since = this.since
        result.activeVersion = this.activeVersion
        result.candidateVersion = this.candidateVersion
        result.durationMillis = this.durationMillis
        result.requestCount = this.requestCount
        for (kind in this.updatedDataKinds) {
            result.updatedDataKinds.add(kind)
        }
        result.truncated = this.truncated
        result.timeBudgetMillis = this.timeBudgetMillis
        result
    }
}

private func countCallsOfKind(calls: ArrayList<SourceFetchRequest>, kind: String): Int64 {
    var count: Int64 = 0
    for (call in calls) {
        if (call.kind == kind) {
            count += 1
        }
    }
    count
}

class ScriptedSourceFetchRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()
    public var slashDefaultBranch: Bool = false

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
        result.contentType = if (request.accept == "text/html") {
            "text/html"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.sourceVariant == "raw") {
            "text/plain"
        } else {
            "application/json"
        }
        result.body = this.bodyFor(request)
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result.attempts = 1
        result
    }

    private func bodyFor(request: SourceFetchRequest): String {
        if (request.kind == SourceKinds.GITCODE_ORG) {
            if (request.repo == "cangjie") {
                if (this.slashDefaultBranch) {
                    return "[{\"id\":1,\"display_name\":\"仓颉公开仓库\",\"path\":\"repo-one\",\"description\":\"中文说明 {真实响应}\",\"default_branch\":\"release/1.0\",\"public\":true,\"namespace\":{\"display_name\":\"仓颉组织\",\"path\":\"cangjie\"},\"web_url\":\"https://gitcode.com/cangjie/repo-one\"}]"
                }
                return "[{\"id\":1,\"display_name\":\"仓颉公开仓库\",\"path\":\"repo-one\",\"description\":\"中文说明 {真实响应}\",\"default_branch\":\"dev\",\"public\":true,\"namespace\":{\"display_name\":\"仓颉组织\",\"path\":\"cangjie\"},\"web_url\":\"https://gitcode.com/cangjie/repo-one\",\"access_token\":\"fake-live-token\"},{\"id\":2,\"display_name\":\"仓颉私有仓库\",\"path\":\"private-one\",\"default_branch\":\"main\",\"private\":true,\"namespace\":{\"path\":\"cangjie\"}},{\"id\":3,\"path\":\"internal-one\",\"default_branch\":\"main\",\"internal\":true,\"namespace\":{\"path\":\"cangjie\"}},{\"id\":4,\"path\":\"unknown-one\",\"default_branch\":\"main\",\"namespace\":{\"path\":\"cangjie\"}}]"
            }
            return "[]"
        }
        if (request.kind == SourceKinds.GITCODE_BRANCH) {
            return "[{\"name\":\"release/1.0\",\"commit\":{\"id\":\"${scriptedResolvedCommit()}\",\"sha\":\"${scriptedResolvedCommit()}\"}}]"
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

private func scriptedResolvedCommit(): String {
    "abcdef0123456789abcdef0123456789abcdef01"
}

private func countCallsContaining(calls: ArrayList<SourceFetchRequest>, needle: String): Int64 {
    var count: Int64 = 0
    for (call in calls) {
        if (call.url.contains(needle)) {
            count += 1
        }
    }
    count
}

class RawFailContentsSourceFetchRunner <: SourceFetchRunner {
    public var calls: ArrayList<SourceFetchRequest> = ArrayList<SourceFetchRequest>()

    public init() {}

    public func fetch(request: SourceFetchRequest): SourceFetchResult {
        this.calls.add(request)
        let result = SourceFetchResult()
        result.sourceUrl = request.url
        result.normalizedType = request.kind
        result.repo = request.repo
        result.ref = request.ref
        result.path = request.path
        result.repoVisibility = request.repoVisibility
        result.attempts = 1
        if (request.kind == SourceKinds.GITCODE_ORG) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            if (request.repo == "cangjie") {
                result.body = "[{\"id\":1,\"path\":\"repo-one\",\"default_branch\":\"dev\",\"public\":true,\"namespace\":{\"path\":\"cangjie\"}},{\"id\":2,\"path\":\"private-one\",\"default_branch\":\"main\",\"private\":true,\"namespace\":{\"path\":\"cangjie\"}}]"
            } else {
                result.body = "[]"
            }
        } else if (request.kind == SourceKinds.GITCODE_TREE) {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = "{\"tree\":[{\"type\":\"blob\",\"path\":\"src/main.cj\"}]}"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.purpose == "source_raw_snapshot") {
            result.ok = false
            result.status = "http_400"
            result.statusCode = 400
            result.contentType = "application/json"
            result.body = "{\"message\":\"raw unavailable\",\"token\":\"fallback-token\"}"
        } else if (request.kind == SourceKinds.GITCODE_SOURCE && request.purpose == "source_contents_snapshot") {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = "{\"type\":\"file\",\"encoding\":\"base64\",\"content\":\"IyBSRUFETUUKcHVibGljIGZ1bmMgZmFsbGJhY2tNYWluKCk6IFVuaXQge30K\",\"path\":\"src/main.cj\",\"sha\":\"abc123\",\"html_url\":\"https://gitcode.com/cangjie/repo-one/blob/dev/src/main.cj\",\"download_url\":\"https://gitcode.com/cangjie/repo-one/raw/dev/src/main.cj\"}"
        } else {
            result.ok = true
            result.status = "ok"
            result.statusCode = 200
            result.contentType = "application/json"
            result.body = "[]"
        }
        result.bytes = result.body.size
        result.bodyHash = stableSummaryHash(result.body)
        result
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

    public func execute(request: HttpExecutionRequest): HttpExecutionResponse {
        if (!httpExecutionMethodSupported(request.method)) {
            return unsupportedHttpExecutionResponse(request.method)
        }
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

    public func get(request: HttpExecutionRequest): HttpExecutionResponse {
        let getRequest = HttpExecutionRequest()
        getRequest.method = "GET"
        getRequest.url = request.url
        getRequest.accept = request.accept
        getRequest.body = request.body
        getRequest.contentType = request.contentType
        getRequest.timeoutMillis = request.timeoutMillis
        getRequest.retryCount = request.retryCount
        for (header in request.headers) {
            getRequest.headers.add(header)
        }
        this.execute(getRequest)
    }
}

@Test
public class CkbServiceApiTest {
    @TestCase
    public func ckb1Ut001HealthReturnsVersionedEnvelope(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-health"))

        let response = ckbApiHandle(service, "GET", "/v1/health", "", [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"apiVersion\":\"ckb-http-v1\""), true)
        @Expect(response.contains("\"activeKnowledgeVersion\":\"ckb-"), true)
    }

    @TestCase
    public func ckb1Ut002EvidencePackReturnsRedactedJsonEnvelope(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-evidence"))

        let response = ckbApiHandle(service, "POST", "/v1/evidence-pack", "{\"q\":\"HttpClient\",\"budget\":3}", [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"knowledgeVersion\":\"ckb-"), true)
        @Expect(response.contains("\"sourceEvidence\""), true)
        @Expect(response.contains("/Users/"), false)
    }

    @TestCase
    public func ckg0Pos001SchemaKeepsOldRoutesAndListsCangjieAbilityContract(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-schema-ckg0"))

        let response = ckbApiHandle(service, "GET", "/v1/schema", "", [])

        @Expect(response.contains("/v1/evidence-pack"), true)
        @Expect(response.contains("/v1/source-analysis"), true)
        @Expect(response.contains("/v1/events/gitcode/repository-changed"), true)
        @Expect(response.contains("/v1/cangjie/task-knowledge-pack"), true)
        @Expect(response.contains("cangjie_task_knowledge_pack"), true)
        @Expect(CkbSchema.mcpTools().contains("cangjie_knowledge_pack"), true)
        @Expect(CkbSchema.httpLikeRoutes().contains("/v1/cangjie/knowledge-pack"), true)
        @Expect(CkbSchema.mcpTools().contains("cangjie_task_knowledge_pack"), true)
        @Expect(CkbSchema.httpLikeRoutes().contains("/v1/cangjie/task-knowledge-pack"), true)
    }

    @TestCase
    public func ckg0Neg001UnauthorizedAdminRebuildStillHasNoSideEffect(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-admin-ckg0"))

        let response = ckbApiHandle(service, "POST", "/v1/admin/rebuild", "{}", [])

        @Expect(response.contains("\"ok\":false"), true)
        @Expect(response.contains("\"code\":\"ckb.unauthorized\""), true)
    }

    @TestCase
    public func ckg3Ut001CangjieKnowledgePackReturnsVersionedEnvelope(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-cangjie-pack"))

        let response = ckbApiHandle(service, "POST", "/v1/cangjie/knowledge-pack", "{\"task\":\"write JSON parser\",\"budget\":5}", [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"knowledgeVersion\":\"ckb-"), true)
        @Expect(response.contains("\"targetVersion\":\"1.0.0\""), true)
        @Expect(response.contains("\"citations\""), true)
        @Expect(response.contains("\"apiItems\""), true)
    }

    @TestCase
    public func ckg3Bnd001CangjieKnowledgePackRejectsEmptyTask(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-cangjie-empty"))

        let response = ckbApiHandle(service, "POST", "/v1/cangjie/knowledge-pack", "{\"task\":\"\",\"budget\":3}", [])

        @Expect(response.contains("\"ok\":false"), true)
        @Expect(response.contains("\"code\":\"ckb.bad_request\""), true)
    }

    @TestCase
    public func ckg3Bnd002CangjieApiSearchClampsOversizedBudget(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-cangjie-budget"))

        let response = ckbApiHandle(service, "POST", "/v1/cangjie/api-search", "{\"q\":\"ArrayList\",\"module\":\"std.collection\",\"symbol\":\"ArrayList\",\"budget\":999}", [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"truncated\":true"), true)
        @Expect(response.contains("budget_clamped"), true)
    }

    @TestCase
    public func ckg3Pos001CangjieCorpusStatusIsObservable(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-cangjie-status"))

        let response = ckbApiHandle(service, "GET", "/v1/cangjie/corpus/status", "", [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"activeKnowledgeVersion\":\"ckb-"), true)
        @Expect(response.contains("\"docsUrls\""), true)
        @Expect(response.contains("\"stdSources\""), true)
    }

    @TestCase
    public func ckg3Pos002SchemaListsCangjieRoutesAndTools(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-cangjie-schema"))

        let response = ckbApiHandle(service, "GET", "/v1/schema", "", [])

        @Expect(response.contains("/v1/cangjie/knowledge-pack"), true)
        @Expect(response.contains("/v1/cangjie/api-search"), true)
        @Expect(response.contains("cangjie_knowledge_pack"), true)
        @Expect(response.contains("/v1/cangjie/verify-snippet"), true)
    }

    @TestCase
    public func ckg3Neg001VerifySnippetIsNotEnabled(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-cangjie-verify"))

        let response = ckbApiHandle(service, "POST", "/v1/cangjie/verify-snippet", "{\"code\":\"main(){}\"}", [])

        @Expect(response.contains("\"ok\":false"), true)
        @Expect(response.contains("\"code\":\"ckb.not_found\""), true)
    }

    @TestCase
    public func ckg3Neg002CangjieOutputRedactsRequestSecrets(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-cangjie-redact"))

        let response = ckbApiHandle(service, "POST", "/v1/cangjie/diagnose", "{\"compilerOutput\":\"Authorization=Bearer secret-token main function declaration error\",\"code\":\"let token = secret-token\"}", [])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("secret-token"), false)
        @Expect(response.contains("Authorization=Bearer"), false)
    }

    @TestCase
    public func ckb1Bnd001EvidencePackRejectsUnsafeBudgetsAndEmptyQuery(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-bounds"))

        let zero = ckbApiHandle(service, "POST", "/v1/evidence-pack", "{\"q\":\"HttpClient\",\"budget\":0}", [])
        let tooLarge = ckbApiHandle(service, "POST", "/v1/evidence-pack", "{\"q\":\"HttpClient\",\"budget\":999}", [])
        let empty = ckbApiHandle(service, "POST", "/v1/evidence-pack", "{\"q\":\"\",\"budget\":3}", [])

        @Expect(zero.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(tooLarge.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(empty.contains("\"code\":\"ckb.bad_request\""), true)
    }

    @TestCase
    public func ckb1Bnd002SourceAnalysisRejectsUnsafePathsWithoutFetch(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let fake = FakeSourceFetchRunner()
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/ckb-api-source-paths"), sourceRunner: fake)

        let absolute = ckbApiHandle(service, "POST", "/v1/source-analysis", "{\"repo\":\"cangjie/stdx\",\"ref\":\"main\",\"query\":\"HttpClient\",\"candidatePaths\":[\"/Users/a/b.cj\"]}", [])
        let traversal = ckbApiHandle(service, "POST", "/v1/source-analysis", "{\"repo\":\"cangjie/stdx\",\"ref\":\"main\",\"query\":\"HttpClient\",\"candidatePaths\":[\"../x.cj\"]}", [])

        @Expect(absolute.contains("\"code\":\"ckb.bad_request\"") || absolute.contains("\"code\":\"ckb.invalid_workspace_root\""), true)
        @Expect(traversal.contains("\"code\":\"ckb.bad_request\"") || traversal.contains("\"code\":\"ckb.invalid_workspace_root\""), true)
        @Expect(fake.calls.size, 0)
    }

    @TestCase
    public func ckb1Pos001SchedulesExposeServiceV1FrequenciesOnly(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-schedules"))

        let response = ckbApiHandle(service, "GET", "/v1/schedules", "", [])

        @Expect(response.contains("\"name\":\"community_repo_discovery_30d\""), true)
        @Expect(response.contains("\"intervalMinutes\":43200"), true)
        @Expect(response.contains("\"name\":\"docs_probe_30d\""), true)
        @Expect(response.contains("\"name\":\"website_probe_weekly\""), true)
        @Expect(response.contains("\"intervalMinutes\":10080"), true)
        @Expect(response.contains("\"name\":\"website_full_weekly\""), true)
        @Expect(response.contains("\"name\":\"weekly_full_rebuild\""), true)
        @Expect(response.contains("active_item_sync_10m"), false)
        @Expect(response.contains("active_repo_fetch_30m"), false)
        @Expect(response.contains("repo_list_6h"), false)
    }

    @TestCase
    public func ckb1Pos002GitCodeRepositoryChangedEventAcceptsAndDeduplicates(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-events"))
        let body = "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"ref\":\"main\",\"prNumber\":12,\"changedFiles\":[\"src/http/client.cj\"]}"

        let first = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", body, [])
        let second = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", body, [])

        @Expect(first.contains("\"ok\":true"), true)
        @Expect(first.contains("\"status\":\"accepted\"") || first.contains("\"status\":\"duplicate\""), true)
        @Expect(first.contains("\"scheduledProfiles\""), true)
        @Expect(first.contains("\"repo_source_and_items\"") || first.contains("\"items\""), true)
        @Expect(second.contains("\"status\":\"duplicate\""), true)
    }

    @TestCase
    public func ckb1Neg001UnauthorizedAdminRebuildHasNoSideEffect(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-admin"))
        let before = service.rebuildCountForTest()

        let response = ckbApiHandle(service, "POST", "/v1/admin/rebuild", "{}", [])

        @Expect(response.contains("\"code\":\"ckb.unauthorized\""), true)
        @Expect(service.rebuildCountForTest(), before)
    }

    @TestCase
    public func ckb1Neg002InvalidGitCodeEventIsRejectedBeforeQueue(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb-api-event-neg"))
        let before = service.acceptedEventCountForTest()

        let badContract = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", "{\"contractVersion\":\"bad\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\"}", [])
        let missingRepo = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"reason\":\"pr_merged\"}", [])

        @Expect(badContract.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(missingRepo.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(service.acceptedEventCountForTest(), before)
    }

    @TestCase
    public func ckb3Ut001SchedulerCheckpointExposesRuntimeMetrics(): Unit {
        let scheduler = Scheduler(FakeClock(0))
        let runner = ScriptedSchedulerTaskRunner()
        runner.ok = true
        runner.status = "fixture_ok"
        runner.durationMillis = 1234
        runner.requestCount = 7
        runner.updatedDataKinds.add("docs")
        runner.updatedDataKinds.add("website")
        runner.truncated = true
        runner.timeBudgetMillis = 60000
        let executor = SchedulerExecutor(scheduler, runner)

        let result = executor.runDue(limit: 1)
        let entry = scheduler.entries[0]

        @Expect(result.succeeded, 1)
        @Expect(entry.lastDurationMillis, 1234)
        @Expect(entry.lastRequestCount, 7)
        @Expect(entry.lastUpdatedDataKinds.contains("docs"), true)
        @Expect(entry.lastUpdatedDataKinds.contains("website"), true)
        @Expect(entry.lastTruncated, true)
        @Expect(entry.timeBudgetMillis, 60000)
    }

    @TestCase
    public func ckb3Ut002DefaultSchedulerContainsOnlyLowFrequencyAllowlist(): Unit {
        let scheduler = Scheduler(FakeClock(0))
        let expected = ckbSchedulerAllowlistTaskNames()

        @Expect(scheduler.entries.size, expected.size)
        for (name in expected) {
            @Expect(intervalFor(scheduler, name) > 0, true)
        }
        @Expect(intervalFor(scheduler, "active_item_sync_10m"), -1)
        @Expect(intervalFor(scheduler, "active_repo_fetch_30m"), -1)
        @Expect(intervalFor(scheduler, "repo_list_6h"), -1)
        @Expect(intervalFor(scheduler, "active_item_sync_on_merge"), -1)
        @Expect(intervalFor(scheduler, "active_repo_fetch_on_merge"), -1)
        @Expect(intervalFor(scheduler, "repo_list_refresh_on_merge"), -1)
    }

    @TestCase
    public func ckb3Ut003ScheduleTaskProfilesMapAllowlistBudgetsAndDisableActive(): Unit {
        let docs = ckbSyncProfileForScheduleTask("docs_probe_30d")
        let catalog = ckbSyncProfileForScheduleTask("community_repo_discovery_30d")
        let rebuild = ckbSyncProfileForScheduleTask("weekly_full_rebuild")
        let active = ckbSyncProfileForScheduleTask("active_repo_fetch_on_merge")
        let legacy = ckbSyncProfileForScheduleTask("repo_list_6h")

        @Expect(docs.enabled, true)
        @Expect(docs.profile, "docs_probe")
        @Expect(docs.timeBudgetMillis, 60000)
        @Expect(docs.updatedDataKinds.contains("docs"), true)
        @Expect(catalog.updatedDataKinds.contains("repo_catalog"), true)
        @Expect(rebuild.profile, "full_rebuild")
        @Expect(active.enabled, false)
        @Expect(active.status, "unsupported")
        @Expect(legacy.enabled, false)
    }

    @TestCase
    public func ckb3Ut004RepositoryChangedUnavailableSchedulesItemsOnly(): Unit {
        let event = parseGitCodeRepositoryChangedEvent("{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merge\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"targetRef\":\"master\",\"prNumber\":42,\"changedFilesUnavailable\":true,\"changedFiles\":[]}")
        let profiles = ckbProfilesForRepositoryChangedEvent(event, CkbRuntimeConfig())

        @Expect(event.valid, true)
        @Expect(event.changedFilesUnavailable, true)
        @Expect(profiles.contains("items"), true)
        @Expect(profiles.contains("repo_source_and_items"), false)
        @Expect(profiles.contains("repo_list_refresh"), false)
    }

    @TestCase
    public func ckb3Ut005RepositoryChangedCodeFilesScheduleRepoSourceAndItems(): Unit {
        let event = parseGitCodeRepositoryChangedEvent("{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merge\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"targetRef\":\"master\",\"prNumber\":43,\"changedFiles\":[\"src/http/client.cj\",\"README.md\"],\"changedFilesUnavailable\":false}")
        let profiles = ckbProfilesForRepositoryChangedEvent(event, CkbRuntimeConfig())

        @Expect(profiles.contains("items"), false)
        @Expect(profiles.contains("repo_source_and_items"), true)
        @Expect(profiles.contains("repo_list_refresh"), false)
    }

    @TestCase
    public func ckb3Ut006RepositoryChangedRepoListFilesAddRepoListRefresh(): Unit {
        let event = parseGitCodeRepositoryChangedEvent("{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merge\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/community\",\"targetRef\":\"master\",\"prNumber\":44,\"changedFiles\":[\"repo_lists.md\",\"src/main.cj\"],\"changedFilesUnavailable\":false}")
        let profiles = ckbProfilesForRepositoryChangedEvent(event, CkbRuntimeConfig())

        @Expect(profiles.contains("repo_source_and_items"), true)
        @Expect(profiles.contains("repo_list_refresh"), true)
    }

    @TestCase
    public func ckb3Ut007RepositoryChangedDedupeDoesNotIncreaseAcceptedCount(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-dedupe-count"))
        let body = "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merge\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"targetRef\":\"master\",\"prNumber\":45,\"mergeCommitSha\":\"abc\",\"changedFiles\":[\"src/main.cj\"]}"

        let first = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", body, [])
        let second = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", body, [])

        @Expect(first.contains("\"status\":\"accepted\""), true)
        @Expect(second.contains("\"status\":\"duplicate\""), true)
        @Expect(service.acceptedEventCountForTest(), 1)
    }

    @TestCase
    public func ckb3Ut008AdminSchedulerRunTaskNamesForceAllowlist(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let fake = FakeSourceFetchRunner()
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/ckb3-admin-scheduler-tasknames"), sourceRunner: fake)
        let body = "{\"taskNames\":[\"docs_probe_30d\"],\"force\":true,\"reason\":\"operator_test\",\"requestedBy\":\"test\",\"source\":\"unit\"}"

        let response = ckbApiHandle(service, "POST", "/v1/admin/scheduler/run", body, ["Authorization: Bearer admin"])

        @Expect(response.contains("\"ok\":true"), true)
        @Expect(response.contains("\"forced\":true"), true)
        @Expect(response.contains("\"taskNames\":[\"docs_probe_30d\"]"), true)
        @Expect(response.contains("\"succeeded\":1"), true)
        @Expect(countCallsOfKind(fake.calls, SourceKinds.CANGJIE_DOCS), 1)
    }

    @TestCase
    public func p1Pos001SchedulerUsesPersistedManifestRefsInsteadOfHardcodedRelease(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let fake = FakeSourceFetchRunner()
        let store = FileKnowledgeStore("target/p1-scheduler-manifest-ref")
        store.saveCangjieVersionManifest(p1SchedulerManifest("release-9.9.9"))
        let service = CkbCommandLoopService(config, store, sourceRunner: fake)

        _ = ckbApiHandle(service, "POST", "/v1/admin/scheduler/run", "{\"taskNames\":[\"cangjie_release_full_sync\"],\"force\":true}", ["Authorization: Bearer admin"])

        @Expect(p1HasRepoRef(fake.calls, "Cangjie/cangjie_docs", "release-9.9.9"), true)
        @Expect(p1HasRepoRef(fake.calls, "Cangjie/cangjie_runtime", "release-9.9.9"), true)
        @Expect(p1HasRepoRef(fake.calls, "Cangjie/cangjie_stdx", "release-9.9.9"), true)
        @Expect(p1HasRepoRef(fake.calls, "Cangjie/cangjie_tools", "release-9.9.9"), true)
        @Expect(p1HasRepoRef(fake.calls, "Cangjie/cangjie_runtime", "release-1.0.0"), false)
    }

    @TestCase
    public func ckb3Ut009AdminRepositoriesSyncReturnsStructuredOfflineResult(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-admin-repo-sync"))
        let body = "{\"repo\":\"cangjie/stdx\",\"ref\":\"master\",\"profile\":\"repo_source_and_items\",\"changedFiles\":[\"src/main.cj\"],\"prNumber\":46,\"mode\":\"apply\",\"reason\":\"gitcode_pr_merged\"}"

        let response = ckbApiHandle(service, "POST", "/v1/admin/repositories/sync", body, ["Authorization: Bearer admin"])

        @Expect(response.contains("\"status\":\"not_implemented\""), false)
        @Expect(response.contains("\"repo\":\"cangjie/stdx\""), true)
        @Expect(response.contains("\"profile\":\"repo_source_and_items\""), true)
        @Expect(response.contains("\"requestCount\":"), true)
        @Expect(response.contains("\"updatedDataKinds\""), true)
        @Expect(response.contains("\"truncated\":false"), true)
    }

    @TestCase
    public func ckb3Ut010AdminRepoListRefreshReturnsStructuredOfflineResult(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-admin-repo-list"))
        let body = "{\"repo\":\"cangjie/community\",\"ref\":\"master\",\"paths\":[\"repo_list.md\"],\"prNumber\":47,\"mode\":\"apply\",\"reason\":\"gitcode_pr_merged\"}"

        let response = ckbApiHandle(service, "POST", "/v1/admin/repo-list/refresh", body, ["Authorization: Bearer admin"])

        @Expect(response.contains("\"status\":\"not_implemented\""), false)
        @Expect(response.contains("\"matchedPaths\":[\"repo_list.md\"]"), true)
        @Expect(response.contains("\"repoCount\":"), true)
        @Expect(response.contains("\"updatedDataKinds\":[\"repo_list\"]"), true)
    }

    @TestCase
    public func ckb3Bnd001RepositorySyncRejectsUnsafeRepoAndPaths(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-repo-sync-bounds"))

        let badRepo = ckbApiHandle(service, "POST", "/v1/admin/repositories/sync", "{\"repo\":\"private/secret\",\"profile\":\"items\",\"changedFiles\":[\"src/main.cj\"],\"mode\":\"apply\",\"reason\":\"operator\"}", ["Authorization: Bearer admin"])
        let badPath = ckbApiHandle(service, "POST", "/v1/admin/repositories/sync", "{\"repo\":\"cangjie/stdx\",\"profile\":\"repo_source_and_items\",\"changedFiles\":[\"../secret.cj\"],\"mode\":\"apply\",\"reason\":\"operator\"}", ["Authorization: Bearer admin"])

        @Expect(badRepo.contains("\"status\":\"rejected\"") || badRepo.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(badPath.contains("\"status\":\"rejected\"") || badPath.contains("\"code\":\"ckb.bad_request\""), true)
    }

    @TestCase
    public func ckb3Bnd002RepoListRefreshRejectsUnsafePaths(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-repo-list-bounds"))

        let absolute = ckbApiHandle(service, "POST", "/v1/admin/repo-list/refresh", "{\"repo\":\"cangjie/community\",\"paths\":[\"/tmp/repo_list.md\"],\"mode\":\"apply\",\"reason\":\"operator\"}", ["Authorization: Bearer admin"])
        let nonTrigger = ckbApiHandle(service, "POST", "/v1/admin/repo-list/refresh", "{\"repo\":\"cangjie/community\",\"paths\":[\"README.md\"],\"mode\":\"apply\",\"reason\":\"operator\"}", ["Authorization: Bearer admin"])

        @Expect(absolute.contains("\"status\":\"rejected\"") || absolute.contains("\"code\":\"ckb.bad_request\""), true)
        @Expect(nonTrigger.contains("\"status\":\"rejected\"") || nonTrigger.contains("\"code\":\"ckb.bad_request\""), true)
    }

    @TestCase
    public func ckb3Bnd003EventParserKeepsChangedFilesUnavailableFlag(): Unit {
        let event = parseGitCodeRepositoryChangedEvent("{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"eventId\":\"evt-1\",\"deliveryId\":\"del-1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merged\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"targetBranch\":\"master\",\"targetRef\":\"master\",\"prNumber\":\"48\",\"changedFilesTruncated\":true,\"changedFilesUnavailable\":true,\"url\":\"https://gitcode.com/cangjie/stdx/merge_requests/48\"}")

        @Expect(event.valid, true)
        @Expect(event.eventId, "evt-1")
        @Expect(event.deliveryId, "del-1")
        @Expect(event.action, "merged")
        @Expect(event.state, "merged")
        @Expect(event.changedFilesTruncated, true)
        @Expect(event.changedFilesUnavailable, true)
        @Expect(event.ref, "master")
        @Expect(event.prNumber, 48)
    }

    @TestCase
    public func ckb3Pos001StatusAndSchedulesExposeSchedulerMetrics(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/ckb3-status-metrics"), sourceRunner: FakeSourceFetchRunner())
        let body = "{\"taskNames\":[\"docs_probe_30d\"],\"force\":true}"
        _ = ckbApiHandle(service, "POST", "/v1/admin/scheduler/run", body, ["Authorization: Bearer admin"])

        let schedules = ckbApiHandle(service, "GET", "/v1/schedules", "", [])
        let status = ckbApiHandle(service, "GET", "/v1/status", "", [])

        @Expect(schedules.contains("\"lastDurationMillis\":"), true)
        @Expect(schedules.contains("\"lastRequestCount\":1"), true)
        @Expect(schedules.contains("\"lastUpdatedDataKinds\":[\"docs\"]"), true)
        @Expect(schedules.contains("\"timeBudgetMillis\":60000"), true)
        @Expect(status.contains("\"scheduler\""), true)
        @Expect(status.contains("\"lastUpdatedDataKinds\":[\"docs\"]"), true)
    }

    @TestCase
    public func ckb3Pos002HealthReflectsSchedulerDegraded(): Unit {
        let scheduler = Scheduler(FakeClock(0))
        scheduler.entries[0].degraded = true
        let store = FileKnowledgeStore("target/ckb3-health-degraded")
        store.saveScheduler(scheduler.entries)
        let service = CkbCommandLoopService(CkbRuntimeConfig(), store)

        let health = ckbApiHandle(service, "GET", "/v1/health", "", [])

        @Expect(health.contains("\"status\":\"degraded\""), true)
        @Expect(health.contains("\"schedulerDegraded\":true"), true)
    }

    @TestCase
    public func ckb3Pos003SchedulerRunnerFillsProfileMetrics(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let fake = FakeSourceFetchRunner()
        let store = FileKnowledgeStore("target/ckb3-runner-metrics")
        let kb = newKnowledgeBaseFromStore(store).kb
        let runner = CkbSchedulerTaskRunner(kb, config, store, sourceRunner: fake)

        let result = runner.runTask("website_probe_weekly", "", 0)

        @Expect(result.ok, true)
        @Expect(result.status, "profile_ok")
        @Expect(result.requestCount, 3)
        @Expect(result.updatedDataKinds.contains("website"), true)
        @Expect(result.timeBudgetMillis, 90000)
        @Expect(countCallsOfKind(fake.calls, SourceKinds.CANGJIE_WEBSITE), 3)
    }

    @TestCase
    public func ckb3Pos004EventIntakeAcceptedProfilesInEnvelope(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-event-envelope"))
        let body = "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"eventId\":\"evt-2\",\"deliveryId\":\"del-2\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merge\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/community\",\"targetRef\":\"master\",\"prNumber\":49,\"changedFiles\":[\"repo_list.md\",\"src/main.cj\"],\"changedFilesUnavailable\":false}"

        let response = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", body, [])

        @Expect(response.contains("\"apiVersion\":\"ckb-http-v1\""), true)
        @Expect(response.contains("\"status\":\"accepted\""), true)
        @Expect(response.contains("\"dedupeKey\":\""), true)
        @Expect(response.contains("\"repo_source_and_items\""), true)
        @Expect(response.contains("\"repo_list_refresh\""), true)
    }

    @TestCase
    public func ckb3Pos005AdminSchedulerRunEnvelopeIncludesTaskNamesAndForced(): Unit {
        let config = CkbRuntimeConfig()
        config.networkEnabled = true
        let service = CkbCommandLoopService(config, FileKnowledgeStore("target/ckb3-admin-scheduler-envelope"), sourceRunner: FakeSourceFetchRunner())

        let response = ckbApiHandle(service, "POST", "/v1/admin/scheduler/run", "{\"taskNames\":[\"community_repo_discovery_30d\",\"docs_probe_30d\"],\"force\":true}", ["Authorization: Bearer admin"])

        @Expect(response.contains("\"forced\":true"), true)
        @Expect(response.contains("\"taskNames\":[\"community_repo_discovery_30d\",\"docs_probe_30d\"]"), true)
        @Expect(response.contains("\"ran\":2"), true)
        @Expect(response.contains("\"details\""), true)
    }

    @TestCase
    public func ckb3Pos006RepositorySyncProfileItemsUsesCommunityKinds(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-repo-sync-items"))

        let response = ckbApiHandle(service, "POST", "/v1/admin/repositories/sync", "{\"repo\":\"cangjie/stdx\",\"profile\":\"items\",\"prNumber\":50,\"mode\":\"apply\",\"reason\":\"gitcode_pr_merged\"}", ["Authorization: Bearer admin"])

        @Expect(response.contains("\"status\":\"ok\"") || response.contains("\"status\":\"degraded\""), true)
        @Expect(response.contains("\"updatedDataKinds\":[\"issues\",\"pull_requests\",\"comments\"]"), true)
        @Expect(response.contains("\"requestCount\":3"), true)
    }

    @TestCase
    public func ckb3Neg001AdminSchedulerRejectsActiveOnMergeTask(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-admin-scheduler-neg"))

        let response = ckbApiHandle(service, "POST", "/v1/admin/scheduler/run", "{\"taskNames\":[\"active_repo_fetch_on_merge\"],\"force\":true}", ["Authorization: Bearer admin"])

        @Expect(response.contains("\"ok\":false") || response.contains("\"status\":\"rejected\""), true)
        @Expect(response.contains("active_repo_fetch_on_merge"), true)
    }

    @TestCase
    public func ckb3Neg002EventRejectsUnsupportedOwner(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-event-owner-neg"))

        let response = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merge\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"thirdparty/project\",\"targetRef\":\"master\",\"prNumber\":51,\"changedFiles\":[\"src/main.cj\"]}", [])

        @Expect(response.contains("\"code\":\"ckb.bad_request\"") || response.contains("\"status\":\"rejected\""), true)
        @Expect(service.acceptedEventCountForTest(), 0)
    }

    @TestCase
    public func ckb3Neg003EventWithOpenedStateRejected(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-event-opened-neg"))

        let response = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"update\",\"state\":\"opened\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"targetRef\":\"master\",\"prNumber\":52,\"changedFiles\":[\"src/main.cj\"]}", [])

        @Expect(response.contains("\"code\":\"ckb.bad_request\"") || response.contains("\"status\":\"rejected\""), true)
        @Expect(service.acceptedEventCountForTest(), 0)
    }

    @TestCase
    public func ckb3Neg004DuplicateEventDoesNotRunProfilesAgain(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb3-event-duplicate-profiles"))
        let body = "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"eventId\":\"evt-3\",\"deliveryId\":\"del-3\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"action\":\"merge\",\"state\":\"merged\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"targetRef\":\"master\",\"prNumber\":53,\"mergeCommitSha\":\"def\",\"changedFiles\":[\"src/main.cj\"]}"

        _ = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", body, [])
        let second = ckbApiHandle(service, "POST", "/v1/events/gitcode/repository-changed", body, [])

        @Expect(second.contains("\"status\":\"duplicate\""), true)
        @Expect(second.contains("\"scheduledProfiles\":[]"), true)
        @Expect(service.acceptedEventCountForTest(), 1)
    }

    @TestCase
    public func ckb2Ut001ConfigApplyParsesHttpServiceFieldsWithoutBreakingExistingConfig(): Unit {
        let root = "target/ckb2-config"
        let configPath = "${root}/runtime.conf"
        writeFixtureFile(root, "runtime.conf", """
network.enabled=true
sourceAnalysis.enabled=true
sourceAnalysis.maxFiles=11
service.bind=127.0.0.1
service.port=18890
service.maxBudget=20
""")

        let config = loadCkbRuntimeConfig(configPath)

        @Expect(config.serviceBind, "127.0.0.1")
        @Expect(config.servicePort, 18890)
        @Expect(config.serviceMaxBudget, 20)
        @Expect(config.networkEnabled, true)
        @Expect(config.sourceAnalysisEnabled, true)
        @Expect(config.sourceAnalysisMaxFiles, 11)
    }

    @TestCase
    public func ckb2Ut001bConfigApplyParsesFirstInitFieldsAndRedactsPaths(): Unit {
        let root = "target/ckb2-first-init-config"
        let configPath = "${root}/runtime.conf"
        writeFixtureFile(root, "runtime.conf", """
firstInit.enabled=true
firstInit.docsRoot=/Users/example/cangjie_docs
firstInit.toolDocsRoot=/Users/example/cangjie_docs/docs/tools
firstInit.stdRoot=/Users/example/cangjie_std
firstInit.stdxRoot=/Users/example/cangjie_stdx
firstInit.evalRoot=/Users/example/Cangjie-HumanEval
firstInit.targetVersion=1.0.0
benchmarkGap.curationInputPath=/Users/example/ckbtest/gap-curation-input.jsonl
benchmarkGap.targetVersion=1.0.0
""")

        let config = loadCkbRuntimeConfig(configPath)
        let summary = config.redactedSummary()

        @Expect(config.firstInitEnabled, true)
        @Expect(config.firstInitDocsRoot, "/Users/example/cangjie_docs")
        @Expect(config.firstInitToolDocsRoot, "/Users/example/cangjie_docs/docs/tools")
        @Expect(config.firstInitStdRoot, "/Users/example/cangjie_std")
        @Expect(config.firstInitStdxRoot, "/Users/example/cangjie_stdx")
        @Expect(config.firstInitEvalRoot, "/Users/example/Cangjie-HumanEval")
        @Expect(config.firstInitTargetVersion, "1.0.0")
        @Expect(config.benchmarkGapCurationInputPath, "/Users/example/ckbtest/gap-curation-input.jsonl")
        @Expect(config.benchmarkGapTargetVersion, "1.0.0")
        @Expect(summary.contains("firstInit.enabled=true"), true)
        @Expect(summary.contains("firstInit.docsRoot=present"), true)
        @Expect(summary.contains("firstInit.evalRoot=present"), true)
        @Expect(summary.contains("benchmarkGap.curationInput=present"), true)
        @Expect(summary.contains("/Users/example"), false)
    }

    @TestCase
    public func ckb2Ut002AdminTokenAuthorizesWithoutLeakingSecret(): Unit {
        let root = "target/ckb2-auth-admin"
        writeFixtureFile(root, "admin.token", "admin-secret\n")
        let runtime = CkbRuntimeConfig()
        runtime.serviceAdminTokenFile = "${root}/admin.token"
        let config = ckbHttpServiceConfigFromRuntime(runtime)

        let auth = ckbHttpAuthorize(config, ["Authorization: Bearer admin-secret"], "admin")
        let service = CkbCommandLoopService(runtime, FileKnowledgeStore("${root}/store"))
        let response = handleCkbHttpRequest(service, "POST", "/v1/admin/sync", "{}", ["Authorization: Bearer admin-secret"], config)

        @Expect(auth.authorized, true)
        @Expect(auth.authKind, "admin")
        @Expect(auth.diagnostic.contains("admin-secret"), false)
        @Expect(response.body.contains("admin-secret"), false)
        @Expect(response.body.contains("Authorization"), false)
    }

    @TestCase
    public func ckb2Ut003EventTokenOnlyAuthorizesRepositoryChangedIntake(): Unit {
        let root = "target/ckb2-auth-event"
        writeFixtureFile(root, "event.token", "event-secret\n")
        let runtime = CkbRuntimeConfig()
        runtime.serviceEventIngestTokenFile = "${root}/event.token"
        let config = ckbHttpServiceConfigFromRuntime(runtime)

        let eventAuth = ckbHttpAuthorize(config, ["Authorization: Bearer event-secret"], "event")
        let adminAuth = ckbHttpAuthorize(config, ["Authorization: Bearer event-secret"], "admin")
        let readAuth = ckbHttpAuthorize(config, ["Authorization: Bearer event-secret"], "read")

        @Expect(eventAuth.authorized, true)
        @Expect(eventAuth.authKind, "event")
        @Expect(adminAuth.authorized, false)
        @Expect(readAuth.authorized, false)
    }

    @TestCase
    public func ckb2Bnd001OversizedBodyReturnsPayloadTooLargeBeforeApiCore(): Unit {
        let root = "target/ckb2-payload-too-large"
        writeFixtureFile(root, "event.token", "event-secret\n")
        let runtime = CkbRuntimeConfig()
        runtime.serviceEventIngestTokenFile = "${root}/event.token"
        runtime.serviceMaxRequestBytes = 8
        let config = ckbHttpServiceConfigFromRuntime(runtime)
        let service = CkbCommandLoopService(runtime, FileKnowledgeStore("${root}/store"))
        let before = service.acceptedEventCountForTest()

        let response = handleCkbHttpRequest(service, "POST", "/v1/events/gitcode/repository-changed", repeatText("x", 32), ["Authorization: Bearer event-secret"], config)

        @Expect(response.statusCode, 413)
        @Expect(response.body.contains("\"code\":\"ckb.payload_too_large\""), true)
        @Expect(service.acceptedEventCountForTest(), before)
    }

    @TestCase
    public func ckb2Bnd002InvalidServicePortFailsValidationWithRedactedDiagnostic(): Unit {
        let low = CkbHttpServiceConfig()
        low.port = 0
        low.adminTokenFile = "/Users/example/admin-secret-token"
        let high = CkbHttpServiceConfig()
        high.port = 65536
        high.eventIngestTokenFile = "/Users/example/event-secret-token"

        let lowResult = ckbHttpValidateConfig(low)
        let highResult = ckbHttpValidateConfig(high)

        @Expect(lowResult.ok, false)
        @Expect(lowResult.code, "ckb.invalid_config")
        @Expect(lowResult.diagnostic.contains("admin-secret-token"), false)
        @Expect(highResult.ok, false)
        @Expect(highResult.code, "ckb.invalid_config")
        @Expect(highResult.diagnostic.contains("event-secret-token"), false)
    }

    @TestCase
    public func ckb2Ut004AccessLogLineShowsRouteWithoutBodyOrSecret(): Unit {
        let line = ckbHttpAccessLogLine("post", "/v1/evidence-pack", 200, "public", 128, 7)

        @Expect(line.contains("ckb.http.request"), true)
        @Expect(line.contains("method=POST"), true)
        @Expect(line.contains("path=/v1/evidence-pack"), true)
        @Expect(line.contains("status=200"), true)
        @Expect(line.contains("durationMs=7"), true)
        @Expect(line.contains("requestBytes=128"), true)
        @Expect(line.contains("Authorization"), false)
        @Expect(line.contains("Bearer"), false)
        @Expect(line.contains("\"q\""), false)
    }

    @TestCase
    public func ckb2Pos001LocalHandlerHealthReturnsHttp200Json(): Unit {
        let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/ckb2-health"))
        let config = CkbHttpServiceConfig()

        let response = handleCkbHttpRequest(service, "GET", "/v1/health", "", [], config)

        @Expect(response.statusCode, 200)
        @Expect(response.body.contains("\"apiVersion\":\"ckb-http-v1\""), true)
        @Expect(response.body.contains("\"ok\":true"), true)
    }

    @TestCase
    public func ckb2Pos002EventTokenCanPostRepositoryChangedEvent(): Unit {
        let root = "target/ckb2-event-post"
        writeFixtureFile(root, "event.token", "event-secret\n")
        let runtime = CkbRuntimeConfig()
        runtime.serviceEventIngestTokenFile = "${root}/event.token"
        let config = ckbHttpServiceConfigFromRuntime(runtime)
        let service = CkbCommandLoopService(runtime, FileKnowledgeStore("${root}/store"))
        let body = "{\"contractVersion\":\"gcm-ckb-repository-change-v1\",\"provider\":\"gitcode\",\"eventType\":\"merge_request\",\"reason\":\"pr_merged\",\"repo\":\"cangjie/stdx\",\"ref\":\"main\",\"prNumber\":12,\"changedFiles\":[\"src/http/client.cj\"]}"

        let response = handleCkbHttpRequest(service, "POST", "/v1/events/gitcode/repository-changed", body, ["Authorization: Bearer event-secret"], config)

        @Expect(response.statusCode == 202 || response.statusCode == 200, true)
        @Expect(response.body.contains("\"ok\":true"), true)
        @Expect(response.body.contains("\"status\":\"accepted\"") || response.body.contains("\"status\":\"duplicate\""), true)
    }

    @TestCase
    public func ckb2Neg001NoTokenAdminSyncReturns401AndDoesNotMutateStore(): Unit {
        let root = "target/ckb2-admin-no-token"
        writeFixtureFile(root, "admin.token", "admin-secret\n")
        let runtime = CkbRuntimeConfig()
        runtime.serviceAdminTokenFile = "${root}/admin.token"
        let config = ckbHttpServiceConfigFromRuntime(runtime)
        let store = FileKnowledgeStore("${root}/store")
        let service = CkbCommandLoopService(runtime, store)
        let before = store.has("raw/records.ckb")

        let response = handleCkbHttpRequest(service, "POST", "/v1/admin/sync", "{}", [], config)

        @Expect(response.statusCode, 401)
        @Expect(response.body.contains("\"ok\":false"), true)
        @Expect(response.body.contains("\"code\":\"ckb.unauthorized\""), true)
        @Expect(store.has("raw/records.ckb"), before)
    }

    @TestCase
    public func ckb2Neg002EventTokenCannotAccessAdminOrQueryApi(): Unit {
        let root = "target/ckb2-event-forbidden"
        writeFixtureFile(root, "event.token", "event-secret\n")
        let runtime = CkbRuntimeConfig()
        runtime.serviceEventIngestTokenFile = "${root}/event.token"
        let config = ckbHttpServiceConfigFromRuntime(runtime)
        let service = CkbCommandLoopService(runtime, FileKnowledgeStore("${root}/store"))
        let headers = ["Authorization: Bearer event-secret"]

        let admin = handleCkbHttpRequest(service, "POST", "/v1/admin/sync", "{}", headers, config)
        let evidence = handleCkbHttpRequest(service, "POST", "/v1/evidence-pack", "{\"q\":\"HttpClient\",\"budget\":1}", headers, config)

        @Expect(admin.statusCode == 401 || admin.statusCode == 403, true)
        @Expect(admin.body.contains("\"code\":\"ckb.unauthorized\"") || admin.body.contains("\"code\":\"ckb.forbidden\""), true)
        @Expect(evidence.statusCode == 401 || evidence.statusCode == 403, true)
        @Expect(evidence.body.contains("\"code\":\"ckb.unauthorized\"") || evidence.body.contains("\"code\":\"ckb.forbidden\""), true)
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

private func p1SchedulerManifest(ref: String): CangjieVersionManifest {
    let manifest = CangjieVersionManifest()
    manifest.defaultTargetVersion = "1.0.0"
    p1AddManifestSource(manifest, CangjieSourceSets.DOCS, "docs", "Cangjie/cangjie_docs", ref)
    p1AddManifestSource(manifest, CangjieSourceSets.STD, "stdlib", "Cangjie/cangjie_runtime", ref)
    p1AddManifestSource(manifest, CangjieSourceSets.STDX, "stdx", "Cangjie/cangjie_stdx", ref)
    p1AddManifestSource(manifest, CangjieSourceSets.TOOLS, "tools", "Cangjie/cangjie_tools", ref)
    manifest
}

private func p1AddManifestSource(manifest: CangjieVersionManifest, sourceSet: String, sourceFamily: String, repo: String, ref: String): Unit {
    let source = CangjieVersionSource()
    source.targetVersion = manifest.defaultTargetVersion
    source.sourceSet = sourceSet
    source.sourceFamily = sourceFamily
    source.sourceRepo = repo
    source.sourceRef = ref
    source.refKind = "branch"
    source.resolvedCommit = "${ref}-${sourceSet}-commit"
    source.contentHash = "sha256:${ref}-${sourceSet}"
    source.rootKind = "git-root"
    manifest.sources.add(source)
}

private func p1HasRepoRef(calls: ArrayList<SourceFetchRequest>, repo: String, ref: String): Bool {
    for (call in calls) {
        if (call.repo == repo && call.ref == ref) {
            return true
        }
    }
    false
}

private func repeatText(value: String, count: Int64): String {
    let out = StringBuilder()
    for (_ in 0..count) {
        out.append(value)
    }
    out.toString()
}
