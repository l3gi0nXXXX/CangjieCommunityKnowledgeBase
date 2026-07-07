package cangjie_community_knowledge_base

import std.collection.ArrayList
import std.convert.Parsable

public class CkbApiResponse {
    public var ok: Bool = true
    public var apiVersion: String = "ckb-http-v1"
    public var data: String = "{}"
    public var diagnostics: String = "{}"

    public init() {}
}

public class CkbApiError {
    public var code: String = ""
    public var message: String = ""
    public var status: Int64 = 400

    public init() {}

    public init(code: String, message: String, status: Int64) {
        this.code = code
        this.message = message
        this.status = status
    }
}

public class CkbApiRequestContext {
    public var method: String = ""
    public var path: String = ""
    public var headers: ArrayList<String> = ArrayList<String>()
    public var adminAuthorized: Bool = false

    public init() {}
}

public class GitCodeRepositoryChangedEvent {
    public var contractVersion: String = ""
    public var eventId: String = ""
    public var deliveryId: String = ""
    public var provider: String = ""
    public var eventType: String = ""
    public var action: String = ""
    public var state: String = ""
    public var reason: String = ""
    public var repo: String = ""
    public var ref: String = ""
    public var prNumber: Int64 = 0
    public var mergeCommitSha: String = ""
    public var url: String = ""
    public var changedFilesTruncated: Bool = false
    public var changedFilesUnavailable: Bool = false
    public var changedFiles: ArrayList<String> = ArrayList<String>()
    public var valid: Bool = false
    public var errorCode: String = ""
    public var diagnostic: String = ""

    public init() {}
}

public class GitCodeRepositoryChangedEventResult {
    public var eventId: String = ""
    public var status: String = "rejected"
    public var dedupeKey: String = ""
    public var scheduledProfiles: ArrayList<String> = ArrayList<String>()
    public var acceptedAt: String = ""
    public var diagnostic: String = ""

    public init() {}
}

public class CkbAdminOperationResult {
    public var status: String = "not_implemented"
    public var degraded: Bool = true
    public var diagnostic: String = ""
    public var repo: String = ""
    public var ref: String = ""
    public var profile: String = ""
    public var prNumber: Int64 = 0
    public var truncated: Bool = false
    public var matchedPaths: ArrayList<String> = ArrayList<String>()
    public var repoCount: Int64 = 0
    public var requestCount: Int64 = 0
    public var updatedDataKinds: ArrayList<String> = ArrayList<String>()
    public var activeKnowledgeVersion: String = ""
    public var candidateKnowledgeVersion: String = ""
    public var activeRepoListVersion: String = ""
    public var candidateRepoListVersion: String = ""

    public init() {}
}

public func ckbApiEnvelope(data: String, diagnostics!: String = "{}"): String {
    let response = CkbApiResponse()
    response.data = data
    response.diagnostics = ckbApiDiagnosticObject(diagnostics)
    ckbApiRenderResponse(response)
}

public func ckbApiErrorEnvelope(error: CkbApiError, diagnostics!: String = "{}"): String {
    "{\"ok\":false,\"apiVersion\":\"ckb-http-v1\",\"error\":{\"code\":\"${ckbApiJsonEscape(error.code)}\",\"message\":\"${ckbApiJsonEscape(error.message)}\",\"status\":${error.status}},\"diagnostics\":${ckbApiDiagnosticObject(diagnostics)}}"
}

public func ckbApiErrorEnvelope(code: String, message: String, status!: Int64 = 400, diagnostics!: String = "{}"): String {
    ckbApiErrorEnvelope(CkbApiError(code, message, status), diagnostics: diagnostics)
}

public func ckbApiHandle(service: CkbCommandLoopService, method: String, path: String, body: String, headers: Array<String>): String {
    let context = ckbApiRequestContext(method, path, headers)
    let route = context.path
    let verb = context.method

    if (route.startsWith("/v1/admin/")) {
        if (!context.adminAuthorized) {
            return ckbApiErrorEnvelope("ckb.unauthorized", "admin authorization required", status: 401)
        }
        return ckbApiHandleAdmin(service, verb, route, body)
    }

    if (verb == "GET" && route == "/v1/health") {
        return ckbApiEnvelope(ckbApiHealthJson(service.statusSnapshot()))
    }
    if (verb == "GET" && route == "/v1/status") {
        return ckbApiEnvelope(ckbApiStatusJson(service.statusSnapshot()))
    }
    if (verb == "GET" && route == "/v1/schedules") {
        return ckbApiEnvelope(ckbApiSchedulesJson(service.statusSnapshot()))
    }
    if (verb == "GET" && route == "/v1/schema") {
        return ckbApiEnvelope(ckbApiSchemaJson())
    }
    if (verb == "GET" && route == "/v1/cangjie/corpus/status") {
        return ckbApiEnvelope(ckbApiCangjieCorpusStatusJson(service.cangjieCorpusStatus()))
    }
    if (verb == "GET" && route == "/v1/cangjie/llms.txt") {
        return ckbApiEnvelope(ckbApiCangjieMarkdownJson(service.cangjieKnowledgePack("Cangjie language quick context", budget: 5), "llms.txt"))
    }
    if (verb == "GET" && route == "/v1/cangjie/llms-full.txt") {
        return ckbApiEnvelope(ckbApiCangjieMarkdownJson(service.cangjieKnowledgePack("Cangjie language full context", budget: 20), "llms-full.txt"))
    }
    if (verb == "POST" && route == "/v1/cangjie/knowledge-pack") {
        return ckbApiHandleCangjieKnowledgePack(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/syntax-query") {
        return ckbApiHandleCangjieSyntaxQuery(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/api-search") {
        return ckbApiHandleCangjieApiSearch(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/cookbook") {
        return ckbApiHandleCangjieCookbook(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/diagnose") {
        return ckbApiHandleCangjieDiagnose(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/examples") {
        return ckbApiHandleCangjieExamples(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/context-pack") {
        return ckbApiHandleCangjieContextPack(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/version/resolve") {
        return ckbApiHandleCangjieVersionResolve(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/task-knowledge-pack") {
        return ckbApiHandleCangjieTaskKnowledgePack(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/knowledge-coverage") {
        return ckbApiHandleCangjieKnowledgeCoverage(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/compile-diagnose-v2") {
        return ckbApiHandleCangjieCompileDiagnoseV2(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/symbol-lookup") {
        return ckbApiHandleCangjieSymbolLookup(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/doc-section") {
        return ckbApiHandleCangjieDocSection(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/tool-manual") {
        return ckbApiHandleCangjieToolManual(service, body)
    }
    if (verb == "POST" && route == "/v1/cangjie/negative-rules") {
        return ckbApiHandleCangjieNegativeRules(service, body)
    }
    if (verb == "GET" && route == "/v1/cangjie/corpus/freshness") {
        let result = cangjieCorpusFreshnessResultFromReport(service.cangjieCorpusFreshness())
        result.routineUpdateStatusJson = renderCkbRoutineUpdateStatusJson(service.statusSnapshot())
        return ckbApiEnvelope(renderCangjieCorpusFreshnessResultJson(result))
    }
    if (verb == "POST" && route == "/v1/query") {
        return ckbApiHandleEvidence(service, body, true)
    }
    if (verb == "POST" && route == "/v1/evidence-pack") {
        return ckbApiHandleEvidence(service, body, false)
    }
    if (verb == "POST" && route == "/v1/source-analysis") {
        return ckbApiHandleSourceAnalysis(service, body)
    }
    if (verb == "POST" && route == "/v1/events/gitcode/repository-changed") {
        let event = parseGitCodeRepositoryChangedEvent(body)
        return ckbApiGitCodeRepositoryChangedEvent(service, event)
    }
    ckbApiErrorEnvelope("ckb.not_found", "route not found", status: 404, diagnostics: "{\"path\":\"${ckbApiJsonEscape(route)}\"}")
}

public func parseGitCodeRepositoryChangedEvent(body: String): GitCodeRepositoryChangedEvent {
    let event = GitCodeRepositoryChangedEvent()
    let safe = ckbApiAsciiJsonProjection(body)
    event.contractVersion = ckbApiJsonStringField(safe, "contractVersion")
    event.eventId = ckbApiJsonStringField(safe, "eventId")
    event.deliveryId = ckbApiJsonStringField(safe, "deliveryId")
    event.provider = ckbApiJsonStringField(safe, "provider")
    event.eventType = ckbApiJsonStringField(safe, "eventType")
    event.action = ckbApiJsonStringField(safe, "action")
    event.state = ckbApiJsonStringField(safe, "state")
    event.reason = ckbApiJsonStringField(safe, "reason")
    event.repo = ckbApiJsonStringField(safe, "repo")
    event.ref = ckbApiJsonStringField(safe, "ref")
    if (event.ref == "") {
        event.ref = ckbApiJsonStringField(safe, "targetRef")
    }
    if (event.ref == "") {
        event.ref = ckbApiJsonStringField(safe, "targetBranch")
    }
    event.prNumber = ckbApiJsonIntOrStringField(safe, "prNumber", ckbApiJsonIntOrStringField(safe, "iid", 0))
    event.mergeCommitSha = ckbApiJsonStringField(safe, "mergeCommitSha")
    event.url = ckbApiJsonStringField(safe, "url")
    event.changedFilesTruncated = ckbApiJsonBoolField(safe, "changedFilesTruncated")
    event.changedFilesUnavailable = ckbApiJsonBoolField(safe, "changedFilesUnavailable")
    event.changedFiles = ckbApiJsonStringArrayField(safe, "changedFiles")
    if (event.contractVersion != "gcm-ckb-repository-change-v1") {
        event.errorCode = "ckb.bad_request"
        event.diagnostic = "invalid_contract_version"
        return event
    }
    if (event.provider != "gitcode" || event.eventType != "merge_request" || event.reason != "pr_merged") {
        event.errorCode = "ckb.bad_request"
        event.diagnostic = "unsupported_repository_changed_event"
        return event
    }
    if (!ckbApiSafeRepo(event.repo) || !ckbApiCommunityRepoAllowed(event.repo)) {
        event.errorCode = "ckb.bad_request"
        event.diagnostic = "invalid_repo"
        return event
    }
    if ((event.state != "" && event.state != "merged") || (event.action != "" && event.action != "merge" && event.action != "merged")) {
        event.errorCode = "ckb.bad_request"
        event.diagnostic = "event_not_merged"
        return event
    }
    if (event.ref == "") {
        event.ref = "main"
    }
    event.valid = true
    event
}

public func ckbApiGitCodeRepositoryChangedEvent(service: CkbCommandLoopService, event: GitCodeRepositoryChangedEvent): String {
    if (!event.valid) {
        return ckbApiErrorEnvelope(event.errorCode, "invalid repository changed event", status: 400, diagnostics: "{\"reason\":\"${ckbApiJsonEscape(event.diagnostic)}\"}")
    }
    ckbApiEnvelope(ckbApiRepositoryEventResultJson(service.acceptGitCodeRepositoryChangedEvent(event)))
}

private func ckbApiHandleAdmin(service: CkbCommandLoopService, method: String, path: String, body: String): String {
    if (method != "POST") {
        return ckbApiErrorEnvelope("ckb.method_not_allowed", "admin route requires POST", status: 405)
    }
    if (path == "/v1/admin/rebuild") {
        let result = service.runRebuild()
        return ckbApiEnvelope("{\"status\":\"${if (result.ok) { "ok" } else { "degraded" }}\",\"activeKnowledgeVersion\":\"${ckbApiJsonEscape(result.activeVersion)}\",\"candidateKnowledgeVersion\":\"${ckbApiJsonEscape(result.candidateVersion)}\",\"count\":${result.count}}")
    }
    if (path == "/v1/admin/vector/bootstrap") {
        return ckbApiEnvelope(renderCkbVectorBootstrapJson(service.runVectorBootstrap()))
    }
    if (path == "/v1/admin/vector/clean-derived") {
        return ckbApiEnvelope(renderCkbDerivedVectorCleanupJson(service.runDerivedVectorCleanup(ckbApiJsonBoolField(body, "force"))))
    }
    if (path == "/v1/admin/vector/reconcile") {
        return ckbApiEnvelope(renderCkbVectorReconcileJson(service.runVectorReconcile(ckbApiJsonBoolField(body, "force"))))
    }
    if (path == "/v1/admin/scheduler/run") {
        let taskNames = ckbApiJsonStringArrayField(body, "taskNames")
        let force = ckbApiJsonBoolField(body, "force")
        let result = if (taskNames.size > 0) { service.runSchedulerTasks(taskNames, force) } else { service.runScheduler(ckbApiJsonIntField(body, "limit", 1)) }
        if (result.failed > 0 && result.ran == 0) {
            return ckbApiErrorEnvelope("ckb.bad_request", "unsupported scheduler task", status: 400, diagnostics: "{\"details\":\"${ckbApiJsonEscape(result.details)}\"}")
        }
        return ckbApiEnvelope("{\"ran\":${result.ran},\"succeeded\":${result.succeeded},\"failed\":${result.failed},\"degraded\":${result.degraded},\"forced\":${result.forced},\"taskNames\":${ckbApiStringArrayJson(result.taskNames)},\"details\":\"${ckbApiJsonEscape(result.details)}\",\"validationSummaries\":${ckbApiStringArrayJson(result.validationSummaries)},\"validationDiagnostics\":${ckbApiStringArrayJson(result.validationDiagnostics)},\"validationEvidenceHashes\":${ckbApiStringArrayJson(result.validationEvidenceHashes)}}")
    }
    if (path == "/v1/admin/sync") {
        return ckbApiEnvelope(ckbApiAdminResultJson(service.runSync(body: body)))
    }
    if (path == "/v1/admin/initialize") {
        return ckbApiEnvelope(ckbApiFirstInitResultJson(service.runFirstInitialization(body: body)))
    }
    if (path == "/v1/admin/repositories/sync") {
        return ckbApiEnvelope(ckbApiAdminResultJson(service.runRepositorySync(body: body)))
    }
    if (path == "/v1/admin/repo-list/refresh") {
        return ckbApiEnvelope(ckbApiAdminResultJson(service.runRepoListRefresh(body: body)))
    }
    if (path == "/v1/admin/cangjie/landing-status") {
        return ckbApiEnvelope(renderCkbLandingStatusJson(collectCkbLandingStatus(service)))
    }
    ckbApiErrorEnvelope("ckb.not_found", "admin route not found", status: 404)
}

private func ckbApiHandleEvidence(service: CkbCommandLoopService, body: String, queryMode: Bool): String {
    let q = ckbApiJsonStringField(body, "q").trimAscii()
    let budget = ckbApiJsonIntField(body, "budget", 5)
    if (q == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "q must not be empty", status: 400)
    }
    if (budget <= 0 || budget > 20) {
        return ckbApiErrorEnvelope("ckb.bad_request", "budget must be between 1 and 20", status: 400)
    }
    let pack = service.queryEvidencePack(q, budget)
    if (queryMode) {
        return ckbApiEnvelope(ckbApiQueryJson(pack))
    }
    ckbApiEnvelope(ckbApiEvidencePackJson(pack))
}

private func ckbApiHandleCangjieKnowledgePack(service: CkbCommandLoopService, body: String): String {
    let task = ckbApiJsonStringField(body, "task").trimAscii()
    if (task == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "task must not be empty", status: 400)
    }
    let pack = service.cangjieKnowledgePack(task,
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET),
        includeExamples: ckbApiJsonBoolFieldDefault(body, "includeExamples", true) && !ckbApiJsonBoolField(body, "excludeExamples"),
        includeAntiPatterns: ckbApiJsonBoolFieldDefault(body, "includeAntiPatterns", true) && !ckbApiJsonBoolField(body, "excludeAntiPatterns"))
    ckbApiEnvelope(ckbApiCangjieKnowledgePackJson(pack))
}

private func ckbApiHandleCangjieSyntaxQuery(service: CkbCommandLoopService, body: String): String {
    let q = ckbApiJsonStringField(body, "q").trimAscii()
    if (q == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "q must not be empty", status: 400)
    }
    let pack = service.cangjieSyntaxQuery(q,
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))
    ckbApiEnvelope(renderCangjieSyntaxRuleResultJson(cangjieSyntaxRuleResultFromPack(pack, sourceSet: ckbApiJsonStringField(body, "sourceSet"))))
}

private func ckbApiHandleCangjieApiSearch(service: CkbCommandLoopService, body: String): String {
    let q = ckbApiJsonStringField(body, "q").trimAscii()
    let module = ckbApiJsonStringField(body, "module").trimAscii()
    let symbol = ckbApiJsonStringField(body, "symbol").trimAscii()
    if (q == "" && module == "" && symbol == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "q, module, or symbol must not be empty", status: 400)
    }
    let pack = service.cangjieApiSearch(q,
        module: module,
        symbol: symbol,
        sourceSet: ckbApiJsonStringField(body, "sourceSet"),
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))
    ckbApiEnvelope(renderCangjieApiPatternResultJson(cangjieApiPatternResultFromPack(pack, sourceSet: ckbApiJsonStringField(body, "sourceSet"))))
}

private func ckbApiHandleCangjieCookbook(service: CkbCommandLoopService, body: String): String {
    let task = ckbApiJsonStringField(body, "task").trimAscii()
    if (task == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "task must not be empty", status: 400)
    }
    let pack = service.cangjieCookbook(task,
        constraints: ckbApiJsonStringField(body, "constraints"),
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        style: ckbApiJsonStringField(body, "style"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))
    ckbApiEnvelope(renderCangjieRecipeResultJson(cangjieRecipeResultFromPack(pack, sourceSet: ckbApiJsonStringField(body, "sourceSet"))))
}

private func ckbApiHandleCangjieDiagnose(service: CkbCommandLoopService, body: String): String {
    let compilerOutput = ckbApiJsonStringField(body, "compilerOutput").trimAscii()
    let context = ckbApiJsonStringField(body, "context").trimAscii()
    if (compilerOutput == "" && context == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "compilerOutput or context must not be empty", status: 400)
    }
    let pack = service.cangjieDiagnose(ckbApiJsonStringField(body, "code"),
        compilerOutput,
        context: context,
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))
    ckbApiEnvelope(renderCangjieDiagnosticResultJson(cangjieDiagnosticResultFromPack(pack, sourceSet: ckbApiJsonStringField(body, "sourceSet"))))
}

private func ckbApiHandleCangjieExamples(service: CkbCommandLoopService, body: String): String {
    let q = ckbApiJsonStringField(body, "q").trimAscii()
    let module = ckbApiJsonStringField(body, "module").trimAscii()
    let symbol = ckbApiJsonStringField(body, "symbol").trimAscii()
    if (q == "" && module == "" && symbol == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "q, module, or symbol must not be empty", status: 400)
    }
    let pack = service.cangjieExamples(q,
        module: module,
        symbol: symbol,
        maxExamples: ckbApiJsonIntField(body, "maxExamples", CangjieCapabilityLimits.DEFAULT_EXAMPLE_LIMIT),
        targetVersion: ckbApiJsonStringField(body, "targetVersion"))
    ckbApiEnvelope(renderCangjieExampleSearchResultJson(cangjieExampleSearchResultFromPack(pack, sourceSet: ckbApiJsonStringField(body, "sourceSet"))))
}

private func ckbApiHandleCangjieContextPack(service: CkbCommandLoopService, body: String): String {
    let task = ckbApiJsonStringField(body, "task").trimAscii()
    if (task == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "task must not be empty", status: 400)
    }
    let pack = service.cangjieKnowledgePack(task,
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET),
        includeExamples: true,
        includeAntiPatterns: true)
    ckbApiEnvelope(ckbApiCangjieMarkdownJson(pack, "context-pack"))
}

private func ckbApiHandleCangjieVersionResolve(service: CkbCommandLoopService, body: String): String {
    let selector = ckbApiVersionSelectorFromBody(body)
    ckbApiEnvelope(cangjieVersionResolutionJson(service.cangjieResolveVersion(selector)))
}

private func ckbApiHandleCangjieTaskKnowledgePack(service: CkbCommandLoopService, body: String): String {
    let request = ckbApiTaskKnowledgeRequestFromBody(body)
    let validation = validateCangjieTaskKnowledgeRequest(request)
    if (validation != "") {
        return ckbApiErrorEnvelope("ckb.bad_request", validation, status: 400)
    }
    ckbApiEnvelope(cangjieTaskKnowledgePackJson(service.cangjieTaskKnowledgePack(request)))
}

private func ckbApiHandleCangjieKnowledgeCoverage(service: CkbCommandLoopService, body: String): String {
    let request = ckbApiTaskKnowledgeRequestFromBody(body)
    let validation = validateCangjieTaskKnowledgeRequest(request)
    if (validation != "") {
        return ckbApiErrorEnvelope("ckb.bad_request", validation, status: 400)
    }
    ckbApiEnvelope(cangjieKnowledgeCoverageJson(service.cangjieKnowledgeCoverage(request)))
}

private func ckbApiHandleCangjieCompileDiagnoseV2(service: CkbCommandLoopService, body: String): String {
    let compilerOutput = ckbApiJsonStringField(body, "compilerOutput").trimAscii()
    let context = ckbApiJsonStringField(body, "context").trimAscii()
    if (compilerOutput == "" && context == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "compilerOutput or context must not be empty", status: 400)
    }
    ckbApiEnvelope(cangjieTaskKnowledgePackJson(service.cangjieCompileDiagnoseV2(ckbApiJsonStringField(body, "code"),
        compilerOutput,
        context: context,
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        sourceSet: ckbApiJsonStringField(body, "sourceSet"),
        sourceRef: ckbApiJsonStringField(body, "sourceRef"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))))
}

private func ckbApiHandleCangjieSymbolLookup(service: CkbCommandLoopService, body: String): String {
    let symbol = ckbApiFirstNonEmpty(ckbApiJsonStringField(body, "symbol"), ckbApiJsonStringField(body, "q")).trimAscii()
    if (symbol == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "symbol must not be empty", status: 400, diagnostics: "{\"reason\":\"empty_symbol\"}")
    }
    let sourceSet = ckbApiJsonStringField(body, "sourceSet")
    let pack = service.cangjieSymbolLookup(symbol,
        module: ckbApiJsonStringField(body, "module"),
        sourceSet: sourceSet,
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))
    ckbApiEnvelope(renderCangjieSymbolCardResultJson(cangjieSymbolCardResultFromPack(pack, sourceSet: sourceSet)))
}

private func ckbApiHandleCangjieDocSection(service: CkbCommandLoopService, body: String): String {
    let sectionId = ckbApiJsonStringField(body, "sectionId").trimAscii()
    let path = ckbApiJsonStringField(body, "path").trimAscii()
    let heading = ckbApiJsonStringField(body, "heading").trimAscii()
    if (sectionId == "" && path == "" && heading == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "sectionId, path, or heading must not be empty", status: 400, diagnostics: "{\"reason\":\"empty_doc_selector\"}")
    }
    let pack = service.cangjieDocSection(sectionId,
        path: path,
        heading: heading,
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))
    ckbApiEnvelope(renderCangjieDocSectionResultJson(cangjieDocSectionResultFromPack(pack, sourceSet: CangjieSourceSets.DOCS)))
}

private func ckbApiHandleCangjieToolManual(service: CkbCommandLoopService, body: String): String {
    let tool = ckbApiFirstNonEmpty(ckbApiJsonStringField(body, "tool"), ckbApiJsonStringField(body, "command")).trimAscii()
    if (tool == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "tool or command must not be empty", status: 400, diagnostics: "{\"reason\":\"empty_tool\"}")
    }
    let pack = service.cangjieToolManual(tool,
        command: ckbApiJsonStringField(body, "command"),
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))
    ckbApiEnvelope(renderCangjieToolManualResultJson(cangjieToolManualResultFromPack(pack, sourceSet: CangjieSourceSets.TOOLS)))
}

private func ckbApiHandleCangjieNegativeRules(service: CkbCommandLoopService, body: String): String {
    let query = ckbApiFirstNonEmpty(ckbApiJsonStringField(body, "q"), ckbApiJsonStringField(body, "query")).trimAscii()
    if (query == "") {
        return ckbApiErrorEnvelope("ckb.bad_request", "q or query must not be empty", status: 400, diagnostics: "{\"reason\":\"empty_query\"}")
    }
    let pack = service.cangjieNegativeRules(query,
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        budget: ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET))
    ckbApiEnvelope(renderCangjieNegativeRulesResultJson(cangjieNegativeRulesResultFromPack(pack, sourceSet: ckbApiJsonStringField(body, "sourceSet"))))
}

private func ckbApiVersionSelectorFromBody(body: String): CangjieVersionSelector {
    cangjieVersionSelector(
        targetVersion: ckbApiJsonStringField(body, "targetVersion"),
        sourceSet: ckbApiJsonStringField(body, "sourceSet"),
        sourceFamily: ckbApiJsonStringField(body, "sourceFamily"),
        sourceRepo: ckbApiJsonStringField(body, "sourceRepo"),
        sourceRef: ckbApiJsonStringField(body, "sourceRef"),
        refKind: ckbApiJsonStringField(body, "refKind"),
        versionPolicy: ckbApiJsonStringField(body, "versionPolicy"),
        includePrerelease: ckbApiJsonBoolField(body, "includePrerelease"))
}

private func ckbApiTaskKnowledgeRequestFromBody(body: String): CangjieTaskKnowledgeRequest {
    let request = CangjieTaskKnowledgeRequest()
    request.taskId = ckbApiJsonStringField(body, "taskId")
    request.benchmark = ckbApiJsonStringField(body, "benchmark")
    request.taskText = ckbApiFirstNonEmpty(ckbApiJsonStringField(body, "taskText"), ckbApiJsonStringField(body, "task"))
    request.signature = ckbApiJsonStringField(body, "signature")
    request.imports = ckbApiJsonStringArrayField(body, "imports")
    request.argTypes = ckbApiJsonStringArrayField(body, "argTypes")
    request.returnType = ckbApiJsonStringField(body, "returnType")
    request.expectedKnowledgeTags = ckbApiJsonStringArrayField(body, "expectedKnowledgeTags")
    request.starterCodeExcerpt = ckbApiJsonStringField(body, "starterCodeExcerpt")
    request.compilerOutput = ckbApiJsonStringField(body, "compilerOutput")
    request.versionSelector = ckbApiVersionSelectorFromBody(body)
    request.budget = ckbApiJsonIntField(body, "budget", CangjieCapabilityLimits.DEFAULT_BUDGET)
    request.responseMode = ckbApiJsonStringField(body, "responseMode")
    request
}

private func ckbApiHandleSourceAnalysis(service: CkbCommandLoopService, body: String): String {
    let request = SourceAnalysisRequest()
    request.repo = ckbApiJsonStringField(body, "repo")
    request.ref = ckbApiJsonStringField(body, "ref")
    request.query = ckbApiJsonStringField(body, "query")
    request.issueUrl = ckbApiJsonStringField(body, "issueUrl")
    request.prUrl = ckbApiJsonStringField(body, "prUrl")
    request.allowCloneFallback = ckbApiJsonBoolField(body, "allowCloneFallback")
    request.maxFiles = ckbApiJsonIntField(body, "maxFiles", request.maxFiles)
    request.maxBytes = ckbApiJsonIntField(body, "maxBytes", request.maxBytes)
    request.timeoutMillis = ckbApiJsonIntField(body, "timeoutMillis", request.timeoutMillis)
    for (path in ckbApiJsonStringArrayField(body, "changedFiles")) {
        request.changedFiles.add(path)
    }
    for (path in ckbApiJsonStringArrayField(body, "candidatePaths")) {
        request.candidatePaths.add(path)
    }
    let singlePath = ckbApiJsonStringField(body, "path")
    if (singlePath != "") {
        request.candidatePaths.add(singlePath)
    }
    if (!ckbApiSafeRepo(request.repo)) {
        return ckbApiErrorEnvelope("ckb.bad_request", "repo must be owner/repo", status: 400)
    }
    for (path in request.changedFiles) {
        if (!ckbApiSafeRepoRelativePath(path)) {
            return ckbApiErrorEnvelope("ckb.bad_request", "source paths must be repo-relative", status: 400)
        }
    }
    for (path in request.candidatePaths) {
        if (!ckbApiSafeRepoRelativePath(path)) {
            return ckbApiErrorEnvelope("ckb.bad_request", "source paths must be repo-relative", status: 400)
        }
    }
    if (request.ref == "") {
        request.ref = "main"
    }
    ckbApiEnvelope(ckbApiSourceAnalysisJson(service.runSourceAnalysis(request)))
}

private func ckbApiRenderResponse(response: CkbApiResponse): String {
    "{\"ok\":${response.ok},\"apiVersion\":\"${response.apiVersion}\",\"data\":${response.data},\"diagnostics\":${response.diagnostics}}"
}

private func ckbApiHealthJson(status: KnowledgeStatus): String {
    let schedulerDegraded = ckbApiSchedulerDegraded(status)
    let degraded = schedulerDegraded || status.storage.vectorState == EmbeddingProviderState.DEGRADED || status.storage.graphState == EmbeddingProviderState.DEGRADED
    "{\"status\":\"${if (degraded) { "degraded" } else { "ok" }}\",\"activeKnowledgeVersion\":\"${ckbApiJsonEscape(status.activeKnowledgeVersion)}\",\"degraded\":${degraded},\"schedulerDegraded\":${schedulerDegraded},\"schedulerLoop\":${ckbApiSchedulerLoopJson(status.schedulerLoop)}}"
}

private func ckbApiStatusJson(status: KnowledgeStatus): String {
    "{\"activeKnowledgeVersion\":\"${ckbApiJsonEscape(status.activeKnowledgeVersion)}\",\"candidateKnowledgeVersion\":\"${ckbApiJsonEscape(status.candidateKnowledgeVersion)}\",\"activeStateSource\":\"${ckbApiJsonEscape(status.activeStateSource)}\",\"restoreDiagnostic\":\"${ckbApiJsonEscape(redactSensitive(status.restoreDiagnostic))}\",\"storage\":{\"rawCount\":${status.storage.rawCount},\"normalizedCount\":${status.storage.normalizedCount},\"indexCount\":${status.storage.indexCount},\"vectorState\":\"${ckbApiJsonEscape(status.storage.vectorState)}\",\"graphState\":\"${ckbApiJsonEscape(status.storage.graphState)}\",\"localPathRedacted\":${status.localPathRedacted}},\"scheduler\":${ckbApiSchedulesDataJson(status)},\"schedulerLoop\":${ckbApiSchedulerLoopJson(status.schedulerLoop)}}"
}

private func ckbApiSchedulesJson(status: KnowledgeStatus): String {
    ckbApiSchedulesDataJson(status)
}

private func ckbApiSchedulesDataJson(status: KnowledgeStatus): String {
    var out = "{\"entries\":["
    for (i in 0..status.schedules.size) {
        if (i > 0) {
            out += ","
        }
        let entry = status.schedules[i]
        out += "{\"name\":\"${ckbApiJsonEscape(entry.name)}\",\"intervalMinutes\":${entry.intervalMinutes},\"nextRunAt\":${entry.nextRunAt},\"lastSuccessAt\":${entry.lastSuccessAt},\"lastFailureAt\":${entry.lastFailureAt},\"failureCount\":${entry.failureCount},\"degraded\":${entry.degraded},\"lastStatus\":\"${ckbApiJsonEscape(entry.lastStatus)}\",\"lastDurationMillis\":${entry.lastDurationMillis},\"lastRequestCount\":${entry.lastRequestCount},\"lastUpdatedDataKinds\":${ckbApiStringArrayJson(entry.lastUpdatedDataKinds)},\"lastTruncated\":${entry.lastTruncated},\"timeBudgetMillis\":${entry.timeBudgetMillis}}"
    }
    out += "],\"schedulerDegraded\":${ckbApiSchedulerDegraded(status)},\"schedulerLoop\":${ckbApiSchedulerLoopJson(status.schedulerLoop)}}"
    out
}

private func ckbApiSchedulerLoopJson(loop: CkbSchedulerLoopStatus): String {
    "{\"loopStatus\":\"${ckbApiJsonEscape(loop.loopStatus)}\",\"schedulerEnabled\":${loop.schedulerEnabled},\"intervalMillis\":${loop.intervalMillis},\"readinessGate\":\"${ckbApiJsonEscape(loop.readinessGate)}\",\"firstTickDeferred\":${loop.firstTickDeferred},\"tickKind\":\"${ckbApiJsonEscape(loop.tickKind)}\",\"limit\":${loop.limit},\"ran\":${loop.ran},\"taskNames\":${ckbApiStringArrayJson(loop.taskNames)},\"diagnostic\":\"${ckbApiJsonEscape(redactSensitive(loop.diagnostic))}\",\"heartbeatFresh\":${loop.heartbeatFresh},\"loopFailureCount\":${loop.loopFailureCount}}"
}

private func ckbApiSchemaJson(): String {
    let routes = "\"GET /v1/health\",\"GET /v1/status\",\"GET /v1/schedules\",\"GET /v1/schema\",\"GET /mcp\",\"POST /mcp\",\"DELETE /mcp\",\"GET /v1/cangjie/corpus/status\",\"GET /v1/cangjie/llms.txt\",\"GET /v1/cangjie/llms-full.txt\",\"POST /v1/cangjie/knowledge-pack\",\"POST /v1/cangjie/syntax-query\",\"POST /v1/cangjie/api-search\",\"POST /v1/cangjie/cookbook\",\"POST /v1/cangjie/diagnose\",\"POST /v1/cangjie/examples\",\"POST /v1/cangjie/context-pack\",\"POST /v1/cangjie/version/resolve\",\"POST /v1/cangjie/task-knowledge-pack\",\"POST /v1/cangjie/knowledge-coverage\",\"POST /v1/cangjie/compile-diagnose-v2\",\"POST /v1/cangjie/symbol-lookup\",\"POST /v1/cangjie/doc-section\",\"GET /v1/cangjie/corpus/freshness\",\"POST /v1/cangjie/tool-manual\",\"POST /v1/cangjie/negative-rules\",\"POST /v1/query\",\"POST /v1/evidence-pack\",\"POST /v1/source-analysis\",\"POST /v1/events/gitcode/repository-changed\",\"POST /v1/admin/rebuild\",\"POST /v1/admin/vector/bootstrap\",\"POST /v1/admin/vector/clean-derived\",\"POST /v1/admin/vector/reconcile\",\"POST /v1/admin/scheduler/run\",\"POST /v1/admin/repositories/sync\",\"POST /v1/admin/repo-list/refresh\",\"POST /v1/admin/sync\",\"POST /v1/admin/initialize\",\"POST /v1/admin/cangjie/landing-status\""
    let tools = ckbApiStringArrayJson(ckbMcpToolNames())
    let routeAuth = "{\"/v1/admin/*\":\"admin\",\"/v1/events/gitcode/repository-changed\":\"event\",\"/v1/cangjie/*\":\"read\",\"/v1/query\":\"read\",\"/v1/evidence-pack\":\"read\",\"/v1/source-analysis\":\"read\",\"/mcp\":\"read\"}"
    let adminRoutes = "\"POST /v1/admin/rebuild\",\"POST /v1/admin/vector/bootstrap\",\"POST /v1/admin/vector/clean-derived\",\"POST /v1/admin/vector/reconcile\",\"POST /v1/admin/scheduler/run\",\"POST /v1/admin/repositories/sync\",\"POST /v1/admin/repo-list/refresh\",\"POST /v1/admin/sync\",\"POST /v1/admin/initialize\",\"POST /v1/admin/cangjie/landing-status\""
    let eventRoutes = "\"POST /v1/events/gitcode/repository-changed\""
    let readRoutes = "\"GET /mcp\",\"POST /mcp\",\"DELETE /mcp\",\"GET /v1/cangjie/corpus/status\",\"GET /v1/cangjie/llms.txt\",\"GET /v1/cangjie/llms-full.txt\",\"POST /v1/cangjie/knowledge-pack\",\"POST /v1/cangjie/syntax-query\",\"POST /v1/cangjie/api-search\",\"POST /v1/cangjie/cookbook\",\"POST /v1/cangjie/diagnose\",\"POST /v1/cangjie/examples\",\"POST /v1/cangjie/context-pack\",\"POST /v1/cangjie/version/resolve\",\"POST /v1/cangjie/task-knowledge-pack\",\"POST /v1/cangjie/knowledge-coverage\",\"POST /v1/cangjie/compile-diagnose-v2\",\"POST /v1/cangjie/symbol-lookup\",\"POST /v1/cangjie/doc-section\",\"GET /v1/cangjie/corpus/freshness\",\"POST /v1/cangjie/tool-manual\",\"POST /v1/cangjie/negative-rules\",\"POST /v1/query\",\"POST /v1/evidence-pack\",\"POST /v1/source-analysis\""
    "{\"apiVersion\":\"ckb-http-v1\",\"envelope\":\"{ok,apiVersion,data|error,diagnostics}\",\"routes\":[${routes}],\"routeAuth\":${routeAuth},\"adminRoutes\":[${adminRoutes}],\"eventRoutes\":[${eventRoutes}],\"readRoutes\":[${readRoutes}],\"mcpTransports\":[\"stdio\",\"streamable-http\"],\"mcpEndpoint\":\"/mcp\",\"mcpProtocolVersions\":[\"2024-11-05\",\"2025-06-18\"],\"mcpSse\":true,\"tools\":${tools},\"mcpReadOnlyTools\":${tools},\"mcpResources\":[\"ckb://cangjie/corpus/status\",\"ckb://cangjie/llms.txt\",\"ckb://cangjie/llms-full.txt\",\"ckb://cangjie/syntax/{query}\",\"ckb://cangjie/api/{symbol}\",\"ckb://cangjie/cookbook/{task}\"],\"mcpPrompts\":[\"cangjie_write_code_with_ckb\",\"cangjie_fix_compile_error\",\"cangjie_explain_api\",\"cangjie_generate_tests\"],\"plannedNotEnabled\":[\"/v1/cangjie/verify-snippet\"],\"errorCodes\":[\"ckb.bad_request\",\"ckb.unauthorized\",\"ckb.not_found\",\"ckb.method_not_allowed\",\"ckb.invalid_workspace_root\",\"version_not_resolved\",\"unsupported_source_set\"],\"limits\":{\"budgetDefault\":5,\"budgetMax\":20,\"apiVersion\":\"ckb-http-v1\"}}"
}

private func ckbApiQueryJson(pack: EvidencePack): String {
    "{\"knowledgeVersion\":\"${ckbApiJsonEscape(pack.knowledgeVersion)}\",\"truncated\":${pack.truncated},\"degraded\":${pack.degraded},\"rows\":${ckbApiCitationsJson(pack.citations)},\"citations\":${ckbApiCitationsJson(pack.citations)}}"
}

private func ckbApiEvidencePackJson(pack: EvidencePack): String {
    var out = "{\"queryId\":\"${ckbApiJsonEscape(pack.queryId)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(pack.knowledgeVersion)}\",\"truncated\":${pack.truncated},\"degraded\":${pack.degraded}"
    out += ",\"sourceEvidence\":["
    for (i in 0..pack.sourceEvidence.size) {
        if (i > 0) { out += "," }
        let item = pack.sourceEvidence[i]
        out += "{\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"repo\":\"${ckbApiJsonEscape(item.repo)}\",\"path\":\"${ckbApiJsonEscape(item.path)}\",\"symbol\":\"${ckbApiJsonEscape(item.symbol)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\"}"
    }
    out += "],\"docEvidence\":["
    for (i in 0..pack.docEvidence.size) {
        if (i > 0) { out += "," }
        let item = pack.docEvidence[i]
        out += "{\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"title\":\"${ckbApiJsonEscape(item.title)}\",\"docVersion\":\"${ckbApiJsonEscape(item.docVersion)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\"}"
    }
    out += "],\"websiteEvidence\":["
    for (i in 0..pack.websiteEvidence.size) {
        if (i > 0) { out += "," }
        let item = pack.websiteEvidence[i]
        out += "{\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"url\":\"${ckbApiJsonEscape(item.url)}\",\"title\":\"${ckbApiJsonEscape(item.title)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\"}"
    }
    out += "],\"communityEvidence\":["
    for (i in 0..pack.communityEvidence.size) {
        if (i > 0) { out += "," }
        let item = pack.communityEvidence[i]
        out += "{\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"repo\":\"${ckbApiJsonEscape(item.repo)}\",\"issueOrPr\":\"${ckbApiJsonEscape(item.issueOrPr)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\"}"
    }
    out += "],\"webCandidateEvidence\":["
    for (i in 0..pack.webCandidateEvidence.size) {
        if (i > 0) { out += "," }
        let item = pack.webCandidateEvidence[i]
        out += "{\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"url\":\"${ckbApiJsonEscape(item.url)}\",\"requiresReview\":${item.requiresReview},\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\"}"
    }
    out += "],\"citations\":${ckbApiCitationsJson(pack.citations)},\"graphContext\":{\"nodes\":${pack.graphContext.nodes.size},\"edges\":${pack.graphContext.edges.size},\"knowledgeVersion\":\"${ckbApiJsonEscape(pack.graphContext.knowledgeVersion)}\",\"truncated\":${pack.graphContext.truncated}}}"
    out
}

private func ckbApiCangjieKnowledgePackJson(pack: CangjieKnowledgePack): String {
    var out = "{\"queryId\":\"${ckbApiJsonEscape(pack.queryId)}\",\"task\":\"${ckbApiJsonEscape(pack.task)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(pack.knowledgeVersion)}\",\"targetVersion\":\"${ckbApiJsonEscape(pack.targetVersion)}\",\"versionResolutionId\":\"${ckbApiJsonEscape(pack.versionResolutionId)}\",\"truncated\":${pack.truncated},\"degraded\":${pack.degraded},\"executed\":${pack.executed}"
    out += ",\"items\":["
    for (i in 0..pack.items.size) {
        if (i > 0) { out += "," }
        let item = pack.items[i]
        out += "{\"kind\":\"${ckbApiJsonEscape(item.kind)}\",\"title\":\"${ckbApiJsonEscape(item.title)}\",\"content\":\"${ckbApiJsonEscape(item.content)}\",\"module\":\"${ckbApiJsonEscape(item.module)}\",\"symbol\":\"${ckbApiJsonEscape(item.symbol)}\",\"importLine\":\"${ckbApiJsonEscape(item.importLine)}\",\"signature\":\"${ckbApiJsonEscape(item.signature)}\",\"example\":\"${ckbApiJsonEscape(item.example)}\",\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"sourceId\":\"${ckbApiJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${ckbApiJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${ckbApiJsonEscape(item.trustLevel)}\",\"reviewState\":\"${ckbApiJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
    }
    out += "],\"apiItems\":["
    for (i in 0..pack.apiItems.size) {
        if (i > 0) { out += "," }
        let item = pack.apiItems[i]
        out += "{\"module\":\"${ckbApiJsonEscape(item.module)}\",\"symbol\":\"${ckbApiJsonEscape(item.symbol)}\",\"importLine\":\"${ckbApiJsonEscape(item.importLine)}\",\"signature\":\"${ckbApiJsonEscape(item.signature)}\",\"summary\":\"${ckbApiJsonEscape(item.summary)}\",\"example\":\"${ckbApiJsonEscape(item.example)}\",\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"sourceId\":\"${ckbApiJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${ckbApiJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${ckbApiJsonEscape(item.trustLevel)}\",\"reviewState\":\"${ckbApiJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
    }
    out += "],\"examples\":["
    for (i in 0..pack.examples.size) {
        if (i > 0) { out += "," }
        let item = pack.examples[i]
        out += "{\"title\":\"${ckbApiJsonEscape(item.title)}\",\"code\":\"${ckbApiJsonEscape(item.code)}\",\"explanation\":\"${ckbApiJsonEscape(item.explanation)}\",\"module\":\"${ckbApiJsonEscape(item.module)}\",\"symbol\":\"${ckbApiJsonEscape(item.symbol)}\",\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"sourceId\":\"${ckbApiJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${ckbApiJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${ckbApiJsonEscape(item.trustLevel)}\",\"reviewState\":\"${ckbApiJsonEscape(item.reviewState)}\",\"requiresReview\":${item.requiresReview}}"
    }
    out += "],\"diagnostics\":["
    for (i in 0..pack.diagnostics.size) {
        if (i > 0) { out += "," }
        let item = pack.diagnostics[i]
        out += "{\"rule\":\"${ckbApiJsonEscape(item.rule)}\",\"message\":\"${ckbApiJsonEscape(item.message)}\",\"relatedSyntax\":\"${ckbApiJsonEscape(item.relatedSyntax)}\",\"suggestedQuery\":\"${ckbApiJsonEscape(item.suggestedQuery)}\",\"citation\":\"${ckbApiJsonEscape(item.citation)}\",\"sourceId\":\"${ckbApiJsonEscape(item.sourceId)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(item.knowledgeVersion)}\",\"targetVersion\":\"${ckbApiJsonEscape(item.targetVersion)}\",\"trustLevel\":\"${ckbApiJsonEscape(item.trustLevel)}\",\"reviewState\":\"${ckbApiJsonEscape(item.reviewState)}\",\"executed\":${item.executed}}"
    }
    out += "],\"notes\":${ckbApiStringArrayJson(pack.notes)},\"citations\":${ckbApiCitationsJson(pack.citations)}}"
    out
}

private func ckbApiCangjieCorpusStatusJson(status: CangjieCorpusStatus): String {
    "{\"activeKnowledgeVersion\":\"${ckbApiJsonEscape(status.activeKnowledgeVersion)}\",\"targetVersion\":\"${ckbApiJsonEscape(status.targetVersion)}\",\"docsUrls\":${ckbApiStringArrayJson(status.docsUrls)},\"stdSources\":${ckbApiStringArrayJson(status.stdSources)},\"rawCount\":${status.rawCount},\"normalizedCount\":${status.normalizedCount},\"indexCount\":${status.indexCount},\"degraded\":${status.degraded},\"diagnostics\":${ckbApiStringArrayJson(status.diagnostics)}}"
}

private func ckbApiCangjieMarkdownJson(pack: CangjieKnowledgePack, kind: String): String {
    var markdown = "# Cangjie ${kind}\n\nknowledgeVersion: ${pack.knowledgeVersion}\ntargetVersion: ${pack.targetVersion}\n\n"
    for (item in pack.items) {
        markdown += "## ${item.title}\n${item.content}\n\ncitation: ${item.citation}\n\n"
    }
    for (item in pack.apiItems) {
        markdown += "## ${item.symbol}\n${item.summary}\n\nimport: ${item.importLine}\ncitation: ${item.citation}\n\n"
    }
    for (item in pack.examples) {
        markdown += "## ${item.title}\n```cangjie\n${item.code}\n```\n\ncitation: ${item.citation}\n\n"
    }
    "{\"kind\":\"${ckbApiJsonEscape(kind)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(pack.knowledgeVersion)}\",\"targetVersion\":\"${ckbApiJsonEscape(pack.targetVersion)}\",\"truncated\":${pack.truncated},\"degraded\":${pack.degraded},\"markdown\":\"${ckbApiJsonEscape(markdown)}\",\"citations\":${ckbApiCitationsJson(pack.citations)}}"
}

private func ckbApiCitationsJson(citations: ArrayList<SourceReference>): String {
    var out = "["
    for (i in 0..citations.size) {
        if (i > 0) { out += "," }
        let citation = citations[i]
        out += "{\"sourceId\":\"${ckbApiJsonEscape(citation.sourceId)}\",\"citation\":\"${ckbApiJsonEscape(citation.citation)}\",\"knowledgeVersion\":\"${ckbApiJsonEscape(citation.knowledgeVersion)}\"}"
    }
    out += "]"
    out
}

private func ckbApiSourceAnalysisJson(result: SourceAnalysisResult): String {
    var out = "{\"analysisId\":\"${ckbApiJsonEscape(result.analysisId)}\",\"repo\":\"${ckbApiJsonEscape(result.repo)}\",\"ref\":\"${ckbApiJsonEscape(result.ref)}\",\"sourceAcquisition\":\"${ckbApiJsonEscape(result.sourceAcquisition)}\",\"cleanupStatus\":\"${ckbApiJsonEscape(result.cleanupStatus)}\",\"degraded\":${result.degraded},\"diagnostic\":\"${ckbApiJsonEscape(redactSensitive(result.diagnostic))}\",\"filesRead\":["
    for (i in 0..result.filesRead.size) {
        if (i > 0) { out += "," }
        let file = result.filesRead[i]
        out += "{\"path\":\"${ckbApiJsonEscape(file.path)}\",\"citation\":\"${ckbApiJsonEscape(file.citation)}\",\"bytes\":${file.bytes},\"truncated\":${file.truncated}}"
    }
    out += "],\"citations\":${ckbApiStringArrayJson(result.citations)}}"
    out
}

private func ckbApiRepositoryEventResultJson(result: GitCodeRepositoryChangedEventResult): String {
    "{\"eventId\":\"${ckbApiJsonEscape(result.eventId)}\",\"status\":\"${ckbApiJsonEscape(result.status)}\",\"dedupeKey\":\"${ckbApiJsonEscape(result.dedupeKey)}\",\"scheduledProfiles\":${ckbApiStringArrayJson(result.scheduledProfiles)},\"acceptedAt\":\"${ckbApiJsonEscape(result.acceptedAt)}\",\"diagnostics\":{\"status\":\"${ckbApiJsonEscape(redactSensitive(result.diagnostic))}\"}}"
}

private func ckbApiAdminResultJson(result: CkbAdminOperationResult): String {
    "{\"status\":\"${ckbApiJsonEscape(result.status)}\",\"degraded\":${result.degraded},\"diagnostic\":\"${ckbApiJsonEscape(redactSensitive(result.diagnostic))}\",\"repo\":\"${ckbApiJsonEscape(result.repo)}\",\"ref\":\"${ckbApiJsonEscape(result.ref)}\",\"profile\":\"${ckbApiJsonEscape(result.profile)}\",\"prNumber\":${result.prNumber},\"truncated\":${result.truncated},\"matchedPaths\":${ckbApiStringArrayJson(result.matchedPaths)},\"repoCount\":${result.repoCount},\"requestCount\":${result.requestCount},\"updatedDataKinds\":${ckbApiStringArrayJson(result.updatedDataKinds)},\"activeKnowledgeVersion\":\"${ckbApiJsonEscape(result.activeKnowledgeVersion)}\",\"candidateKnowledgeVersion\":\"${ckbApiJsonEscape(result.candidateKnowledgeVersion)}\",\"activeRepoListVersion\":\"${ckbApiJsonEscape(result.activeRepoListVersion)}\",\"candidateRepoListVersion\":\"${ckbApiJsonEscape(result.candidateRepoListVersion)}\"}"
}

private func ckbApiFirstInitResultJson(result: CkbFirstInitResult): String {
    var out = "{\"status\":\"${if (result.ok) { "ok" } else { "degraded" }}\",\"degraded\":${!result.ok},\"dryRun\":${result.dryRun},\"persisted\":${result.persisted},\"activeKnowledgeVersion\":\"${ckbApiJsonEscape(result.activeVersion)}\",\"candidateKnowledgeVersion\":\"${ckbApiJsonEscape(result.candidateVersion)}\",\"validation\":{\"ok\":${result.validation.ok},\"failedGates\":${ckbApiStringArrayJson(result.validation.failedGates)},\"queryChecks\":${ckbApiStringArrayJson(result.validation.queryChecks)}}"
    out += ",\"sources\":["
    for (i in 0..result.sources.size) {
        if (i > 0) { out += "," }
        let source = result.sources[i]
        out += "{\"name\":\"${ckbApiJsonEscape(source.name)}\",\"ok\":${source.ok},\"fileCount\":${source.fileCount},\"recordCount\":${source.recordCount},\"diagnostics\":${ckbApiStringArrayJson(source.diagnostics)}}"
    }
    out += "],\"diagnostics\":${ckbApiStringArrayJson(result.diagnostics)}}"
    out
}

private func ckbApiStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) { out += "," }
        out += "\"${ckbApiJsonEscape(values[i])}\""
    }
    out += "]"
    out
}

private func ckbApiFirstNonEmpty(a: String, b: String): String {
    if (a.trimAscii() != "") { a } else { b }
}

private func ckbApiSchedulerDegraded(status: KnowledgeStatus): Bool {
    let loop = status.schedulerLoop
    if (loop.loopStatus == "failed" || loop.loopStatus == "scheduler_disabled" || loop.loopFailureCount > 0) {
        return true
    }
    if (loop.loopStatus == "running" && !loop.heartbeatFresh) {
        return true
    }
    for (entry in status.schedules) {
        if (entry.degraded) {
            return true
        }
    }
    false
}

private func ckbApiRequestContext(method: String, path: String, headers: Array<String>): CkbApiRequestContext {
    let context = CkbApiRequestContext()
    context.method = method.trimAscii().toAsciiUpper()
    context.path = path.trimAscii()
    for (header in headers) {
        let cleaned = header.trimAscii()
        context.headers.add(cleaned)
        let lower = cleaned.toAsciiLower()
        if ((lower.startsWith("authorization:") && lower != "authorization:") || (lower.startsWith("x-ckb-admin-token:") && lower != "x-ckb-admin-token:")) {
            context.adminAuthorized = true
        }
    }
    context
}

private func ckbApiDiagnosticObject(raw: String): String {
    let text = redactSensitive(raw.trimAscii())
    if (text.startsWith("{") && text.endsWith("}")) {
        return text
    }
    "{\"message\":\"${ckbApiJsonEscape(text)}\"}"
}

private func ckbApiJsonEscape(raw: String): String {
    let text = redactSensitive(raw)
    let out = StringBuilder()
    for (ch in text.toRuneArray()) {
        if (ch == r'"') {
            out.append("\\\"")
        } else if (ch == r'\\') {
            out.append("\\\\")
        } else if (ch == r'\n') {
            out.append("\\n")
        } else if (ch == r'\r') {
            out.append("\\r")
        } else if (ch == r'\t') {
            out.append("\\t")
        } else {
            out.append(ch)
        }
    }
    out.toString()
}

private class CkbApiJsonStringScan {
    var ok: Bool = false
    var value: String = ""
    var end: Int64 = 0

    init() {}
}

private func ckbApiAsciiJsonProjection(raw: String): String {
    let out = StringBuilder()
    for (ch in raw.toRuneArray()) {
        if (UInt32(ch) <= 0x7Fu32) {
            out.append(ch)
        } else {
            out.append(r' ')
        }
    }
    out.toString()
}

private func ckbApiJsonStringField(raw: String, key: String): String {
    let start = ckbApiJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "\"") {
        return ""
    }
    let scan = ckbApiReadJsonStringAt(raw, start)
    if (scan.ok) {
        return scan.value
    }
    ""
}

private func ckbApiJsonBoolField(raw: String, key: String): Bool {
    let start = ckbApiJsonTopLevelValueStart(raw, key)
    start >= 0 && raw[start..raw.size].startsWith("true")
}

private func ckbApiJsonBoolFieldDefault(raw: String, key: String, fallback: Bool): Bool {
    let start = ckbApiJsonTopLevelValueStart(raw, key)
    if (start < 0) {
        return fallback
    }
    raw[start..raw.size].startsWith("true")
}

private func ckbApiJsonIntField(raw: String, key: String, fallback: Int64): Int64 {
    let start = ckbApiJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size) {
        return fallback
    }
    var end = start
    while (end < raw.size) {
        let ch = raw[end..end + 1]
        if (ch == "," || ch == "}" || ch == "]" || ch == " " || ch == "\n" || ch == "\r" || ch == "\t") {
            break
        }
        end += 1
    }
    try { Int64.parse(raw[start..end].trimAscii()) } catch (_: Exception) { fallback }
}

private func ckbApiJsonIntOrStringField(raw: String, key: String, fallback: Int64): Int64 {
    let start = ckbApiJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size) {
        return fallback
    }
    if (raw[start..start + 1] == "\"") {
        let value = ckbApiJsonStringField(raw, key).trimAscii()
        return try { Int64.parse(value) } catch (_: Exception) { fallback }
    }
    ckbApiJsonIntField(raw, key, fallback)
}

private func ckbApiJsonStringArrayField(raw: String, key: String): ArrayList<String> {
    let values = ArrayList<String>()
    let start = ckbApiJsonTopLevelValueStart(raw, key)
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "[") {
        return values
    }
    var i = start + 1
    while (i < raw.size) {
        i = ckbApiSkipJsonWhitespace(raw, i)
        if (i >= raw.size || raw[i..i + 1] == "]") {
            break
        }
        if (raw[i..i + 1] == "\"") {
            let scan = ckbApiReadJsonStringAt(raw, i)
            if (scan.ok) {
                values.add(scan.value)
                i = scan.end
            } else {
                break
            }
        } else {
            i += 1
        }
        i = ckbApiSkipJsonWhitespace(raw, i)
        if (i < raw.size && raw[i..i + 1] == ",") {
            i += 1
        }
    }
    values
}

private func ckbApiJsonTopLevelValueStart(raw: String, key: String): Int64 {
    var i: Int64 = 0
    var depth: Int64 = 0
    var inString = false
    var escaped = false
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (inString) {
            if (escaped) {
                escaped = false
            } else if (ch == "\\") {
                escaped = true
            } else if (ch == "\"") {
                inString = false
            }
            i += 1
            continue
        }
        if (ch == "\"") {
            if (depth == 1) {
                let scan = ckbApiReadJsonStringAt(raw, i)
                if (scan.ok && scan.value == key) {
                    var colon = ckbApiSkipJsonWhitespace(raw, scan.end)
                    if (colon < raw.size && raw[colon..colon + 1] == ":") {
                        return ckbApiSkipJsonWhitespace(raw, colon + 1)
                    }
                }
                i = if (scan.ok) { scan.end } else { i + 1 }
                continue
            }
            inString = true
        } else if (ch == "{" || ch == "[") {
            depth += 1
        } else if (ch == "}" || ch == "]") {
            depth -= 1
        }
        i += 1
    }
    -1
}

private func ckbApiReadJsonStringAt(raw: String, start: Int64): CkbApiJsonStringScan {
    let scan = CkbApiJsonStringScan()
    if (start < 0 || start >= raw.size || raw[start..start + 1] != "\"") {
        return scan
    }
    var i = start + 1
    var escaped = false
    var value = ""
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (escaped) {
            value += ckbApiJsonUnescapeChar(ch)
            escaped = false
        } else if (ch == "\\") {
            escaped = true
        } else if (ch == "\"") {
            scan.ok = true
            scan.value = value
            scan.end = i + 1
            return scan
        } else {
            value += ch
        }
        i += 1
    }
    scan
}

private func ckbApiJsonUnescapeChar(ch: String): String {
    if (ch == "\"") { return "\"" }
    if (ch == "\\") { return "\\" }
    if (ch == "/") { return "/" }
    if (ch == "n") { return "\n" }
    if (ch == "r") { return "\r" }
    if (ch == "t") { return "\t" }
    ch
}

private func ckbApiSkipJsonWhitespace(raw: String, start: Int64): Int64 {
    var i = start
    while (i < raw.size) {
        let ch = raw[i..i + 1]
        if (ch != " " && ch != "\n" && ch != "\r" && ch != "\t") {
            break
        }
        i += 1
    }
    i
}

private func ckbApiSafeRepo(raw: String): Bool {
    let parts = raw.split("/")
    if (parts.size != 2) {
        return false
    }
    ckbApiSafePathPart(parts[0]) && ckbApiSafePathPart(parts[1])
}

private func ckbApiCommunityRepoAllowed(raw: String): Bool {
    let parts = raw.split("/")
    if (parts.size != 2) {
        return false
    }
    let owner = parts[0].toAsciiLower()
    owner == "cangjie" || owner == "cangjie-sig" || owner == "cangjie-tpc"
}

private func ckbApiSafePathPart(raw: String): Bool {
    if (raw == "" || raw == "." || raw == "..") {
        return false
    }
    for (ch in raw.toRuneArray()) {
        let ok = (ch >= r'a' && ch <= r'z') || (ch >= r'A' && ch <= r'Z') || (ch >= r'0' && ch <= r'9') || ch == r'_' || ch == r'-' || ch == r'.'
        if (!ok) {
            return false
        }
    }
    true
}

private func ckbApiSafeRepoRelativePath(raw: String): Bool {
    let path = raw.trimAscii()
    if (path == "" || path.startsWith("/") || path.startsWith("~") || path.contains("\\") || path.contains("..")) {
        return false
    }
    for (part in path.split("/")) {
        if (part == "" || part == "." || part == "..") {
            return false
        }
    }
    true
}
