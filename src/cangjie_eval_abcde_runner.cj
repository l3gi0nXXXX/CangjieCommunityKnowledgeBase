package cangjie_community_knowledge_base

import std.collection.{ArrayList, HashSet}
import std.convert.Parsable
import std.env.getVariable
import std.fs.{Directory, File, Path, exists, canonicalize}
import std.io.*
import std.process.*
import stdx.encoding.json.*

public class CkbAbcdeGroups {
    public static let A: String = "A-no-ckb"
    public static let B: String = "B-ckb-context"
    public static let C: String = "C-ckb-mcp-stdio"
    public static let D: String = "D-ckb-mcp-http"
    public static let E: String = "E-local-cangjie-docs"
}

public class CkbAbcdeRunnerOptions {
    public var runMode: String = "development"
    public var explicitRunMode: Bool = false
    public var datasetVersion: String = ""
    public var candidateVersion: String = ""
    public var knowledgeVersion: String = ""
    public var modelFingerprint: String = "claude-code-glm-5.2"
    public var repoRoot: String = ckbAbcdeDefaultRepoRoot()
    public var runsRoot: String = "/Users/l3gi0n/Downloads/ckbtest"
    public var runId: String = ""
    public var datasetRoot: String = ""
    public var manifestPath: String = ""
    public var ckbBin: String = ""
    public var ckbStore: String = ""
    public var ckbHttpBase: String = "http://127.0.0.1:18890"
    public var docsRoot: String = "/Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs"
    public var caseStart: Int64 = 0
    public var caseEnd: Int64 = 163
    public var groups: ArrayList<String> = ArrayList<String>()
    public var preflightOnly: Bool = false
    public var skipClaude: Bool = false
    public var help: Bool = false
    public var agentAttempts: Int64 = 1
    public var providerRetries: Int64 = 0
    public var sdkRetries: Int64 = 0
    public var maxTurns: Int64 = 1
    public var knowledgeRestRetries: Int64 = 0
    public var certificationPreflightPath: String = ""
    public var certificationRunManifestPath: String = ""
    public var expectedModelVersion: String = "GLM-5.2"
    public var providerIdentityHash: String = ""
    public var providerIdentityArtifactPath: String = ""
    public var modelTimeoutSeconds: Int64 = 180
    public var modelEffort: String = "low"
    public var modelMaxBudgetUsd: String = ""
    public var modelEffortExplicit: Bool = false
    public var modelMaxBudgetUsdExplicit: Bool = false

    public init() {
        this.datasetRoot = "${this.repoRoot}/test/cangjie_eval/cases/Cangjie-HumanEval"
        this.manifestPath = "${this.repoRoot}/test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
        this.ckbBin = "${this.repoRoot}/target/release/bin/main"
        this.ckbStore = "${this.repoRoot}/ckb-data"
        this.groups.add(CkbAbcdeGroups.A)
        this.groups.add(CkbAbcdeGroups.B)
        this.groups.add(CkbAbcdeGroups.C)
        this.groups.add(CkbAbcdeGroups.D)
        this.groups.add(CkbAbcdeGroups.E)
    }
}

public func ckbAbcdeCertificationBudget(options: CkbAbcdeRunnerOptions): CkbCertificationBudget {
    let budget = CkbCertificationBudget()
    budget.agentAttempts = options.agentAttempts
    budget.providerRetries = options.providerRetries
    budget.sdkRetries = options.sdkRetries
    budget.maxTurns = options.maxTurns
    budget.knowledgeRestRetries = options.knowledgeRestRetries
    budget
}

public func ckbAbcdeCertificationTransportParity(rest: CkbAbcdeParityObservation, stdio: CkbAbcdeParityObservation, http: CkbAbcdeParityObservation): Bool {
    ckbAbcdeParityDiagnostic(rest, stdio, http) == "ok" && rest.evidenceHash != "" && rest.evidenceHash == stdio.evidenceHash && rest.evidenceHash == http.evidenceHash
}

public class CkbAbcdeCommandResult {
    public var exitCode: Int64 = 1
    public var stdout: String = ""
    public var stderr: String = ""

    public init() {}
}

public class CkbAbcdeSampleAssessment {
    public var completeResult: Bool = false
    public var identityMatched: Bool = false
    public var sampleAttempt: Int64 = 0
    public init() {}
}

public class CkbAbcdeUsageStats {
    public var usageParseStatus: String = "missing_result"
    public var modelInputTokens: Int64 = 0
    public var modelOutputTokens: Int64 = 0
    public var modelCacheReadTokens: Int64 = 0
    public var modelCacheCreationTokens: Int64 = 0
    public var modelTotalTokens: Int64 = 0
    public var llmTurnCount: Int64 = 0
    public var usageSourcePath: String = ""

    public init() {}
}

public class CkbAbcdePreflightResult {
    public var ok: Bool = true
    public var checks: ArrayList<String> = ArrayList<String>()
    public var diagnostics: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func add(name: String, passed: Bool, diagnostic: String): Unit {
        this.checks.add("{\"name\":\"${ckbAbcdeJsonEscape(name)}\",\"ok\":${passed},\"diagnostic\":\"${ckbAbcdeJsonEscape(diagnostic)}\"}")
        if (!passed) {
            this.ok = false
            this.diagnostics.add("${name}: ${diagnostic}")
        }
    }
}

public class CkbAbcdeParityObservation {
    public var caseId: String = ""
    public var interfaceId: String = "cangjie_task_knowledge_pack"
    public var transport: String = ""
    public var ok: Bool = false
    public var evidenceHash: String = ""
    public var coveragePass: Bool = false
    public var citationCount: Int64 = 0
    public var diagnostic: String = ""
    public var payloadPath: String = ""

    public init() {}
}

public class CkbAbcdeParityReport {
    public var caseId: String = ""
    public var interfaceId: String = "cangjie_task_knowledge_pack"
    public var ok: Bool = false
    public var diagnostic: String = ""
    public var rest: CkbAbcdeParityObservation = CkbAbcdeParityObservation()
    public var stdio: CkbAbcdeParityObservation = CkbAbcdeParityObservation()
    public var http: CkbAbcdeParityObservation = CkbAbcdeParityObservation()

    public init() {}
}

public class CkbAbcdeTaskContext {
    public var taskId: String = ""
    public var benchmark: String = "Cangjie-HumanEval"
    public var taskText: String = ""
    public var signature: String = ""
    public var datasetVersion: String = ""
    public var promptHash: String = ""
    public var starterHash: String = ""
    public var targetVersion: String = "1.0.0"
    public var sourceSet: String = CangjieSourceSets.ALL
    public var versionPolicy: String = CangjieVersionPolicies.DEFAULT
    public var expectedKnowledgeTags: ArrayList<String> = ArrayList<String>()

    public init() {}
}

public func parseCkbAbcdeRunnerOptions(args: Array<String>): CkbAbcdeRunnerOptions {
    let options = CkbAbcdeRunnerOptions()
    var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-eval-abcde") {
            i += 1
            continue
        }
        if (arg == "--help" || arg == "-h") {
            options.help = true
            i += 1
            continue
        }
        if (arg == "--preflight-only") {
            options.preflightOnly = true
            i += 1
            continue
        }
        if (arg == "--skip-claude") {
            options.skipClaude = true
            i += 1
            continue
        }
        if (arg == "--run-mode" && i + 1 < args.size) { options.runMode = args[i + 1].trimAscii(); options.explicitRunMode = true; i += 2; continue }
        if (arg == "--dataset-version" && i + 1 < args.size) { options.datasetVersion = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--candidate-version" && i + 1 < args.size) { options.candidateVersion = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--knowledge-version" && i + 1 < args.size) { options.knowledgeVersion = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--model-fingerprint" && i + 1 < args.size) { options.modelFingerprint = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--certification-preflight" && i + 1 < args.size) { options.certificationPreflightPath = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--certification-run-manifest" && i + 1 < args.size) { options.certificationRunManifestPath = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--expected-model-version" && i + 1 < args.size) { options.expectedModelVersion = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--provider-identity-hash" && i + 1 < args.size) { options.providerIdentityHash = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--provider-identity-artifact" && i + 1 < args.size) { options.providerIdentityArtifactPath = args[i + 1].trimAscii(); i += 2; continue }
        if (arg == "--model-timeout-seconds" && i + 1 < args.size) { options.modelTimeoutSeconds = ckbAbcdeParseInt(args[i + 1], -1); i += 2; continue }
        if (arg == "--model-effort" && i + 1 < args.size) { options.modelEffort = args[i + 1].trimAscii(); options.modelEffortExplicit = true; i += 2; continue }
        if (arg == "--model-max-budget-usd" && i + 1 < args.size) { options.modelMaxBudgetUsd = args[i + 1].trimAscii(); options.modelMaxBudgetUsdExplicit = true; i += 2; continue }
        if (arg == "--run-id" && i + 1 < args.size) {
            options.runId = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--repo-root" && i + 1 < args.size) {
            options.repoRoot = args[i + 1].trimAscii()
            options.datasetRoot = "${options.repoRoot}/test/cangjie_eval/cases/Cangjie-HumanEval"
            options.manifestPath = "${options.repoRoot}/test/cangjie_eval/cangjie_humaneval_manifest.jsonl"
            options.ckbBin = "${options.repoRoot}/target/release/bin/main"
            options.ckbStore = "${options.repoRoot}/ckb-data"
            i += 2
            continue
        }
        if (arg == "--runs-root" && i + 1 < args.size) {
            options.runsRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--dataset-root" && i + 1 < args.size) {
            options.datasetRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--manifest" && i + 1 < args.size) {
            options.manifestPath = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--ckb-bin" && i + 1 < args.size) {
            options.ckbBin = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--ckb-store" && i + 1 < args.size) {
            options.ckbStore = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--ckb-http-base" && i + 1 < args.size) {
            options.ckbHttpBase = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--docs-root" && i + 1 < args.size) {
            options.docsRoot = args[i + 1].trimAscii()
            i += 2
            continue
        }
        if (arg == "--case-start" && i + 1 < args.size) {
            options.caseStart = ckbAbcdeParseInt(args[i + 1], options.caseStart)
            i += 2
            continue
        }
        if (arg == "--case-end" && i + 1 < args.size) {
            options.caseEnd = ckbAbcdeParseInt(args[i + 1], options.caseEnd)
            i += 2
            continue
        }
        if (arg == "--case-id" && i + 1 < args.size) {
            let parsed = ckbAbcdeParseCaseIndex(args[i + 1])
            options.caseStart = parsed
            options.caseEnd = parsed
            i += 2
            continue
        }
        if (arg == "--groups" && i + 1 < args.size) {
            options.groups = ckbAbcdeParseGroups(args[i + 1])
            i += 2
            continue
        }
        i += 1
    }
    options
}

public func runCangjieEvalAbcde(args: Array<String>): Int64 {
    let usage = ckbAbcdeStrictUsageDiagnostic(args)
    if (usage != "ok") { println("usage error: ${usage}"); return 2 }
    let options = parseCkbAbcdeRunnerOptions(args)
    if (options.help) {
        print(ckbAbcdeUsage())
        return 0
    }
    let developmentContract = ckbAbcdeDevelopmentOptionsDiagnostic(options)
    if (developmentContract != "") { println("usage error: ${developmentContract}"); return 2 }
    if (options.runId == "") {
        options.runId = "abcde-${ckbAbcdeGeneratedRunId()}"
    }
    let safetyDiagnostic = ckbAbcdeOptionsSafetyDiagnostic(options)
    if (safetyDiagnostic != "ok") {
        println("ABCDE safety check failed: ${safetyDiagnostic}")
        return 1
    }
    let runRoot = "${options.runsRoot}/${options.runId}"
    if (options.runMode == "certification") {
        let certificationDiagnostic = ckbAbcdeCertificationEntryDiagnostic(options, runRoot)
        if (certificationDiagnostic != "ok") {
            println("ABCDE certification start blocked: ${certificationDiagnostic}")
            return 1
        }
    }
    ckbAbcdeEnsureDir(runRoot)
    if (options.runMode == "certification") {
        // Preserve exact trusted inputs in the immutable run evidence. Do not
        // rerun the legacy development preflight or synthesize replacements.
        ckbAbcdeWriteText("${runRoot}/preflight.json", ckbAbcdeReadText(options.certificationPreflightPath))
        ckbAbcdeWriteText("${runRoot}/run-manifest.json", ckbAbcdeReadText(options.certificationRunManifestPath))
        ckbAbcdeWriteText("${runRoot}/provider-identity.json",ckbAbcdeReadText(options.providerIdentityArtifactPath))
        options.certificationPreflightPath="${runRoot}/preflight.json"
        options.certificationRunManifestPath="${runRoot}/run-manifest.json"
        options.providerIdentityArtifactPath="${runRoot}/provider-identity.json"
    } else {
        let preflight = ckbAbcdePreflight(options, runRoot)
        ckbAbcdeWriteText("${runRoot}/preflight.json", ckbAbcdeRenderPreflightJson(options, runRoot, preflight))
        ckbAbcdeWriteText("${runRoot}/preflight.md", ckbAbcdeRenderPreflightMarkdown(options, runRoot, preflight))
        if (!preflight.ok) {
            println("ABCDE preflight failed: ${runRoot}/preflight.md")
            return 1
        }
        if (options.preflightOnly) {
            println("ABCDE preflight ok: ${runRoot}")
            return 0
        }
    }

    ckbAbcdeWriteText("${runRoot}/case-usage-summary.csv", "caseId,usageParseOkGroupCount,caseTotalModelTokens,caseAverageModelTokensPerGroup,caseTotalLlmTurns,caseAverageLlmTurnsPerGroup,usageParseFailedGroups\n")
    var failed: Int64 = 0
    var caseIndex = options.caseStart
    while (caseIndex <= options.caseEnd) {
        let caseId = ckbAbcdeCaseId(caseIndex)
        let caseRoot = "${runRoot}/cases/${caseId}"
        ckbAbcdeEnsureDir(caseRoot)
        let summaries = ArrayList<String>()
        var previousGroup = ""
        for (group in options.groups) {
            let resultLine = ckbAbcdeRunCaseGroup(options, runRoot, caseId, group, previousGroup)
            summaries.add(resultLine)
            ckbAbcdeAppendText("${runRoot}/results.jsonl", "${resultLine}\n")
            if (resultLine.contains("\"status\":\"failed\"")) {
                failed += 1
            }
            previousGroup = group
        }
        ckbAbcdeWriteText("${caseRoot}/case-summary.json", ckbAbcdeRenderCaseSummary(options, runRoot, caseId, summaries))
        ckbAbcdeAppendText("${runRoot}/case-usage-summary.csv", ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId, summaries) + "\n")
        caseIndex += 1
    }
    if (options.explicitRunMode && options.runMode == "development" && options.caseStart == 0 && options.caseEnd == 163) {
        let aggregate = aggregateDevelopmentRun(options, runRoot)
        if (!aggregate.ok) { failed += 1 }
    }
    ckbAbcdeWriteSummary(runRoot)
    let pass1GateOk = ckbAbcdeWritePass1GateArtifactsIfFullRun(options, runRoot)
    println("ABCDE run complete: ${runRoot}")
    if (failed > 0 || !pass1GateOk) { 1 } else { 0 }
}

// Certification is an auditable one-shot operation.  Silently ignored or
// duplicated arguments would make the recorded lineage differ from operator
// intent, so validate the complete argv before applying defaults.
public func ckbAbcdeStrictUsageDiagnostic(args: Array<String>): String {
    let flags = HashSet<String>()
    let valued = HashSet<String>()
    for (name in ["--run-mode","--dataset-version","--candidate-version","--knowledge-version","--model-fingerprint","--certification-preflight","--certification-run-manifest","--expected-model-version","--provider-identity-hash","--provider-identity-artifact","--model-timeout-seconds","--model-effort","--model-max-budget-usd","--run-id","--repo-root","--runs-root","--dataset-root","--manifest","--ckb-bin","--ckb-store","--ckb-http-base","--docs-root","--case-start","--case-end","--case-id","--groups","--config","--store"]) { valued.add(name) }
    for (name in ["--help","-h","--preflight-only","--skip-claude"]) { flags.add(name) }
    let seen = HashSet<String>(); var commandSeen = false; var i: Int64 = 0
    while (i < args.size) {
        let arg = args[i]
        if (arg == "cangjie-eval-abcde" && !commandSeen) { commandSeen=true; i+=1; continue }
        if (flags.contains(arg)) {
            if (seen.contains(arg)) { return "duplicate_argument:${arg}" }; seen.add(arg); i+=1; continue
        }
        if (valued.contains(arg)) {
            if (seen.contains(arg)) { return "duplicate_argument:${arg}" }
            if (i+1>=args.size || args[i+1].startsWith("--")) { return "missing_argument_value:${arg}" }
            if (arg == "--model-timeout-seconds" && ckbAbcdeModelTimeoutDiagnostic(args[i+1]) != "ok") { return ckbAbcdeModelTimeoutDiagnostic(args[i+1]) }
            if (arg == "--model-effort" && ckbAbcdeModelEffortDiagnostic(args[i+1]) != "ok") { return ckbAbcdeModelEffortDiagnostic(args[i+1]) }
            if (arg == "--model-max-budget-usd" && ckbAbcdeModelMaxBudgetDiagnostic(args[i+1]) != "ok") { return ckbAbcdeModelMaxBudgetDiagnostic(args[i+1]) }
            seen.add(arg); i+=2; continue
        }
        return "unknown_argument:${arg}"
    }
    if (!commandSeen) { return "command_required" }
    "ok"
}

public func ckbAbcdeModelTimeoutDiagnostic(value: String): String {
    if (value == "" || value != value.trimAscii()) { return "invalid_argument_value:--model-timeout-seconds" }
    try {
        let parsed = Int64.parse(value)
        if (parsed <= 0 || parsed > 3600) { return "invalid_argument_value:--model-timeout-seconds" }
    } catch (_: Exception) { return "invalid_argument_value:--model-timeout-seconds" }
    "ok"
}

public func ckbAbcdeModelEffortDiagnostic(value: String): String {
    if (value == "" || value != value.trimAscii()) { return "invalid_argument_value:--model-effort" }
    if (!(["low", "medium", "high", "xhigh", "max"].contains(value))) { return "invalid_argument_value:--model-effort" }
    "ok"
}

public func ckbAbcdeModelMaxBudgetDiagnostic(value: String): String {
    if (value == "" || value != value.trimAscii()) { return "invalid_argument_value:--model-max-budget-usd" }
    let lowered = value.toAsciiLower()
    if (lowered.contains("nan") || lowered.contains("inf")) { return "invalid_argument_value:--model-max-budget-usd" }
    try { let parsed = Float64.parse(value); if (parsed <= 0.0 || parsed > 100.0) { return "invalid_argument_value:--model-max-budget-usd" } } catch (_: Exception) { return "invalid_argument_value:--model-max-budget-usd" }
    "ok"
}

public func runCangjieAbcdeParitySmoke(args: Array<String>): Int64 {
    let taskContextJson = ckbAbcdeSmokeTaskContextJson()
    let service = CkbCommandLoopService(CkbRuntimeConfig(), FileKnowledgeStore("target/abcde-parity-smoke-store"))
    let report = ckbAbcdeProbeInProcessTransportParity(service, "CJ-HUMANEVAL-000", taskContextJson)
    let restResponse = ckbAbcdeParityStructuredPayload(ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack", taskContextJson, []), "rest")
    let promptB = renderCkbAbcdePrompt(CkbAbcdeGroups.B, "CJ-HUMANEVAL-000", "Implement `src/solution.cj`.", taskContextJson + "\n---CKB_RESPONSE---\n" + restResponse)
    let promptC = renderCkbAbcdePrompt(CkbAbcdeGroups.C, "CJ-HUMANEVAL-000", "Implement `src/solution.cj`.", taskContextJson)
    let promptD = renderCkbAbcdePrompt(CkbAbcdeGroups.D, "CJ-HUMANEVAL-000", "Implement `src/solution.cj`.", taskContextJson)
    let stdioUse = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"mcp__ckb-cangjie__cangjie_task_knowledge_pack\"}]}}"
    let httpUse = "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"mcp__ckb-cangjie-http__cangjie_task_knowledge_pack\"}]}}"
    let canonicalOk = taskContextJson.contains("\"taskId\":\"CJ-HUMANEVAL-000\"") && taskContextJson.contains("\"targetVersion\":\"1.0.0\"")
    let bPromptOk = promptB.contains("Canonical CKB Task Context") && promptB.contains("CKB REST Context") && promptB.contains("\"versionResolution\"")
    let stdioPromptOk = promptC.contains("mcp__ckb-cangjie__cangjie_task_knowledge_pack")
    let httpPromptOk = promptD.contains("mcp__ckb-cangjie-http__cangjie_task_knowledge_pack")
    let toolEvidenceOk = ckbAbcdeToolEvidence(CkbAbcdeGroups.C, stdioUse) == "cangjie_task_knowledge_pack" &&
        ckbAbcdeToolEvidence(CkbAbcdeGroups.D, httpUse) == "cangjie_task_knowledge_pack"
    let ok = canonicalOk && bPromptOk && stdioPromptOk && httpPromptOk && toolEvidenceOk && report.ok
    println("abcde-parity-smoke ok=${ok}")
    println("canonicalTaskContext=${canonicalOk}")
    println("bRestTaskPackPrompt=${bPromptOk}")
    println("stdioTaskToolPrompt=${stdioPromptOk}")
    println("httpTaskToolPrompt=${httpPromptOk}")
    println("toolEvidenceOk=${toolEvidenceOk}")
    println("transportParity=${report.ok}")
    println(ckbAbcdeRenderParityJsonl(report))
    if (ok) { 0 } else { 1 }
}

public func renderCkbAbcdePrompt(group: String, caseId: String, modelTask: String, contextText: String): String {
    renderCkbAbcdePromptForMode(group, caseId, modelTask, contextText, "development")
}

public func renderCkbAbcdePromptForMode(group: String, caseId: String, modelTask: String, contextText: String, runMode: String): String {
    let taskContextJson = ckbAbcdePromptTaskContextJson(contextText)
    let restContextText = ckbAbcdePromptRestContext(contextText)
    var out = "# ${caseId} ${group}\n\n"
    out += "Run mode: ${if (runMode == "certification") { "certification" } else { "development" }}. This label changes retry and accounting policy only; it does not expose tests, previous attempts, or other case artifacts.\n\n"
    out += "You are completing one Cangjie HumanEval case. Modify only `src/solution.cj` in the current workspace. Keep the public function signature unchanged. The copied workspace root is your current directory; if the task text below mentions `starter/src/solution.cj`, still edit exactly `src/solution.cj`. Do not read hidden tests, reference solutions, unrelated repositories, or files outside the allowed paths. Use at most three knowledge or documentation lookup tool calls before editing; do not perform prolonged research. If documentation is inconclusive, implement directly from the starter signature, examples, and common Cangjie syntax. After editing, reply with a short completion note.\n\n"
    if (group == CkbAbcdeGroups.A) {
        out += "Knowledge policy for this run: No CKB baseline. Do not use CKB HTTP APIs, MCP tools, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.B) {
        out += "Knowledge policy for this run: use only the CKB REST context embedded below. Do not use MCP tools, local cangjie_docs, web search, or external source repositories.\n\n"
        out += "## CKB REST Context\n\n```json\n${restContextText}\n```\n\n"
    } else if (group == CkbAbcdeGroups.C) {
        out += "Knowledge policy for this run: use the configured stdio MCP server `ckb-cangjie`. Before reading or editing `src/solution.cj`, you must call `mcp__ckb-cangjie__cangjie_task_knowledge_pack` at least once with the canonical task context in this prompt. This run is invalid without that real tool call, even if the task looks trivial. Do not use CKB REST context, HTTP MCP, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.D) {
        out += "Knowledge policy for this run: use the configured Streamable HTTP MCP server `ckb-cangjie-http`. Before reading or editing `src/solution.cj`, you must call `mcp__ckb-cangjie-http__cangjie_task_knowledge_pack` at least once with the canonical task context in this prompt. This run is invalid without that real tool call, even if the task looks trivial. Do not use CKB REST context, stdio MCP, local cangjie_docs, web search, or external source repositories.\n\n"
    } else if (group == CkbAbcdeGroups.E) {
        out += "Knowledge policy for this run: 当前这个项目是仓颉语言开发的项目。You may use local official Cangjie docs under /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs when Cangjie syntax, standard library, stdx, or tool usage knowledge is needed. Start from /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs/dev-guide/summary_cjnative_EN.md and /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs/tools/summary_cjnative_EN.md when they are useful, and prefer targeted read-only Bash rg queries or focused Read calls over loading large documents. You may use Bash only for read-only inspection inside the current temporary workspace or read-only documentation queries under /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs. For documentation Bash queries, prefer absolute paths such as `rg \"ArrayList\" /Users/l3gi0n/work/workspace_cangjie/cangjie_docs-release-1.0/docs`; do not rely on `cd` followed by later relative documentation queries. Do not use CKB REST APIs, MCP tools, web search, network commands, shell commands that write/delete/move files, or external source repositories.\n\n"
    }
    if (group == CkbAbcdeGroups.B || group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        out += "## Canonical CKB Task Context\n\n"
        out += "Use this exact JSON as the task context for CKB REST or MCP `cangjie_task_knowledge_pack`.\n\n"
        out += "```json\n${taskContextJson}\n```\n\n"
    }
    out += "## Task\n\n"
    out += modelTask
    if (!modelTask.endsWith("\n")) {
        out += "\n"
    }
    out
}

private func ckbAbcdePromptTaskContextJson(contextText: String): String {
    let marker = "\n---CKB_RESPONSE---\n"
    let parts = contextText.split(marker)
    if (parts.size > 0) { parts[0] } else { contextText }
}

private func ckbAbcdePromptRestContext(contextText: String): String {
    let marker = "\n---CKB_RESPONSE---\n"
    let parts = contextText.split(marker)
    if (parts.size > 1) { parts[1] } else { contextText }
}

public func renderCkbAbcdeMcpConfig(group: String, ckbBin: String, ckbStore: String, ckbHttpBase: String): String {
    if (group == CkbAbcdeGroups.C) {
        let stdioScript = ckbAbcdeNativeTlsBootstrapScript(ckbBin, ["--store", ckbStore, "mcp-stdio"])
        return "{\n  \"mcpServers\": {\n    \"ckb-cangjie\": {\n      \"command\": \"/bin/zsh\",\n      \"args\": [\"-lc\", \"${ckbAbcdeJsonEscape(stdioScript)}\"]\n    }\n  }\n}\n"
    }
    if (group == CkbAbcdeGroups.D) {
        return "{\n  \"mcpServers\": {\n    \"ckb-cangjie-http\": {\n      \"type\": \"http\",\n      \"url\": \"${ckbAbcdeJsonEscape(ckbHttpBase)}/mcp\"\n    }\n  }\n}\n"
    }
    "{\n  \"mcpServers\": {}\n}\n"
}

public func ckbAbcdeJsonEscape(value: String): String {
    let out = StringBuilder()
    for (ch in value.toRuneArray()) {
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

public func ckbAbcdeBuildTaskContext(caseRoot: String, caseId: String): CkbAbcdeTaskContext {
    ckbAbcdeBuildTaskContext(caseRoot, caseId, "")
}

public func ckbAbcdeBuildTaskContext(caseRoot: String, caseId: String, manifestText: String): CkbAbcdeTaskContext {
    let context = CkbAbcdeTaskContext()
    context.taskId = caseId
    context.taskText = ckbAbcdeReadText("${caseRoot}/prompt.md")
    let starter = ckbAbcdeReadText("${caseRoot}/starter/src/solution.cj")
    context.signature = ckbAbcdeExtractCangjieSignature(starter)
    for (tag in ckbAbcdeInferKnowledgeTags("${context.taskText}\n${starter}")) {
        context.expectedKnowledgeTags.add(tag)
    }
    if (manifestText.contains("cangjie-humaneval-authority-v1")) {
        match (cangjieHumanEvalAuthorityRowForCase(manifestText, caseId)) {
            case Some(row) =>
                context.signature = row.signature
                context.targetVersion = row.targetVersion
                context.datasetVersion = row.datasetVersion
                context.promptHash = row.promptHash
                context.starterHash = row.starterHash
            case None => ()
        }
    }
    context
}

public func ckbAbcdeRenderTaskContextJson(context: CkbAbcdeTaskContext): String {
    "{\"taskId\":\"${ckbAbcdeJsonEscape(context.taskId)}\",\"benchmark\":\"${ckbAbcdeJsonEscape(context.benchmark)}\",\"taskText\":\"${ckbAbcdeJsonEscape(context.taskText)}\",\"signature\":\"${ckbAbcdeJsonEscape(context.signature)}\",\"datasetVersion\":\"${ckbAbcdeJsonEscape(context.datasetVersion)}\",\"promptHash\":\"${ckbAbcdeJsonEscape(context.promptHash)}\",\"starterHash\":\"${ckbAbcdeJsonEscape(context.starterHash)}\",\"expectedKnowledgeTags\":${ckbAbcdeStringArrayJson(context.expectedKnowledgeTags)},\"targetVersion\":\"${ckbAbcdeJsonEscape(context.targetVersion)}\",\"sourceSet\":\"${ckbAbcdeJsonEscape(context.sourceSet)}\",\"versionPolicy\":\"${ckbAbcdeJsonEscape(context.versionPolicy)}\",\"budget\":10,\"responseMode\":\"evidence\"}"
}

private func ckbAbcdeExtractCangjieSignature(source: String): String {
    for (line in source.split("\n")) {
        let trimmed = line.trimAscii()
        if (trimmed.startsWith("func ")) {
            let parts = trimmed.split("{")
            if (parts.size > 0) { return parts[0].trimAscii() }
            return trimmed
        }
    }
    ""
}

private func ckbAbcdeInferKnowledgeTags(text: String): ArrayList<String> {
    let tags = ArrayList<String>()
    let lower = text.toAsciiLower()
    ckbAbcdeAddTagIf(tags, lower.contains("arraylist") || lower.contains("array<"), "ArrayList")
    ckbAbcdeAddTagIf(tags, lower.contains("string") || lower.contains("rune"), "String")
    ckbAbcdeAddTagIf(tags, lower.contains("hashmap") || lower.contains("map"), "HashMap")
    ckbAbcdeAddTagIf(tags, lower.contains("hashset") || lower.contains("set"), "HashSet")
    ckbAbcdeAddTagIf(tags, lower.contains("sort"), "sort")
    ckbAbcdeAddTagIf(tags, lower.contains("int64") || lower.contains("float"), "numeric")
    ckbAbcdeAddTagIf(tags, lower.contains("option") || lower.contains("none") || lower.contains("some"), "Option")
    if (tags.size == 0) {
        tags.add("Cangjie syntax")
    }
    tags
}

private func ckbAbcdeAddTagIf(tags: ArrayList<String>, condition: Bool, tag: String): Unit {
    if (condition && !tags.contains(tag)) {
        tags.add(tag)
    }
}

private func ckbAbcdeStringArrayJson(values: ArrayList<String>): String {
    var out = "["
    for (i in 0..values.size) {
        if (i > 0) {
            out += ","
        }
        out += "\"${ckbAbcdeJsonEscape(values[i])}\""
    }
    out + "]"
}

private func ckbAbcdeSmokeTaskContextJson(): String {
    let context = CkbAbcdeTaskContext()
    context.taskId = "CJ-HUMANEVAL-000"
    context.taskText = "Implement a Cangjie ArrayList helper."
    context.signature = "func solution(values: Array<Int64>): Int64"
    context.expectedKnowledgeTags.add("ArrayList")
    context.expectedKnowledgeTags.add("Cangjie syntax")
    ckbAbcdeRenderTaskContextJson(context)
}

public func ckbAbcdeSmokeTaskContextJsonForTest(): String {
    ckbAbcdeSmokeTaskContextJson()
}

private func ckbAbcdeRunCaseGroup(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, group: String, previousGroup: String): String {
    let caseSrc = "${options.datasetRoot}/${caseId}"
    let groupRoot = "${runRoot}/cases/${caseId}/${group}"
    let workspace = "${groupRoot}/workspace"
    let taskContext = ckbAbcdeBuildTaskContext(caseSrc, caseId, ckbAbcdeReadText(options.manifestPath))
    let taskContextJson = ckbAbcdeRenderTaskContextJson(taskContext)
    ckbAbcdeEnsureDir(groupRoot)
    ckbAbcdeWriteText("${groupRoot}/canonical-task-context.json", taskContextJson + "\n")
    ckbAbcdeWriteText("${groupRoot}/switch-gate.json", "{\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"status\":\"entered\"}\n")
    ckbAbcdeAppendText("${runRoot}/cases/${caseId}/env-switch-checks.jsonl", ckbAbcdeRenderEnvSwitchCheck(caseId, previousGroup, group, workspace, groupRoot) + "\n")

    let copy = ckbAbcdeRunShell("rm -rf ${ckbAbcdeShellQuote(workspace)} && cp -R ${ckbAbcdeShellQuote("${caseSrc}/starter")} ${ckbAbcdeShellQuote(workspace)}", "")
    ckbAbcdeWriteText("${groupRoot}/workspace-copy.stdout.log", copy.stdout)
    ckbAbcdeWriteText("${groupRoot}/workspace-copy.stderr.log", copy.stderr)
    ckbAbcdeEnsureDir("${groupRoot}/session")
    ckbAbcdeEnsureDir("${groupRoot}/runtime-home")
    let entryWorkspaceId = "cases/${caseId}/${group}/workspace"
    let entrySessionId = "cases/${caseId}/${group}/session"
    let entryRuntimeHomeId = "cases/${caseId}/${group}/runtime-home"
    let entryIsolationDiagnostic = ckbAbcdeIsolationDiagnostic(caseId, entryWorkspaceId, entrySessionId, entryRuntimeHomeId, "", "", "", "")
    ckbAbcdeWriteText("${groupRoot}/isolation.json", "{\"workspaceId\":\"${ckbAbcdeJsonEscape(entryWorkspaceId)}\",\"sessionId\":\"${ckbAbcdeJsonEscape(entrySessionId)}\",\"runtimeHomeId\":\"${ckbAbcdeJsonEscape(entryRuntimeHomeId)}\",\"diagnostic\":\"${entryIsolationDiagnostic}\"}\n")

    var contextText = ""
    var knowledgeReady = true
    if (group == CkbAbcdeGroups.B) {
        let body = taskContextJson
        ckbAbcdeWriteText("${groupRoot}/ckb-rest-request.json", body)
        let rest = ckbAbcdeRunShell("curl ${ckbAbcdeCurlRetryFlags()} --max-time 20 -fsS -X POST -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/ckb-rest-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/cangjie/task-knowledge-pack")}", "")
        contextText = rest.stdout
        knowledgeReady = rest.exitCode == 0 && rest.stdout.contains("\"ok\":true")
        ckbAbcdeWriteText("${groupRoot}/ckb-rest-response.json", rest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-task-knowledge-pack.json", rest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-knowledge-pack.json", rest.stdout)
        ckbAbcdeWriteText("${groupRoot}/ckb-rest.stderr.log", rest.stderr)
        contextText = taskContextJson + "\n---CKB_RESPONSE---\n" + rest.stdout
    } else if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        contextText = taskContextJson
    }

    if (group == CkbAbcdeGroups.C) {
        ckbAbcdeRunMcpStdioSmoke(options, groupRoot, taskContextJson: taskContextJson)
    }
    if (group == CkbAbcdeGroups.D) {
        ckbAbcdeRunMcpHttpSmoke(options, groupRoot, taskContextJson: taskContextJson)
    }

    let mcpConfig = renderCkbAbcdeMcpConfig(group, options.ckbBin, options.ckbStore, options.ckbHttpBase)
    ckbAbcdeWriteText("${groupRoot}/mcp-config.json", mcpConfig)
    if (group != CkbAbcdeGroups.C && group != CkbAbcdeGroups.D) {
        ckbAbcdeWriteText("${groupRoot}/empty-mcp.json", mcpConfig)
    } else if (group == CkbAbcdeGroups.C) {
        ckbAbcdeWriteText("${groupRoot}/ckb-mcp-stdio.json", mcpConfig)
    } else if (group == CkbAbcdeGroups.D) {
        ckbAbcdeWriteText("${groupRoot}/ckb-mcp-http.json", mcpConfig)
    }

    let prompt = renderCkbAbcdePromptForMode(group, caseId, ckbAbcdeReadText("${caseSrc}/prompt.md"), contextText, options.runMode)
    ckbAbcdeWriteText("${groupRoot}/prompt.final.md", prompt)

    var claudeExit: Int64 = 0
    if (options.skipClaude) {
        ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl", "{\"event\":\"skipped\",\"reason\":\"skip-claude\"}\n")
        ckbAbcdeWriteText("${groupRoot}/claude.stdout.log", "")
        ckbAbcdeWriteText("${groupRoot}/claude.stderr.log", "")
    } else {
        let claude = if (options.runMode == "certification") { ckbAbcdeRunClaudeCertification(options, group, groupRoot, workspace, "${groupRoot}/runtime-home", caseSrc) } else { ckbAbcdeRunClaude(options, group, groupRoot, workspace, options.docsRoot, "${caseSrc}/starter") }
        claudeExit = claude.exitCode
    }
    let usage = ckbAbcdeParseClaudeUsageFile("${groupRoot}/claude-transcript.jsonl")
    ckbAbcdeWriteText("${groupRoot}/usage.json", ckbAbcdeRenderUsageJson(usage) + "\n")
    ckbAbcdeWriteText("${groupRoot}/attempt-evidence.json", "{\"transportAttemptCount\":${ckbAbcdeClaudeAttemptCount(groupRoot)},\"sampleAttemptCount\":${ckbAbcdeSampleAttemptCount(groupRoot)},\"workspaceRestoreEvidenceHash\":\"${ckbAbcdeJsonEscape(ckbAbcdeWorkspaceRestoreEvidenceHash(groupRoot))}\",\"attemptsPath\":\"claude-attempts.jsonl\",\"restoresPath\":\"workspace-restores.jsonl\"}\n")

    // The answer is immutable before verifier-owned material enters the workspace.
    let frozenAnswer=ckbAbcdeReadText("${workspace}/src/solution.cj")
    let frozenAnswerHash=benchmarkGapSha256(frozenAnswer)
    ckbAbcdeWriteText("${groupRoot}/answer-freeze.json","{\"answerHash\":\"${frozenAnswerHash}\",\"verifierMounted\":false}\n")
    let inject = ckbAbcdeRunShell("cp ${ckbAbcdeShellQuote("${caseSrc}/tests/TestMain.cj")} ${ckbAbcdeShellQuote("${workspace}/src/main.cj")} && cp ${ckbAbcdeShellQuote("${caseSrc}/tests/cjpm.executable.toml")} ${ckbAbcdeShellQuote("${workspace}/cjpm.toml")}", "")
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.stdout.log", inject.stdout)
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.stderr.log", inject.stderr)
    ckbAbcdeWriteText("${groupRoot}/hidden-test-inject.log", inject.stdout + inject.stderr)
    ckbAbcdeWriteText("${groupRoot}/verifier-mount.json","{\"injectExitCode\":${inject.exitCode},\"answerHashBefore\":\"${frozenAnswerHash}\",\"answerHashAfter\":\"${benchmarkGapSha256(ckbAbcdeReadText("${workspace}/src/solution.cj"))}\",\"mountedAfterFreeze\":${inject.exitCode==0}}\n")
    let test = ckbAbcdeRunShell("cjpm run", workspace)
    let testLog = test.stdout + test.stderr
    ckbAbcdeWriteText("${groupRoot}/test.log", testLog)

    let transcript = ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl") + ckbAbcdeReadText("${groupRoot}/claude.stdout.log") + ckbAbcdeReadText("${groupRoot}/claude.stderr.log")
    let toolEvidence = ckbAbcdeToolEvidence(group, transcript)
    let violation = ckbAbcdeForbiddenEvidence(group, transcript)
    let unitPass = test.exitCode == 0 && !ckbAbcdeTestLogContainsFailure(testLog)
    let unitPassAt1 = ckbAbcdeUnitPassAt1(unitPass, groupRoot)
    let toolReady = ckbAbcdeRequiredKnowledgeReady(group, knowledgeReady, toolEvidence)
    let legacyFailureType = ckbAbcdeFailureType(claudeExit, test.exitCode, unitPass, violation, testLog, toolReady)
    let failureType = if (options.explicitRunMode) { ckbAbcdeExpandedFailureType(legacyFailureType) } else { legacyFailureType }
    let protocolViolation = violation != "none"
    let observedModel = ckbAbcdeObservedModel(transcript)
    let sampleReady = !options.explicitRunMode || options.runMode != "development" || ckbAbcdeSampleAttemptCount(groupRoot) == 1
    let modelReady = (!options.explicitRunMode || observedModel == options.expectedModelVersion) && sampleReady
    if (options.explicitRunMode) {
        ckbAbcdeWriteText("${groupRoot}/provider-identity.json", ckbAbcdeProviderIdentityJson(observedModel, ckbAbcdeClaudeVersion()))
    }
    let status = if (copy.exitCode == 0 && inject.exitCode == 0 && claudeExit == 0 && unitPass && violation == "none" && toolReady && modelReady) { "passed" } else { "failed" }
    ckbAbcdeWriteText("${groupRoot}/test-result.json", "{\"testExitCode\":${test.exitCode},\"unitPassAt1\":${unitPassAt1},\"transportAttemptCount\":${ckbAbcdeClaudeAttemptCount(groupRoot)},\"sampleAttemptCount\":${ckbAbcdeSampleAttemptCount(groupRoot)},\"workspaceRestoreEvidenceHash\":\"${ckbAbcdeJsonEscape(ckbAbcdeWorkspaceRestoreEvidenceHash(groupRoot))}\",\"failureType\":\"${failureType}\",\"testLogPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/test.log")}\"}\n")
    ckbAbcdeWriteText("${groupRoot}/protocol-audit.json", "{\"protocolViolation\":${protocolViolation},\"protocolViolationReason\":\"${ckbAbcdeJsonEscape(violation)}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(group)}\",\"toolTransport\":\"${ckbAbcdeToolTransport(group)}\",\"toolEvidence\":\"${ckbAbcdeJsonEscape(toolEvidence)}\"}\n")
    if (group == CkbAbcdeGroups.E) {
        ckbAbcdeWriteText("${groupRoot}/docs-path-audit.json", "{\"docsRoot\":\"${ckbAbcdeJsonEscape(options.docsRoot)}\",\"summaryFiles\":[\"${ckbAbcdeJsonEscape("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")}\",\"${ckbAbcdeJsonEscape("${options.docsRoot}/tools/summary_cjnative_EN.md")}\"],\"allowed\":${exists(Path("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")) && exists(Path("${options.docsRoot}/tools/summary_cjnative_EN.md"))}}\n")
    }
    var result = if(options.runMode=="certification"){ckbAbcdeRenderStrictCertificationCase(options,caseId,group,groupRoot,frozenAnswerHash,transcript,testLog,unitPassAt1,violation,toolReady)}else{ckbAbcdeRenderCaseResult(options, runRoot, caseId, group, status, claudeExit, test.exitCode, unitPass, unitPassAt1, failureType, toolEvidence, violation, groupRoot)}
    if (options.explicitRunMode && options.runMode == "development") {
        let attemptCount = ckbAbcdeClaudeAttemptCount(groupRoot)
        let resultEvidence = ckbAbcdeTriageEvidence(options, caseId, if (attemptCount > 0) { attemptCount } else { 1 }, failureType, unitPass, protocolViolation, claudeExit, test.exitCode, groupRoot)
        ckbAbcdeWriteText("${groupRoot}/result-evidence.json", resultEvidence + "\n")
        let closureInput = CangjieEvalDevelopmentClosureInput()
        closureInput.caseResultJson = result; closureInput.resultEvidenceJson = resultEvidence; closureInput.taskText = taskContext.taskText
        closureInput.firstClassifierJson = ckbAbcdeReadText("${groupRoot}/classifier-1.json")
        closureInput.secondClassifierJson = ckbAbcdeReadText("${groupRoot}/classifier-2.json")
        let closureInputs = ArrayList<CangjieEvalDevelopmentClosureInput>(); closureInputs.add(closureInput)
        let closure = orchestrateDevelopmentClosure(closureInputs, options.runId)
        ckbAbcdeWriteText("${groupRoot}/development-closure.json", closure.developmentClosureJson + "\n")
        ckbAbcdeWriteText("${groupRoot}/authoritative-gap.jsonl", closure.authoritativeGapJsonl)
        if (closure.knowledgeGapCount == 1) { result = result.replace("\"knowledgeGapConfirmationStatus\":\"pending_classifier_artifacts\"", "\"knowledgeGapConfirmationStatus\":\"confirmed\"") }
    }
    ckbAbcdeWriteText("${groupRoot}/case-result.json", result + "\n")
    ckbAbcdeWriteText("${groupRoot}/audit.json", "{\"toolEvidence\":\"${toolEvidence}\",\"violation\":\"${violation}\"}\n")
    result
}

private func ckbAbcdeRenderStrictCertificationCase(options:CkbAbcdeRunnerOptions,caseId:String,group:String,groupRoot:String,answerHash:String,transcript:String,testLog:String,unitPassAt1:Bool,violation:String,toolReady:Bool):String{
    let row=CkbCertificationCaseEvidence();row.runId=options.runId;row.caseId=caseId;row.group=group;row.datasetVersion=options.datasetVersion;row.knowledgeVersion=options.knowledgeVersion;row.modelFingerprint=options.modelFingerprint;row.expectedModelVersion=options.expectedModelVersion;row.observedModelVersion=ckbAbcdeObservedModel(transcript);row.claudeCodeVersion=ckbAbcdeClaudeVersion();row.providerIdentityHash=options.providerIdentityHash
    let preflight=ckbAbcdeReadText(options.certificationPreflightPath);let manifestText=ckbAbcdeReadText(options.certificationRunManifestPath);row.preflightHash=benchmarkGapSha256(preflight)
    try{let manifest=JsonValue.fromStr(manifestText).asObject();row.runManifestHash=ckbAbcdeStrictJsonString(manifest,"runManifestHash")}catch(_:Exception){}
    let authority=parseCangjieHumanEvalAuthorityManifest(ckbAbcdeReadText(options.manifestPath));for(a in authority.rows){if(a.caseId==caseId){row.authorityCaseHash=a.caseHash;row.authorityTestsHash=a.testsHash}}
    let workspace="${groupRoot}/workspace";let runtimeHome="${groupRoot}/runtime-home";row.workspaceId=benchmarkGapSha256(try{canonicalize(Path(workspace)).toString()}catch(_:Exception){workspace});row.sessionId=benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/session-id.txt"));row.runtimeHomeId=benchmarkGapSha256(try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){runtimeHome})
    let probe=ckbAbcdeReadText("${groupRoot}/sandbox-probe.json");row.isolationEvidenceHash=benchmarkGapSha256(probe);row.answerHash=answerHash;row.transcriptHash=benchmarkGapSha256(transcript);row.testHash=benchmarkGapSha256(testLog);row.configHash=benchmarkGapSha256(ckbAbcdeReadText("${groupRoot}/mcp-config.json")+ckbAbcdeReadText("${groupRoot}/runtime-policy.json")+ckbAbcdeReadText(options.providerIdentityArtifactPath));row.artifactHash=benchmarkGapSha256(row.answerHash+row.transcriptHash+row.testHash+row.configHash)
    let lowered=transcript.toAsciiLower();row.referenceExposure=if(violation.contains("reference")||lowered.contains("/reference")){1}else{0};row.hiddenTestExposure=if(violation.contains("test")||lowered.contains("/tests/")||lowered.contains("testmain.cj")){1}else{0};row.teacherExposure=if(violation.contains("teacher")||lowered.contains("cangjieteacher")||lowered.contains("teacher-solutions")){1}else{0};row.crossCaseExposure=if(violation.contains("cross_case")||ckbAbcdeTranscriptHasOtherCase(transcript,caseId)){1}else{0}
    let attempts=ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl");let attemptCount=ckbAbcdeClaudeAttemptCount(groupRoot);row.agentRetryCount=if(attemptCount>1){attemptCount-1}else{0};row.retryUsed=attemptCount!=1||attempts.contains("\"retryUsed\":true");row.fallbackUsed=attempts.contains("\"fallbackUsed\":true")||lowered.contains("fallback_model");row.providerRetryCount=ckbAbcdeCountOccurrences(transcript,"provider_retry");row.sdkRetryCount=ckbAbcdeCountOccurrences(transcript,"sdk_retry");row.llmTurnCount=ckbAbcdeParseClaudeUsageFromText(transcript,"transcript").llmTurnCount
    row.sandboxDeniedOutsideWorkspace=ckbAbcdeStrictSandboxProbeOk(probe,workspace,runtimeHome);row.verifierMountedAfterAnswerFreeze=ckbAbcdeStrictVerifierMountOk(ckbAbcdeReadText("${groupRoot}/verifier-mount.json"),answerHash);row.certificationPassAt1=unitPassAt1&&toolReady&&violation=="none"&&row.observedModelVersion==row.expectedModelVersion&&!row.retryUsed&&!row.fallbackUsed&&row.providerRetryCount==0&&row.sdkRetryCount==0&&row.sandboxDeniedOutsideWorkspace&&row.verifierMountedAfterAnswerFreeze&&row.referenceExposure==0&&row.hiddenTestExposure==0&&row.teacherExposure==0&&row.crossCaseExposure==0&&ckbAbcdeParseClaudeUsageFromText(transcript,"transcript").llmTurnCount==1
    sealCkbCertificationEvidence(row);renderCkbCertificationEvidenceJson(row)
}
public func ckbAbcdeRenderStrictCertificationCaseForTest(options:CkbAbcdeRunnerOptions,caseId:String,group:String,groupRoot:String,answerHash:String,transcript:String,testLog:String,unitPassAt1:Bool,violation:String,toolReady:Bool):String{ckbAbcdeRenderStrictCertificationCase(options,caseId,group,groupRoot,answerHash,transcript,testLog,unitPassAt1,violation,toolReady)}

private func ckbAbcdeObservedModel(transcript:String):String{for(line in transcript.split("\n")){try{let o=JsonValue.fromStr(line).asObject();if(ckbAbcdeStrictJsonString(o,"subtype")=="init"){return ckbAbcdeStrictJsonString(o,"model")}}catch(_:Exception){}};""}

private func ckbAbcdeStrictSandboxProbeOk(raw:String,workspace:String,runtimeHome:String):Bool{try{let o=JsonValue.fromStr(raw).asObject();ckbAbcdeStrictJsonBool(o,"ok")&&ckbAbcdeStrictJsonBool(o,"deniedOutsideWorkspace")&&ckbAbcdeStrictJsonBool(o,"deniedTests")&&ckbAbcdeStrictJsonBool(o,"deniedReference")&&ckbAbcdeStrictJsonBool(o,"deniedTeacher")&&ckbAbcdeStrictJsonString(o,"workspaceCanonical")==canonicalize(Path(workspace)).toString()&&ckbAbcdeStrictJsonString(o,"runtimeHomeCanonical")==canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){false}}
private func ckbAbcdeStrictVerifierMountOk(raw:String,answerHash:String):Bool{try{let o=JsonValue.fromStr(raw).asObject();ckbAbcdeStrictJsonInt(o,"injectExitCode",-1)==0&&ckbAbcdeStrictJsonString(o,"answerHashBefore")==answerHash&&ckbAbcdeStrictJsonString(o,"answerHashAfter")==answerHash&&ckbAbcdeStrictJsonBool(o,"mountedAfterFreeze")}catch(_:Exception){false}}
private func ckbAbcdeTranscriptHasOtherCase(raw:String,current:String):Bool{for(i in 0..164){let id=ckbAbcdeCaseId(i);if(id!=current&&raw.contains(id)){return true}};false}

private func ckbAbcdeRunClaude(options: CkbAbcdeRunnerOptions, group: String, groupRoot: String, workspace: String, docsRoot: String, authoritativeWorkspace: String): CkbAbcdeCommandResult {
    var last = CkbAbcdeCommandResult()
    var sampleAttempt: Int64 = 0
    for (transportAttempt in 1..=2) {
        var restoreJson = "{\"transportAttempt\":${transportAttempt},\"restored\":false,\"diagnostic\":\"initial_authoritative_copy\"}"
        if (transportAttempt > 1) {
            restoreJson = ckbAbcdeRestoreWorkspaceForRetry(workspace, authoritativeWorkspace, transportAttempt)
            ckbAbcdeAppendText("${groupRoot}/workspace-restores.jsonl", restoreJson + "\n")
            if (!restoreJson.contains("\"restored\":true")) {
                let blocked = CkbAbcdeCommandResult(); blocked.exitCode = 125; blocked.stderr = "workspace_restore_failed"; return blocked
            }
        }
        let current = ckbAbcdeRunClaudeOnce(group, groupRoot, workspace, docsRoot, transportAttempt, options.expectedModelVersion, options.modelTimeoutSeconds, options.modelEffort, options.modelMaxBudgetUsd)
        last = current
        let transcript = ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-${transportAttempt}.jsonl")
        let assessment = ckbAbcdeAssessSample(transcript, options.expectedModelVersion)
        ckbAbcdeWriteText("${groupRoot}/model-transport-diagnostic.attempt-${transportAttempt}.json", ckbAbcdeRenderModelTransportDiagnostic(transcript, current.exitCode, assessment, options.modelTimeoutSeconds, options.modelEffort, options.modelMaxBudgetUsd) + "\n")
        if (current.exitCode == 0 && assessment.completeResult && assessment.identityMatched) { sampleAttempt += 1 }
        let restoreHash = if (transportAttempt > 1) { benchmarkGapSha256(restoreJson) } else { "" }
        ckbAbcdeAppendText("${groupRoot}/claude-attempts.jsonl", "{\"attempt\":${transportAttempt},\"transportAttempt\":${transportAttempt},\"sampleAttempt\":${if (current.exitCode == 0 && assessment.completeResult && assessment.identityMatched) { sampleAttempt } else { 0 }},\"exitCode\":${current.exitCode},\"completeResult\":${assessment.completeResult},\"identityMatched\":${assessment.identityMatched},\"workspaceRestored\":${transportAttempt > 1 && restoreJson.contains("\"restored\":true")},\"restoreEvidenceHash\":\"${restoreHash}\"}\n")
        if (current.exitCode == 0 && assessment.completeResult && assessment.identityMatched) {
            ckbAbcdePublishClaudeSampleArtifacts(groupRoot, transportAttempt)
            return current
        }
    }
    ckbAbcdePublishClaudeAttemptArtifacts(groupRoot, 2)
    last
}

public func ckbAbcdeAssessSample(transcript: String, expectedModel: String): CkbAbcdeSampleAssessment {
    let result = CkbAbcdeSampleAssessment()
    var observedModel = ""
    for (line in transcript.split("\n")) {
        try {
            let object = JsonValue.fromStr(line).asObject()
            if (ckbAbcdeStrictJsonString(object, "subtype") == "init") { observedModel = ckbAbcdeStrictJsonString(object, "model") }
            if (ckbAbcdeStrictJsonString(object, "type") == "result" && ckbAbcdeStrictJsonString(object, "subtype") == "success" && !ckbAbcdeStrictJsonBool(object, "is_error")) { result.completeResult = true }
        } catch (_: Exception) {}
    }
    result.identityMatched = result.completeResult && observedModel == expectedModel
    result.sampleAttempt = if (result.identityMatched) { 1 } else { 0 }
    result
}

public func ckbAbcdeRenderModelTransportDiagnostic(transcript: String, exitCode: Int64, assessment: CkbAbcdeSampleAssessment, timeoutSeconds: Int64, effort: String, maxBudgetUsd: String): String {
    let toolUses = ckbAbcdeCountOccurrences(transcript, "\"type\":\"tool_use\"")
    let toolResults = ckbAbcdeCountOccurrences(transcript, "\"type\":\"tool_result\"")
    let thinkingEvents = ckbAbcdeCountOccurrences(transcript, "\"subtype\":\"thinking_tokens\"")
    let reason = if (exitCode == 124 && !assessment.completeResult) { "provider_no_terminal_result_timeout" } else if (!assessment.completeResult) { "missing_terminal_result" } else if (!assessment.identityMatched) { "model_identity_mismatch" } else { "ok" }
    "{\"exitCode\":${exitCode},\"timeoutSeconds\":${timeoutSeconds},\"effort\":\"${ckbAbcdeJsonEscape(effort)}\",\"maxBudgetUsd\":\"${ckbAbcdeJsonEscape(maxBudgetUsd)}\",\"completeResult\":${assessment.completeResult},\"identityMatched\":${assessment.identityMatched},\"sampleEligible\":${assessment.sampleAttempt == 1},\"toolUseCount\":${toolUses},\"toolResultCount\":${toolResults},\"thinkingEventCount\":${thinkingEvents},\"terminalDiagnostic\":\"${reason}\"}"
}

public func ckbAbcdeShouldRetryTransport(exitCode: Int64, assessment: CkbAbcdeSampleAssessment): Bool {
    exitCode != 0 || !assessment.completeResult || !assessment.identityMatched
}

public func ckbAbcdeRestoreWorkspaceForRetry(workspace: String, authoritativeWorkspace: String, transportAttempt: Int64): String {
    let beforeHash = benchmarkGapSha256(ckbAbcdeReadText("${workspace}/src/solution.cj"))
    let authorityHash = benchmarkGapSha256(ckbAbcdeReadText("${authoritativeWorkspace}/src/solution.cj"))
    let restored = ckbAbcdeRunShell("rm -rf ${ckbAbcdeShellQuote(workspace)} && cp -R ${ckbAbcdeShellQuote(authoritativeWorkspace)} ${ckbAbcdeShellQuote(workspace)}", "")
    let afterHash = benchmarkGapSha256(ckbAbcdeReadText("${workspace}/src/solution.cj"))
    let ok = restored.exitCode == 0 && afterHash == authorityHash
    let base = "{\"transportAttempt\":${transportAttempt},\"restored\":${ok},\"beforeHash\":\"${beforeHash}\",\"authorityHash\":\"${authorityHash}\",\"afterHash\":\"${afterHash}\",\"diagnostic\":\"${if (ok) { "ok" } else { "workspace_restore_failed" }}\"}"
    base.replace("}", ",\"evidenceHash\":\"${benchmarkGapSha256(base)}\"}")
}

private func ckbAbcdePublishClaudeSampleArtifacts(groupRoot: String, transportAttempt: Int64): Unit {
    let transcript = ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-${transportAttempt}.jsonl")
    let stderr = ckbAbcdeReadText("${groupRoot}/claude.attempt-${transportAttempt}.stderr.log")
    ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stdout.log", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stderr.log", stderr)
}

// Certification has exactly one agent invocation. Provider/SDK retry and
// fallback are separately prohibited by the trusted P6 manifest and P7 gate.
private func ckbAbcdeRunClaudeCertification(options:CkbAbcdeRunnerOptions,group:String,groupRoot:String,workspace:String,runtimeHome:String,caseSrc:String):CkbAbcdeCommandResult{
    let profilePath="${groupRoot}/certification.sb"
    ckbAbcdeWriteText(profilePath,ckbAbcdeCertificationSandboxProfile(workspace,runtimeHome,options.ckbBin,options.ckbStore,caseSrc))
    let probe=ckbAbcdeCertificationSandboxProbe(profilePath,workspace,runtimeHome,caseSrc)
    ckbAbcdeWriteText("${groupRoot}/sandbox-probe.json",probe.stdout)
    if(probe.exitCode!=0){let blocked=CkbAbcdeCommandResult();blocked.exitCode=126;blocked.stderr="certification_sandbox_probe_failed";ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl","");ckbAbcdeWriteText("${groupRoot}/claude.stdout.log","");ckbAbcdeWriteText("${groupRoot}/claude.stderr.log",blocked.stderr);return blocked}
    ckbAbcdeWriteText("${groupRoot}/runtime-policy.json","{\"model\":\"${ckbAbcdeJsonEscape(options.expectedModelVersion)}\",\"maxTurns\":1,\"agentAttempts\":1,\"providerRetries\":0,\"sdkRetries\":0,\"fallbackEnabled\":false}\n")
    let current=ckbAbcdeRunClaudeOnceInCertificationSandbox(group,groupRoot,workspace,runtimeHome,profilePath,options.expectedModelVersion,options.modelTimeoutSeconds)
    ckbAbcdeAppendText("${groupRoot}/claude-attempts.jsonl","{\"attempt\":1,\"exitCode\":${current.exitCode},\"retryUsed\":false,\"fallbackUsed\":false}\n")
    ckbAbcdePublishClaudeAttemptArtifacts(groupRoot,1)
    current
}

public func ckbAbcdeCertificationSandboxProfile(workspace:String,runtimeHome:String,ckbBin:String,ckbStore:String,caseSrc:String):String{
    let w=ckbAbcdeSandboxPath(workspace);let h=ckbAbcdeSandboxPath(runtimeHome);let bin=ckbAbcdeSandboxPath(ckbBin);let store=ckbAbcdeSandboxPath(ckbStore);let tests=ckbAbcdeSandboxPath("${caseSrc}/tests");let reference=ckbAbcdeSandboxPath("${caseSrc}/translation");let teacher=ckbAbcdeSandboxPath("/Users/l3gi0n/work/workspace_cangjie/CangjieTeacher")
    "(version 1)\n(import \"system.sb\")\n(deny default)\n(allow process*)\n(allow sysctl-read)\n(allow mach-lookup)\n(allow network*)\n(allow file-read* (literal \"/opt/homebrew/bin/claude\") (subpath \"/opt/homebrew/lib/node_modules\") (subpath \"${w}\") (subpath \"${h}\") (literal \"${bin}\") (subpath \"${store}\"))\n(allow file-write* (subpath \"${w}\") (subpath \"${h}\"))\n(deny file-read* (subpath \"${tests}\") (subpath \"${reference}\") (subpath \"${teacher}\"))\n"
}

private func ckbAbcdeSandboxLiteral(value:String):String{value.replace("\\","\\\\").replace("\"","\\\"")}
private func ckbAbcdeSandboxPath(value:String):String{ckbAbcdeSandboxLiteral(try{canonicalize(Path(value)).toString()}catch(_:Exception){value})}

private func ckbAbcdeCertificationSandboxProbe(profilePath:String,workspace:String,runtimeHome:String,caseSrc:String):CkbAbcdeCommandResult{
    let workspacePath=try{canonicalize(Path(workspace)).toString()}catch(_:Exception){workspace};let homePath=try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){runtimeHome};let casePath=try{canonicalize(Path(caseSrc)).toString()}catch(_:Exception){caseSrc};let sandboxProfile=try{canonicalize(Path(profilePath)).toString()}catch(_:Exception){profilePath}
    let marker="${workspacePath}/.sandbox-write-probe"
    let outside=Path(workspacePath).parent.join(".sandbox-outside-probe").toString()
    let script="[ \"$HOME\" = ${ckbAbcdeShellQuote(homePath)} ] || exit 38; /usr/bin/true || exit 39; printf probe > ${ckbAbcdeShellQuote(marker)} && rm -f ${ckbAbcdeShellQuote(marker)} || exit 40; ! /usr/bin/touch ${ckbAbcdeShellQuote(outside)} >/dev/null 2>&1 || exit 41; ! /bin/ls ${ckbAbcdeShellQuote("${casePath}/tests")} >/dev/null 2>&1 || exit 42; ! /bin/ls ${ckbAbcdeShellQuote("${casePath}/translation")} >/dev/null 2>&1 || exit 43; ! /bin/ls ${ckbAbcdeShellQuote("/Users/l3gi0n/work/workspace_cangjie/CangjieTeacher")} >/dev/null 2>&1 || exit 44"
    let raw=ckbAbcdeRunShell("HOME=${ckbAbcdeShellQuote(homePath)} XDG_CONFIG_HOME=${ckbAbcdeShellQuote("${homePath}/xdg-config")} XDG_CACHE_HOME=${ckbAbcdeShellQuote("${homePath}/xdg-cache")} CLAUDE_CONFIG_DIR=${ckbAbcdeShellQuote("${homePath}/claude-config")} sandbox-exec -f ${ckbAbcdeShellQuote(sandboxProfile)} /bin/zsh -lc ${ckbAbcdeShellQuote(script)}",workspacePath)
    let result=CkbAbcdeCommandResult();result.exitCode=raw.exitCode;result.stderr=raw.stderr;result.stdout="{\"ok\":${raw.exitCode==0},\"deniedOutsideWorkspace\":${raw.exitCode==0},\"deniedTests\":${raw.exitCode==0},\"deniedReference\":${raw.exitCode==0},\"deniedTeacher\":${raw.exitCode==0},\"workspaceCanonical\":\"${ckbAbcdeJsonEscape(try{canonicalize(Path(workspace)).toString()}catch(_:Exception){""})}\",\"runtimeHomeCanonical\":\"${ckbAbcdeJsonEscape(try{canonicalize(Path(runtimeHome)).toString()}catch(_:Exception){""})}\"}\n";result
}
public func ckbAbcdeCertificationSandboxProbeForTest(profilePath:String,workspace:String,runtimeHome:String,caseSrc:String):CkbAbcdeCommandResult{ckbAbcdeCertificationSandboxProbe(profilePath,workspace,runtimeHome,caseSrc)}

private func ckbAbcdeRunClaudeOnceInCertificationSandbox(group:String,groupRoot:String,workspace:String,runtimeHome:String,profilePath:String,expectedModel:String,modelTimeoutSeconds:Int64):CkbAbcdeCommandResult{
    let transcript="${groupRoot}/claude-transcript.attempt-1.jsonl";let stderr="${groupRoot}/claude.attempt-1.stderr.log"
    ckbAbcdeWriteText("${runtimeHome}/mcp-config.json",ckbAbcdeReadText("${groupRoot}/mcp-config.json"))
    let command=ckbAbcdeCertificationClaudeCommand(groupRoot,runtimeHome,profilePath,expectedModel,transcript,stderr)
    let script=ckbAbcdeClaudeTimeoutShell(command,stderr,modelTimeoutSeconds)+"; exit $code";ckbAbcdeRunShell(script,workspace)
}
public func ckbAbcdeCertificationClaudeCommand(groupRoot:String,runtimeHome:String,profilePath:String,expectedModel:String,transcript:String,stderr:String):String{"session_id=$(uuidgen | tr '[:upper:]' '[:lower:]'); printf '%s' \"$session_id\" > ${ckbAbcdeShellQuote("${groupRoot}/session-id.txt")}; HOME=${ckbAbcdeShellQuote(runtimeHome)} XDG_CONFIG_HOME=${ckbAbcdeShellQuote("${runtimeHome}/xdg-config")} XDG_CACHE_HOME=${ckbAbcdeShellQuote("${runtimeHome}/xdg-cache")} CLAUDE_CONFIG_DIR=${ckbAbcdeShellQuote("${runtimeHome}/claude-config")} ANTHROPIC_MAX_RETRIES=0 CLAUDE_CODE_MAX_RETRIES=0 sandbox-exec -f ${ckbAbcdeShellQuote(profilePath)} /opt/homebrew/bin/claude -p --verbose --no-session-persistence --session-id \"$session_id\" --model ${ckbAbcdeShellQuote(expectedModel)} --output-format stream-json --strict-mcp-config --mcp-config ${ckbAbcdeShellQuote("${runtimeHome}/mcp-config.json")} < ${ckbAbcdeShellQuote("${groupRoot}/prompt.final.md")} > ${ckbAbcdeShellQuote(transcript)} 2> ${ckbAbcdeShellQuote(stderr)}"}

private func ckbAbcdeRunClaudeOnce(group: String, groupRoot: String, workspace: String, docsRoot: String, attempt: Int64, expectedModel: String, modelTimeoutSeconds: Int64, modelEffort: String, modelMaxBudgetUsd: String): CkbAbcdeCommandResult {
    var addDir = "--add-dir ${ckbAbcdeShellQuote(workspace)}"
    if (group == CkbAbcdeGroups.E) {
        addDir += " --add-dir ${ckbAbcdeShellQuote(docsRoot)}"
    }
    let toolLimit = ckbAbcdeClaudeToolLimitForGroup(group)
    let transcript = "${groupRoot}/claude-transcript.attempt-${attempt}.jsonl"
    let stderr = "${groupRoot}/claude.attempt-${attempt}.stderr.log"
    let budgetFlag = if (modelMaxBudgetUsd == "") { "" } else { " --max-budget-usd ${ckbAbcdeShellQuote(modelMaxBudgetUsd)}" }
    ckbAbcdeWriteText("${groupRoot}/model-transport-profile.json", "{\"effort\":\"${ckbAbcdeJsonEscape(modelEffort)}\",\"maxBudgetUsd\":\"${ckbAbcdeJsonEscape(modelMaxBudgetUsd)}\",\"timeoutSeconds\":${modelTimeoutSeconds},\"attempt\":${attempt}}\n")
    let command = "claude -p --verbose --no-session-persistence --model ${ckbAbcdeShellQuote(expectedModel)} --effort ${ckbAbcdeShellQuote(modelEffort)}${budgetFlag} --output-format stream-json --strict-mcp-config --mcp-config ${ckbAbcdeShellQuote("${groupRoot}/mcp-config.json")} ${ckbAbcdeClaudePermissionFlag()} ${toolLimit} ${addDir} < ${ckbAbcdeShellQuote("${groupRoot}/prompt.final.md")} > ${ckbAbcdeShellQuote(transcript)} 2> ${ckbAbcdeShellQuote(stderr)}"
    let script = ckbAbcdeClaudeTimeoutShell(command, stderr, modelTimeoutSeconds) + "; cp ${ckbAbcdeShellQuote(transcript)} ${ckbAbcdeShellQuote("${groupRoot}/claude-transcript.jsonl")} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(transcript)} ${ckbAbcdeShellQuote("${groupRoot}/claude.stdout.log")} 2>/dev/null || true; cp ${ckbAbcdeShellQuote(stderr)} ${ckbAbcdeShellQuote("${groupRoot}/claude.stderr.log")} 2>/dev/null || true; exit $code"
    ckbAbcdeRunShell(script, workspace)
}

private func ckbAbcdePublishClaudeAttemptArtifacts(groupRoot: String, attemptCount: Int64): Unit {
    let transcript = ckbAbcdeMergedClaudeAttemptText(groupRoot, "claude-transcript.attempt-", ".jsonl", attemptCount)
    let stderr = ckbAbcdeMergedClaudeAttemptText(groupRoot, "claude.attempt-", ".stderr.log", attemptCount)
    ckbAbcdeWriteText("${groupRoot}/claude-transcript.jsonl", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stdout.log", transcript)
    ckbAbcdeWriteText("${groupRoot}/claude.stderr.log", stderr)
}

private func ckbAbcdeMergedClaudeAttemptText(groupRoot: String, prefix: String, suffix: String, attemptCount: Int64): String {
    let out = StringBuilder()
    for (attempt in 1..=attemptCount) {
        ckbAbcdeAppendAttemptText(out, ckbAbcdeReadText("${groupRoot}/${prefix}${attempt}${suffix}"))
    }
    out.toString()
}

private func ckbAbcdeAppendAttemptText(out: StringBuilder, text: String): Unit {
    if (text == "") {
        return
    }
    out.append(text)
    if (!text.endsWith("\n")) {
        out.append("\n")
    }
}

public func ckbAbcdeJoinClaudeAttemptTextForTest(first: String, second: String): String {
    let out = StringBuilder()
    ckbAbcdeAppendAttemptText(out, first)
    ckbAbcdeAppendAttemptText(out, second)
    out.toString()
}

private func ckbAbcdeClaudeTimeoutShell(command: String, stderrPath: String, timeoutSeconds: Int64): String {
    let quotedStderr = ckbAbcdeShellQuote(stderrPath)
    let safeTimeout = if (timeoutSeconds < 1) { 1 } else { timeoutSeconds }
    let perl = ckbAbcdeShellQuote("defined POSIX::setsid() or exit 125; exec @ARGV")
    let isolatedCommand = ckbAbcdeShellQuote(command)
    "/usr/bin/perl -MPOSIX -e ${perl} /bin/zsh -lc ${isolatedCommand} & child=$!; elapsed=0; timed_out=0; while /bin/kill -0 \"$child\" 2>/dev/null; do if [ \"$elapsed\" -ge ${safeTimeout} ]; then echo claude_timeout_after_${safeTimeout}s >> ${quotedStderr}; /bin/kill -TERM -- \"-$child\" 2>/dev/null || true; grace=0; while /bin/kill -0 -- \"-$child\" 2>/dev/null && [ \"$grace\" -lt 2 ]; do sleep 1; grace=$((grace + 1)); done; /bin/kill -KILL -- \"-$child\" 2>/dev/null || true; timed_out=1; break; fi; sleep 1; elapsed=$((elapsed + 1)); done; if [ \"$timed_out\" -eq 1 ]; then wait \"$child\" 2>/dev/null || true; code=124; else wait \"$child\"; code=$?; fi"
}

public func ckbAbcdeClaudeTimeoutShellForTest(command: String, stderrPath: String, timeoutSeconds: Int64): String {
    ckbAbcdeClaudeTimeoutShell(command, stderrPath, timeoutSeconds)
}

public func ckbAbcdeClaudeTimeoutShellForOptionsForTest(command: String, stderrPath: String, options: CkbAbcdeRunnerOptions): String {
    ckbAbcdeClaudeTimeoutShell(command, stderrPath, options.modelTimeoutSeconds)
}

public func ckbAbcdeRunClaudeTimeoutShellForTest(command:String,stderrPath:String,timeoutSeconds:Int64,workspace:String):CkbAbcdeCommandResult {
    ckbAbcdeRunShell(ckbAbcdeClaudeTimeoutShell(command,stderrPath,timeoutSeconds)+"; exit $code",workspace)
}

private func ckbAbcdeClaudePermissionFlag(): String {
    "--dangerously-skip-permissions"
}

public func ckbAbcdeClaudePermissionFlagForTest(): String {
    ckbAbcdeClaudePermissionFlag()
}

public func ckbAbcdeClaudeToolLimitForGroup(group: String): String {
    ""
}

private func ckbAbcdeCurlRetryFlags(): String {
    "--retry 3 --retry-delay 2 --retry-connrefused"
}

public func ckbAbcdeCurlRetryFlagsForTest(): String {
    ckbAbcdeCurlRetryFlags()
}

private func ckbAbcdeRunMcpStdioSmoke(options: CkbAbcdeRunnerOptions, groupRoot: String, taskContextJson!: String = ckbAbcdeSmokeTaskContextJson()): Unit {
    let requests = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-abcde-runner\",\"version\":\"1.0\"}}}\n" +
        "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}\n" +
        "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\",\"params\":{}}\n" +
        "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":${taskContextJson}}}\n"
    ckbAbcdeWriteText("${groupRoot}/mcp-stdio-smoke-requests.jsonl", requests)
    let script = "cat ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke-requests.jsonl")} | ( " +
        ckbAbcdeNativeTlsBootstrapScript(options.ckbBin, ["--store", options.ckbStore, "mcp-stdio"]) +
        " ) > ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke.stdout.jsonl")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-stdio-smoke.stderr.log")}"
    let result = ckbAbcdeRunShell(script, "")
    let stdout = ckbAbcdeReadText("${groupRoot}/mcp-stdio-smoke.stdout.jsonl")
    let ok = result.exitCode == 0 && stdout.contains("cangjie_task_knowledge_pack") && stdout.contains("\"versionResolution\"")
    let observation = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-smoke", "mcp_stdio", stdout)
    ckbAbcdeWriteText("${groupRoot}/mcp-stdio-tools-list.json", "{\"exitCode\":${result.exitCode},\"knowledgePackCallOk\":${ok},\"taskKnowledgePackCallOk\":${ok},\"toolNamesContainsTaskKnowledgePack\":${stdout.contains("cangjie_task_knowledge_pack")},\"versionResolutionReturned\":${stdout.contains("\"versionResolution\"")}}\n")
    ckbAbcdeWriteText("${groupRoot}/parity.jsonl", ckbAbcdeRenderParityObservationJson(observation) + "\n")
}

private func ckbAbcdeRunMcpHttpSmoke(options: CkbAbcdeRunnerOptions, groupRoot: String, taskContextJson!: String = ckbAbcdeSmokeTaskContextJson()): Unit {
    let initBody = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-abcde-runner\",\"version\":\"1.0\"}}}"
    let initializedBody = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}"
    let callBody = "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":${taskContextJson}}}"
    ckbAbcdeWriteText("${groupRoot}/mcp-http-initialize-request.json", initBody)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-initialized-request.json", initializedBody)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-tool-call-request.json", callBody)
    let script = "curl --max-time 5 -i -sS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-response.txt")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize.stderr.log")}; " +
        "sid=$(grep -i '^mcp-session-id:' ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialize-response.txt")} | head -n1 | cut -d' ' -f2 | tr -d '\\r'); " +
        "printf '%s\\n' \"$sid\" > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-session-id.txt")}; " +
        "if [ -z \"$sid\" ]; then exit 4; fi; " +
        "curl --max-time 5 -fsS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialized-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialized-response.txt")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-initialized.stderr.log")}; " +
        "curl --max-time 10 -fsS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' --data-binary @${ckbAbcdeShellQuote("${groupRoot}/mcp-http-tool-call-request.json")} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-tool-call-response.json")} 2> ${ckbAbcdeShellQuote("${groupRoot}/mcp-http-tool-call.stderr.log")}; " +
        "curl --max-time 5 -fsS -N -H 'Accept: text/event-stream' -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")}"
    let get = ckbAbcdeRunShell(script, "")
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.stdout.log", get.stdout)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.stderr.log", get.stderr)
    let ready = get.stdout.contains("event") || get.stdout.contains("ready")
    let callResponse = ckbAbcdeReadText("${groupRoot}/mcp-http-tool-call-response.json")
    let toolOk = callResponse.contains("\"versionResolution\"") && callResponse.contains("\"queryPlan\"")
    let observation = ckbAbcdeParityObservationFromResponse("CJ-HUMANEVAL-smoke", "mcp_http", callResponse)
    ckbAbcdeWriteText("${groupRoot}/mcp-http-smoke.json", "{\"exitCode\":${get.exitCode},\"ok\":${toolOk},\"taskKnowledgePackCallOk\":${toolOk},\"sseReady\":${ready},\"versionResolutionReturned\":${callResponse.contains("\"versionResolution\"")}}\n")
    ckbAbcdeWriteText("${groupRoot}/parity.jsonl", ckbAbcdeRenderParityObservationJson(observation) + "\n")
}

public func ckbAbcdeProbeInProcessTransportParity(service: CkbCommandLoopService, caseId: String, taskContextJson: String): CkbAbcdeParityReport {
    let report = CkbAbcdeParityReport()
    report.caseId = caseId
    report.rest = ckbAbcdeParityObservationFromResponse(caseId, "rest", ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack", taskContextJson, []))
    let jsonRpc = ckbAbcdeMcpTaskKnowledgePackRequest(taskContextJson)
    report.stdio = ckbAbcdeParityObservationFromResponse(caseId, "mcp_stdio", CkbMcpStdioServer(service).handleRequest(jsonRpc))
    report.http = ckbAbcdeParityObservationFromResponse(caseId, "mcp_http", ckbAbcdeRunInProcessMcpHttpToolCall(service, jsonRpc))
    report.diagnostic = ckbAbcdeParityDiagnostic(report.rest, report.stdio, report.http)
    report.ok = report.diagnostic == "ok"
    report
}

public func ckbAbcdeProbeInProcessTransportParityArtifacts(service: CkbCommandLoopService, runRoot: String, caseId: String, taskContextJson: String): CkbAbcdeParityReport {
    ckbAbcdeEnsureDir(runRoot)
    let jsonRpc = ckbAbcdeMcpTaskKnowledgePackRequest(taskContextJson)
    let restPath = "${runRoot}/transport-parity-rest.json"
    let stdioPath = "${runRoot}/transport-parity-stdio.json"
    let httpPath = "${runRoot}/transport-parity-http.json"
    let restResponse = ckbApiHandle(service, "POST", "/v1/cangjie/task-knowledge-pack", taskContextJson, [])
    let stdioResponse = CkbMcpStdioServer(service).handleRequest(jsonRpc)
    let httpResponse = ckbAbcdeRunInProcessMcpHttpToolCall(service, jsonRpc)
    ckbAbcdeWriteText(restPath, restResponse)
    ckbAbcdeWriteText(stdioPath, stdioResponse)
    ckbAbcdeWriteText(httpPath, httpResponse)
    ckbAbcdeBuildParityReportFromPayloads(caseId, runRoot, restPath, restResponse, 0, "", stdioPath, stdioResponse, 0, "", httpPath, httpResponse, 0, "")
}

public func ckbAbcdeProbeRealTransportParity(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, taskContextJson: String): CkbAbcdeParityReport {
    ckbAbcdeEnsureDir(runRoot)
    ckbAbcdeWriteText("${runRoot}/transport-parity-task-context.json", taskContextJson + "\n")

    let restRequestPath = "${runRoot}/transport-parity-rest-request.json"
    let restPath = "${runRoot}/transport-parity-rest.json"
    ckbAbcdeWriteText(restRequestPath, taskContextJson)
    let rest = ckbAbcdeRunShell("curl ${ckbAbcdeCurlRetryFlags()} --max-time 10 -fsS -X POST -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote(restRequestPath)} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/cangjie/task-knowledge-pack")}", "")
    ckbAbcdeWriteText(restPath, rest.stdout)
    ckbAbcdeWriteText("${runRoot}/transport-parity-rest.stderr.log", rest.stderr)

    let stdioRequestPath = "${runRoot}/transport-parity-stdio-requests.jsonl"
    let stdioFullPath = "${runRoot}/transport-parity-stdio-full.jsonl"
    let stdioPath = "${runRoot}/transport-parity-stdio.json"
    let stdioRequests = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-transport-parity\",\"version\":\"1.0\"}}}\n" +
        "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}\n" +
        ckbAbcdeMcpTaskKnowledgePackRequest(taskContextJson) + "\n"
    ckbAbcdeWriteText(stdioRequestPath, stdioRequests)
    let stdioScript = "cat ${ckbAbcdeShellQuote(stdioRequestPath)} | ( " +
        ckbAbcdeNativeTlsBootstrapScript(options.ckbBin, ["--store", options.ckbStore, "mcp-stdio"]) +
        " ) > ${ckbAbcdeShellQuote(stdioFullPath)} 2> ${ckbAbcdeShellQuote("${runRoot}/transport-parity-stdio.stderr.log")}"
    let stdio = ckbAbcdeRunShell(stdioScript, "")
    let stdioFull = ckbAbcdeReadText(stdioFullPath)
    let stdioPayload = ckbAbcdeExtractMcpToolResponse(stdioFull)
    ckbAbcdeWriteText(stdioPath, stdioPayload)

    let initBody = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-transport-parity\",\"version\":\"1.0\"}}}"
    let initializedBody = "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}"
    let callBody = ckbAbcdeMcpTaskKnowledgePackRequest(taskContextJson)
    let httpInitPath = "${runRoot}/transport-parity-http-initialize-request.json"
    let httpInitializedPath = "${runRoot}/transport-parity-http-initialized-request.json"
    let httpRequestPath = "${runRoot}/transport-parity-http-request.json"
    let httpPath = "${runRoot}/transport-parity-http.json"
    ckbAbcdeWriteText(httpInitPath, initBody)
    ckbAbcdeWriteText(httpInitializedPath, initializedBody)
    ckbAbcdeWriteText(httpRequestPath, callBody)
    let httpScript = "curl --max-time 5 -i -sS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' --data-binary @${ckbAbcdeShellQuote(httpInitPath)} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialize-response.txt")} 2> ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialize.stderr.log")}; " +
        "sid=$(grep -i '^mcp-session-id:' ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialize-response.txt")} | head -n1 | cut -d' ' -f2 | tr -d '\\r'); " +
        "printf '%s\\n' \"$sid\" > ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-session-id.txt")}; " +
        "if [ -z \"$sid\" ]; then exit 4; fi; " +
        "curl --max-time 5 -fsS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' --data-binary @${ckbAbcdeShellQuote(httpInitializedPath)} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialized-response.txt")} 2> ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http-initialized.stderr.log")}; " +
        "curl --max-time 10 -fsS -X POST -H 'Accept: application/json, text/event-stream' -H 'Content-Type: application/json' -H \"Mcp-Session-Id: $sid\" -H 'MCP-Protocol-Version: 2025-06-18' --data-binary @${ckbAbcdeShellQuote(httpRequestPath)} ${ckbAbcdeShellQuote("${options.ckbHttpBase}/mcp")} > ${ckbAbcdeShellQuote(httpPath)} 2> ${ckbAbcdeShellQuote("${runRoot}/transport-parity-http.stderr.log")}"
    let http = ckbAbcdeRunShell(httpScript, "")
    let httpPayload = ckbAbcdeReadText(httpPath)

    ckbAbcdeBuildParityReportFromPayloads(caseId, runRoot, restPath, rest.stdout, rest.exitCode, rest.stderr, stdioPath, stdioPayload, stdio.exitCode, ckbAbcdeReadText("${runRoot}/transport-parity-stdio.stderr.log"), httpPath, httpPayload, http.exitCode, ckbAbcdeReadText("${runRoot}/transport-parity-http.stderr.log"))
}

private func ckbAbcdeBuildParityReportFromPayloads(
    caseId: String,
    runRoot: String,
    restPath: String,
    restResponse: String,
    restExitCode: Int64,
    restStderr: String,
    stdioPath: String,
    stdioResponse: String,
    stdioExitCode: Int64,
    stdioStderr: String,
    httpPath: String,
    httpResponse: String,
    httpExitCode: Int64,
    httpStderr: String
): CkbAbcdeParityReport {
    let report = CkbAbcdeParityReport()
    report.caseId = caseId
    report.rest = ckbAbcdeParityObservationFromArtifact(caseId, "rest", restPath, restResponse, restExitCode, restStderr)
    report.stdio = ckbAbcdeParityObservationFromArtifact(caseId, "mcp_stdio", stdioPath, stdioResponse, stdioExitCode, stdioStderr)
    report.http = ckbAbcdeParityObservationFromArtifact(caseId, "mcp_http", httpPath, httpResponse, httpExitCode, httpStderr)
    report.diagnostic = ckbAbcdeParityDiagnostic(report.rest, report.stdio, report.http)
    report.ok = report.diagnostic == "ok"
    ckbAbcdeWriteText("${runRoot}/transport-parity.jsonl", ckbAbcdeRenderParityJsonl(report) + "\n")
    report
}

private func ckbAbcdeMcpTaskKnowledgePackRequest(taskContextJson: String): String {
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"cangjie_task_knowledge_pack\",\"arguments\":${taskContextJson}}}"
}

private func ckbAbcdeRunInProcessMcpHttpToolCall(service: CkbCommandLoopService, jsonRpc: String): String {
    let sessionStore = CkbMcpHttpSessionStore()
    let httpConfig = CkbHttpServiceConfig()
    let mcpConfig = CkbMcpHttpServiceConfig()
    let initBody = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2025-06-18\",\"capabilities\":{},\"clientInfo\":{\"name\":\"ckb-abcde-runner\",\"version\":\"1.0\"}}}"
    let initHeaders = ["Content-Type: application/json", "Accept: application/json, text/event-stream"]
    let initResponse = handleCkbMcpHttpRequest(service, "POST", "/mcp", initBody, initHeaders, httpConfig, mcpConfig, sessionStore)
    let sessionId = ckbAbcdeMcpHttpSessionId(initResponse.headers)
    if (sessionId == "") {
        return initResponse.body
    }
    let sessionHeaders = ["Content-Type: application/json", "Accept: application/json, text/event-stream", "MCP-Protocol-Version: 2025-06-18", "Mcp-Session-Id: ${sessionId}"]
    _ = handleCkbMcpHttpRequest(service, "POST", "/mcp", "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\",\"params\":{}}", sessionHeaders, httpConfig, mcpConfig, sessionStore)
    handleCkbMcpHttpRequest(service, "POST", "/mcp", jsonRpc, sessionHeaders, httpConfig, mcpConfig, sessionStore).body
}

private func ckbAbcdeMcpHttpSessionId(headers: ArrayList<String>): String {
    for (header in headers) {
        let lower = header.toAsciiLower()
        if (lower.startsWith("mcp-session-id:")) {
            let parts = header.split(":")
            if (parts.size > 1) { return parts[1].trimAscii() }
        }
    }
    ""
}

public func ckbAbcdeParityObservationFromResponse(caseId: String, transport: String, response: String): CkbAbcdeParityObservation {
    let payload = ckbAbcdeParityStructuredPayload(response, transport)
    let observation = CkbAbcdeParityObservation()
    observation.caseId = caseId
    observation.transport = transport
    observation.evidenceHash = ckbAbcdeJsonStringField(payload, "evidenceHash")
    observation.coveragePass = payload.contains("\"coveragePass\":true")
    observation.citationCount = ckbAbcdeCountOccurrences(payload, "\"citation\"")
    observation.ok = payload != "" && observation.evidenceHash != ""
    observation.diagnostic = if (payload == "") { "missing_structured_payload" } else if (observation.evidenceHash == "") { "missing_evidence_hash" } else { "ok" }
    observation
}

private func ckbAbcdeParityObservationFromArtifact(caseId: String, transport: String, payloadPath: String, response: String, exitCode: Int64, stderr: String): CkbAbcdeParityObservation {
    let observation = ckbAbcdeParityObservationFromResponse(caseId, transport, response)
    observation.payloadPath = payloadPath
    if (exitCode != 0) {
        observation.ok = false
        observation.diagnostic = "${observation.diagnostic};transport_exit_${exitCode}:${utf8SafePrefix(stderr.replace("\n", " "), 160)}"
    } else if (!observation.ok && stderr.trimAscii() != "") {
        observation.diagnostic = "${observation.diagnostic};${utf8SafePrefix(stderr.replace("\n", " "), 160)}"
    }
    observation
}

public func ckbAbcdeParityObservationFromArtifactForTest(caseId: String, transport: String, payloadPath: String, response: String, exitCode: Int64, stderr: String): CkbAbcdeParityObservation {
    ckbAbcdeParityObservationFromArtifact(caseId, transport, payloadPath, response, exitCode, stderr)
}

private func ckbAbcdeExtractMcpToolResponse(stdout: String): String {
    for (line in stdout.split("\n")) {
        if (line.contains("\"structuredContent\"") && line.contains("\"cangjie_task_knowledge_pack\"")) {
            return line
        }
    }
    for (line in stdout.split("\n")) {
        if (line.contains("\"structuredContent\"")) {
            return line
        }
    }
    ""
}

public func ckbAbcdeParityStructuredPayload(response: String, transport: String): String {
    if (transport == "rest") {
        return ckbMcpJsonObjectField(response, "data")
    }
    let result = ckbMcpJsonObjectField(response, "result")
    ckbMcpJsonObjectField(result, "structuredContent")
}

private func ckbAbcdeParityDiagnostic(rest: CkbAbcdeParityObservation, stdio: CkbAbcdeParityObservation, http: CkbAbcdeParityObservation): String {
    if (!rest.ok) { return "rest_${rest.diagnostic}" }
    if (!stdio.ok) { return "mcp_stdio_${stdio.diagnostic}" }
    if (!http.ok) { return "mcp_http_${http.diagnostic}" }
    if (rest.evidenceHash != stdio.evidenceHash || rest.evidenceHash != http.evidenceHash) { return "evidence_hash_mismatch" }
    if (rest.coveragePass != stdio.coveragePass || rest.coveragePass != http.coveragePass) { return "coverage_mismatch" }
    if (rest.citationCount != stdio.citationCount || rest.citationCount != http.citationCount) { return "citation_count_mismatch" }
    "ok"
}

public func ckbAbcdeParityDiagnosticForTest(rest: CkbAbcdeParityObservation, stdio: CkbAbcdeParityObservation, http: CkbAbcdeParityObservation): String {
    ckbAbcdeParityDiagnostic(rest, stdio, http)
}

public func ckbAbcdeRenderParityJsonl(report: CkbAbcdeParityReport): String {
    ckbAbcdeRenderParityObservationJson(report.rest) + "\n" +
        ckbAbcdeRenderParityObservationJson(report.stdio) + "\n" +
        ckbAbcdeRenderParityObservationJson(report.http)
}

public func ckbAbcdeRenderParityObservationJson(observation: CkbAbcdeParityObservation): String {
    "{\"caseId\":\"${ckbAbcdeJsonEscape(observation.caseId)}\",\"interfaceId\":\"${ckbAbcdeJsonEscape(observation.interfaceId)}\",\"transport\":\"${ckbAbcdeJsonEscape(observation.transport)}\",\"ok\":${observation.ok},\"evidenceHash\":\"${ckbAbcdeJsonEscape(observation.evidenceHash)}\",\"coveragePass\":${observation.coveragePass},\"citationCount\":${observation.citationCount},\"diagnostic\":\"${ckbAbcdeJsonEscape(observation.diagnostic)}\",\"payloadPath\":\"${ckbAbcdeJsonEscape(observation.payloadPath)}\"}"
}

private func ckbAbcdePreflight(options: CkbAbcdeRunnerOptions, runRoot: String): CkbAbcdePreflightResult {
    let result = CkbAbcdePreflightResult()
    result.add("runs_root", exists(Path(options.runsRoot)), options.runsRoot)
    result.add("run_root_created", exists(Path(runRoot)), runRoot)
    result.add("ckb_bin", exists(Path(options.ckbBin)), options.ckbBin)
    result.add("ckb_store", exists(Path(options.ckbStore)), options.ckbStore)
    result.add("dataset_root", exists(Path(options.datasetRoot)), options.datasetRoot)
    result.add("manifest", exists(Path(options.manifestPath)) && ckbAbcdeManifestLineCount(options.manifestPath) == 164, "lines=${ckbAbcdeManifestLineCount(options.manifestPath)}")
    result.add("humaneval_cases", ckbAbcdeCaseLayoutOk(options.datasetRoot), "CJ-HUMANEVAL-000..163 required files")
    result.add("docs_root", exists(Path(options.docsRoot)) && exists(Path("${options.docsRoot}/dev-guide/summary_cjnative_EN.md")) && exists(Path("${options.docsRoot}/tools/summary_cjnative_EN.md")), options.docsRoot)
    result.add("claude_cli", ckbAbcdeRunShell("command -v claude >/dev/null && claude --version >/dev/null", "").exitCode == 0, "claude command available")
    result.add("claude_glm52_settings", ckbAbcdeClaudeSettingsLooksGlm52(), "~/.claude/settings.json model keys")
    result.add("cjpm_cli", ckbAbcdeRunShell("command -v cjpm >/dev/null && cjpm --version >/dev/null", "").exitCode == 0, "cjpm command available")
    result.add("ckb_http_health", ckbAbcdeRunShell(ckbAbcdePreflightHttpHealthCommand(options.ckbHttpBase), "").exitCode == 0, options.ckbHttpBase)
    result.add("ckb_http_schema", ckbAbcdeRunShell("curl --max-time 5 -fsS ${ckbAbcdeShellQuote("${options.ckbHttpBase}/v1/schema")} | grep -q cangjie_task_knowledge_pack", "").exitCode == 0, "${options.ckbHttpBase}/v1/schema")
    let stdioRoot = "${runRoot}/preflight-stdio"
    ckbAbcdeEnsureDir(stdioRoot)
    ckbAbcdeRunMcpStdioSmoke(options, stdioRoot)
    let stdioJson = ckbAbcdeReadText("${stdioRoot}/mcp-stdio-tools-list.json")
    result.add("mcp_stdio", stdioJson.contains("\"knowledgePackCallOk\":true"), "${stdioRoot}/mcp-stdio-tools-list.json")
    let httpRoot = "${runRoot}/preflight-http"
    ckbAbcdeEnsureDir(httpRoot)
    ckbAbcdeRunMcpHttpSmoke(options, httpRoot)
    let httpJson = ckbAbcdeReadText("${httpRoot}/mcp-http-smoke.json")
    result.add("mcp_http", httpJson.contains("\"ok\":true"), "${httpRoot}/mcp-http-smoke.json")
    let parity = ckbAbcdeProbeRealTransportParity(options, runRoot, "preflight", ckbAbcdeSmokeTaskContextJson())
    ckbAbcdeWriteText("${runRoot}/preflight-parity.jsonl", ckbAbcdeRenderParityJsonl(parity) + "\n")
    result.add("transport_parity", parity.ok, "${runRoot}/preflight-parity.jsonl diagnostic=${parity.diagnostic}")
    result
}

public func ckbAbcdePreflightHttpHealthCommand(baseUrl: String): String {
    "curl --max-time 15 -fsS ${ckbAbcdeShellQuote("${baseUrl}/v1/health")} >/dev/null"
}

private func ckbAbcdeRenderPreflightJson(options: CkbAbcdeRunnerOptions, runRoot: String, result: CkbAbcdePreflightResult): String {
    var checks = ""
    for (i in 0..result.checks.size) {
        if (i > 0) {
            checks += ","
        }
        checks += result.checks[i]
    }
    "{\"ok\":${result.ok},\"runRoot\":\"${ckbAbcdeJsonEscape(runRoot)}\",\"runsRoot\":\"${ckbAbcdeJsonEscape(options.runsRoot)}\",\"expectedModelVersion\":\"${ckbAbcdeJsonEscape(options.expectedModelVersion)}\",\"caseStart\":${options.caseStart},\"caseEnd\":${options.caseEnd},\"checks\":[${checks}]}\n"
}

private func ckbAbcdeRenderPreflightMarkdown(options: CkbAbcdeRunnerOptions, runRoot: String, result: CkbAbcdePreflightResult): String {
    var out = "# CKB ABCDE Benchmark Preflight\n\n"
    out += "- ok: ${result.ok}\n"
    out += "- runRoot: `${runRoot}`\n"
    out += "- runsRoot: `${options.runsRoot}`\n"
    out += "- expectedModelVersion: `${options.expectedModelVersion}`\n"
    out += "- cases: `${options.caseStart}..${options.caseEnd}`\n\n"
    out += "## Checks\n\n"
    for (check in result.checks) {
        out += "- `${check}`\n"
    }
    if (result.diagnostics.size > 0) {
        out += "\n## Diagnostics\n\n"
        for (diagnostic in result.diagnostics) {
            out += "- ${diagnostic}\n"
        }
    }
    out
}

private func ckbAbcdeWriteSummary(runRoot: String): Unit {
    let results = ckbAbcdeReadText("${runRoot}/results.jsonl")
    let lines = results.split("\n")
    let total = ckbAbcdeSummaryTotalForGroup(lines, "ALL")
    let passed = ckbAbcdeSummaryPassedForGroup(lines, "ALL")
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, "ALL")
    var csv = "group,total,passed,failed,pass_at_1,average_token_per_case,average_llm_turns_per_case,usage_parse_failed\n"
    csv += ckbAbcdeRenderSummaryCsvRow("ALL", lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.A, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.B, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.C, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.D, lines)
    csv += ckbAbcdeRenderSummaryCsvRow(CkbAbcdeGroups.E, lines)
    ckbAbcdeWriteText("${runRoot}/summary.csv", csv)

    var md = "# CKB ABCDE Benchmark Summary\n\n"
    md += "- total: ${total}\n"
    md += "- passed: ${passed}\n"
    md += "- failed: ${total - passed}\n"
    md += "- pass@1: ${passAt1}\n"
    md += "- results: `${runRoot}/results.jsonl`\n"
    md += "- case usage summary: `${runRoot}/case-usage-summary.csv`\n\n"
    md += "| Group | total | passed | failed | pass@1 | avg token/case | avg llm turns/case | usage parse failed |\n"
    md += "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n"
    md += ckbAbcdeRenderSummaryMarkdownRow("ALL", lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.A, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.B, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.C, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.D, lines)
    md += ckbAbcdeRenderSummaryMarkdownRow(CkbAbcdeGroups.E, lines)
    ckbAbcdeWriteText("${runRoot}/summary.md", md)
}

private func ckbAbcdeWritePass1GateArtifactsIfFullRun(options: CkbAbcdeRunnerOptions, runRoot: String): Bool {
    if (!ckbAbcdeShouldRunPass1Gate(options)) {
        return true
    }
    ckbAbcdeWritePass1GateArtifacts(options, runRoot)
}

public func ckbAbcdeWritePass1GateArtifactsForTest(options: CkbAbcdeRunnerOptions, runRoot: String): Bool {
    ckbAbcdeWritePass1GateArtifacts(options, runRoot)
}

private func ckbAbcdeShouldRunPass1Gate(options: CkbAbcdeRunnerOptions): Bool {
    options.caseStart == 0 && options.caseEnd == 163 && (options.groups.contains(CkbAbcdeGroups.C) || options.groups.contains(CkbAbcdeGroups.D))
}

private func ckbAbcdeWritePass1GateArtifacts(options: CkbAbcdeRunnerOptions, runRoot: String): Bool {
    if (options.runMode == "certification") {
        let strict=ckbStrictCertificationGate(ckbAbcdeReadText("${runRoot}/results.jsonl"),ckbAbcdeReadText(options.manifestPath))
        ckbAbcdeWriteText("${runRoot}/pass1-gate.json",renderCkbStrictCertificationGateJson(strict));ckbAbcdeWriteText("${runRoot}/pass1-gate.md",renderCkbStrictCertificationGateMarkdown(strict));return strict.ok
    }
    let gateOptions = CangjieHumanEvalPass1GateOptions()
    gateOptions.runRoot = runRoot
    gateOptions.manifestPath = options.manifestPath
    gateOptions.expectedTotal = options.caseEnd - options.caseStart + 1
    gateOptions.expectedPass = gateOptions.expectedTotal
    gateOptions.groups.clear()
    if (options.groups.contains(CkbAbcdeGroups.C)) {
        gateOptions.groups.add(CangjieHumanEvalPass1GateGroups.C)
    }
    if (options.groups.contains(CkbAbcdeGroups.D)) {
        gateOptions.groups.add(CangjieHumanEvalPass1GateGroups.D)
    }
    if (gateOptions.groups.size == 0) {
        return true
    }
    let gate = cangjieHumanEvalPass1GateFromFiles(gateOptions)
    ckbAbcdeWriteText("${runRoot}/pass1-gate.json", renderCangjieHumanEvalPass1GateJson(gate))
    ckbAbcdeWriteText("${runRoot}/pass1-gate.md", renderCangjieHumanEvalPass1GateMarkdown(gate))
    if (!gate.ok) {
        ckbAbcdeWriteText("${runRoot}/gap-curation-input.jsonl", emitCangjieHumanEvalGapCurationInput(gate))
    }
    gate.ok
}

private func ckbAbcdeRenderSummaryCsvRow(group: String, lines: Array<String>): String {
    let total = ckbAbcdeSummaryTotalForGroup(lines, group)
    let passed = ckbAbcdeSummaryPassedForGroup(lines, group)
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, group)
    let usageOk = ckbAbcdeSummaryUsageOkForGroup(lines, group)
    let tokenTotal = ckbAbcdeSummaryTokenTotalForGroup(lines, group)
    let turnTotal = ckbAbcdeSummaryTurnTotalForGroup(lines, group)
    "${group},${total},${passed},${total - passed},${passAt1},${ckbAbcdeAverageText(tokenTotal, usageOk)},${ckbAbcdeAverageText(turnTotal, usageOk)},${total - usageOk}\n"
}

private func ckbAbcdeRenderSummaryMarkdownRow(group: String, lines: Array<String>): String {
    let total = ckbAbcdeSummaryTotalForGroup(lines, group)
    let passed = ckbAbcdeSummaryPassedForGroup(lines, group)
    let passAt1 = ckbAbcdeSummaryPassAt1ForGroup(lines, group)
    let usageOk = ckbAbcdeSummaryUsageOkForGroup(lines, group)
    let tokenTotal = ckbAbcdeSummaryTokenTotalForGroup(lines, group)
    let turnTotal = ckbAbcdeSummaryTurnTotalForGroup(lines, group)
    "| ${group} | ${total} | ${passed} | ${total - passed} | ${passAt1} | ${ckbAbcdeAverageText(tokenTotal, usageOk)} | ${ckbAbcdeAverageText(turnTotal, usageOk)} | ${total - usageOk} |\n"
}

private func ckbAbcdeSummaryTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() == "") {
            continue
        }
        if (ckbAbcdeSummaryLineMatchesGroup(line, group)) {
            total += 1
        }
    }
    total
}

private func ckbAbcdeSummaryPassedForGroup(lines: Array<String>, group: String): Int64 {
    var passed: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"status\":\"passed\"")) {
            passed += 1
        }
    }
    passed
}

private func ckbAbcdeSummaryPassAt1ForGroup(lines: Array<String>, group: String): Int64 {
    var passAt1: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"unitPassAt1\":true")) {
            passAt1 += 1
        }
    }
    passAt1
}

private func ckbAbcdeSummaryUsageOkForGroup(lines: Array<String>, group: String): Int64 {
    var ok: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            ok += 1
        }
    }
    ok
}

private func ckbAbcdeSummaryTokenTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            total += ckbAbcdeJsonIntField(line, "modelTotalTokens", 0)
        }
    }
    total
}

private func ckbAbcdeSummaryTurnTotalForGroup(lines: Array<String>, group: String): Int64 {
    var total: Int64 = 0
    for (line in lines) {
        if (line.trimAscii() != "" && ckbAbcdeSummaryLineMatchesGroup(line, group) && line.contains("\"usageParseStatus\":\"ok\"")) {
            total += ckbAbcdeJsonIntField(line, "llmTurnCount", 0)
        }
    }
    total
}

private func ckbAbcdeSummaryLineMatchesGroup(line: String, group: String): Bool {
    group == "ALL" || line.contains("\"group\":\"${group}\"")
}

public func ckbAbcdeRenderEnvSwitchCheck(caseId: String, fromGroup: String, toGroup: String, workspace: String, groupRoot: String): String {
    let fromValue = if (fromGroup == "") { "START" } else { fromGroup }
    "{\"caseId\":\"${caseId}\",\"fromGroup\":\"${fromValue}\",\"toGroup\":\"${toGroup}\",\"cwd\":\"${ckbAbcdeJsonEscape(workspace)}\",\"mcpConfigPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/mcp-config.json")}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(toGroup)}\",\"toolTransport\":\"${ckbAbcdeToolTransport(toGroup)}\",\"cleanupAction\":\"fresh_group_workspace_and_strict_mcp_config\",\"ok\":true}\n".trimAscii()
}

public func ckbAbcdeRenderCaseResult(
    options: CkbAbcdeRunnerOptions,
    runRoot: String,
    caseId: String,
    group: String,
    status: String,
    claudeExitCode: Int64,
    testExitCode: Int64,
    unitPass: Bool,
    unitPassAt1: Bool,
    failureType: String,
    toolEvidence: String,
    violation: String,
    groupRoot: String
): String {
    let protocolViolation = violation != "none"
    let modelRunStatus = if (claudeExitCode == 0) { "ok" } else { "failed" }
    let toolCallCount = ckbAbcdeToolCallCount(group, toolEvidence)
    let firstClaudeExitCode = ckbAbcdeFirstClaudeAttemptExitCode(groupRoot)
    let claudeAttemptCount = ckbAbcdeClaudeAttemptCount(groupRoot)
    let usage = ckbAbcdeParseClaudeUsageFile("${groupRoot}/claude-transcript.jsonl")
    let explicitDevelopment = options.explicitRunMode && options.runMode == "development"
    let recordedRunMode = if (options.explicitRunMode) { options.runMode } else { "" }
    let workspaceId = "cases/${caseId}/${group}/workspace"
    let sessionId = "cases/${caseId}/${group}/session"
    let runtimeHomeId = "cases/${caseId}/${group}/runtime-home"
    let finalAttempt = if (claudeAttemptCount > 0) { claudeAttemptCount } else { 1 }
    let firstAttemptPass = unitPassAt1 && status == "passed"
    let triageEvidence = ckbAbcdeTriageEvidence(options, caseId, finalAttempt, failureType, unitPass, protocolViolation, claudeExitCode, testExitCode, groupRoot)
    let triage = if (options.explicitRunMode) { triageEvalFailure(triageEvidence) } else { CangjieEvalFailureTriageResult() }
    let triageStatus = if (!options.explicitRunMode) { "legacy" } else if (triage.ok) { triage.category } else { "blocked:${triage.diagnostic}" }
    let failureRoute = if (triage.ok) { triage.route } else { ckbAbcdeFailureRoute(failureType) }
    let firstAttemptTriage = if (firstAttemptPass) { "none" } else if (firstClaudeExitCode != 0) { "environment_failure" } else { triageStatus }
    let confirmationStatus = if (triage.ok && triage.category == "knowledge_gap") { "pending_classifier_artifacts" } else { "not_applicable" }
    let observedRuntimeModel = ckbAbcdeObservedModel(ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl"))
    let claudeCodeVersion = ckbAbcdeClaudeVersion()
    let canonicalProviderIdentity = ckbAbcdeProviderIdentityJson(observedRuntimeModel, claudeCodeVersion)
    let providerIdentityText = ckbAbcdeReadText("${groupRoot}/provider-identity.json")
    let providerIdentityHash = if (providerIdentityText == "") { "" } else { benchmarkGapSha256(providerIdentityText) }
    let identityReady = observedRuntimeModel == options.expectedModelVersion && providerIdentityText == canonicalProviderIdentity && ckbAbcdeStrictSha256(providerIdentityHash)
    let developmentPass = explicitDevelopment && status == "passed" && identityReady
    let closureStatus = if (!options.explicitRunMode) { "legacy" } else if (options.runMode == "certification") { "certification_not_run" } else if (developmentPass && triage.ok && triage.category == "none") { "development_closed" } else { "development_open" }
    "{\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"benchmark\":\"Cangjie-HumanEval\",\"runMode\":\"${ckbAbcdeJsonEscape(recordedRunMode)}\",\"datasetVersion\":\"${ckbAbcdeJsonEscape(options.datasetVersion)}\",\"candidateVersion\":\"${ckbAbcdeJsonEscape(options.candidateVersion)}\",\"lineageKnowledgeVersion\":\"${ckbAbcdeJsonEscape(options.knowledgeVersion)}\",\"modelFingerprint\":\"${ckbAbcdeJsonEscape(options.modelFingerprint)}\",\"workspaceId\":\"${ckbAbcdeJsonEscape(workspaceId)}\",\"sessionId\":\"${ckbAbcdeJsonEscape(sessionId)}\",\"runtimeHomeId\":\"${ckbAbcdeJsonEscape(runtimeHomeId)}\",\"developmentPass\":${developmentPass},\"firstAttemptPass\":${firstAttemptPass},\"firstAttemptTriage\":\"${ckbAbcdeJsonEscape(firstAttemptTriage)}\",\"knowledgeGapConfirmationStatus\":\"${confirmationStatus}\",\"certificationPassAt1\":null,\"closureStatus\":\"${closureStatus}\",\"triageStatus\":\"${ckbAbcdeJsonEscape(triageStatus)}\",\"failureRoute\":\"${failureRoute}\",\"caseId\":\"${caseId}\",\"group\":\"${group}\",\"expectedModelVersion\":\"${ckbAbcdeJsonEscape(options.expectedModelVersion)}\",\"observedModelVersion\":\"${ckbAbcdeJsonEscape(observedRuntimeModel)}\",\"model\":\"${ckbAbcdeJsonEscape(observedRuntimeModel)}\",\"claudeCodeVersion\":\"${ckbAbcdeJsonEscape(claudeCodeVersion)}\",\"providerIdentityHash\":\"${ckbAbcdeJsonEscape(providerIdentityHash)}\",\"knowledgeEntry\":\"${ckbAbcdeKnowledgeEntry(group)}\",\"preflightStatus\":\"ok\",\"modelRunStatus\":\"${modelRunStatus}\",\"status\":\"${status}\",\"claudeExitCode\":${claudeExitCode},\"firstClaudeExitCode\":${firstClaudeExitCode},\"claudeAttemptCount\":${claudeAttemptCount},\"testExitCode\":${testExitCode},\"unitPass\":${unitPass},\"unitPassAt1\":${unitPassAt1},\"failureType\":\"${failureType}\",\"usageParseStatus\":\"${usage.usageParseStatus}\",\"modelInputTokens\":${usage.modelInputTokens},\"modelOutputTokens\":${usage.modelOutputTokens},\"modelCacheReadTokens\":${usage.modelCacheReadTokens},\"modelCacheCreationTokens\":${usage.modelCacheCreationTokens},\"modelTotalTokens\":${usage.modelTotalTokens},\"llmTurnCount\":${usage.llmTurnCount},\"usageSourcePath\":\"${ckbAbcdeJsonEscape(usage.usageSourcePath)}\",\"ckbUsed\":${ckbAbcdeUsesCkb(group)},\"localDocsUsed\":${group == CkbAbcdeGroups.E},\"toolTransport\":\"${ckbAbcdeToolTransport(group)}\",\"toolCallCount\":${toolCallCount},\"toolEvidence\":\"${ckbAbcdeJsonEscape(toolEvidence)}\",\"toolEvidenceHash\":\"${ckbAbcdeJsonEscape(ckbAbcdeEvidenceHash(groupRoot))}\",\"toolCoveragePass\":${ckbAbcdeCoveragePass(groupRoot)},\"transportParityPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/parity.jsonl")}\",\"knowledgeVersion\":\"${ckbAbcdeJsonEscape(ckbAbcdeKnowledgeVersion(groupRoot))}\",\"citationCount\":${ckbAbcdeCitationCount(groupRoot)},\"docsPathCount\":${if (group == CkbAbcdeGroups.E) { 2 } else { 0 }},\"protocolViolation\":${protocolViolation},\"protocolViolationReason\":\"${ckbAbcdeJsonEscape(violation)}\",\"durationMs\":0,\"promptPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/prompt.final.md")}\",\"transcriptPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/claude-transcript.jsonl")}\",\"testLogPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/test.log")}\",\"resultPath\":\"${ckbAbcdeJsonEscape("${groupRoot}/case-result.json")}\",\"notes\":\"${ckbAbcdeJsonEscape(ckbAbcdeResultNotes(status, violation, toolEvidence))}\"}"
}

private func ckbAbcdeTriageEvidence(options: CkbAbcdeRunnerOptions, caseId: String, attempt: Int64, failureType: String, unitPass: Bool, protocolViolation: Bool, claudeExitCode: Int64, testExitCode: Int64, groupRoot: String): String {
    let timedOut = claudeExitCode == 124
    let environmentFailure = claudeExitCode != 0 && !timedOut
    let reasoningFailure = !unitPass && claudeExitCode == 0 && testExitCode != 0
    let observation = if (failureType == "none") { "case_passed" } else { failureType }
    let firstRetrieval = ckbAbcdeReadText("${groupRoot}/claude-transcript.attempt-1.jsonl")
    let taskContext = ckbAbcdeReadText("${groupRoot}/canonical-task-context.json")
    let structuredMissing = ckbAbcdeHasBoundStructuredMissingEvidence(caseId, taskContext, firstRetrieval)
    let coverageCompilerConflict = ckbAbcdeHasBoundStructuredCoveragePass(caseId, taskContext, firstRetrieval) && ckbAbcdeReadText("${groupRoot}/test.log").toAsciiLower().contains("is not a member of")
    let suspectedKnowledgeGap = options.runMode == "development" && failureType == "compile_error" && !unitPass && !protocolViolation && claudeExitCode == 0 && testExitCode != 0 && (structuredMissing || coverageCompilerConflict)
    let retrievalDiagnostic = if (structuredMissing && suspectedKnowledgeGap) { "structured_missing_evidence" } else if (coverageCompilerConflict && suspectedKnowledgeGap) { "coverage_compiler_member_conflict" } else { "not_applicable" }
    let retrievalEvidenceHash = if (suspectedKnowledgeGap) { benchmarkGapSha256(taskContext + firstRetrieval) } else { "" }
    let base = "{\"caseId\":\"${ckbAbcdeJsonEscape(caseId)}\",\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"datasetVersion\":\"${ckbAbcdeJsonEscape(options.datasetVersion)}\",\"attempt\":${attempt},\"runMode\":\"${ckbAbcdeJsonEscape(options.runMode)}\",\"failureObservation\":\"${ckbAbcdeJsonEscape(observation)}\",\"protocolViolation\":${protocolViolation},\"timedOut\":${timedOut},\"environmentFailure\":${environmentFailure},\"suspectedKnowledgeGap\":${suspectedKnowledgeGap},\"retrievalDiagnostic\":\"${retrievalDiagnostic}\",\"retrievalEvidenceHash\":\"${retrievalEvidenceHash}\",\"reasoningFailure\":${reasoningFailure && !suspectedKnowledgeGap},\"failureType\":\"${ckbAbcdeJsonEscape(failureType)}\",\"unitPass\":${unitPass}}"
    let hash = cangjieEvalTriageResultEvidenceHash(base)
    base.replace("}", ",\"resultEvidenceHash\":\"${hash}\"}")
}

private func ckbAbcdeHasBoundStructuredCoveragePass(caseId: String, taskContext: String, transcript: String): Bool {
    if (caseId == "" || !taskContext.contains("\"taskId\":\"${ckbAbcdeJsonEscape(caseId)}\"") || transcript == "") { return false }
    for (line in transcript.split("\n")) {
        if (!line.contains("\"type\":\"user\"") || !line.contains("\"type\":\"tool_result\"")) { continue }
        try {
            _ = JsonValue.fromStr(line).asObject()
            if (line.contains("\\\"coveragePass\\\":true") || line.contains("\"coveragePass\":true")) { return true }
        } catch (_: Exception) {}
    }
    false
}

private func ckbAbcdeHasBoundStructuredMissingEvidence(caseId: String, taskContext: String, transcript: String): Bool {
    if (caseId == "" || !taskContext.contains("\"taskId\":\"${ckbAbcdeJsonEscape(caseId)}\"") || transcript == "") { return false }
    for (line in transcript.split("\n")) {
        if (!line.contains("\"type\":\"user\"") || !line.contains("\"type\":\"tool_result\"")) { continue }
        try {
            _ = JsonValue.fromStr(line).asObject()
            let citationMissing = line.contains("\\\"diagnostic\\\":\\\"missing_citation\\\"") || line.contains("\"diagnostic\":\"missing_citation\"")
            let evidenceMissing = line.contains("\\\"reason\\\":\\\"evidence_missing\\\"") || line.contains("\"reason\":\"evidence_missing\"") || line.contains("\\\"missingReason\\\":\\\"evidence_missing\\\"") || line.contains("\"missingReason\":\"evidence_missing\"")
            let coverageMissing = (line.contains("\\\"coveragePass\\\":false") || line.contains("\"coveragePass\":false")) && (line.contains("\\\"status\\\":\\\"missing\\\"") || line.contains("\"status\":\"missing\"") || line.contains("\\\"missingCount\\\":") || line.contains("\"missingCount\":"))
            if (citationMissing || evidenceMissing || coverageMissing) { return true }
        } catch (_: Exception) {}
    }
    false
}

public func ckbAbcdeHasBoundStructuredMissingEvidenceForTest(caseId: String, taskContext: String, transcript: String): Bool {
    ckbAbcdeHasBoundStructuredMissingEvidence(caseId, taskContext, transcript)
}

public func ckbAbcdeTriageEvidenceForTest(options: CkbAbcdeRunnerOptions, caseId: String, attempt: Int64, failureType: String, unitPass: Bool, protocolViolation: Bool, claudeExitCode: Int64, testExitCode: Int64, groupRoot: String): String {
    ckbAbcdeTriageEvidence(options, caseId, attempt, failureType, unitPass, protocolViolation, claudeExitCode, testExitCode, groupRoot)
}

private func ckbAbcdeRenderCaseSummary(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, summaries: ArrayList<String>): String {
    var rows = ""
    var failed: Int64 = 0
    var violations: Int64 = 0
    var usageOk: Int64 = 0
    var tokenTotal: Int64 = 0
    var turnTotal: Int64 = 0
    var usageFailedGroups = ""
    for (i in 0..summaries.size) {
        if (i > 0) {
            rows += ","
        }
        rows += summaries[i]
        if (summaries[i].contains("\"status\":\"failed\"")) {
            failed += 1
        }
        if (summaries[i].contains("\"protocolViolation\":true")) {
            violations += 1
        }
        if (summaries[i].contains("\"usageParseStatus\":\"ok\"")) {
            usageOk += 1
            tokenTotal += ckbAbcdeJsonIntField(summaries[i], "modelTotalTokens", 0)
            turnTotal += ckbAbcdeJsonIntField(summaries[i], "llmTurnCount", 0)
        } else {
            if (usageFailedGroups != "") {
                usageFailedGroups += ","
            }
            usageFailedGroups += "\"${ckbAbcdeJsonEscape(ckbAbcdeJsonStringField(summaries[i], "group"))}\""
        }
    }
    "{\"runId\":\"${ckbAbcdeJsonEscape(options.runId)}\",\"caseId\":\"${caseId}\",\"benchmark\":\"Cangjie-HumanEval\",\"completedGroups\":${summaries.size},\"failedGroups\":${failed},\"protocolViolationGroups\":${violations},\"usageParseOkGroupCount\":${usageOk},\"caseTotalModelTokens\":${tokenTotal},\"caseAverageModelTokensPerGroup\":${ckbAbcdeAverageText(tokenTotal, usageOk)},\"caseTotalLlmTurns\":${turnTotal},\"caseAverageLlmTurnsPerGroup\":${ckbAbcdeAverageText(turnTotal, usageOk)},\"usageParseFailedGroups\":[${usageFailedGroups}],\"resultRows\":[${rows}],\"caseResultPaths\":\"${ckbAbcdeJsonEscape("${runRoot}/cases/${caseId}")}\",\"envSwitchChecksPath\":\"${ckbAbcdeJsonEscape("${runRoot}/cases/${caseId}/env-switch-checks.jsonl")}\"}\n"
}

private func ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId: String, summaries: ArrayList<String>): String {
    var usageOk: Int64 = 0
    var tokenTotal: Int64 = 0
    var turnTotal: Int64 = 0
    var failedGroups = ""
    for (summary in summaries) {
        if (summary.contains("\"usageParseStatus\":\"ok\"")) {
            usageOk += 1
            tokenTotal += ckbAbcdeJsonIntField(summary, "modelTotalTokens", 0)
            turnTotal += ckbAbcdeJsonIntField(summary, "llmTurnCount", 0)
        } else {
            if (failedGroups != "") {
                failedGroups += "|"
            }
            failedGroups += ckbAbcdeJsonStringField(summary, "group")
        }
    }
    "${caseId},${usageOk},${tokenTotal},${ckbAbcdeAverageText(tokenTotal, usageOk)},${turnTotal},${ckbAbcdeAverageText(turnTotal, usageOk)},${failedGroups}"
}

public func ckbAbcdeRenderCaseSummaryForTest(options: CkbAbcdeRunnerOptions, runRoot: String, caseId: String, summaries: ArrayList<String>): String {
    ckbAbcdeRenderCaseSummary(options, runRoot, caseId, summaries)
}

public func ckbAbcdeRenderCaseUsageSummaryCsvRowForTest(caseId: String, summaries: ArrayList<String>): String {
    ckbAbcdeRenderCaseUsageSummaryCsvRow(caseId, summaries)
}

private func ckbAbcdeToolEvidence(group: String, transcript: String): String {
    if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        for (line in transcript.split("\n")) {
            if (line.contains("\"subtype\":\"init\"")) {
                continue
            }
            if (line.contains("mcp__ckb-cangjie__cangjie_task_knowledge_pack") ||
                line.contains("mcp__ckb-cangjie-http__cangjie_task_knowledge_pack") ||
                line.contains("\"name\":\"cangjie_task_knowledge_pack\"")) {
                return "cangjie_task_knowledge_pack"
            }
        }
        return "manual_required"
    }
    "none"
}

public func ckbAbcdeToolEvidenceForTest(group: String, transcript: String): String {
    ckbAbcdeToolEvidence(group, transcript)
}

private func ckbAbcdeKnowledgeEntry(group: String): String {
    if (group == CkbAbcdeGroups.B) { return "ckb_rest" }
    if (group == CkbAbcdeGroups.C) { return "mcp_stdio" }
    if (group == CkbAbcdeGroups.D) { return "mcp_http" }
    if (group == CkbAbcdeGroups.E) { return "local_docs" }
    "none"
}

private func ckbAbcdeToolTransport(group: String): String {
    if (group == CkbAbcdeGroups.C) { return "stdio" }
    if (group == CkbAbcdeGroups.D) { return "streamable_http" }
    "none"
}

private func ckbAbcdeUsesCkb(group: String): Bool {
    group == CkbAbcdeGroups.B || group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D
}

private func ckbAbcdeToolCallCount(group: String, toolEvidence: String): Int64 {
    if ((group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) && toolEvidence == "cangjie_task_knowledge_pack") {
        return 1
    }
    0
}

private func ckbAbcdeRequiredKnowledgeReady(group: String, knowledgeReady: Bool, toolEvidence: String): Bool {
    if (group == CkbAbcdeGroups.B) {
        return knowledgeReady
    }
    if (group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) {
        return toolEvidence == "cangjie_task_knowledge_pack"
    }
    true
}

private func ckbAbcdeFailureType(claudeExitCode: Int64, testExitCode: Int64, unitPass: Bool, violation: String, testLog: String, toolReady: Bool): String {
    if (violation != "none") {
        return "protocol_violation"
    }
    if (claudeExitCode == 124) {
        return "timeout"
    }
    if (!toolReady) {
        return "tool_unavailable"
    }
    if (claudeExitCode != 0) {
        return "model_error"
    }
    if (unitPass) {
        return "none"
    }
    let lowered = testLog.toAsciiLower()
    if (testExitCode != 0 && (lowered.contains("compile") || lowered.contains("syntax") || lowered.contains("error:"))) {
        return "compile_error"
    }
    "unit_failure"
}

public func ckbAbcdeExpandedFailureType(legacy: String): String {
    if (legacy == "protocol_violation") { return "policy_violation" }
    if (legacy == "tool_unavailable") { return "tool_failure" }
    if (legacy == "model_error") { return "environment_failure" }
    if (legacy == "unit_failure") { return "test_failure" }
    legacy
}

public func ckbAbcdeDevelopmentOptionsDiagnostic(options: CkbAbcdeRunnerOptions): String {
    if (!options.explicitRunMode) { return "" }
    if (options.runMode != "development" && options.runMode != "certification") { return "run_mode_invalid" }
    if (options.datasetVersion.trimAscii() == "" || options.knowledgeVersion.trimAscii() == "" || options.modelFingerprint.trimAscii() == "") { return "frozen_lineage_required" }
    if (options.runMode == "development" && options.candidateVersion.trimAscii() == "") { return "candidate_version_required" }
    if (options.runMode == "development" && options.expectedModelVersion != "GLM-5.2") { return "development_requires_glm_5_2" }
    if (options.runMode == "development" && ckbAbcdeModelEffortDiagnostic(options.modelEffort) != "ok") { return ckbAbcdeModelEffortDiagnostic(options.modelEffort) }
    if (options.runMode == "certification") {
        if (options.modelEffortExplicit || options.modelMaxBudgetUsdExplicit) { return "certification_forbids_development_transport_profile" }
        if (options.caseStart != 0 || options.caseEnd != 163) { return "certification_requires_full_164" }
        if (options.groups.size != 1 || (options.groups[0] != CkbAbcdeGroups.C && options.groups[0] != CkbAbcdeGroups.D)) { return "certification_requires_single_frozen_treatment_transport" }
        if (options.skipClaude || options.preflightOnly) { return "certification_requires_real_model_execution" }
        if (ckbCertificationBudgetDiagnostic(ckbAbcdeCertificationBudget(options)) != "ok") { return ckbCertificationBudgetDiagnostic(ckbAbcdeCertificationBudget(options)) }
        if (!parseCangjieHumanEvalAuthorityManifest(ckbAbcdeReadText(options.manifestPath)).ok) { return "certification_requires_authority_manifest" }
        if (options.certificationPreflightPath == "" || options.certificationRunManifestPath == "") { return "certification_requires_p6_artifacts" }
        if (options.expectedModelVersion == "") { return "certification_requires_exact_model_version" }
        if (!ckbAbcdeStrictSha256(options.providerIdentityHash)) { return "certification_requires_provider_identity_hash" }
        if(options.providerIdentityArtifactPath==""){return "certification_requires_provider_identity_artifact"}
    }
    ""
}

// Certification never falls through to the legacy development preflight. The
// trusted P6 artifacts are immutable inputs, while this run root must be fresh.
public func ckbAbcdeCertificationEntryDiagnostic(options: CkbAbcdeRunnerOptions, runRoot: String): String {
    if (options.runMode != "certification") { return "ok" }
    if (!exists(Path(options.certificationPreflightPath)) || !exists(Path(options.certificationRunManifestPath))) { return "p6_artifact_missing" }
    if(!exists(Path(options.providerIdentityArtifactPath))||benchmarkGapSha256(ckbAbcdeReadText(options.providerIdentityArtifactPath))!=options.providerIdentityHash){return "provider_identity_artifact_invalid"}
    let p6 = cangjieCertificationReleaseGateIntegrated(options.certificationPreflightPath, options.certificationRunManifestPath)
    if (!p6.ok) { return "p6_artifact_verification_failed" }
    try {
        let manifest = JsonValue.fromStr(ckbAbcdeReadText(options.certificationRunManifestPath)).asObject()
        if (ckbAbcdeStrictJsonString(manifest, "runId") != options.runId) { return "p6_run_identity_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest, "fingerprint") != options.modelFingerprint) { return "p6_fingerprint_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest,"providerIdentityHash")!=options.providerIdentityHash) { return "p6_provider_identity_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest,"modelVersion")!=options.expectedModelVersion) { return "p6_model_identity_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest,"certificationTransport")!=options.groups[0]) { return "p6_transport_mismatch" }
        if (ckbAbcdeStrictJsonString(manifest,"claudeCodeVersion")!=ckbAbcdeClaudeVersion()) { return "p6_claude_version_drift" }
        let provider=JsonValue.fromStr(ckbAbcdeReadText(options.providerIdentityArtifactPath)).asObject();if(ckbAbcdeStrictJsonString(provider,"model")!=options.expectedModelVersion||ckbAbcdeStrictJsonString(provider,"claudeCodeVersion")!=ckbAbcdeClaudeVersion()||ckbAbcdeStrictJsonString(provider,"provider")==""){return "provider_runtime_identity_mismatch"}
    } catch (_: Exception) { return "p6_manifest_malformed" }
    let authority = parseCangjieHumanEvalAuthorityManifest(ckbAbcdeReadText(options.manifestPath))
    if (!authority.ok || authority.rows.size != 164) { return "authority_manifest_invalid" }
    if (exists(Path(runRoot))) {
        try { for (_ in Directory.readFrom(Path(runRoot))) { return "certification_run_root_not_empty" } }
        catch (_: Exception) { return "certification_run_root_unreadable" }
    }
    "ok"
}

private func ckbAbcdeStrictJsonString(object: JsonObject, key: String): String {
    match (object.get(key)) { case Some(value) => value.asString().getValue(); case None => "" }
}
private func ckbAbcdeStrictJsonBool(object:JsonObject,key:String):Bool{match(object.get(key)){case Some(value)=>value.asBool().getValue();case None=>false}}
private func ckbAbcdeStrictJsonInt(object:JsonObject,key:String,fallback:Int64):Int64{match(object.get(key)){case Some(value)=>value.asInt().getValue();case None=>fallback}}
private func ckbAbcdeStrictSha256(value:String):Bool{let runes=value.toRuneArray();if(runes.size!=71||!value.startsWith("sha256:")){return false};for(i in 7..71){let c=runes[i];if(!((c>=r'0'&&c<=r'9')||(c>=r'a'&&c<=r'f'))){return false}};true}

public func ckbAbcdeFailureRoute(failureType: String): String {
    if (failureType == "knowledge_gap") { return "knowledge_candidate_pending_independent_triage" }
    if (failureType == "reasoning_error") { return "model_capability" }
    if (failureType == "dataset_defect") { return "dataset_repair" }
    if (failureType == "tool_failure" || failureType == "timeout" || failureType == "environment_failure") { return "infrastructure_repair" }
    if (failureType == "policy_violation") { return "policy_blocked" }
    if (failureType == "none") { return "closed" }
    "functional_repair"
}

public func ckbAbcdeIsolationDiagnostic(caseId: String, workspaceId: String, sessionId: String, runtimeHomeId: String, previousCaseId: String, previousWorkspaceId: String, previousSessionId: String, previousRuntimeHomeId: String): String {
    if (caseId.trimAscii() == "" || workspaceId.trimAscii() == "" || sessionId.trimAscii() == "" || runtimeHomeId.trimAscii() == "") { return "isolation_identity_required" }
    if (previousCaseId != "" && previousCaseId != caseId && (workspaceId == previousWorkspaceId || sessionId == previousSessionId || runtimeHomeId == previousRuntimeHomeId)) { return "cross_case_isolation_reuse" }
    ""
}

public func ckbAbcdeFailureTypeForTest(claudeExitCode: Int64, testExitCode: Int64, unitPass: Bool, violation: String, testLog: String, toolReady: Bool): String {
    ckbAbcdeFailureType(claudeExitCode, testExitCode, unitPass, violation, testLog, toolReady)
}

private func ckbAbcdeResultNotes(status: String, violation: String, toolEvidence: String): String {
    if (violation != "none") {
        return violation
    }
    if (toolEvidence == "manual_required") {
        return "tool evidence requires manual transcript review"
    }
    if (status == "failed") {
        return "see transcript and test log"
    }
    ""
}

private func ckbAbcdeClaudeVersion(): String {
    let result = ckbAbcdeRunShell("claude --version 2>/dev/null | head -n1", "")
    result.stdout.trimAscii()
}

public func ckbAbcdeClaudeVersionForTest(): String { ckbAbcdeClaudeVersion() }

private func ckbAbcdeKnowledgeVersion(groupRoot: String): String {
    let text = ckbAbcdeReadText("${groupRoot}/ckb-task-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-context-pack.json") +
        ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl") +
        ckbAbcdeReadText("${groupRoot}/claude.stdout.log")
    ckbAbcdeJsonStringField(text, "knowledgeVersion")
}

private func ckbAbcdeCitationCount(groupRoot: String): Int64 {
    ckbAbcdeCountOccurrences(ckbAbcdeReadText("${groupRoot}/ckb-task-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-context-pack.json") +
        ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl"), "\"citation\"")
}

private func ckbAbcdeEvidenceHash(groupRoot: String): String {
    ckbAbcdeJsonStringField(ckbAbcdeReadText("${groupRoot}/parity.jsonl") +
        ckbAbcdeReadText("${groupRoot}/ckb-task-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-context-pack.json") +
        ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl") +
        ckbAbcdeReadText("${groupRoot}/claude.stdout.log"), "evidenceHash")
}

private func ckbAbcdeCoveragePass(groupRoot: String): Bool {
    (ckbAbcdeReadText("${groupRoot}/parity.jsonl") +
        ckbAbcdeReadText("${groupRoot}/ckb-task-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-knowledge-pack.json") +
        ckbAbcdeReadText("${groupRoot}/ckb-context-pack.json") +
        ckbAbcdeReadText("${groupRoot}/claude-transcript.jsonl") +
        ckbAbcdeReadText("${groupRoot}/claude.stdout.log")).contains("\"coveragePass\":true")
}

private func ckbAbcdeCountOccurrences(text: String, needle: String): Int64 {
    if (needle == "" || text.size < needle.size) {
        return 0
    }
    let parts = text.split(needle)
    if (parts.size <= 1) { 0 } else { parts.size - 1 }
}

private func ckbAbcdeJsonStringField(text: String, field: String): String {
    let marker = "\"${field}\":\""
    let parts = text.split(marker)
    if (parts.size <= 1) {
        return ""
    }
    let tail = parts[1]
    let values = tail.split("\"")
    if (values.size > 0) { values[0] } else { "" }
}

public func ckbAbcdeJsonStringFieldForTest(text: String, field: String): String {
    ckbAbcdeJsonStringField(text, field)
}

public func ckbAbcdeCountOccurrencesForTest(text: String, needle: String): Int64 {
    ckbAbcdeCountOccurrences(text, needle)
}

private func ckbAbcdeUnitPassAt1(unitPass: Bool, groupRoot: String): Bool {
    if (!unitPass) { return false }
    let attempts = ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl")
    if (attempts.contains("\"sampleAttempt\":")) { return ckbAbcdeSampleAttemptCount(groupRoot) == 1 }
    ckbAbcdeFirstClaudeAttemptExitCodeFromText(attempts) == 0
}

private func ckbAbcdeFirstClaudeAttemptExitCode(groupRoot: String): Int64 {
    ckbAbcdeFirstClaudeAttemptExitCodeFromText(ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl"))
}

private func ckbAbcdeClaudeAttemptCount(groupRoot: String): Int64 {
    var count: Int64 = 0
    for (line in ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl").split("\n")) {
        if (line.contains("\"attempt\":")) {
            count += 1
        }
    }
    count
}

private func ckbAbcdeSampleAttemptCount(groupRoot: String): Int64 {
    var count: Int64 = 0
    for (line in ckbAbcdeReadText("${groupRoot}/claude-attempts.jsonl").split("\n")) {
        if (ckbAbcdeJsonIntField(line, "sampleAttempt", 0) > count) { count = ckbAbcdeJsonIntField(line, "sampleAttempt", 0) }
    }
    count
}

private func ckbAbcdeWorkspaceRestoreEvidenceHash(groupRoot: String): String {
    let evidence = ckbAbcdeReadText("${groupRoot}/workspace-restores.jsonl")
    if (evidence == "") { "" } else { benchmarkGapSha256(evidence) }
}

private func ckbAbcdeFirstClaudeAttemptExitCodeFromText(attempts: String): Int64 {
    for (line in attempts.split("\n")) {
        if (line.contains("\"attempt\":1")) {
            return ckbAbcdeJsonIntField(line, "exitCode", -1)
        }
    }
    -1
}

private func ckbAbcdeJsonIntField(text: String, field: String, fallback: Int64): Int64 {
    let parts = text.split("\"${field}\":")
    if (parts.size <= 1) {
        return fallback
    }
    var raw = parts[1]
    let commaParts = raw.split(",")
    if (commaParts.size > 0) {
        raw = commaParts[0]
    }
    let braceParts = raw.split("}")
    if (braceParts.size > 0) {
        raw = braceParts[0]
    }
    ckbAbcdeParseInt(raw.trimAscii(), fallback)
}

private func ckbAbcdeParseClaudeUsageFile(path: String): CkbAbcdeUsageStats {
    ckbAbcdeParseClaudeUsageFromText(ckbAbcdeReadText(path), path)
}

public func ckbAbcdeParseClaudeUsageFromText(transcript: String, sourcePath: String): CkbAbcdeUsageStats {
    let stats = CkbAbcdeUsageStats()
    stats.usageSourcePath = sourcePath
    var resultLine = ""
    for (line in transcript.split("\n")) {
        if (ckbAbcdeTranscriptLineIsResult(line)) {
            resultLine = line
        }
    }
    if (resultLine == "") {
        stats.usageParseStatus = "missing_result"
        return stats
    }

    let inputTokens = ckbAbcdeJsonIntFieldAny(resultLine, "input_tokens", "inputTokens", "modelInputTokens", -1)
    let outputTokens = ckbAbcdeJsonIntFieldAny(resultLine, "output_tokens", "outputTokens", "modelOutputTokens", -1)
    let cacheReadTokens = ckbAbcdeJsonIntFieldAny(resultLine, "cache_read_input_tokens", "cacheReadInputTokens", "modelCacheReadTokens", 0)
    let cacheCreationTokens = ckbAbcdeJsonIntFieldAny(resultLine, "cache_creation_input_tokens", "cacheCreationInputTokens", "modelCacheCreationTokens", 0)
    let explicitTotal = ckbAbcdeJsonIntFieldAny(resultLine, "total_tokens", "totalTokens", "modelTotalTokens", -1)
    let turns = ckbAbcdeJsonIntFieldAny(resultLine, "num_turns", "numTurns", "llmTurnCount", -1)

    let computedTotal = ckbAbcdeNonNegative(inputTokens) + ckbAbcdeNonNegative(outputTokens) + cacheReadTokens + cacheCreationTokens
    let total = if (explicitTotal >= 0) { explicitTotal } else { computedTotal }
    if (turns < 0 || total <= 0 || inputTokens < 0 || outputTokens < 0) {
        stats.usageParseStatus = "missing_usage"
        return stats
    }

    stats.usageParseStatus = "ok"
    stats.modelInputTokens = inputTokens
    stats.modelOutputTokens = outputTokens
    stats.modelCacheReadTokens = cacheReadTokens
    stats.modelCacheCreationTokens = cacheCreationTokens
    stats.modelTotalTokens = total
    stats.llmTurnCount = turns
    stats
}

public func ckbAbcdeRenderUsageJson(stats: CkbAbcdeUsageStats): String {
    "{\"usageParseStatus\":\"${stats.usageParseStatus}\",\"modelInputTokens\":${stats.modelInputTokens},\"modelOutputTokens\":${stats.modelOutputTokens},\"modelCacheReadTokens\":${stats.modelCacheReadTokens},\"modelCacheCreationTokens\":${stats.modelCacheCreationTokens},\"modelTotalTokens\":${stats.modelTotalTokens},\"llmTurnCount\":${stats.llmTurnCount},\"usageSourcePath\":\"${ckbAbcdeJsonEscape(stats.usageSourcePath)}\"}"
}

private func ckbAbcdeTranscriptLineIsResult(line: String): Bool {
    (line.contains("\"type\":\"result\"") || line.contains("\"type\": \"result\"")) &&
        !line.contains("\"subtype\":\"init\"")
}

private func ckbAbcdeJsonIntFieldAny(text: String, fieldA: String, fieldB: String, fieldC: String, fallback: Int64): Int64 {
    let a = ckbAbcdeJsonIntField(text, fieldA, fallback)
    if (a != fallback) {
        return a
    }
    let b = ckbAbcdeJsonIntField(text, fieldB, fallback)
    if (b != fallback) {
        return b
    }
    ckbAbcdeJsonIntField(text, fieldC, fallback)
}

private func ckbAbcdeNonNegative(value: Int64): Int64 {
    if (value < 0) { 0 } else { value }
}

private func ckbAbcdeAverageText(total: Int64, count: Int64): String {
    if (count <= 0) {
        return "null"
    }
    let whole = total / count
    let remainder = total % count
    if (remainder == 0) {
        return "${whole}"
    }
    let tenth = (remainder * 10) / count
    "${whole}.${tenth}"
}

public func ckbAbcdeAverageTextForTest(total: Int64, count: Int64): String {
    ckbAbcdeAverageText(total, count)
}

public func ckbAbcdeUnitPassAt1FromAttemptsForTest(unitPass: Bool, attempts: String): Bool {
    if (!unitPass) { return false }
    for (line in attempts.split("\n")) {
        if (ckbAbcdeJsonIntField(line, "sampleAttempt", 0) == 1) { return true }
    }
    // Compatibility for historical artifacts written before sampleAttempt existed.
    ckbAbcdeFirstClaudeAttemptExitCodeFromText(attempts) == 0
}

private func ckbAbcdeTestLogContainsFailure(testLog: String): Bool {
    testLog.contains("CangjieEval failure") ||
        testLog.contains("An exception has occurred") ||
        testLog.contains("FAILED") ||
        testLog.contains("Error: cjpm run failed")
}

private func ckbAbcdeForbiddenEvidence(group: String, transcript: String): String {
    let lowered = transcript.toAsciiLower()
    if (group == CkbAbcdeGroups.A && (lowered.contains("cangjie_knowledge_pack") || lowered.contains("cangjie_task_knowledge_pack") || lowered.contains("/v1/cangjie") || lowered.contains("cangjie_docs-release"))) {
        return "forbidden_knowledge_entry"
    }
    if (group == CkbAbcdeGroups.B && (lowered.contains("mcp__") || lowered.contains("cangjie_docs-release"))) {
        return "forbidden_tool_or_docs_entry"
    }
    if ((group == CkbAbcdeGroups.C || group == CkbAbcdeGroups.D) && lowered.contains("cangjie_docs-release")) {
        return "forbidden_local_docs_entry"
    }
    if (group == CkbAbcdeGroups.E && (lowered.contains("mcp__") || lowered.contains("/v1/cangjie"))) {
        return "forbidden_ckb_entry"
    }
    if (group == CkbAbcdeGroups.E) {
        let eViolation = ckbAbcdeForbiddenLocalDocsEvidence(transcript)
        if (eViolation != "none") {
            return eViolation
        }
    }
    "none"
}

public func ckbAbcdeForbiddenEvidenceForTest(group: String, transcript: String): String {
    ckbAbcdeForbiddenEvidence(group, transcript)
}

private func ckbAbcdeForbiddenLocalDocsEvidence(transcript: String): String {
    for (line in transcript.split("\n")) {
        let lowered = line.toAsciiLower()
        if (lowered.contains("\"type\":\"tool_use\"") &&
            (lowered.contains("\"name\":\"webfetch\"") || lowered.contains("\"name\":\"websearch\"") ||
             lowered.contains("\"name\":\"task\"") || lowered.contains("\"name\":\"askuserquestion\""))) {
            return "forbidden_e_tool_use"
        }
    }
    "none"
}

private func ckbAbcdeRunShell(script: String, cwd: String): CkbAbcdeCommandResult {
    let result = CkbAbcdeCommandResult()
    let finalScript = if (cwd == "") { script } else { "cd ${ckbAbcdeShellQuote(cwd)} && ${script}" }
    try {
        let process = launch("/bin/zsh", ["-lc", finalScript], stdOut: ProcessRedirect.Pipe, stdErr: ProcessRedirect.Pipe)
        result.stdout = ckbAbcdeSafeReadPipe(process.stdOutPipe)
        result.stderr = ckbAbcdeSafeReadPipe(process.stdErrPipe)
        result.exitCode = process.wait()
    } catch (e: Exception) {
        result.exitCode = 127
        result.stderr = "launch_failed"
    }
    result
}

private func ckbAbcdeSafeReadPipe(pipe: InputStream): String {
    try {
        StringReader<InputStream>(pipe).readToEnd()
    } catch (_: Exception) {
        "invalid_response_encoding"
    }
}

private func ckbAbcdeReadText(path: String): String {
    try {
        String.fromUtf8(File.readFrom(Path(path)))
    } catch (_: Exception) {
        ""
    }
}

private func ckbAbcdeWriteText(path: String, text: String): Unit {
    let target = Path(path)
    if (!exists(target.parent)) {
        Directory.create(target.parent, recursive: true)
    }
    File.writeTo(target, text.toArray())
}

private func ckbAbcdeAppendText(path: String, text: String): Unit {
    let existing = if (exists(Path(path))) { ckbAbcdeReadText(path) } else { "" }
    ckbAbcdeWriteText(path, existing + text)
}

private func ckbAbcdeEnsureDir(path: String): Unit {
    if (!exists(Path(path))) {
        Directory.create(Path(path), recursive: true)
    }
}

private func ckbAbcdeCaseLayoutOk(datasetRoot: String): Bool {
    for (i in 0..164) {
        let caseRoot = "${datasetRoot}/${ckbAbcdeCaseId(i)}"
        if (!exists(Path("${caseRoot}/metadata.json")) ||
            !exists(Path("${caseRoot}/prompt.md")) ||
            !exists(Path("${caseRoot}/starter/cjpm.toml")) ||
            !exists(Path("${caseRoot}/starter/src/solution.cj")) ||
            !exists(Path("${caseRoot}/starter/src/eval_support.cj")) ||
            !exists(Path("${caseRoot}/tests/TestMain.cj")) ||
            !exists(Path("${caseRoot}/tests/cjpm.executable.toml"))) {
            return false
        }
    }
    true
}

private func ckbAbcdeManifestLineCount(path: String): Int64 {
    var count: Int64 = 0
    for (line in ckbAbcdeReadText(path).split("\n")) {
        if (line.trimAscii() != "") {
            count += 1
        }
    }
    count
}

private func ckbAbcdeClaudeSettingsLooksGlm52(): Bool {
    let home = match (getVariable("HOME")) {
        case Some(value) => value
        case None => ""
    }
    if (home == "") {
        return false
    }
    let text = ckbAbcdeReadText("${home}/.claude/settings.json")
    text.contains("GLM-5.2") &&
        text.contains("ANTHROPIC_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_OPUS_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_SONNET_MODEL") &&
        text.contains("ANTHROPIC_DEFAULT_HAIKU_MODEL") &&
        text.contains("CLAUDE_CODE_SUBAGENT_MODEL")
}

private func ckbAbcdeGeneratedRunId(): String {
    let result = ckbAbcdeRunShell("date +%Y%m%d-%H%M%S", "")
    let value = result.stdout.trimAscii()
    if (value == "") { "manual" } else { value }
}

private func ckbAbcdeDefaultRepoRoot(): String {
    match (getVariable("CKB_REPO_ROOT")) {
        case Some(value) => value
        case None => "/Users/l3gi0n/work/workspace_cangjie/CangjieCommunityKnowledgeBase"
    }
}

public func ckbAbcdeOptionsSafetyDiagnostic(options: CkbAbcdeRunnerOptions): String {
    if (options.runsRoot != "/Users/l3gi0n/Downloads/ckbtest") {
        return "runs_root_must_be_/Users/l3gi0n/Downloads/ckbtest"
    }
    if (!ckbAbcdeSafePathSegment(options.runId)) {
        return "unsafe_run_id"
    }
    if (options.caseStart < 0 || options.caseEnd > 163 || options.caseStart > options.caseEnd) {
        return "case_range_must_be_0_163"
    }
    if (options.groups.size == 0) {
        return "groups_must_not_be_empty"
    }
    if (!options.ckbHttpBase.startsWith("http://127.0.0.1:") && !options.ckbHttpBase.startsWith("http://localhost:")) {
        return "ckb_http_base_must_be_loopback_http"
    }
    "ok"
}

private func ckbAbcdeSafePathSegment(value: String): Bool {
    let trimmed = value.trimAscii()
    if (trimmed == "" || trimmed == "." || trimmed == "..") {
        return false
    }
    if (trimmed.contains("/") || trimmed.contains("\\") || trimmed.contains("..") ||
        trimmed.contains("$") || trimmed.contains("'") || trimmed.contains("\"") ||
        trimmed.contains("`") || trimmed.contains("\n") || trimmed.contains("\r")) {
        return false
    }
    true
}

private func ckbAbcdeParseInt(value: String, fallback: Int64): Int64 {
    try {
        Int64.parse(value)
    } catch (_: Exception) {
        fallback
    }
}

private func ckbAbcdeParseCaseIndex(value: String): Int64 {
    let trimmed = value.trimAscii()
    if (trimmed.startsWith("CJ-HUMANEVAL-")) {
        return ckbAbcdeParseInt(trimmed.replace("CJ-HUMANEVAL-", ""), 0)
    }
    ckbAbcdeParseInt(trimmed, 0)
}

private func ckbAbcdeParseGroups(value: String): ArrayList<String> {
    let groups = ArrayList<String>()
    for (raw in value.split(",")) {
        let item = raw.trimAscii()
        let group = if (item == "A" || item == CkbAbcdeGroups.A) {
            CkbAbcdeGroups.A
        } else if (item == "B" || item == CkbAbcdeGroups.B) {
            CkbAbcdeGroups.B
        } else if (item == "C" || item == CkbAbcdeGroups.C) {
            CkbAbcdeGroups.C
        } else if (item == "D" || item == CkbAbcdeGroups.D) {
            CkbAbcdeGroups.D
        } else if (item == "E" || item == CkbAbcdeGroups.E) {
            CkbAbcdeGroups.E
        } else {
            ""
        }
        if (group != "") {
            groups.add(group)
        }
    }
    groups
}

private func ckbAbcdeCaseId(index: Int64): String {
    if (index < 10) {
        return "CJ-HUMANEVAL-00${index}"
    }
    if (index < 100) {
        return "CJ-HUMANEVAL-0${index}"
    }
    "CJ-HUMANEVAL-${index}"
}

private func ckbAbcdeShellQuote(value: String): String {
    "'" + value.replace("'", "'\\''") + "'"
}

public func ckbAbcdeNativeTlsBootstrapScript(command: String, args: Array<String>): String {
    var script = "export CKB_NATIVE_TLS_BOOTSTRAPPED=1; " +
        "MAGIC_ROOT=\"" + "$" + "{MAGIC_PATH:-}\"; " +
        "if [ -z \"" + "$" + "{MAGIC_ROOT}\" ]; then MAGIC_ROOT=\"" + "$" + "{CKB_MAGIC_ROOT:-}\"; fi; " +
        "CANGJIE_ROOT=\"" + "$" + "{CANGJIE_HOME:-}\"; " +
        "if [ -z \"" + "$" + "{CANGJIE_ROOT}\" ]; then CANGJIE_ROOT=\"" + "$" + "{CKB_CANGJIE_ROOT:-}\"; fi; " +
        "CKB_DYLD_EXTRA=\"/opt/homebrew/opt/openssl@3/lib:/opt/homebrew/opt/openssl@3.5/lib:/usr/local/opt/openssl@3/lib:/Users/l3gi0n/cangjie100/runtime/lib/darwin_aarch64_llvm:/Users/l3gi0n/work/workspace_cangjie/CangjieMagic/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx:/Users/l3gi0n/work/workspace_cangjie/Metis/ffi\"; " +
        "if [ -n \"" + "$" + "{CANGJIE_ROOT}\" ]; then CKB_DYLD_EXTRA=\"" + "$" + "{CKB_DYLD_EXTRA}:" + "$" + "{CANGJIE_ROOT}/runtime/lib/darwin_aarch64_llvm\"; fi; " +
        "if [ -n \"" + "$" + "{MAGIC_ROOT}\" ]; then CKB_DYLD_EXTRA=\"" + "$" + "{CKB_DYLD_EXTRA}:" + "$" + "{MAGIC_ROOT}/libs/cangjie-stdx-mac-aarch64-1.0.0.1/darwin_aarch64_llvm/dynamic/stdx\"; fi; " +
        "export DYLD_LIBRARY_PATH=\"" +
        "$" + "{CKB_DYLD_EXTRA}:" +
        "$" + "{DYLD_LIBRARY_PATH}\"; " +
        "exec " + ckbAbcdeShellQuote(command)
    for (arg in args) {
        script += " " + ckbAbcdeShellQuote(arg)
    }
    script
}

private func ckbAbcdeUsage(): String {
    "Usage: cangjie_community_knowledge_base cangjie-eval-abcde --run-mode <development|certification> --run-id <id> --dataset-version <version> --knowledge-version <version> --model-fingerprint <sha256> [--candidate-version <version>] [--model-timeout-seconds <1..3600, default 180>] [--model-effort <low|medium|high|xhigh|max> --model-max-budget-usd <positive>] [--case-id CJ-HUMANEVAL-000|--case-start 0 --case-end 163] [--groups C|D] [--runs-root <path>] [--ckb-http-base <url>] [--ckb-bin <path>] [--ckb-store <path>] [--dataset-root <path>] [--manifest <authority.jsonl>] [--docs-root <path>] [--certification-preflight <preflight.json> --certification-run-manifest <run-manifest.json> --expected-model-version <exact> --provider-identity-hash <sha256> --provider-identity-artifact <redacted.json>]\n"
}
